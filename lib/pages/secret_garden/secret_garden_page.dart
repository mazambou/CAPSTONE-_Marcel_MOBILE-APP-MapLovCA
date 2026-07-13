part of '../../app.dart';

class SecretGardenScreen extends StatefulWidget {
  const SecretGardenScreen({super.key});
  @override
  State<SecretGardenScreen> createState() => _SecretGardenScreenState();
}

class _SecretGardenScreenState extends State<SecretGardenScreen> {
  String duration = '10 min';
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Secret Garden',
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/secret_garden/secret_garden_locked_placeholder.png',
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const _SectionTitle('Private album'),
      const Text(
        'Request time-limited access. The owner can revoke access at any time.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: ['5 min', '10 min', '20 min', '1 hour', 'Permanent']
            .map(
              (d) => ChoiceChip(
                label: Text(d),
                selected: duration == d,
                onSelected: (_) => setState(() => duration = d),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      _PrimaryButton('Request access', onPressed: () {}),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.gardenManagement),
        icon: const Icon(Icons.settings_outlined),
        label: const Text('Manage my Secret Garden'),
      ),
      const _SectionTitle('Access history'),
      const ListTile(
        leading: Icon(Icons.history),
        title: Text('Sophie’s album'),
        subtitle: Text('10 min • Expired yesterday'),
      ),
    ],
  );
}
