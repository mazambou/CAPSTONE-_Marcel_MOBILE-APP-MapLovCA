part of '../../app.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final bio = TextEditingController();
  final residenceCityOther = TextEditingController();
  final originCityOther = TextEditingController();
  final residenceRegionOther = TextEditingController();
  final originRegionOther = TextEditingController();
  String gender = '';
  bool genderLocked = false;
  String? bodyType;
  String residenceCountry = 'Canada';
  String residenceCity = 'Toronto';
  String residenceRegion = 'Ontario';
  String originCountry = 'Canada';
  String originRegion = 'Ontario';
  String originCity = 'Toronto';
  bool saving = false;
  bool loadingProfile = true;
  bool detectingResidence = MapLovRepository.instance.isLive;
  bool residenceDetected = !MapLovRepository.instance.isLive;
  String? residenceDetectionError;
  bool originCountryLocked = false;
  bool originRegionLocked = false;
  bool originCityLocked = false;
  bool loadingResidenceRegions = false;
  bool loadingResidenceCities = false;
  bool loadingOriginRegions = false;
  bool loadingOriginCities = false;
  String? residenceRegionError;
  String? residenceCityError;
  String? originRegionError;
  String? originCityError;
  int _originGeographyRequest = 0;
  late Future<List<Map<String, dynamic>>> photos;
  Uint8List? pendingProfilePhoto;
  bool uploadingPhoto = false;
  bool faceReferenceReady = !MapLovRepository.instance.isLive;
  bool loadingFaceReference = MapLovRepository.instance.isLive;
  bool enrollingFaceReference = false;

  @override
  void initState() {
    super.initState();
    photos = MapLovRepository.instance.myPhotos();
    unawaited(_loadGeography());
    unawaited(_loadFaceReference());
  }

  Future<void> _loadFaceReference() async {
    try {
      final ready = await MapLovRepository.instance.hasFaceReference();
      if (mounted) setState(() => faceReferenceReady = ready);
    } catch (_) {
      if (mounted) setState(() => faceReferenceReady = false);
    } finally {
      if (mounted) setState(() => loadingFaceReference = false);
    }
  }

  Future<void> _loadGeography() async {
    try {
      await _loadCountries();
      final profile = await MapLovRepository.instance.myProfileDetails();
      if (profile != null && mounted) {
        var savedResidenceCountry =
            profile['residence_country_name'] as String? ??
            profile['country_name'] as String? ??
            'Canada';
        if (!_worldCountries.contains(savedResidenceCountry)) {
          savedResidenceCountry = _worldCountries.contains('Canada')
              ? 'Canada'
              : (_worldCountries.firstOrNull ?? '');
        }
        await _loadRegions(savedResidenceCountry);
        final savedResidenceCity =
            profile['residence_city'] as String? ??
            profile['city'] as String? ??
            'Toronto';
        final savedResidenceRegion =
            profile['residence_region'] as String? ??
            _firstRegionForCountry(savedResidenceCountry);
        if (savedResidenceRegion.isNotEmpty) {
          await _loadCities(savedResidenceCountry, savedResidenceRegion);
        }
        var savedOriginCountry =
            profile['origin_country_name'] as String? ?? 'Canada';
        if (!_worldCountries.contains(savedOriginCountry)) {
          savedOriginCountry = savedResidenceCountry;
        }
        await _loadRegions(savedOriginCountry);
        final savedOriginCity = profile['origin_city'] as String?;
        final savedOriginRegion =
            profile['origin_region'] as String? ??
            _firstRegionForCountry(savedOriginCountry);
        if (savedOriginRegion.isNotEmpty) {
          await _loadCities(savedOriginCountry, savedOriginRegion);
        }
        final storedGender = profile['gender'] as String?;
        final savedGender =
            const {'Woman', 'Man', 'Non-binary'}.contains(storedGender)
            ? storedGender!
            : gender;
        setState(() {
          gender = savedGender;
          genderLocked = storedGender == savedGender && savedGender.isNotEmpty;
          bodyType = _normalizedProfileBodyType(
            profile['body_type'] as String?,
            savedGender,
          );
          residenceCountry = savedResidenceCountry;
          final regions = _regionsByCountry[residenceCountry] ?? const [];
          if (regions.contains(savedResidenceRegion)) {
            residenceRegion = savedResidenceRegion;
          } else {
            residenceRegion = 'Other region';
            residenceRegionOther.text = savedResidenceRegion;
          }
          residenceCity = _citySelection(
            residenceCountry,
            residenceRegion,
            savedResidenceCity,
            residenceCityOther,
          );
          originCountry = savedOriginCountry;
          originCountryLocked =
              (profile['origin_country_name'] as String?)?.trim().isNotEmpty ==
              true;
          if (savedOriginRegion.trim().isNotEmpty) {
            final regions = _regionsByCountry[savedOriginCountry] ?? const [];
            if (regions.contains(savedOriginRegion)) {
              originRegion = savedOriginRegion;
            } else {
              originRegion = 'Other region';
              originRegionOther.text = savedOriginRegion;
            }
            originRegionLocked = true;
          } else {
            originRegion = _firstRegionForCountry(savedOriginCountry);
          }
          if (savedOriginCity != null && savedOriginCity.trim().isNotEmpty) {
            originCity = _citySelection(
              originCountry,
              originRegion,
              savedOriginCity,
              originCityOther,
            );
            originCityLocked = true;
          }
        });
      }
      if (MapLovRepository.instance.isLive) {
        await _detectResidence();
      }
    } finally {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  String? _supportedResidenceCountry(String detected) {
    if (_worldCountries.contains(detected)) return detected;
    return const {
      'United States of America': 'United States',
      'Ivory Coast': 'Côte d’Ivoire',
      'Democratic Republic of Congo': 'Democratic Republic of the Congo',
      'Republic of the Congo': 'Congo',
    }[detected];
  }

  Future<void> _detectResidence() async {
    if (mounted) {
      setState(() {
        detectingResidence = true;
        residenceDetectionError = null;
      });
    }
    try {
      final detected = await LocationService.instance.detectResidence();
      final country = _supportedResidenceCountry(detected.country);
      if (country == null) {
        throw ResidenceDetectionFailure(
          'MapLov does not yet support profiles from ${detected.country}.',
        );
      }
      await _loadRegions(country);
      final regions = _regionsByCountry[country] ?? const <String>[];
      final exactRegion = regions
          .where(
            (region) => region.toLowerCase() == detected.region.toLowerCase(),
          )
          .firstOrNull;
      final selectedRegion =
          exactRegion ??
          _regionForKnownCity(country, detected.city) ??
          (regions.isEmpty ? 'Other region' : regions.first);
      await _loadCities(country, selectedRegion);
      final cities = _citiesForCountryRegion(country, selectedRegion);
      final selectedCity = cities
          .where((city) => city.toLowerCase() == detected.city.toLowerCase())
          .firstOrNull;

      await MapLovRepository.instance.updateLocation(
        latitude: detected.position.latitude,
        longitude: detected.position.longitude,
        accuracy: detected.position.accuracy,
      );
      await MapLovRepository.instance.syncResidenceFromLocation(
        country: country,
        countryCode: detected.countryCode,
        region: detected.region,
        city: detected.city,
      );
      if (!mounted) return;
      setState(() {
        residenceCountry = country;
        residenceRegion = selectedRegion;
        residenceRegionOther.text = selectedRegion == 'Other region'
            ? detected.region
            : '';
        residenceCity = selectedCity ?? 'Other city';
        residenceCityOther.text = selectedCity == null ? detected.city : '';
        residenceDetected = true;
        detectingResidence = false;
        residenceDetectionError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        residenceDetected = false;
        detectingResidence = false;
        residenceDetectionError =
            'GPS location is required to verify your country of residence.';
      });
    }
  }

  Future<void> _changeOriginCountry(String value) async {
    final request = ++_originGeographyRequest;
    setState(() {
      originCountry = value;
      originRegion = '';
      originCity = '';
      originRegionOther.clear();
      originCityOther.clear();
      loadingOriginRegions = true;
      loadingOriginCities = false;
      originRegionError = null;
      originCityError = null;
    });
    try {
      await _loadRegions(value);
      if (!mounted || request != _originGeographyRequest) return;
    } catch (_) {
      if (!mounted || request != _originGeographyRequest) return;
      setState(() => originRegionError = 'Unable to load regions.');
    } finally {
      if (mounted && request == _originGeographyRequest) {
        setState(() => loadingOriginRegions = false);
      }
    }
  }

  Future<void> _changeOriginRegion(String value) async {
    final request = ++_originGeographyRequest;
    setState(() {
      originRegion = value;
      originCity = '';
      originCityOther.clear();
      loadingOriginCities = value != 'Other region';
      originCityError = null;
    });
    if (value == 'Other region') return;
    try {
      await _loadCities(originCountry, value);
      if (!mounted || request != _originGeographyRequest) return;
    } catch (_) {
      if (!mounted || request != _originGeographyRequest) return;
      setState(() => originCityError = 'Unable to load cities.');
    } finally {
      if (mounted && request == _originGeographyRequest) {
        setState(() => loadingOriginCities = false);
      }
    }
  }

  String _citySelection(
    String country,
    String region,
    String city,
    TextEditingController other,
  ) {
    if (_cityBelongsToSelection(country, region, city)) {
      return city;
    }
    other.text = city;
    return 'Other city';
  }

  String _cityValue(String selection, TextEditingController other) =>
      selection == 'Other city' ? other.text.trim() : selection;

  @override
  void dispose() {
    bio.dispose();
    residenceCityOther.dispose();
    originCityOther.dispose();
    residenceRegionOther.dispose();
    originRegionOther.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    if (uploadingPhoto) return;
    if (!faceReferenceReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create your private reference selfie first.'),
        ),
      );
      return;
    }
    try {
      final photo = await pickImageForUpload(context, imageQuality: 88);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        pendingProfilePhoto = bytes;
        uploadingPhoto = true;
      });
      final photoId = await MapLovRepository.instance.uploadProfilePhoto(
        bytes: bytes,
        extension: photo.name.split('.').last.toLowerCase(),
      );
      if (photoId != null) {
        await MapLovRepository.instance.setPrimaryPhoto(photoId);
      }
      final refreshed = MapLovRepository.instance.myPhotos();
      if (MapLovRepository.instance.isLive) await refreshed;
      if (mounted) {
        setState(() {
          photos = refreshed;
          if (MapLovRepository.instance.isLive) pendingProfilePhoto = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => pendingProfilePhoto = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Photo upload failed: $error')));
      }
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> _captureReferenceSelfie() async {
    if (enrollingFaceReference || faceReferenceReady) return;
    try {
      if (!await confirmFaceVerificationConsent(context)) return;
      final selfie = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (selfie == null) return;
      if (mounted) setState(() => enrollingFaceReference = true);
      await LocationService.instance.updateMyLocation();
      await MapLovRepository.instance.enrollFaceReference(
        bytes: await selfie.readAsBytes(),
        extension: selfie.name.split('.').last.toLowerCase(),
      );
      if (mounted) {
        setState(() => faceReferenceReady = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Private reference selfie verified.')),
        );
      }
    } on FaceVerificationException catch (error) {
      if (error.rejectsRegistration) {
        await _handleRejectedDuplicateRegistration();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to verify the reference selfie: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => enrollingFaceReference = false);
    }
  }

  Future<void> _handleRejectedDuplicateRegistration() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account not created'),
        content: const Text(
          'MapLov rejected this registration because the selfie matches an existing private reference. The provisional account and uploaded selfie are removed. Use account recovery or contact support.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go to login'),
          ),
        ],
      ),
    );
    await AuthService.instance.discardRejectedRegistration();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _continue() async {
    if (!const {'Woman', 'Man', 'Non-binary'}.contains(gender)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose your gender to continue.')),
      );
      return;
    }
    if (!faceReferenceReady && MapLovRepository.instance.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A private reference selfie is required.'),
        ),
      );
      return;
    }
    if (MapLovRepository.instance.isLive && !residenceDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verify your country of residence with GPS before continuing.',
          ),
        ),
      );
      return;
    }
    final savedResidenceRegion = residenceRegion == 'Other region'
        ? residenceRegionOther.text.trim()
        : residenceRegion;
    final savedOriginRegion = originRegion == 'Other region'
        ? originRegionOther.text.trim()
        : originRegion;
    final savedResidenceCity = _cityValue(residenceCity, residenceCityOther);
    final savedOriginCity = _cityValue(originCity, originCityOther);
    if (savedResidenceRegion.isEmpty || savedOriginRegion.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a region.')));
      return;
    }
    if (savedResidenceCity.isEmpty || savedOriginCity.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a city.')));
      return;
    }
    setState(() => saving = true);
    try {
      await MapLovRepository.instance.saveMyProfile({
        'gender': gender,
        'body_type': bodyType,
        'bio': bio.text.trim(),
        'spoken_languages': const ['English'],
        'city': savedResidenceCity,
        'residence_city': savedResidenceCity,
        'residence_region': savedResidenceRegion,
        'residence_country_id': _countryId(residenceCountry),
        'residence_region_id': _regionId(residenceCountry, residenceRegion),
        'residence_city_id': _cityId(
          residenceCountry,
          residenceRegion,
          residenceCity,
        ),
        'origin_country_name': originCountry,
        'origin_region': savedOriginRegion,
        'origin_city': savedOriginCity,
        'origin_country_id': _countryId(originCountry),
        'origin_region_id': _regionId(originCountry, originRegion),
        'origin_city_id': _cityId(originCountry, originRegion, originCity),
      });
      await MapLovRepository.instance.completeProfileIfReady();
      if (mounted) Navigator.pushNamed(context, AppRoutes.preferences);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Create your profile',
    children: [
      const LinearProgressIndicator(value: 0.35),
      const SizedBox(height: 22),
      Card(
        key: const Key('private_reference_selfie'),
        color: faceReferenceReady ? Colors.green.shade50 : AppColors.palePink,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: faceReferenceReady
                        ? Colors.green.shade100
                        : AppColors.blush,
                    child: Icon(
                      faceReferenceReady
                          ? Icons.verified_user_outlined
                          : Icons.face_retouching_natural_outlined,
                      color: faceReferenceReady
                          ? Colors.green.shade700
                          : AppColors.coral,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      faceReferenceReady
                          ? 'Identity selfie verified'
                          : 'Verify your identity with a private selfie',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (faceReferenceReady)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                faceReferenceReady
                    ? 'Your reference selfie is verified, kept private and never displayed on your profile.'
                    : 'Take one clear, front-facing selfie. MapLov keeps it private, compares it with existing private reference selfies to prevent duplicate accounts, and uses it to confirm your profile photos. It never appears on your profile.',
                style: const TextStyle(color: AppColors.grayText, height: 1.35),
              ),
              if (!faceReferenceReady) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: AppColors.coral),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Private • Security verification only',
                        style: TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (loadingFaceReference || enrollingFaceReference)
                const Center(
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (!faceReferenceReady)
                FilledButton.icon(
                  key: const Key('capture_reference_selfie'),
                  onPressed: _captureReferenceSelfie,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take my private selfie'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Profile photo',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Center(
        child: Stack(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: photos,
              builder: (context, snapshot) {
                if (pendingProfilePhoto != null) {
                  return ClipOval(
                    child: Image.memory(
                      pendingProfilePhoto!,
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                    ),
                  );
                }
                final loadedPhotos = snapshot.data ?? const [];
                final photo =
                    loadedPhotos
                            .where((item) => item['is_primary'] == true)
                            .firstOrNull?['url']
                        as String? ??
                    loadedPhotos.firstOrNull?['url'] as String?;
                return ClipOval(
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: photo == null
                        ? const ColoredBox(
                            color: AppColors.palePink,
                            child: Icon(
                              Icons.person,
                              size: 70,
                              color: AppColors.softPink,
                            ),
                          )
                        : photo.startsWith('http')
                        ? Image.network(photo, fit: BoxFit.cover)
                        : Image.asset(photo, fit: BoxFit.cover),
                  ),
                );
              },
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'Add profile photo',
                onPressed: uploadingPhoto ? null : _pickProfilePhoto,
                icon: uploadingPhoto
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
              ),
            ),
          ],
        ),
      ),
      const _SectionTitle('About you'),
      const Text(
        'Your name and birth date are already saved. Confirm your current residence, then tell MapLov where you are originally from.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 12),
      const _SectionTitle('Current residence'),
      _geographyFields(
        country: residenceCountry,
        region: residenceRegion,
        city: residenceCity,
        otherController: residenceCityOther,
        countryLabel: 'Current country of residence',
        cityLabel: 'Current city of residence',
        onCountryChanged: (value) {},
        onCityChanged: (value) => setState(() => residenceCity = value),
        onRegionChanged: (value) => setState(() {
          residenceRegion = value;
          residenceCity = _firstCityForCountryRegion(
            residenceCountry,
            residenceRegion,
          );
          residenceCityOther.clear();
        }),
        regionOtherController: residenceRegionOther,
        countryReadOnly: true,
        countryUsesGps: true,
        countryRefreshing: detectingResidence,
        countryError: residenceDetectionError,
        onRefreshCountry: () => unawaited(_detectResidence()),
        loadingRegions: loadingResidenceRegions,
        loadingCities: loadingResidenceCities,
        regionError: residenceRegionError,
        cityError: residenceCityError,
      ),
      const _SectionTitle('Your origin'),
      _geographyFields(
        country: originCountry,
        region: originRegion,
        city: originCity,
        otherController: originCityOther,
        countryLabel: 'Country of origin',
        cityLabel: 'City of origin',
        onCountryChanged: (value) => unawaited(_changeOriginCountry(value)),
        onCityChanged: (value) => setState(() => originCity = value),
        onRegionChanged: (value) => unawaited(_changeOriginRegion(value)),
        regionOtherController: originRegionOther,
        countryReadOnly: originCountryLocked,
        regionReadOnly: originRegionLocked,
        cityReadOnly: originCityLocked,
        loadingRegions: loadingOriginRegions,
        loadingCities: loadingOriginCities,
        regionError: originRegionError,
        cityError: originCityError,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: gender.isEmpty ? null : gender,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.tr('Gender'),
          helperText: context.tr(
            'Your gender is saved during registration and cannot be changed later.',
          ),
        ),
        items: const ['Woman', 'Man', 'Non-binary']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: genderLocked
            ? null
            : (value) => setState(() {
                gender = value ?? gender;
                if (!_bodyTypeAllowedForProfileGender(bodyType, gender)) {
                  bodyType = null;
                }
              }),
      ),
      const SizedBox(height: 12),
      _BodyTypeSelector(
        selected: bodyType == null ? const {} : {bodyType!},
        enabledGalleries: _profileBodyGalleries(gender),
        onChanged: (value) => setState(() => bodyType = value.firstOrNull),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: bio,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: context.tr('Tell people about yourself'),
        ),
      ),
      const SizedBox(height: 20),
      KeyedSubtree(
        key: const Key('profile_setup_continue'),
        child: _PrimaryButton(
          loadingProfile
              ? 'Loading…'
              : saving
              ? 'Saving…'
              : 'Continue to preferences',
          onPressed: saving || loadingProfile ? () {} : _continue,
        ),
      ),
    ],
  );

  Widget _geographyFields({
    required String country,
    required String city,
    String? region,
    required TextEditingController otherController,
    required String countryLabel,
    required String cityLabel,
    required ValueChanged<String> onCountryChanged,
    required ValueChanged<String> onCityChanged,
    ValueChanged<String>? onRegionChanged,
    TextEditingController? regionOtherController,
    bool countryReadOnly = false,
    bool regionReadOnly = false,
    bool cityReadOnly = false,
    bool countryUsesGps = false,
    bool countryRefreshing = false,
    String? countryError,
    bool loadingRegions = false,
    bool loadingCities = false,
    String? regionError,
    String? cityError,
    VoidCallback? onRefreshCountry,
  }) {
    final cities = [
      ..._citiesForCountryRegion(country, region ?? 'Any region'),
      'Other city',
    ];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('${countryLabel}_$country'),
          initialValue: _worldCountries.contains(country) ? country : null,
          isExpanded: true,
          menuMaxHeight: 360,
          decoration: InputDecoration(
            labelText: context.tr(countryLabel),
            prefixIcon: const Icon(Icons.public),
            errorText: countryError,
            helperText: countryReadOnly
                ? countryUsesGps
                      ? context.tr(
                          countryRefreshing
                              ? 'Detecting from your current GPS location…'
                              : 'Detected automatically by GPS. The country cannot be changed manually.',
                        )
                      : context.tr('Country of origin can only be chosen once.')
                : null,
            suffixIcon: countryUsesGps
                ? countryRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const Key('profile_setup_refresh_residence'),
                          tooltip: 'Refresh GPS residence',
                          onPressed: saving ? null : onRefreshCountry,
                          icon: const Icon(Icons.my_location),
                        )
                : null,
          ),
          items: _worldCountries
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: saving || countryReadOnly
              ? null
              : (value) {
                  if (value != null) onCountryChanged(value);
                },
        ),
        const SizedBox(height: 12),
        if (region != null && onRegionChanged != null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('${countryLabel}_region_$country'),
            initialValue: region.isEmpty
                ? null
                : [
                    ...?_regionsByCountry[country],
                    'Other region',
                  ].contains(region)
                ? region
                : 'Other region',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Region'),
              prefixIcon: const Icon(Icons.map_outlined),
              errorText: regionError,
              suffixIcon: loadingRegions
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            items: [...?_regionsByCountry[country], 'Other region']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: saving || regionReadOnly || loadingRegions
                ? null
                : (value) {
                    if (value != null) onRegionChanged(value);
                  },
          ),
          if (region == 'Other region') ...[
            const SizedBox(height: 12),
            TextField(
              controller: regionOtherController,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: context.tr('Region name'),
                prefixIcon: const Icon(Icons.edit_location_alt_outlined),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          key: ValueKey('${cityLabel}_${country}_$city'),
          initialValue: city.isEmpty
              ? null
              : cities.contains(city)
              ? city
              : 'Other city',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr(cityLabel),
            prefixIcon: const Icon(Icons.location_city_outlined),
            errorText: cityError,
            helperText: cityReadOnly
                ? context.tr('City of origin can only be chosen once.')
                : null,
            suffixIcon: loadingCities
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: cities
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged:
              saving ||
                  cityReadOnly ||
                  loadingRegions ||
                  loadingCities ||
                  region?.isEmpty == true
              ? null
              : (value) {
                  if (value != null) onCityChanged(value);
                },
        ),
        if (city == 'Other city') ...[
          const SizedBox(height: 12),
          TextField(
            controller: otherController,
            enabled: !saving && !cityReadOnly,
            decoration: InputDecoration(
              labelText: context.tr('$cityLabel name'),
              prefixIcon: const Icon(Icons.edit_location_alt_outlined),
            ),
          ),
        ],
      ],
    );
  }
}
