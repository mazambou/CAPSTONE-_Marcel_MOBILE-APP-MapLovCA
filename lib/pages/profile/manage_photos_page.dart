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
  bool _referenceReady = !MapLovRepository.instance.isLive;
  bool _accountReady = !MapLovRepository.instance.isLive;
  bool _loadingReference = MapLovRepository.instance.isLive;
  bool _verifyingPrimaryPhoto = false;

  @override
  void initState() {
    super.initState();
    _reload();
    unawaited(_loadReferenceStatus());
  }

  Future<void> _loadReferenceStatus() async {
    final repository = MapLovRepository.instance;
    try {
      final ready = await repository.hasFaceReference();
      if (mounted) setState(() => _referenceReady = ready);
    } catch (_) {
      if (mounted) setState(() => _referenceReady = false);
    } finally {
      if (mounted) setState(() => _loadingReference = false);
    }
    try {
      final accountReady = await repository.hasAccountVerification();
      if (mounted) setState(() => _accountReady = accountReady);
    } catch (_) {
      if (mounted) setState(() => _accountReady = false);
    }
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
    if (_loadingReference) {
      _showError('Identity verification is still loading. Try again.');
      return;
    }
    if (!_referenceReady && !_accountReady) {
      try {
        final existingPhotos = await _photos;
        if (existingPhotos.any(
          (photo) => photo['verification_method'] == 'account_checks',
        )) {
          await LocationService.instance.updateMyLocation();
          final eligible = await MapLovRepository.instance
              .verifyQuebecResidence();
          if (eligible) {
            _accountReady = await MapLovRepository.instance
                .hasAccountVerification();
          }
        }
      } catch (_) {
        // The generic message below does not expose the Québec route.
      }
    }
    if (!_referenceReady && !_accountReady) {
      if (!mounted) return;
      _showError(
        'Verify your email or SMS registration, phone and residence before adding photos.',
      );
      return;
    }
    if (!mounted) return;
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
          withoutBiometrics: !_referenceReady,
        );
        if (mounted) setState(() => _uploadedCount++);
      }
      _refreshPhotos();
    } on FaceVerificationException catch (error) {
      if (_uploadedCount > 0) _refreshPhotos();
      if (mounted) _showError(error.message);
    } catch (error) {
      if (_uploadedCount > 0) _refreshPhotos();
      if (mounted) _showError('Photo upload failed: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _verifyPrimaryPhoto() async {
    if (_verifyingPrimaryPhoto) return;
    try {
      if (!await confirmFaceVerificationConsent(context)) return;
      final selfie = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: kIsWeb ? null : 85,
        maxWidth: kIsWeb ? null : 1600,
        maxHeight: kIsWeb ? null : 1600,
      );
      if (selfie == null) return;
      if (mounted) setState(() => _verifyingPrimaryPhoto = true);
      final prepared = await prepareReferenceSelfie(selfie);
      await LocationService.instance.updateMyLocation();
      await MapLovRepository.instance.verifyExistingProfilePhoto(
        bytes: prepared.bytes,
        extension: prepared.extension,
      );
      if (!mounted) return;
      setState(() {
        _referenceReady = true;
        _verifyingPrimaryPhoto = false;
      });
      _refreshPhotos();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Profile photo verified.'))),
      );
    } on FaceVerificationException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('Unable to verify the profile photo: $error');
    } finally {
      if (mounted) setState(() => _verifyingPrimaryPhoto = false);
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

  Future<void> _setPrimaryPhoto(Map<String, dynamic> photo) async {
    if (photo['moderation_status'] == 'under_review' ||
        photo['is_primary'] == true) {
      return;
    }
    try {
      await MapLovRepository.instance.setPrimaryPhoto(photo['id'] as String);
      _refreshPhotos();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (error) {
      if (mounted) _showError('Unable to update the profile photo: $error');
    }
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
  ).showSnackBar(SnackBar(content: Text(context.tr(message))));

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Manage photos',
    children: [
      const Text(
        'Your profile photo is shown first. The other photos belong to your public album. You can choose any visible album photo as your profile photo.',
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
          final unverifiedPrimary = photos.any(
            (photo) =>
                photo['is_primary'] == true &&
                photo['moderation_status'] == 'visible' &&
                photo['verification_method'] == 'account_checks' &&
                photo['is_verified'] != true,
          );
          return Column(
            children: [
              if (unverifiedPrimary) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Photo not verified'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'Your profile photo has not been face verified. You can verify it whenever you choose.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('verify_existing_profile_photo'),
                          onPressed: _verifyingPrimaryPhoto
                              ? null
                              : _verifyPrimaryPhoto,
                          icon: _verifyingPrimaryPhoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: Text(context.tr('Verify my photo')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              GridView.count(
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
                      onTap: underReview
                          ? null
                          : () => _openPhoto(photo, photos),
                      onLongPress: () => _showDeleteControl(id),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            mediaImage(
                              photo['url'] as String,
                              fit: BoxFit.cover,
                            ),
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
                            if (photo['is_primary'] == true)
                              const Positioned(
                                left: 8,
                                bottom: 8,
                                child: Chip(
                                  avatar: Icon(Icons.person, size: 16),
                                  label: Text('Profile photo'),
                                ),
                              )
                            else if (!underReview)
                              Positioned(
                                left: 7,
                                bottom: 7,
                                child: IconButton.filled(
                                  key: Key('set_primary_photo_$id'),
                                  tooltip: context.tr('Use as profile photo'),
                                  onPressed: () => _setPrimaryPhoto(photo),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 40,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.person_outline,
                                    size: 21,
                                  ),
                                ),
                              ),
                            if (_deleteControls.contains(id))
                              Positioned(
                                top: 7,
                                right: 7,
                                child: IconButton.filled(
                                  key: Key('delete_managed_photo_$id'),
                                  tooltip: context.tr('Delete photo'),
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
