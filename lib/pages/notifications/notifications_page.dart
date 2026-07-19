part of '../../app.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String category = 'all';

  IconData _icon(String kind) => switch (kind) {
    'message' => Icons.chat_bubble_outline,
    'friend_request' || 'friend_accepted' => Icons.person_add_alt,
    'garden_request' || 'garden_response' => Icons.lock_open_outlined,
    'post_like' => Icons.favorite_outline,
    'post_comment' => Icons.comment_outlined,
    'security' => Icons.shield_outlined,
    _ => Icons.notifications_none,
  };

  Future<void> _open(MapLovNotification item) async {
    await MapLovRepository.instance.markNotificationRead(item.id);
    if (!mounted) return;
    final route = switch (item.entityType) {
      'conversation' => AppRoutes.messages,
      'post' => AppRoutes.posts,
      'garden_album' => AppRoutes.gardenAccessRequests,
      'profile' => AppRoutes.matches,
      _ => null,
    };
    if (route != null) Navigator.pushNamed(context, route);
  }

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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All')),
            ButtonSegment(value: 'message', label: Text('Messages')),
            ButtonSegment(value: 'friend', label: Text('Friends')),
            ButtonSegment(value: 'garden', label: Text('Garden')),
            ButtonSegment(value: 'post', label: Text('Posts')),
          ],
          selected: {category},
          onSelectionChanged: (value) => setState(() => category = value.first),
        ),
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<MapLovNotification>>(
        stream: MapLovRepository.instance.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data ?? const <MapLovNotification>[];
          final items = all.where((item) {
            if (category == 'all') return true;
            if (category == 'friend') return item.kind.startsWith('friend');
            if (category == 'garden') return item.kind.startsWith('garden');
            if (category == 'post') return item.kind.startsWith('post');
            return item.kind == category;
          }).toList();
          if (items.isEmpty) return const Text('No notifications yet.');
          return Column(
            children: items
                .map(
                  (item) => Card(
                    color: item.isRead ? null : AppColors.palePink,
                    child: ListTile(
                      onTap: () => _open(item),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.blush,
                        child: Icon(_icon(item.kind), color: AppColors.coral),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${context.tr(item.body)}\n'
                        '${context.tr(_relativeTime(item.createdAt))}',
                      ),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'read',
                            child: Text('Mark as read'),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'read') {
                            await MapLovRepository.instance
                                .markNotificationRead(item.id);
                          } else if (value == 'archive') {
                            await MapLovRepository.instance.archiveNotification(
                              item.id,
                            );
                          } else {
                            await MapLovRepository.instance.deleteNotification(
                              item.id,
                            );
                          }
                          if (mounted) setState(() {});
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

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.inMinutes < 1) return 'Now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }
}
