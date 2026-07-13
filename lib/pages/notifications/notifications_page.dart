part of '../../app.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.chat_bubble_outline,
        'New message',
        'Sophie sent you a message.',
        'Now',
      ),
      (
        Icons.person_add_alt,
        'Friend request',
        'Alex wants to connect with you.',
        '10m',
      ),
      (
        Icons.lock_open_outlined,
        'Secret Garden request',
        'Taylor requested temporary access.',
        '1h',
      ),
      (
        Icons.favorite_outline,
        'New like',
        'Your post received 5 new likes.',
        '3h',
      ),
      (
        Icons.comment_outlined,
        'New comment',
        'Sophie commented on your post.',
        'Yesterday',
      ),
    ];
    return _AppPage(
      title: 'Notifications',
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('Mark all as read'),
          ),
        ),
        ...items.indexed.map(
          (entry) => Card(
            color: entry.$1 < 2 ? AppColors.palePink : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.blush,
                child: Icon(entry.$2.$1, color: AppColors.coral),
              ),
              title: Text(
                entry.$2.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(entry.$2.$3),
              trailing: Text(entry.$2.$4, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }
}
