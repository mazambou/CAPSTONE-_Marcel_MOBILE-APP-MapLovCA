part of '../../app.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _messageIsError = false;

  String get _email =>
      widget.email ??
      AuthService.instance.emailForVerification ??
      'your email address';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_email == 'your email address') {
      setState(() {
        _message = 'Return to registration and enter your email address.';
        _messageIsError = true;
      });
      return;
    }
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6,8}$').hasMatch(code)) {
      setState(() {
        _message = 'Enter the verification code sent by email.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await AuthService.instance.verifyEmailCode(email: _email, code: code);
      if (!mounted) return;
      if (!AuthService.instance.isConfigured) {
        _continueToProfile();
      } else {
        setState(() {
          _message = 'Email verified. Continuing…';
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_email == 'your email address') {
      setState(() {
        _message = 'Return to registration and enter your email address.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await AuthService.instance.resendVerificationEmail(_email);
      if (mounted) {
        setState(() {
          _codeController.clear();
          _message = 'A new verification code has been sent.';
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continueToProfile() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.profileSetup,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Verify your email',
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        size: 88,
        color: AppColors.coral,
      ),
      const SizedBox(height: 20),
      Text(
        'Check your inbox',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        'We sent a verification code to $_email. Enter it below to continue creating your profile.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 24),
      TextField(
        key: const Key('email_verification_code'),
        controller: _codeController,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        maxLength: 8,
        autofillHints: const [AutofillHints.oneTimeCode],
        enabled: !_isLoading,
        onSubmitted: (_) => _verify(),
        decoration: InputDecoration(
          labelText: context.tr('Verification code'),
          prefixIcon: const Icon(Icons.password_outlined),
        ),
      ),
      if (_message != null) ...[
        const SizedBox(height: 8),
        Text(
          _message!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _messageIsError ? AppColors.error : AppColors.success,
          ),
        ),
      ],
      const SizedBox(height: 18),
      _PrimaryButton(
        _isLoading ? 'Verifying…' : 'Verify email',
        onPressed: _isLoading ? () {} : _verify,
      ),
      OutlinedButton(
        onPressed: _isLoading ? null : _resend,
        child: const Text('Resend code'),
      ),
    ],
  );
}
