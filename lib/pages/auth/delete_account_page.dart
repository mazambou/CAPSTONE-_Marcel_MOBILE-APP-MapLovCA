part of '../../app.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_confirmationController.text.trim() != 'DELETE') {
      setState(() => _errorText = 'Type DELETE exactly to confirm.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await AuthService.instance.requestAccountDeletion();
      if (!mounted) return;
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
    title: 'Delete account',
    children: [
      const Icon(Icons.warning_amber_rounded, size: 82, color: AppColors.error),
      const SizedBox(height: 18),
      const Text(
        'This action is permanent',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'Your profile will immediately become unavailable. Your data will then follow the legal retention and deletion process.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 24),
      _Field(
        'Type DELETE to confirm',
        Icons.delete_outline,
        controller: _confirmationController,
        enabled: !_isLoading,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _deleteAccount(),
      ),
      if (_errorText != null) ...[
        const SizedBox(height: 10),
        Text(_errorText!, style: const TextStyle(color: AppColors.error)),
      ],
      const SizedBox(height: 18),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        onPressed: _isLoading ? null : _deleteAccount,
        child: Text(
          _isLoading ? 'Deleting account...' : 'Permanently delete my account',
        ),
      ),
      TextButton(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
