part of '../../app.dart';

class BlockUserScreen extends StatelessWidget {
  const BlockUserScreen({super.key});
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Block user',
    children: [
      const _UserSafetyCard(),
      const SizedBox(height: 18),
      const Text(
        'After blocking, you will no longer see each other, exchange messages, or receive notifications. You can unblock this person later in Settings.',
      ),
      const SizedBox(height: 24),
      _PrimaryButton('Confirm block', onPressed: () => Navigator.pop(context)),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
