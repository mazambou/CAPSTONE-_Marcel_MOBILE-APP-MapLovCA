part of '../../app.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String kind) => switch (kind) {
    'message' => Icons.chat_bubble_outline,
    'friend_request' || 'friend_accepted' => Icons.person_add_alt,
    'garden_request' || 'garden_response' => Icons.lock_open_outlined,
    'post_like' => Icons.favorite_outline,
    'post_comment' => Icons.comment_outlined,
    'security' => Icons.shield_outlined,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Notifications',
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () async {
            await MapLovRepository.instance.markNotificationsRead();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications marked as read.')),
              );
            }
          },
          child: const Text('Mark all as read'),
        ),
      ),
      StreamBuilder<List<MapLovNotification>>(
        stream: MapLovRepository.instance.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <MapLovNotification>[];
          if (items.isEmpty) return const Text('No notifications yet.');
          return Column(
            children: items
                .map(
                  (item) => Card(
                    color: item.isRead ? null : AppColors.palePink,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.blush,
                        child: Icon(_icon(item.kind), color: AppColors.coral),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.body),
                      trailing: Text(
                        _relativeTime(item.createdAt),
                        style: const TextStyle(fontSize: 12),
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

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}
