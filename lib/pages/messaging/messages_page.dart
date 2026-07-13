part of '../../app.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 1,
    title: 'Messages',
    children: [
      SizedBox(
        height: 150,
        child: Image.asset('assets/chat/chat_conversation_placeholder.png'),
      ),
      ...mockProfiles.asMap().entries.map(
        (entry) => ListTile(
          onTap: () => Navigator.pushNamed(context, AppRoutes.chat),
          leading: CircleAvatar(
            backgroundImage: AssetImage(entry.value.imagePath),
          ),
          title: Text(
            entry.value.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            entry.key == 0 ? 'That sounds perfect! 😊' : 'See you soon',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.key == 0 ? '18:42' : 'Yesterday',
                style: const TextStyle(fontSize: 12),
              ),
              if (entry.key == 0) const Badge(label: Text('2')),
            ],
          ),
        ),
      ),
    ],
  );
}
