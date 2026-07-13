part of '../../app.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

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
        'Your profile, messages, posts and private albums will be scheduled for deletion. This cannot be undone after the legal retention period.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 24),
      const _Field('Type DELETE to confirm', Icons.delete_outline),
      const SizedBox(height: 18),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        ),
        child: const Text('Permanently delete my account'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
