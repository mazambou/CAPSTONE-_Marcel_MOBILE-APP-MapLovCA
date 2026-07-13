part of '../../app.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    if (password.length < 8 ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      setState(
        () => _errorText =
            'Use at least 8 characters, including a number and a symbol.',
      );
      return;
    }
    if (password != _confirmationController.text) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await AuthService.instance.updatePassword(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your password has been updated.')),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
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
    title: 'Create new password',
    children: [
      const Icon(
        Icons.verified_user_outlined,
        size: 76,
        color: AppColors.coral,
      ),
      const SizedBox(height: 18),
      const Text(
        'Choose a strong password with at least 8 characters, one number and one symbol.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 26),
      _Field(
        'New password',
        Icons.lock_outline,
        secret: true,
        controller: _passwordController,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        enabled: !_isLoading,
      ),
      const SizedBox(height: 14),
      _Field(
        'Confirm new password',
        Icons.lock_outline,
        secret: true,
        controller: _confirmationController,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.newPassword],
        enabled: !_isLoading,
        onSubmitted: (_) => _updatePassword(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 10),
        Text(_errorText!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 22),
      _PrimaryButton(
        _isLoading ? 'Updating password...' : 'Update password',
        onPressed: _isLoading ? () {} : _updatePassword,
      ),
    ],
  );
}
