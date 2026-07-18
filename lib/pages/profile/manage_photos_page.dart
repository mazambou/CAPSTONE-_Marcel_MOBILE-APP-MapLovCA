part of '../../app.dart';

class ManagePhotosScreen extends StatefulWidget {
  const ManagePhotosScreen({super.key});

  @override
  State<ManagePhotosScreen> createState() => _ManagePhotosScreenState();
}

class _ManagePhotosScreenState extends State<ManagePhotosScreen> {
  late Future<List<Map<String, dynamic>>> _photos;
  final Set<String> _deleteControls = {};
  bool _uploading = false;
  int _uploadedCount = 0;
  int _uploadTotal = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _photos = MapLovRepository.instance.myPhotos();
  }

  void _refreshPhotos() {
    if (!mounted) return;
    setState(() {
      _deleteControls.clear();
      _reload();
    });
  }

  Future<void> _addPhoto() async {
    if (_uploading) return;
    List<XFile> photos;
    try {
      photos = await pickImagesForUpload(
        context,
        imageQuality: 88,
        maxWidth: 2048,
      );
    } catch (error) {
      if (mounted) _showError('Unable to open the camera or gallery: $error');
      return;
    }
    if (photos.isEmpty) return;
    setState(() {
      _uploading = true;
      _uploadedCount = 0;
      _uploadTotal = photos.length;
    });
    try {
      for (final photo in photos) {
        final bytes = await photo.readAsBytes();
        await MapLovRepository.instance.uploadProfilePhoto(
          bytes: bytes,
          extension: photo.name.split('.').last.toLowerCase(),
        );
        if (mounted) setState(() => _uploadedCount++);
      }
      _refreshPhotos();
    } catch (error) {
      if (mounted) _showError('Photo upload failed: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await MapLovRepository.instance.deleteProfilePhoto(photo);
    if (!deleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your profile must keep at least one photo.'),
        ),
      );
      return;
    }
    _refreshPhotos();
  }

  Future<void> _openPhoto(
    Map<String, dynamic> photo,
    List<Map<String, dynamic>> photos,
  ) async {
    if (photo['moderation_status'] == 'under_review') return;
    final profileId = MapLovRepository.instance.currentUserId;
    final loaded = profileId == null
        ? demoProfileOrUnavailable
        : await MapLovRepository.instance.getProfile(profileId);
    if (!mounted || loaded == null) return;
    final visiblePhotos = photos
        .where((item) => item['moderation_status'] != 'under_review')
        .toList();
    final visibleIndex = visiblePhotos.indexWhere(
      (item) => item['id'] == photo['id'],
    );
    final profileIndex = loaded.photoIds.indexOf(photo['id'] as String);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          profile: loaded,
          initialIndex: profileIndex >= 0 ? profileIndex : visibleIndex,
        ),
      ),
    );
  }

  void _showDeleteControl(String id) {
    setState(() {
      _deleteControls
        ..clear()
        ..add(id);
    });
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

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
              ...photos.map((photo) {
                final id = photo['id'] as String;
                final underReview =
                    photo['moderation_status'] == 'under_review';
                return GestureDetector(
                  key: Key('managed_photo_$id'),
                  onTap: underReview ? null : () => _openPhoto(photo, photos),
                  onLongPress: () => _showDeleteControl(id),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        mediaImage(photo['url'] as String, fit: BoxFit.cover),
                        if (underReview)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: .58),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Photo under moderation',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_deleteControls.contains(id))
                          Positioned(
                            top: 7,
                            right: 7,
                            child: IconButton.filled(
                              key: Key('delete_managed_photo_$id'),
                              tooltip: 'Delete photo',
                              onPressed: () => _deletePhoto(photo),
                              constraints: const BoxConstraints.tightFor(
                                width: 38,
                                height: 38,
                              ),
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close, size: 20),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
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
                      Text(
                        _uploading
                            ? 'Uploading $_uploadedCount/$_uploadTotal…'
                            : 'Add photos',
                      ),
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
