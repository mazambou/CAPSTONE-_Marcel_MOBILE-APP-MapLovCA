part of '../../app.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<Map<String, dynamic>>> users;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => users = MapLovRepository.instance.adminUsers();

  Future<void> _setStatus(String id, String status) async {
    await MapLovRepository.instance.setAccountStatus(id, status);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'User management',
    children: [
      const Text(
        'Only administrators can change account status. Every action is written to the audit log.',
        style: TextStyle(color: AppColors.grayText),
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: users,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Access denied or unavailable: ${snapshot.error}');
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Text('No user data is available in demo mode.');
          }
          return Column(
            children: items
                .map(
                  (user) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        user['first_name'] as String? ?? 'MapLov member',
                      ),
                      subtitle: Text(
                        '${user['city'] ?? ''} • ${user['status']} • ${user['role']}',
                      ),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'active',
                            child: Text('Activate'),
                          ),
                          PopupMenuItem(
                            value: 'suspended',
                            child: Text('Suspend'),
                          ),
                          PopupMenuItem(value: 'banned', child: Text('Ban')),
                        ],
                        onSelected: (status) =>
                            _setStatus(user['id'] as String, status),
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
