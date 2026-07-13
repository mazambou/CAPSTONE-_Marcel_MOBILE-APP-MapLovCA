part of '../../app.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, this.email});

  final String? email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  StreamSubscription<MapLovAuthEvent>? _authSubscription;
  bool _isLoading = false;
  String? _message;
  bool _messageIsError = false;

  String get _email =>
      widget.email ?? AuthService.instance.currentEmail ?? 'your email address';

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.instance.events.listen((event) {
      if (event == MapLovAuthEvent.signedIn ||
          event == MapLovAuthEvent.userUpdated) {
        _continueToProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final verified = await AuthService.instance
          .refreshAndCheckEmailVerification();
      if (!mounted) return;
      if (verified) {
        _continueToProfile();
      } else {
        setState(() {
          _message = 'Your email is not verified yet. Check your inbox.';
          _messageIsError = true;
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
          _message = 'A new verification email has been sent.';
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
        'We sent a verification link to $_email. Verify your email to continue creating your profile.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grayText),
      ),
      if (_message != null) ...[
        const SizedBox(height: 16),
        Text(
          _message!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _messageIsError ? AppColors.error : AppColors.success,
          ),
        ),
      ],
      const SizedBox(height: 28),
      _PrimaryButton(
        _isLoading ? 'Checking...' : 'I verified my email',
        onPressed: _isLoading ? () {} : _checkVerification,
      ),
      OutlinedButton(
        onPressed: _isLoading ? null : _resend,
        child: const Text('Resend verification email'),
      ),
    ],
  );
}
