part of '../../app.dart';

class GardenManagementScreen extends StatelessWidget {
  const GardenManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Manage Secret Garden',
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/secret_garden/secret_garden_locked_placeholder.png',
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const _SectionTitle('Private albums'),
      Card(
        child: ListTile(
          leading: const Icon(
            Icons.photo_library_outlined,
            color: AppColors.coral,
          ),
          title: const Text('My private moments'),
          subtitle: const Text('6 photos • 2 active viewers'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.gardenViewer),
        ),
      ),
      OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Create private album'),
      ),
      const _SectionTitle('Access control'),
      Card(
        child: ListTile(
          leading: const Icon(Icons.pending_actions_outlined),
          title: const Text('Access requests'),
          subtitle: const Text('2 requests waiting'),
          trailing: const Badge(label: Text('2')),
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.gardenAccessRequests),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.history),
          title: Text('Access history'),
          subtitle: Text('Review active, expired and revoked access'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    ],
  );
}
