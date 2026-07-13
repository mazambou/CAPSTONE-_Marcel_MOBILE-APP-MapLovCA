part of '../../app.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<ConversationItem>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = MapLovRepository.instance.conversations();
  }

  @override
  Widget build(BuildContext context) => _MainPage(
    index: 1,
    title: 'Messages',
    children: [
      SizedBox(
        height: 150,
        child: Image.asset('assets/chat/chat_conversation_placeholder.png'),
      ),
      FutureBuilder<List<ConversationItem>>(
        future: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <ConversationItem>[];
          if (items.isEmpty) {
            return const ListTile(
              leading: Icon(Icons.forum_outlined),
              title: Text('No conversations yet'),
              subtitle: Text('Open a profile and tap Message to start.'),
            );
          }
          return Column(
            children: items
                .map(
                  (item) => ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: item.id,
                          profile: item.profile,
                        ),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundImage: profileImageProvider(item.profile),
                    ),
                    title: Text(
                      item.profile.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      item.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.unread > 0
                        ? Badge(label: Text('${item.unread}'))
                        : null,
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}
