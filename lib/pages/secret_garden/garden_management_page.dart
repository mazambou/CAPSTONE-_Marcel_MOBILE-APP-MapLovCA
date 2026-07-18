part of '../../app.dart';

class GardenManagementScreen extends StatefulWidget {
  const GardenManagementScreen({super.key});
  @override
  State<GardenManagementScreen> createState() => _GardenManagementScreenState();
}

class _GardenManagementScreenState extends State<GardenManagementScreen> {
  late Future<List<GardenAlbumItem>> albums;
  bool creatingAlbum = false;
  String? uploadingAlbumId;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    albums = MapLovRepository.instance.gardenAlbums();
  }

  Future<String?> _requestAlbumTitle({
    required String dialogTitle,
    required String actionLabel,
    String initialValue = '',
  }) async {
    var draft = initialValue;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Album name'),
          textInputAction: TextInputAction.done,
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final title = await _requestAlbumTitle(
      dialogTitle: 'Create private album',
      actionLabel: 'Create',
    );
    if (title == null || title.isEmpty) return;
    setState(() => creatingAlbum = true);
    try {
      await MapLovRepository.instance.createGardenAlbum(title);
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) _showError('Unable to create the private album: $error');
    } finally {
      if (mounted) setState(() => creatingAlbum = false);
    }
  }

  Future<void> _addPhoto(GardenAlbumItem album) async {
    if (uploadingAlbumId != null) return;
    List<XFile> images;
    try {
      images = await pickImagesForUpload(context, imageQuality: 88);
    } catch (error) {
      if (mounted) _showError('Unable to open the camera or gallery: $error');
      return;
    }
    if (images.isEmpty) return;
    setState(() => uploadingAlbumId = album.id);
    try {
      for (final image in images) {
        await MapLovRepository.instance.uploadGardenPhoto(
          albumId: album.id,
          bytes: await image.readAsBytes(),
          extension: image.name.split('.').last.toLowerCase(),
        );
      }
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) _showError('Unable to add the private photo: $error');
    } finally {
      if (mounted) setState(() => uploadingAlbumId = null);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _rename(GardenAlbumItem album) async {
    final title = await _requestAlbumTitle(
      dialogTitle: 'Rename album',
      actionLabel: 'Save',
      initialValue: album.title,
    );
    if (title == null || title.isEmpty) return;
    await MapLovRepository.instance.renameGardenAlbum(album.id, title);
    if (mounted) setState(_reload);
  }

  Future<void> _showHistory() async {
    final history = await MapLovRepository.instance.gardenAccessHistory();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Access history',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (history.isEmpty)
              const ListTile(title: Text('No access history yet.')),
            ...history.map(
              (item) => ListTile(
                leading: Icon(
                  item['status'] == 'approved'
                      ? Icons.lock_open
                      : Icons.history,
                ),
                title: Text('${item['status']}'),
                subtitle: Text(
                  '${item['requested_at'] ?? ''}'.split('T').first,
                ),
                trailing: item['status'] == 'approved'
                    ? TextButton(
                        onPressed: () async {
                          await MapLovRepository.instance.revokeGardenAccess(
                            item['id'] as String,
                          );
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Revoke'),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
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
          if (snapshot.hasError) {
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.error_outline,
                  color: AppColors.coral,
                ),
                title: const Text('Unable to load private albums'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                ),
              ),
            );
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
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'photo',
                            child: Text('Add photos'),
                          ),
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete album'),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'photo') await _addPhoto(album);
                          if (value == 'rename') await _rename(album);
                          if (value == 'delete') {
                            await MapLovRepository.instance.deleteGardenAlbum(
                              album.id,
                            );
                            if (mounted) setState(_reload);
                          }
                        },
                      ),
                      onTap: uploadingAlbumId == album.id
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GardenViewerScreen(
                                  album: album,
                                  canManageAlbum: true,
                                ),
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
        onPressed: creatingAlbum ? null : _create,
        icon: creatingAlbum
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.create_new_folder_outlined),
        label: Text(creatingAlbum ? 'Creating album…' : 'Create private album'),
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
      OutlinedButton.icon(
        onPressed: _showHistory,
        icon: const Icon(Icons.history),
        label: const Text('Access history and active access'),
      ),
    ],
  );
}
