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
  String gender = 'Prefer not to say';
  String residenceCountry = 'Canada';
  String residenceCity = 'Toronto';
  String residenceRegion = 'Ontario';
  String originCountry = 'Canada';
  String originRegion = 'Ontario';
  String originCity = 'Toronto';
  bool saving = false;
  bool loadingProfile = true;
  bool originCountryLocked = false;
  bool originRegionLocked = false;
  bool originCityLocked = false;
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
      final profile = await MapLovRepository.instance.myProfileDetails();
      if (profile == null || !mounted) return;
      final savedResidenceCountry =
          profile['residence_country_name'] as String? ??
          profile['country_name'] as String? ??
          'Canada';
      final savedResidenceCity =
          profile['residence_city'] as String? ??
          profile['city'] as String? ??
          'Toronto';
      final savedResidenceRegion =
          profile['residence_region'] as String? ??
          _regionForKnownCity(savedResidenceCountry, savedResidenceCity) ??
          _firstRegionForCountry(savedResidenceCountry);
      setState(() {
        residenceCountry = _worldCountries.contains(savedResidenceCountry)
            ? savedResidenceCountry
            : 'Canada';
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
        final savedOriginCountry = profile['origin_country_name'] as String?;
        if (savedOriginCountry != null &&
            _worldCountries.contains(savedOriginCountry)) {
          originCountry = savedOriginCountry;
          originCountryLocked = true;
        }
        final savedOriginCity = profile['origin_city'] as String?;
        final savedOriginRegion =
            profile['origin_region'] as String? ??
            (savedOriginCity == null
                ? null
                : _regionForKnownCity(originCountry, savedOriginCity));
        if (savedOriginRegion != null && savedOriginRegion.trim().isNotEmpty) {
          final regions = _regionsByCountry[originCountry] ?? const [];
          if (regions.contains(savedOriginRegion)) {
            originRegion = savedOriginRegion;
          } else {
            originRegion = 'Other region';
            originRegionOther.text = savedOriginRegion;
          }
          originRegionLocked = true;
        } else {
          originRegion = _firstRegionForCountry(originCountry);
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
    } finally {
      if (mounted) setState(() => loadingProfile = false);
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

  Future<void> _continue() async {
    if (!faceReferenceReady && MapLovRepository.instance.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A private reference selfie is required.'),
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
        'bio': bio.text.trim(),
        'spoken_languages': const ['English'],
        'country_name': residenceCountry,
        'city': savedResidenceCity,
        'residence_country_name': residenceCountry,
        'residence_city': savedResidenceCity,
        'residence_region': savedResidenceRegion,
        'origin_country_name': originCountry,
        'origin_region': savedOriginRegion,
        'origin_city': savedOriginCity,
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
        color: AppColors.palePink,
        child: ListTile(
          key: const Key('private_reference_selfie'),
          leading: CircleAvatar(
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
            ),
          ),
          title: const Text(
            'Private reference selfie',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            faceReferenceReady
                ? 'Verified and kept private. It is never shown on your profile.'
                : 'Take a clear front-facing selfie. It will only be used to verify your profile photos.',
          ),
          trailing: loadingFaceReference || enrollingFaceReference
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : faceReferenceReady
              ? const Icon(Icons.check_circle, color: Colors.green)
              : FilledButton(
                  key: const Key('capture_reference_selfie'),
                  onPressed: _captureReferenceSelfie,
                  child: const Text('Take selfie'),
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
        onCountryChanged: (value) => setState(() {
          residenceCountry = value;
          residenceRegion = _regionsByCountry[value]?.first ?? 'Other region';
          residenceCity = _firstCityForCountryRegion(value, residenceRegion);
          residenceCityOther.clear();
        }),
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
      ),
      const _SectionTitle('Your origin'),
      _geographyFields(
        country: originCountry,
        region: originRegion,
        city: originCity,
        otherController: originCityOther,
        countryLabel: 'Country of origin',
        cityLabel: 'City of origin',
        onCountryChanged: (value) => setState(() {
          originCountry = value;
          originRegion = _firstRegionForCountry(value);
          originCity = _firstCityForCountryRegion(value, originRegion);
          originRegionOther.clear();
          originCityOther.clear();
        }),
        onCityChanged: (value) => setState(() => originCity = value),
        onRegionChanged: (value) => setState(() {
          originRegion = value;
          originCity = _firstCityForCountryRegion(originCountry, originRegion);
          originCityOther.clear();
        }),
        regionOtherController: originRegionOther,
        countryReadOnly: originCountryLocked,
        regionReadOnly: originRegionLocked,
        cityReadOnly: originCityLocked,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: gender,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.tr('Gender')),
        items: const ['Woman', 'Man', 'Non-binary', 'Prefer not to say']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => gender = value ?? gender),
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
  }) {
    final cities = [
      ..._citiesForCountryRegion(country, region ?? 'Any region'),
      'Other city',
    ];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('${countryLabel}_$country'),
          initialValue: country,
          isExpanded: true,
          menuMaxHeight: 360,
          decoration: InputDecoration(
            labelText: context.tr(countryLabel),
            prefixIcon: const Icon(Icons.public),
            helperText: countryReadOnly
                ? countryLabel.contains('residence')
                      ? context.tr('Determined by your verified phone number.')
                      : context.tr('Country of origin can only be chosen once.')
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
            initialValue:
                [
                  ...?_regionsByCountry[country],
                  'Other region',
                ].contains(region)
                ? region
                : 'Other region',
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Region'),
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            items: [...?_regionsByCountry[country], 'Other region']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: saving || regionReadOnly
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
          initialValue: cities.contains(city) ? city : 'Other city',
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr(cityLabel),
            prefixIcon: const Icon(Icons.location_city_outlined),
            helperText: cityReadOnly
                ? context.tr('City of origin can only be chosen once.')
                : null,
          ),
          items: cities
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: saving || cityReadOnly
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
