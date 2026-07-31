part of '../../app.dart';

class MagicLinkScreen extends StatefulWidget {
  const MagicLinkScreen({super.key});

  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

class _MagicLinkScreenState extends State<MagicLinkScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
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
      await AuthService.instance.sendMagicLink(email);
      if (mounted) setState(() => _sent = true);
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
    title: 'Magic Link',
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        size: 84,
        color: AppColors.coral,
      ),
      const SizedBox(height: 18),
      Text(
        _sent ? 'Check your inbox' : 'Sign in without a password',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        _sent
            ? 'If this email belongs to an existing MapLov account, a secure sign-in link has been sent.'
            : 'Enter your account email. The link opens MapLov and signs you in on this device.',
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
        onSubmitted: (_) => _send(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 10),
        Text(_errorText!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 20),
      _PrimaryButton(
        _sent ? 'Resend Magic Link' : 'Send Magic Link',
        onPressed: _isLoading ? () {} : _send,
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to login'),
      ),
    ],
  );
}
