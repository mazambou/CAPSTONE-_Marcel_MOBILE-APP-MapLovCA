part of '../../app.dart';

class GardenViewerScreen extends StatelessWidget {
  const GardenViewerScreen({super.key, this.album});
  final GardenAlbumItem? album;

  @override
  Widget build(BuildContext context) {
    final selected =
        album ??
        const GardenAlbumItem(
          id: 'demo-garden',
          ownerId: 'me',
          title: 'My private moments',
        );
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
          future: MapLovRepository.instance.gardenPhotoUrls(selected.id),
          builder: (context, snapshot) {
            final photos = snapshot.data ?? const <String>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
                          children: photos
                              .map(
                                (path) => InteractiveViewer(
                                  child: path.startsWith('http')
                                      ? Image.network(path, fit: BoxFit.contain)
                                      : Image.asset(path, fit: BoxFit.contain),
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
