part of '../../app.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Blocked users',
    children: [
      const Text(
        'Blocked people cannot find your profile, message you or interact with your content.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
          title: const Text('Blocked profile'),
          subtitle: const Text('Blocked 3 days ago'),
          trailing: TextButton(onPressed: () {}, child: const Text('Unblock')),
        ),
      ),
    ],
  );
}
