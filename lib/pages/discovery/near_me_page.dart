part of '../../app.dart';

class NearMeScreen extends StatefulWidget {
  const NearMeScreen({super.key});
  @override
  State<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends State<NearMeScreen> {
  double distance = 10;
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
        onChanged: (v) => setState(() => distance = v),
      ),
      Wrap(
        spacing: 8,
        children: [1, 2, 5, 10, 25, 50]
            .map(
              (km) => ChoiceChip(
                label: Text('$km km'),
                selected: distance == km,
                onSelected: (_) => setState(() => distance = km.toDouble()),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      ...mockProfiles.map(
        (p) => ListTile(
          leading: CircleAvatar(backgroundImage: AssetImage(p.imagePath)),
          title: Text('${p.name}, ${p.age}'),
          subtitle: Text('${p.city} • About ${(p.age % 5) + 1} km away'),
        ),
      ),
    ],
  );
}
