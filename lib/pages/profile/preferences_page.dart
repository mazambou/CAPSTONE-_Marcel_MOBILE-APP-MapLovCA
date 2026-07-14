part of '../../app.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  RangeValues ages = const RangeValues(24, 38);
  String searchMode = 'Around me';
  String gender = 'Everyone';
  String relationshipGoal = 'Long-term';
  String language = 'Any language';
  String personality = 'Any personality';
  bool requiredGender = false;
  bool requiredLocation = false;
  bool requiredLanguage = false;
  bool requiredGoal = false;
  final country = TextEditingController();
  bool loading = true;

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
        'my_country' => 'Country',
        'specific_country' => 'Specific country',
        'worldwide' => 'Worldwide',
        _ => 'Around me',
      };
      gender = saved.genders.firstOrNull ?? 'Everyone';
      relationshipGoal = saved.relationshipGoals.firstOrNull ?? 'Long-term';
      language = saved.languages.firstOrNull ?? 'Any language';
      personality = saved.personalities.firstOrNull ?? 'Any personality';
      country.text = saved.countries.firstOrNull ?? '';
      requiredGender = saved.requiredGenders;
      requiredLocation = saved.requiredLocation;
      requiredLanguage = saved.requiredLanguages;
      requiredGoal = saved.requiredRelationshipGoal;
      loading = false;
    });
  }

  @override
  void dispose() {
    country.dispose();
    super.dispose();
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
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Around me', label: Text('Nearby')),
          ButtonSegment(value: 'Country', label: Text('Country')),
          ButtonSegment(value: 'Specific country', label: Text('Specific')),
          ButtonSegment(value: 'Worldwide', label: Text('World')),
        ],
        selected: {searchMode},
        onSelectionChanged: (value) => setState(() => searchMode = value.first),
      ),
      const SizedBox(height: 14),
      _Field('Preferred country', Icons.public, controller: country),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Required location criterion'),
        subtitle: const Text('Otherwise, location remains a preference.'),
        value: requiredLocation,
        onChanged: (value) => setState(() => requiredLocation = value),
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
        loading ? 'Loading…' : 'Save preferences',
        onPressed: () async {
          if (loading) return;
          await MapLovRepository.instance.savePreferences(
            DiscoveryFilters(
              minimumAge: ages.start.round(),
              maximumAge: ages.end.round(),
              locationMode: switch (searchMode) {
                'Country' => 'my_country',
                'Specific country' => 'specific_country',
                'Worldwide' => 'worldwide',
                _ => 'near_me',
              },
              countries: country.text.trim().isEmpty
                  ? const []
                  : [country.text.trim()],
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
              requiredGenders: requiredGender,
              requiredLocation: requiredLocation,
              requiredLanguages: requiredLanguage,
              requiredRelationshipGoal: requiredGoal,
            ),
          );
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (_) => false,
            );
          }
        },
      ),
    ],
  );
}
