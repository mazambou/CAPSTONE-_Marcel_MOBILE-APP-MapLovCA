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
  String gender = 'Prefer not to say';
  String residenceCountry = 'Canada';
  String residenceCity = 'Toronto';
  String originCountry = 'Canada';
  String originCity = 'Toronto';
  bool saving = false;
  bool loadingProfile = true;
  bool originCountryLocked = false;
  bool originCityLocked = false;
  late Future<List<Map<String, dynamic>>> photos;

  @override
  void initState() {
    super.initState();
    photos = MapLovRepository.instance.myPhotos();
    unawaited(_loadGeography());
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
      setState(() {
        residenceCountry = _worldCountries.contains(savedResidenceCountry)
            ? savedResidenceCountry
            : 'Canada';
        residenceCity = _citySelection(
          residenceCountry,
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
        if (savedOriginCity != null && savedOriginCity.trim().isNotEmpty) {
          originCity = _citySelection(
            originCountry,
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
    String city,
    TextEditingController other,
  ) {
    if ((_registrationCitiesByCountry[country] ?? const []).contains(city)) {
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
    super.dispose();
  }

  Future<void> _managePhotos() async {
    await Navigator.pushNamed(context, AppRoutes.managePhotos);
    if (mounted) {
      setState(() => photos = MapLovRepository.instance.myPhotos());
    }
  }

  Future<void> _continue() async {
    setState(() => saving = true);
    try {
      await MapLovRepository.instance.saveMyProfile({
        'gender': gender,
        'bio': bio.text.trim(),
        'spoken_languages': const ['English'],
        'country_name': residenceCountry,
        'city': _cityValue(residenceCity, residenceCityOther),
        'residence_country_name': residenceCountry,
        'residence_city': _cityValue(residenceCity, residenceCityOther),
        'origin_country_name': originCountry,
        'origin_city': _cityValue(originCity, originCityOther),
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
      Center(
        child: Stack(
          children: [
            FutureBuilder<List<Map<String, dynamic>>>(
              future: photos,
              builder: (context, snapshot) {
                final photo = snapshot.data?.firstOrNull?['url'] as String?;
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
                onPressed: _managePhotos,
                icon: const Icon(Icons.add_a_photo_outlined),
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
        city: residenceCity,
        otherController: residenceCityOther,
        countryLabel: 'Current country of residence',
        cityLabel: 'Current city of residence',
        onCountryChanged: (value) => setState(() {
          residenceCountry = value;
          residenceCity =
              _registrationCitiesByCountry[value]?.first ?? 'Other city';
          residenceCityOther.clear();
        }),
        onCityChanged: (value) => setState(() => residenceCity = value),
        countryReadOnly: true,
      ),
      const _SectionTitle('Your origin'),
      _geographyFields(
        country: originCountry,
        city: originCity,
        otherController: originCityOther,
        countryLabel: 'Country of origin',
        cityLabel: 'City of origin',
        onCountryChanged: (value) => setState(() {
          originCountry = value;
          originCity =
              _registrationCitiesByCountry[value]?.first ?? 'Other city';
          originCityOther.clear();
        }),
        onCityChanged: (value) => setState(() => originCity = value),
        countryReadOnly: originCountryLocked,
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
    required TextEditingController otherController,
    required String countryLabel,
    required String cityLabel,
    required ValueChanged<String> onCountryChanged,
    required ValueChanged<String> onCityChanged,
    bool countryReadOnly = false,
    bool cityReadOnly = false,
  }) {
    final cities = [...?_registrationCitiesByCountry[country], 'Other city'];
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
