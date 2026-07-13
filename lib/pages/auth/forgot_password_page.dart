part of '../../app.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) setState(() => _emailSent = true);
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = AuthService.instance.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Forgot password',
    children: [
      const Icon(Icons.lock_reset, size: 84, color: AppColors.coral),
      const SizedBox(height: 18),
      Text(
        _emailSent ? 'Check your inbox' : 'Reset your password',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        _emailSent
            ? 'If an account exists for this email, a secure reset link has been sent.'
            : 'Enter the email connected to your MapLov account. We will send you a secure reset link.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 28),
      _Field(
        'Email address',
        Icons.email_outlined,
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        enabled: !_isLoading,
        onSubmitted: (_) => _sendResetLink(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 10),
        Text(_errorText!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 20),
      _PrimaryButton(
        _emailSent ? 'Resend reset link' : 'Send reset link',
        onPressed: _isLoading ? () {} : _sendResetLink,
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to login'),
      ),
    ],
  );
}
