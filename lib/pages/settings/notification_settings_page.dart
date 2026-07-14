part of '../../app.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, bool>? values;
  static const labels = {
    'messages': 'Messages',
    'friend_requests': 'Friend requests',
    'post_activity': 'Post likes and comments',
    'garden_requests': 'Secret Garden requests',
    'compatibility_suggestions': 'Compatibility suggestions',
    'marketing': 'Marketing updates',
    'security': 'Security alerts',
    'push_enabled': 'Push notifications',
    'in_app_enabled': 'In-app notifications',
    'email_important': 'Important events by email',
    'quiet_hours_enabled': 'Quiet hours (10 PM–7 AM)',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final loaded = await MapLovRepository.instance.notificationPreferences();
    if (mounted) setState(() => values = loaded);
  }

  Future<void> _change(String key, bool value) async {
    setState(() => values![key] = value);
    await MapLovRepository.instance.saveNotificationPreferences(values!);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Notification settings',
    children: [
      const Text(
        'Security notifications cannot be disabled.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 12),
      if (values == null)
        const Center(child: CircularProgressIndicator())
      else
        ...values!.entries.map(
          (entry) => SwitchListTile(
            value: entry.value,
            onChanged: entry.key == 'security'
                ? null
                : (value) => _change(entry.key, value),
            title: Text(labels[entry.key] ?? entry.key),
          ),
        ),
    ],
  );
}
