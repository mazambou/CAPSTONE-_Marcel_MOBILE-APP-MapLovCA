part of '../../app.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestChange() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }
    if (email == AuthService.instance.currentEmail?.toLowerCase()) {
      setState(() => _errorText = 'Enter a different email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await AuthService.instance.requestEmailChange(email);
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
    title: 'Change email address',
    children: [
      const Icon(Icons.alternate_email, size: 76, color: AppColors.coral),
      const SizedBox(height: 18),
      Text(
        _sent ? 'Confirm the email change' : 'Use a new email address',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        _sent
            ? 'For your security, follow the confirmation instructions sent by MapLov. Supabase may require approval from both the current and new addresses.'
            : 'Current email: ${AuthService.instance.currentEmail ?? 'Unavailable'}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 24),
      _Field(
        'New email address',
        Icons.email_outlined,
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        enabled: !_isLoading,
        onSubmitted: (_) => _requestChange(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 10),
        Text(_errorText!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 20),
      _PrimaryButton(
        _sent ? 'Resend confirmation' : 'Request email change',
        onPressed: _isLoading ? () {} : _requestChange,
      ),
    ],
  );
}
