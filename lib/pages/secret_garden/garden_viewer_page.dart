part of '../../app.dart';

class GardenViewerScreen extends StatefulWidget {
  const GardenViewerScreen({super.key, this.album});
  final GardenAlbumItem? album;

  @override
  State<GardenViewerScreen> createState() => _GardenViewerScreenState();
}

class _GardenViewerScreenState extends State<GardenViewerScreen> {
  late Future<List<Map<String, dynamic>>> managedPhotos;

  GardenAlbumItem get selected =>
      widget.album ??
      const GardenAlbumItem(
        id: 'demo-garden',
        ownerId: 'me',
        title: 'My private moments',
      );

  bool get canManage =>
      MapLovRepository.instance.currentUserId == selected.ownerId;

  @override
  void initState() {
    super.initState();
    managedPhotos = MapLovRepository.instance.gardenPhotos(selected.id);
  }

  Future<void> _delete(Map<String, dynamic> photo) async {
    await MapLovRepository.instance.deleteGardenPhoto(
      photo['id'] as String,
      photo['storage_path'] as String,
    );
    if (mounted) {
      setState(() {
        managedPhotos = MapLovRepository.instance.gardenPhotos(selected.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17131B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Text(
          selected.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<String>>(
          future: canManage
              ? managedPhotos.then(
                  (items) =>
                      items.map((item) => item['url'] as String).toList(),
                )
              : MapLovRepository.instance.gardenPhotoUrls(selected.id),
          builder: (context, snapshot) {
            final photos = snapshot.data ?? const <String>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This access has expired or is no longer available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, color: AppColors.softPink),
                      SizedBox(width: 8),
                      Text(
                        'Private and time-limited access',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: photos.isEmpty
                      ? const Center(
                          child: Text(
                            'No photos in this album.',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : PageView(
                          children: photos.indexed
                              .map(
                                (entry) => Stack(
                                  children: [
                                    Positioned.fill(
                                      child: InteractiveViewer(
                                        child: entry.$2.startsWith('http')
                                            ? Image.network(
                                                entry.$2,
                                                fit: BoxFit.contain,
                                              )
                                            : Image.asset(
                                                entry.$2,
                                                fit: BoxFit.contain,
                                              ),
                                      ),
                                    ),
                                    if (canManage)
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: IconButton.filled(
                                          tooltip: 'Delete private photo',
                                          onPressed: () async {
                                            final items = await managedPhotos;
                                            await _delete(items[entry.$1]);
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Private content cannot be shared or downloaded.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
