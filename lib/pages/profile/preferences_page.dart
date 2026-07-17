part of '../../app.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  RangeValues ages = const RangeValues(24, 38);
  String searchMode = 'Near me';
  double distance = 50;
  String selectedCity = 'Any city';
  String preferredCountry = 'Canada';
  String gender = 'Everyone';
  String relationshipGoal = 'Long-term';
  String language = 'Any language';
  String personality = 'Any personality';
  bool requiredGender = false;
  bool requiredLanguage = false;
  bool requiredGoal = false;
  bool loading = true;
  bool saving = false;
  List<String> savedOriginCountries = const [];
  List<String> savedOriginCities = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final saved = await MapLovRepository.instance.myPreferences();
    if (!mounted) return;
    setState(() {
      ages = RangeValues(
        saved.minimumAge.toDouble(),
        saved.maximumAge.toDouble(),
      );
      searchMode = switch (saved.locationMode) {
        'my_country' => 'My country',
        'specific_country' || 'worldwide' => 'International',
        _ => 'Near me',
      };
      distance = saved.distanceKm.toDouble().clamp(1, 100);
      selectedCity = saved.cities.firstOrNull ?? 'Any city';
      gender = saved.genders.firstOrNull ?? 'Everyone';
      relationshipGoal = saved.relationshipGoals.firstOrNull ?? 'Long-term';
      language = saved.languages.firstOrNull ?? 'Any language';
      personality = saved.personalities.firstOrNull ?? 'Any personality';
      preferredCountry = saved.countries.firstOrNull ?? 'Canada';
      requiredGender = saved.requiredGenders;
      requiredLanguage = saved.requiredLanguages;
      requiredGoal = saved.requiredRelationshipGoal;
      savedOriginCountries = saved.originCountries;
      savedOriginCities = saved.originCities;
      loading = false;
    });
  }

  void _backToProfileDetails() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
    }
  }

  Future<void> _continue() async {
    if (loading || saving) return;
    final completingRegistration =
        !AuthService.instance.isConfigured ||
        AuthService.instance.requiresPreferencesCompletion;
    setState(() => saving = true);
    try {
      await MapLovRepository.instance.savePreferences(
        DiscoveryFilters(
          minimumAge: ages.start.round(),
          maximumAge: ages.end.round(),
          distanceKm: distance.round(),
          locationMode: switch (searchMode) {
            'My country' => 'my_country',
            'International' => 'specific_country',
            _ => 'near_me',
          },
          countries: searchMode == 'International'
              ? [preferredCountry]
              : const [],
          cities: searchMode == 'My country' && selectedCity != 'Any city'
              ? [selectedCity]
              : const [],
          genders: gender == 'Everyone' ? const [] : [gender],
          relationshipGoals: [relationshipGoal],
          languages: language == 'Any language'
              ? const []
              : language == 'English & French'
              ? const ['English', 'French']
              : [language],
          personalities: personality == 'Any personality'
              ? const []
              : [personality],
          originCountries: savedOriginCountries,
          originCities: savedOriginCities,
          requiredGenders: requiredGender,
          requiredLocation: true,
          requiredLanguages: requiredLanguage,
          requiredRelationshipGoal: requiredGoal,
        ),
      );
      await AuthService.instance.markPreferencesCompleted();
      if (!mounted) return;
      if (AuthService.instance.isConfigured &&
          AuthService.instance.isPhoneVerified) {
        if (completingRegistration) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          );
          return;
        }
        if (Navigator.canPop(context)) Navigator.pop(context);
        return;
      }
      Navigator.pushNamed(context, AppRoutes.verifyPhone);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save preferences: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Dating preferences',
    children: [
      const Text(
        'Tell MapLov who you would like to meet. These preferences improve your compatibility results.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const _SectionTitle('Who you want to meet'),
      DropdownButtonFormField<String>(
        initialValue: gender,
        decoration: const InputDecoration(labelText: 'Gender'),
        items: ['Everyone', 'Women', 'Men', 'Non-binary']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => gender = value ?? gender),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Required gender criterion'),
        subtitle: const Text('Hide profiles that do not match this choice.'),
        value: requiredGender,
        onChanged: (value) => setState(() => requiredGender = value),
      ),
      const SizedBox(height: 14),
      Text('Age range: ${ages.start.round()}–${ages.end.round()}'),
      RangeSlider(
        values: ages,
        min: 18,
        max: 80,
        onChanged: (value) => setState(() => ages = value),
      ),
      const _SectionTitle('Search location'),
      _SearchLocationSelector(
        mode: searchMode,
        distance: distance,
        selectedCity: selectedCity,
        selectedCountry: preferredCountry,
        onModeChanged: (value) => setState(() => searchMode = value),
        onDistanceChanged: (value) => setState(() => distance = value),
        onCityChanged: (value) =>
            setState(() => selectedCity = value ?? 'Any city'),
        onCountryChanged: (value) =>
            setState(() => preferredCountry = value ?? 'Canada'),
      ),
      const _SectionTitle('Compatibility priorities'),
      DropdownButtonFormField<String>(
        initialValue: relationshipGoal,
        decoration: const InputDecoration(labelText: 'Relationship goal'),
        items: ['Long-term', 'Dating', 'Friendship', 'Networking']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) =>
            setState(() => relationshipGoal = value ?? relationshipGoal),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Required relationship goal'),
        value: requiredGoal,
        onChanged: (value) => setState(() => requiredGoal = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: language,
        decoration: const InputDecoration(labelText: 'Languages'),
        items: ['English & French', 'English', 'French', 'Any language']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => language = value ?? language),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Required language criterion'),
        value: requiredLanguage,
        onChanged: (value) => setState(() => requiredLanguage = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: personality,
        decoration: const InputDecoration(labelText: 'Personality'),
        items:
            [
                  'Any personality',
                  'Calm',
                  'Creative',
                  'Adventurous',
                  'Intellectual',
                ]
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
        onChanged: (value) =>
            setState(() => personality = value ?? personality),
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        loading
            ? 'Loading…'
            : saving
            ? 'Saving…'
            : 'Next',
        onPressed: _continue,
      ),
      TextButton.icon(
        key: const Key('preferences_back_to_profile'),
        onPressed: saving ? null : _backToProfileDetails,
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back to profile details'),
      ),
    ],
  );
}
