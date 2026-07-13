part of '../../app.dart';

class SecretGardenScreen extends StatefulWidget {
  const SecretGardenScreen({super.key, this.owner});
  final UserProfile? owner;

  @override
  State<SecretGardenScreen> createState() => _SecretGardenScreenState();
}

class _SecretGardenScreenState extends State<SecretGardenScreen> {
  String duration = '10 min';
  late Future<List<GardenAlbumItem>> albums;

  @override
  void initState() {
    super.initState();
    albums = MapLovRepository.instance.gardenAlbums(ownerId: widget.owner?.id);
  }

  int? get seconds => switch (duration) {
    '5 min' => 300,
    '10 min' => 600,
    '20 min' => 1200,
    '1 hour' => 3600,
    _ => null,
  };

  Future<void> _request(GardenAlbumItem album) async {
    try {
      await MapLovRepository.instance.requestGardenAccess(album.id, seconds);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Access request sent.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to request access: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: widget.owner == null
        ? 'Secret Garden'
        : '${widget.owner!.name}’s Secret Garden',
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
      const _SectionTitle('Private albums'),
      const Text(
        'Access is time-limited. The owner can revoke it at any time.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: ['5 min', '10 min', '20 min', '1 hour', 'Permanent']
            .map(
              (value) => ChoiceChip(
                label: Text(value),
                selected: duration == value,
                onSelected: (_) => setState(() => duration = value),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 14),
      FutureBuilder<List<GardenAlbumItem>>(
        future: albums,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <GardenAlbumItem>[];
          if (items.isEmpty) {
            return const Text('No private album is available.');
          }
          return Column(
            children: items
                .map(
                  (album) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.lock_outline,
                        color: AppColors.coral,
                      ),
                      title: Text(album.title),
                      subtitle: Text('${album.photoCount} private photos'),
                      trailing: widget.owner == null
                          ? const Icon(Icons.chevron_right)
                          : FilledButton(
                              onPressed: () => _request(album),
                              child: const Text('Request access'),
                            ),
                      onTap: widget.owner == null
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GardenViewerScreen(album: album),
                              ),
                            )
                          : null,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      if (widget.owner == null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.gardenManagement),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Manage my Secret Garden'),
        ),
      ],
    ],
  );
}
