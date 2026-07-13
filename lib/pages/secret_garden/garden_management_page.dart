part of '../../app.dart';

class GardenManagementScreen extends StatefulWidget {
  const GardenManagementScreen({super.key});
  @override
  State<GardenManagementScreen> createState() => _GardenManagementScreenState();
}

class _GardenManagementScreenState extends State<GardenManagementScreen> {
  late Future<List<GardenAlbumItem>> albums;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => albums = MapLovRepository.instance.gardenAlbums();

  Future<void> _create() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create private album'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Album name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    await MapLovRepository.instance.createGardenAlbum(title);
    if (mounted) setState(_reload);
  }

  Future<void> _addPhoto(GardenAlbumItem album) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;
    await MapLovRepository.instance.uploadGardenPhoto(
      albumId: album.id,
      bytes: await image.readAsBytes(),
      extension: image.name.split('.').last,
    );
    if (mounted) setState(_reload);
  }

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
      FutureBuilder<List<GardenAlbumItem>>(
        future: albums,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <GardenAlbumItem>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: items
                .map(
                  (album) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.photo_library_outlined,
                        color: AppColors.coral,
                      ),
                      title: Text(album.title),
                      subtitle: Text('${album.photoCount} photos'),
                      trailing: IconButton(
                        onPressed: () => _addPhoto(album),
                        tooltip: 'Add private photo',
                        icon: const Icon(Icons.add_a_photo_outlined),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GardenViewerScreen(album: album),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      OutlinedButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Create private album'),
      ),
      const _SectionTitle('Access control'),
      Card(
        child: ListTile(
          leading: const Icon(Icons.pending_actions_outlined),
          title: const Text('Access requests'),
          subtitle: const Text('Review waiting requests'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.gardenAccessRequests),
        ),
      ),
    ],
  );
}
