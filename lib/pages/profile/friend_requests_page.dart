part of '../../app.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});
  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  late Future<List<FriendshipItem>> requests;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    requests = MapLovRepository.instance.friendships(status: 'pending');
  }

  Future<void> _respond(FriendshipItem item, bool accept) async {
    try {
      await MapLovRepository.instance.respondToFriendRequest(item.id, accept);
      if (mounted) setState(() => _reload());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update friend request: $error')),
        );
      }
    }
  }

  Future<void> _cancel(FriendshipItem item) async {
    try {
      await MapLovRepository.instance.removeFriendship(item.id, cancel: true);
      if (mounted) setState(() => _reload());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to cancel friend request: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Friend requests'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: FutureBuilder<List<FriendshipItem>>(
        future: requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => setState(() => _reload()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry friend requests'),
              ),
            );
          }
          final all = snapshot.data ?? const <FriendshipItem>[];
          final received = all.where((item) => !item.sentByMe).toList();
          final sent = all.where((item) => item.sentByMe).toList();
          return TabBarView(
            children: [
              received.isEmpty
                  ? const _EmptyFriendState(
                      icon: Icons.mark_email_read_outlined,
                      message: 'No received friend requests.',
                    )
                  : ListView(
                      children: received
                          .map(
                            (item) => ListTile(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfileScreen(
                                    profile: item.profile,
                                  ),
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundImage: profileImageProvider(
                                  item.profile,
                                ),
                              ),
                              title: Text(item.profile.name),
                              subtitle: const Text('Wants to connect'),
                              trailing: Wrap(
                                children: [
                                  IconButton(
                                    tooltip: 'Accept request',
                                    onPressed: () => _respond(item, true),
                                    icon: const Icon(
                                      Icons.check,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Decline request',
                                    onPressed: () => _respond(item, false),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
              sent.isEmpty
                  ? const _EmptyFriendState(
                      icon: Icons.outbox_outlined,
                      message: 'No sent friend requests.',
                    )
                  : ListView(
                      children: sent
                          .map(
                            (item) => ListTile(
                              leading: CircleAvatar(
                                backgroundImage: profileImageProvider(
                                  item.profile,
                                ),
                              ),
                              title: Text(item.profile.name),
                              trailing: TextButton(
                                onPressed: () => _cancel(item),
                                child: const Text('Cancel'),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ],
          );
        },
      ),
    ),
  );
}

class _EmptyFriendState extends StatelessWidget {
  const _EmptyFriendState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: AppColors.softPink),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: AppColors.grayText)),
      ],
    ),
  );
}
