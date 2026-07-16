part of '../../app.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  late Future<List<FriendshipItem>> items;
  String query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      items = MapLovRepository.instance.friendships(status: 'accepted');

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Friends',
    children: [
      TextField(
        onChanged: (value) =>
            setState(() => query = value.trim().toLowerCase()),
        decoration: const InputDecoration(
          hintText: 'Search friends',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<FriendshipItem>>(
        future: items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final friends = (snapshot.data ?? const <FriendshipItem>[]).where(
            (item) => item.profile.name.toLowerCase().contains(query),
          );
          return Column(
            children: friends
                .map(
                  (item) => Card(
                    child: ListTile(
                      onTap: () async {
                        if (!await _requireProfilePhotos(context, minimum: 3) ||
                            !context.mounted) {
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PublicProfileScreen(profile: item.profile),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundImage: profileImageProvider(item.profile),
                      ),
                      title: Text(
                        item.profile.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.profile.city),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'message',
                            child: Text('Message'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove friend'),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text('Block user'),
                          ),
                          PopupMenuItem(
                            value: 'report',
                            child: Text('Report user'),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'message') {
                            final id = await MapLovRepository.instance
                                .startConversation(item.profile.id);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: id,
                                    profile: item.profile,
                                  ),
                                ),
                              );
                            }
                          } else if (value == 'remove') {
                            await MapLovRepository.instance.removeFriendship(
                              item.id,
                            );
                            if (mounted) setState(_reload);
                          } else if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => value == 'block'
                                    ? BlockUserScreen(profile: item.profile)
                                    : ReportUserScreen(profile: item.profile),
                              ),
                            );
                          }
                        },
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
