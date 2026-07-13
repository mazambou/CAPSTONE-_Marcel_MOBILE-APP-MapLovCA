part of '../../app.dart';

class NearMeScreen extends StatefulWidget {
  const NearMeScreen({super.key});
  @override
  State<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends State<NearMeScreen> {
  double distance = 10;
  late Future<List<UserProfile>> profiles;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    profiles = _findNearby();
  }

  Future<List<UserProfile>> _findNearby() async {
    if (MapLovRepository.instance.isLive) {
      await LocationService.instance.updateMyLocation();
    }
    return MapLovRepository.instance.discoverProfiles(
      tab: 'Nearby',
      filters: DiscoveryFilters(distanceKm: distance.round()),
    );
  }

  void _setDistance(double value) {
    setState(() {
      distance = value;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) => _MainPage(
    index: 2,
    title: 'Near me',
    children: [
      const Text(
        'Only approximate distance is shown. Exact locations stay private.',
      ),
      Slider(
        value: distance,
        min: 1,
        max: 50,
        divisions: 49,
        label: '${distance.round()} km',
        onChanged: (value) => setState(() => distance = value),
        onChangeEnd: _setDistance,
      ),
      Wrap(
        spacing: 8,
        children: [1, 2, 5, 10, 25, 50]
            .map(
              (km) => ChoiceChip(
                label: Text('$km km'),
                selected: distance == km,
                onSelected: (_) => _setDistance(km.toDouble()),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<UserProfile>>(
        future: profiles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.location_off_outlined),
                title: const Text('Location unavailable'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            );
          }
          final items = snapshot.data ?? const <UserProfile>[];
          return Column(
            children: items
                .map(
                  (profile) => ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicProfileScreen(profile: profile),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundImage: profileImageProvider(profile),
                    ),
                    title: Text('${profile.name}, ${profile.age}'),
                    subtitle: Text(
                      '${profile.city} • About ${profile.distanceKm} km away',
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}
