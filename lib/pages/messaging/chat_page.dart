part of '../../app.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sophie'),
      actions: [
        PopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'block', child: Text('Block user')),
            PopupMenuItem(value: 'report', child: Text('Report user')),
          ],
          onSelected: (v) => Navigator.pushNamed(
            context,
            v == 'block' ? AppRoutes.blockUser : AppRoutes.reportUser,
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                _Bubble('Hi! How was your day?', false),
                _Bubble('Great! I found a new café downtown.', true),
                _Bubble('Want to try it this weekend?', true),
                _Bubble('Absolutely 😊', false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Message...'),
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.mic_none)),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.send, color: AppColors.coral),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
