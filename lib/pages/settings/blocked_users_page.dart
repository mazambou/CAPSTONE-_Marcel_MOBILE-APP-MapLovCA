part of '../../app.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late Future<List<UserProfile>> users;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => users = MapLovRepository.instance.blockedUsers();

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Blocked users',
    children: [
      const Text(
        'Blocked people cannot find your profile, message you or interact with your content.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<UserProfile>>(
        future: users,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <UserProfile>[];
          if (items.isEmpty) return const Text('You have not blocked anyone.');
          return Column(
            children: items
                .map(
                  (profile) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profileImageProvider(profile),
                      ),
                      title: Text(profile.name),
                      trailing: TextButton(
                        onPressed: () async {
                          await MapLovRepository.instance.unblockUser(
                            profile.id,
                          );
                          if (mounted) setState(_reload);
                        },
                        child: const Text('Unblock'),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}
