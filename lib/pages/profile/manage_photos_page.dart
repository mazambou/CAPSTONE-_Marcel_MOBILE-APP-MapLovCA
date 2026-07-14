part of '../../app.dart';

class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({super.key});

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  late Future<List<Map<String, dynamic>>> _photos;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _photos = MapLovRepository.instance.myPhotos();

  Future<void> _addPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (photo == null) return;
    setState(() => _uploading = true);
    try {
      await MapLovRepository.instance.uploadProfilePhoto(
        bytes: await photo.readAsBytes(),
        extension: photo.name.split('.').last.toLowerCase(),
      );
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo upload failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final deleted = await MapLovRepository.instance.deleteProfilePhoto(photo);
    if (!deleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your profile must keep at least one photo.'),
        ),
      );
      return;
    }
    if (mounted) setState(_reload);
  }

  Future<void> _setPrimary(Map<String, dynamic> photo) async {
    await MapLovRepository.instance.setPrimaryPhoto(photo['id'] as String);
    if (mounted) setState(_reload);
  }

  Future<void> _move(
    List<Map<String, dynamic>> photos,
    int index,
    int offset,
  ) async {
    final target = index + offset;
    if (target < 0 || target >= photos.length) return;
    final reordered = List<Map<String, dynamic>>.from(photos);
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    await MapLovRepository.instance.reorderProfilePhotos(reordered);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Manage photos',
    children: [
      const Text(
        'Your first photo is your main profile photo. Photos are stored privately and served with temporary secure links.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 18),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _photos,
        builder: (context, snapshot) {
          final photos = snapshot.data ?? const <Map<String, dynamic>>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              photos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              ...photos.asMap().entries.map(
                (entry) => ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (entry.value['url'] as String).startsWith('http')
                          ? Image.network(
                              entry.value['url'] as String,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              entry.value['url'] as String,
                              fit: BoxFit.cover,
                            ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          tooltip: 'Delete photo',
                          onPressed: () => _deletePhoto(entry.value),
                          icon: const Icon(Icons.close, size: 17),
                        ),
                      ),
                      Positioned(
                        left: 7,
                        top: 7,
                        child: ActionChip(
                          avatar: Icon(
                            entry.value['is_primary'] == true
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                          ),
                          label: Text(
                            entry.value['is_primary'] == true
                                ? 'Main'
                                : 'Set main',
                          ),
                          onPressed: () => _setPrimary(entry.value),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Move earlier',
                              onPressed: entry.key == 0
                                  ? null
                                  : () => _move(photos, entry.key, -1),
                              icon: const Icon(Icons.arrow_back, size: 18),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Move later',
                              onPressed: entry.key == photos.length - 1
                                  ? null
                                  : () => _move(photos, entry.key, 1),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: _uploading ? null : _addPhoto,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.palePink,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.softPink),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_uploading)
                        const CircularProgressIndicator()
                      else
                        const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.coral,
                        ),
                      const SizedBox(height: 8),
                      Text(_uploading ? 'Uploading…' : 'Add photo'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 22),
      _PrimaryButton('Done', onPressed: () => Navigator.pop(context)),
    ],
  );
}
