part of '../../app.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool discoverable = true;
  bool approximateDistance = true;
  bool onlineStatus = false;

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Privacy',
    children: [
      SwitchListTile(
        value: discoverable,
        onChanged: (value) => setState(() => discoverable = value),
        title: const Text('Show my profile in Discover'),
        subtitle: const Text('Allow eligible users to find your profile.'),
      ),
      SwitchListTile(
        value: approximateDistance,
        onChanged: (value) => setState(() => approximateDistance = value),
        title: const Text('Show approximate distance'),
        subtitle: const Text('Your exact location is never displayed.'),
      ),
      SwitchListTile(
        value: onlineStatus,
        onChanged: (value) => setState(() => onlineStatus = value),
        title: const Text('Show online status'),
      ),
      const _SectionTitle('Private content'),
      const ListTile(
        leading: Icon(Icons.people_outline),
        title: Text('Post visibility'),
        subtitle: Text('Friends only'),
      ),
      ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Secret Garden access'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.gardenManagement),
      ),
    ],
  );
}
