part of '../../app.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final values = <String, bool>{
    'Messages': true,
    'Friend requests': true,
    'Post likes and comments': true,
    'Secret Garden requests': true,
    'Compatibility suggestions': false,
    'Marketing updates': false,
  };

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Notification settings',
    children: [
      const Text(
        'Security notifications cannot be disabled.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 12),
      ...values.entries.map(
        (entry) => SwitchListTile(
          value: entry.value,
          onChanged: (value) => setState(() => values[entry.key] = value),
          title: Text(entry.key),
        ),
      ),
    ],
  );
}
