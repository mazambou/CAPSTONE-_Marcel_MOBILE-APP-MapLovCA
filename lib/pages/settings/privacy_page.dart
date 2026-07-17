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
  bool vip = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await MapLovRepository.instance.myProfileDetails();
    final subscription = await MapLovRepository.instance.subscriptionInfo();
    if (!mounted) return;
    setState(() {
      discoverable = profile?['is_discoverable'] as bool? ?? true;
      approximateDistance =
          profile?['show_approximate_distance'] as bool? ?? true;
      onlineStatus = profile?['show_online_status'] as bool? ?? false;
      vip = subscription.isVip;
    });
  }

  Future<void> _save(String key, bool value) async {
    await MapLovRepository.instance.saveMyProfile({key: value});
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Privacy',
    children: [
      SwitchListTile(
        value: discoverable,
        onChanged: (value) {
          if (!value && !vip) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invisible navigation requires Premium VIP.'),
              ),
            );
            Navigator.pushNamed(context, AppRoutes.premium);
            return;
          }
          setState(() => discoverable = value);
          unawaited(_save('is_discoverable', value));
        },
        title: const Text('Show my profile in Discover'),
        subtitle: const Text(
          'VIP members can stay out of Discover. People can see your profile after you like them or send them a message.',
        ),
      ),
      SwitchListTile(
        value: approximateDistance,
        onChanged: (value) {
          setState(() => approximateDistance = value);
          unawaited(_save('show_approximate_distance', value));
        },
        title: const Text('Show approximate distance'),
        subtitle: const Text('Your exact location is never displayed.'),
      ),
      SwitchListTile(
        value: onlineStatus,
        onChanged: (value) {
          setState(() => onlineStatus = value);
          unawaited(_save('show_online_status', value));
        },
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
