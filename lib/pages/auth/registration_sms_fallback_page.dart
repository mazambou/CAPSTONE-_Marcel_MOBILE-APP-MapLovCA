part of '../../app.dart';

class RegistrationSmsFallbackScreen extends StatefulWidget {
  const RegistrationSmsFallbackScreen({super.key, this.email});

  final String? email;

  @override
  State<RegistrationSmsFallbackScreen> createState() =>
      _RegistrationSmsFallbackScreenState();
}

class _RegistrationSmsFallbackScreenState
    extends State<RegistrationSmsFallbackScreen> {
  final _codeController = TextEditingController();
  String? _phone;
  String? _message;
  bool _messageIsError = false;
  bool _loading = false;
  bool _codeSent = false;

  String? get _email =>
      widget.email ?? AuthService.instance.emailForVerification;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhone());
  }

  Future<void> _loadPhone() async {
    final phone = await AuthService.instance.phoneNumberForVerification();
    if (mounted) setState(() => _phone = phone);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email;
    final phone = _phone;
    if (email == null || phone == null) {
      setState(() {
        _message = 'Your registration phone number is unavailable. Return to email verification.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService.instance.sendRegistrationSmsFallback(
        email: email,
        phone: phone,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _codeController.clear();
        _message = 'A verification code was sent by SMS.';
        _messageIsError = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _email;
    final phone = _phone;
    if (email == null ||
        phone == null ||
        !RegExp(r'^\d{4,10}$').hasMatch(_codeController.text.trim())) {
      setState(() {
        _message = 'Enter the code sent by SMS.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService.instance.verifyRegistrationSmsFallback(
        email: email,
        phone: phone,
        code: _codeController.text,
      );
      if (!mounted) return;
      setState(() {
        _message = 'Phone verified. Continuing…';
        _messageIsError = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Verify with SMS',
    children: [
      const Icon(Icons.sms_outlined, size: 88, color: AppColors.coral),
      const SizedBox(height: 18),
      Text(
        'Your email is taking longer than expected',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        _phone == null
            ? 'Your registration phone number is unavailable. Return to email verification.'
            : context
                  .tr('We can send a code to {phone}.')
                  .replaceFirst('{phone}', _phone!),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
      const Text(
        'SMS verifies your phone number. Your email will remain unverified until you confirm it later in Security.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 24),
      if (_codeSent) ...[
        const SizedBox(height: 14),
        TextField(
          key: const Key('registration_sms_code'),
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          enabled: !_loading,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => _verifyCode(),
          decoration: InputDecoration(
            labelText: context.tr('SMS code'),
            prefixIcon: const Icon(Icons.password_outlined),
          ),
        ),
      ],
      if (_message != null) ...[
        const SizedBox(height: 10),
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
        _loading
            ? 'Please wait…'
            : _codeSent
            ? 'Verify SMS code'
            : 'Send SMS code',
        onPressed: _loading || _phone == null
            ? () {}
            : _codeSent
            ? _verifyCode
            : _sendCode,
      ),
      if (_codeSent)
        TextButton(
          onPressed: _loading ? null : _sendCode,
          child: const Text('Resend SMS code'),
        ),
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('Use email code instead'),
      ),
    ],
  );
}
