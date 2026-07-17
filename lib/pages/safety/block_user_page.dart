part of '../../app.dart';

class BlockUserScreen extends StatelessWidget {
  const BlockUserScreen({super.key, this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final selected = profile ?? demoProfileOrUnavailable;
    return _AppPage(
      title: 'Block user',
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: profileImageProvider(selected),
          ),
          title: Text(
            selected.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(selected.city),
        ),
        const SizedBox(height: 18),
        const Text(
          'After blocking, you will no longer see each other, exchange messages, or receive notifications. You can unblock this person later in Settings.',
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          'Confirm block',
          onPressed: () async {
            await MapLovRepository.instance.blockUser(selected.id);
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User blocked.')));
              Navigator.pop(context, true);
            }
          },
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
