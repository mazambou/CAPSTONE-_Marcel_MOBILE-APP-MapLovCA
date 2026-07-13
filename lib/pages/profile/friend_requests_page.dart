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

  void _reload() =>
      requests = MapLovRepository.instance.friendships(status: 'pending');

  Future<void> _respond(FriendshipItem item, bool accept) async {
    await MapLovRepository.instance.respondToFriendRequest(item.id, accept);
    if (mounted) setState(_reload);
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
          final all = snapshot.data ?? const <FriendshipItem>[];
          return TabBarView(
            children: [
              ListView(
                children: all
                    .where((item) => !item.sentByMe)
                    .map(
                      (item) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageProvider(item.profile),
                        ),
                        title: Text(item.profile.name),
                        subtitle: const Text('Wants to connect'),
                        trailing: Wrap(
                          children: [
                            IconButton(
                              onPressed: () => _respond(item, true),
                              icon: const Icon(
                                Icons.check,
                                color: AppColors.success,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _respond(item, false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              ListView(
                children: all
                    .where((item) => item.sentByMe)
                    .map(
                      (item) => ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImageProvider(item.profile),
                        ),
                        title: Text(item.profile.name),
                        trailing: TextButton(
                          onPressed: () async {
                            await MapLovRepository.instance.removeFriendship(
                              item.id,
                              cancel: true,
                            );
                            if (mounted) setState(_reload);
                          },
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
