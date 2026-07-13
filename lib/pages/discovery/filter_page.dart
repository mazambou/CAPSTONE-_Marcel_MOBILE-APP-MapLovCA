part of '../../app.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  RangeValues ages = const RangeValues(24, 38);
  String locationMode = 'Near me';
  double distance = 10;
  String selectedCity = 'Any city';
  String selectedCountry = 'Canada';
  RangeValues standardAges = const RangeValues(22, 30);
  double standardDistance = 50;
  RangeValues advancedAges = const RangeValues(22, 30);
  double advancedDistance = 50;
  bool standardVerified = true;
  bool advancedVerified = true;
  bool photoVerified = true;
  bool activeToday = true;
  final Map<String, String> standardSelections = {
    'Language': 'Any',
    'Religion': 'Any',
    'Relationship goal': 'Any',
    'Want children': 'Any',
    'Relationship status': 'Any',
    'Body type': 'Any',
    'Education level': 'Any',
  };
  final Set<String> standardInterests = {'Travel', 'Music', 'Hiking'};
  final Map<String, String> advancedSelections = {
    'Language': 'Any',
    'Religion': 'Any',
    'Relationship goal': 'Any',
    'Want children': 'Any',
    'Relationship status': 'Any',
    'Body type': 'Any',
    'Beard': 'Any',
    'Smoking': 'Any',
    'Education level': 'Any',
    'Profession': 'Any profession',
    'Income level': 'Any income level',
  };

  void _resetFilters() {
    setState(() {
      ages = const RangeValues(18, 80);
      locationMode = 'Near me';
      distance = 10;
      selectedCity = 'Any city';
      selectedCountry = 'Canada';
      standardAges = const RangeValues(22, 30);
      standardDistance = 50;
      advancedAges = const RangeValues(22, 30);
      advancedDistance = 50;
      standardVerified = true;
      advancedVerified = true;
      photoVerified = true;
      activeToday = true;
      standardSelections.updateAll((key, value) => 'Any');
      standardSelections['Language'] = 'Any';
      standardSelections['Education level'] = 'Any';
      standardInterests
        ..clear()
        ..addAll(['Travel', 'Music', 'Hiking']);
      advancedSelections.updateAll((key, value) => 'Any');
      advancedSelections['Profession'] = 'Any profession';
      advancedSelections['Income level'] = 'Any income level';
    });
  }

  Future<void> _showResults() async {
    final tab = DefaultTabController.of(context).index;
    final selectedAges = tab == 2
        ? advancedAges
        : tab == 1
        ? standardAges
        : ages;
    final selectedDistance = tab == 2
        ? advancedDistance
        : tab == 1
        ? standardDistance
        : distance;
    final language = tab == 2
        ? advancedSelections['Language']
        : standardSelections['Language'];
    final goal = tab == 2
        ? advancedSelections['Relationship goal']
        : standardSelections['Relationship goal'];
    final mode = switch (locationMode) {
      'My country' => 'my_country',
      'International' => 'specific_country',
      _ => 'near_me',
    };
    final filters = DiscoveryFilters(
      minimumAge: selectedAges.start.round(),
      maximumAge: selectedAges.end.round(),
      distanceKm: selectedDistance.round(),
      locationMode: mode,
      countries: locationMode == 'International' ? [selectedCountry] : const [],
      cities: locationMode == 'My country' && selectedCity != 'Any city'
          ? [selectedCity]
          : const [],
      languages: language == null || language == 'Any' ? const [] : [language],
      relationshipGoals: goal == null || goal == 'Any' ? const [] : [goal],
      verifiedOnly: tab == 2 ? advancedVerified : tab == 1 && standardVerified,
      activeTodayOnly: tab == 2 && activeToday,
    );
    await MapLovRepository.instance.savePreferences(filters);
    if (mounted) Navigator.pop(context, filters);
  }

  void _setStandardSelection(String title, String value) {
    setState(() => standardSelections[title] = value);
  }

  void _setAdvancedSelection(String title, String value) {
    setState(() => advancedSelections[title] = value);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Filters',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            TextButton(onPressed: _resetFilters, child: const Text('Reset')),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Quick Filter'),
                ),
              ),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Standard Filter'),
                ),
              ),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Advanced Filter'),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildQuickFilter(),
            _buildStandardFilter(),
            _buildAdvancedFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilter() {
    return _FilterTabList(
      key: const Key('quick_filter_tab'),
      buttonKey: const Key('quick_show_results'),
      onShowResults: _showResults,
      children: [
        const _Dropdown('Gender', ['Everyone', 'Women', 'Men', 'Non-binary']),
        const SizedBox(height: 12),
        Text('Age ${ages.start.round()}–${ages.end.round()}'),
        RangeSlider(
          values: ages,
          min: 18,
          max: 80,
          onChanged: (value) => setState(() => ages = value),
        ),
        const _SectionTitle('Search location'),
        const Text(
          'Choose how far MapLov should search for profiles.',
          style: TextStyle(color: AppColors.grayText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Near me', 'My country', 'International']
              .map(
                (mode) => ChoiceChip(
                  key: Key('location_mode_$mode'),
                  label: Text(mode),
                  avatar: Icon(
                    mode == 'Near me'
                        ? Icons.near_me_outlined
                        : mode == 'My country'
                        ? Icons.flag_outlined
                        : Icons.public,
                    size: 18,
                  ),
                  selected: locationMode == mode,
                  onSelected: (_) => setState(() => locationMode = mode),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (locationMode) {
            'My country' => _MyCountryFilter(
              key: const ValueKey('my_country_filter'),
              selectedCity: selectedCity,
              onCityChanged: (city) {
                setState(() => selectedCity = city ?? 'Any city');
              },
            ),
            'International' => _InternationalFilter(
              key: const ValueKey('international_filter'),
              selectedCountry: selectedCountry,
              onCountryChanged: (country) {
                setState(() => selectedCountry = country ?? 'Canada');
              },
            ),
            _ => _NearMeFilter(
              key: const ValueKey('near_me_filter'),
              distance: distance,
              onDistanceChanged: (value) => setState(() => distance = value),
            ),
          },
        ),
        const _SectionTitle('More preferences'),
        const _Dropdown('Languages', ['English', 'French', 'Spanish']),
        const SizedBox(height: 12),
        const _Dropdown('Relationship goal', [
          'Long-term',
          'Dating',
          'Friendship',
        ]),
        const SizedBox(height: 12),
        const Text('Interests'),
        const Wrap(
          spacing: 8,
          children: [
            FilterChip(label: Text('Travel'), selected: true, onSelected: null),
            FilterChip(label: Text('Music'), selected: false, onSelected: null),
            FilterChip(
              label: Text('Sports'),
              selected: false,
              onSelected: null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardFilter() {
    return _FilterTabList(
      key: const Key('standard_filter_tab'),
      buttonKey: const Key('standard_show_results'),
      onShowResults: _showResults,
      children: [
        _RangeFilterCard(
          title: 'Age range',
          icon: Icons.calendar_month_outlined,
          values: standardAges,
          min: 18,
          max: 60,
          onChanged: (value) => setState(() => standardAges = value),
        ),
        _DistanceFilterCard(
          distance: standardDistance,
          onChanged: (value) => setState(() => standardDistance = value),
        ),
        _ChoiceFilterCard(
          title: 'Language',
          icon: Icons.language,
          options: const ['Any', 'English', 'French', 'Spanish', 'Arabic'],
          selected: standardSelections['Language']!,
          onSelected: (value) => _setStandardSelection('Language', value),
        ),
        _ChoiceFilterCard(
          title: 'Religion',
          icon: Icons.self_improvement_outlined,
          options: const ['Any', 'Christian', 'Muslim', 'Hindu', 'Buddhist'],
          selected: standardSelections['Religion']!,
          onSelected: (value) => _setStandardSelection('Religion', value),
        ),
        _ChoiceFilterCard(
          title: 'Relationship goal',
          icon: Icons.favorite_outline,
          options: const [
            'Any',
            'Marriage',
            'Serious relationship',
            'Friendship',
          ],
          selected: standardSelections['Relationship goal']!,
          onSelected: (value) =>
              _setStandardSelection('Relationship goal', value),
        ),
        _ChoiceFilterCard(
          title: 'Want children',
          icon: Icons.family_restroom_outlined,
          options: const [
            'Any',
            'Want children',
            'Have children',
            'Don’t want',
          ],
          selected: standardSelections['Want children']!,
          onSelected: (value) => _setStandardSelection('Want children', value),
        ),
        _ChoiceFilterCard(
          title: 'Relationship status',
          icon: Icons.people_outline,
          options: const ['Any', 'Single', 'Divorced', 'Separated', 'Widowed'],
          selected: standardSelections['Relationship status']!,
          onSelected: (value) =>
              _setStandardSelection('Relationship status', value),
        ),
        const _HeightFilterCard(),
        _ChoiceFilterCard(
          title: 'Body type',
          icon: Icons.accessibility_new,
          options: const [
            'Any',
            'Slim',
            'Athletic',
            'Average',
            'Curvy',
            'Full-figured',
          ],
          selected: standardSelections['Body type']!,
          onSelected: (value) => _setStandardSelection('Body type', value),
        ),
        _ChoiceFilterCard(
          title: 'Education level',
          icon: Icons.school_outlined,
          options: const [
            'Any',
            'High school',
            'College',
            'Bachelor’s',
            'Master’s',
          ],
          selected: standardSelections['Education level']!,
          onSelected: (value) =>
              _setStandardSelection('Education level', value),
        ),
        _FilterSwitchCard(
          title: 'Verified profile',
          icon: Icons.verified_user_outlined,
          value: standardVerified,
          onChanged: (value) => setState(() => standardVerified = value),
        ),
        _MultiChoiceFilterCard(
          title: 'Interests',
          icon: Icons.star_outline,
          options: const [
            'Travel',
            'Music',
            'Hiking',
            'Fitness',
            'Food',
            'Movies',
            'Reading',
            'Photography',
          ],
          selected: standardInterests,
          onToggle: (value) {
            setState(() {
              if (!standardInterests.add(value)) {
                standardInterests.remove(value);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedFilter() {
    return _FilterTabList(
      key: const Key('advanced_filter_tab'),
      buttonKey: const Key('advanced_show_results'),
      onShowResults: _showResults,
      children: [
        const _AdvancedNotice(),
        _AdvancedSection(
          title: 'Basic',
          subtitle: 'Refine your main preferences',
          icon: Icons.auto_awesome,
          children: [
            _RangeFilterCard(
              title: 'Age range',
              icon: Icons.calendar_month_outlined,
              values: advancedAges,
              min: 18,
              max: 60,
              onChanged: (value) => setState(() => advancedAges = value),
            ),
            _DistanceFilterCard(
              distance: advancedDistance,
              onChanged: (value) => setState(() => advancedDistance = value),
            ),
            _ChoiceFilterCard(
              title: 'Language',
              icon: Icons.language,
              options: const ['Any', 'English', 'French', 'Spanish'],
              selected: advancedSelections['Language']!,
              onSelected: (value) => _setAdvancedSelection('Language', value),
              nested: true,
            ),
            _ChoiceFilterCard(
              title: 'Religion',
              icon: Icons.self_improvement_outlined,
              options: const ['Any', 'Christian', 'Muslim', 'Hindu'],
              selected: advancedSelections['Religion']!,
              onSelected: (value) => _setAdvancedSelection('Religion', value),
              nested: true,
            ),
          ],
        ),
        _AdvancedSection(
          title: 'Family & Relationship',
          subtitle: 'Your life situation and relationship goals',
          icon: Icons.favorite_outline,
          children: [
            _advancedChoice('Relationship goal', Icons.favorite_border, const [
              'Any',
              'Marriage',
              'Serious relationship',
              'Friendship',
            ]),
            _advancedChoice(
              'Want children',
              Icons.family_restroom_outlined,
              const ['Any', 'Want children', 'Have children', 'Don’t want'],
            ),
            _advancedChoice('Relationship status', Icons.people_outline, const [
              'Any',
              'Single',
              'Divorced',
              'Separated',
              'Widowed',
            ]),
          ],
        ),
        _AdvancedSection(
          title: 'Appearance',
          subtitle: 'Physical preferences',
          icon: Icons.person_outline,
          children: [
            const _HeightFilterCard(nested: true),
            _advancedChoice('Body type', Icons.accessibility_new, const [
              'Any',
              'Slim',
              'Athletic',
              'Average',
              'Curvy',
              'Full-figured',
            ]),
            const _ColorFilterCard(
              title: 'Eye color',
              colors: [
                Color(0xFF704214),
                Color(0xFF72A5C7),
                Color(0xFF78A95C),
                Color(0xFFD69B3D),
                Color(0xFF8C8C8C),
              ],
            ),
            const _ColorFilterCard(
              title: 'Hair color',
              colors: [
                Color(0xFF282828),
                Color(0xFF53372E),
                Color(0xFF91532D),
                Color(0xFFF0C77B),
                Color(0xFFC85238),
              ],
            ),
            _advancedChoice('Beard', Icons.face_retouching_natural, const [
              'Any',
              'No beard',
              'Short beard',
              'Full beard',
            ]),
            _advancedChoice('Smoking', Icons.smoke_free, const [
              'Any',
              'Non-smoker',
              'Smoker',
            ]),
          ],
        ),
        _AdvancedSection(
          title: 'Education & Career',
          subtitle: 'Education and professional background',
          icon: Icons.school_outlined,
          children: [
            _advancedChoice('Education level', Icons.school_outlined, const [
              'Any',
              'High school',
              'College',
              'Bachelor’s',
              'Master’s',
              'Doctorate',
            ]),
            _ChoiceFilterCard(
              title: 'Profession',
              icon: Icons.work_outline,
              options: const [
                'Any profession',
                'Technology',
                'Healthcare',
                'Education',
                'Business',
                'Arts',
              ],
              selected: advancedSelections['Profession']!,
              onSelected: (value) => _setAdvancedSelection('Profession', value),
              nested: true,
            ),
            _ChoiceFilterCard(
              title: 'Income level',
              icon: Icons.paid_outlined,
              options: const [
                'Any income level',
                'Under 50k',
                '50k–100k',
                '100k–150k',
                '150k+',
              ],
              selected: advancedSelections['Income level']!,
              onSelected: (value) =>
                  _setAdvancedSelection('Income level', value),
              nested: true,
              premium: true,
            ),
          ],
        ),
        _AdvancedSection(
          title: 'Verified & Activity',
          subtitle: 'Trust and activity',
          icon: Icons.verified_user_outlined,
          children: [
            _FilterSwitchCard(
              title: 'Verified profile',
              icon: Icons.verified_user_outlined,
              value: advancedVerified,
              onChanged: (value) => setState(() => advancedVerified = value),
              nested: true,
            ),
            _FilterSwitchCard(
              title: 'Photo verified',
              icon: Icons.add_a_photo_outlined,
              value: photoVerified,
              onChanged: (value) => setState(() => photoVerified = value),
              nested: true,
            ),
            _FilterSwitchCard(
              title: 'Active today',
              icon: Icons.circle,
              value: activeToday,
              onChanged: (value) => setState(() => activeToday = value),
              nested: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _advancedChoice(String title, IconData icon, List<String> options) {
    return _ChoiceFilterCard(
      title: title,
      icon: icon,
      options: options,
      selected: advancedSelections[title]!,
      onSelected: (value) => _setAdvancedSelection(title, value),
      nested: true,
    );
  }
}

class _FilterTabList extends StatelessWidget {
  const _FilterTabList({
    super.key,
    required this.children,
    required this.onShowResults,
    required this.buttonKey,
  });

  final List<Widget> children;
  final VoidCallback onShowResults;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        ...children,
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            key: buttonKey,
            onPressed: onShowResults,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Show Results',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeFilterCard extends StatelessWidget {
  const _RangeFilterCard({
    required this.title,
    required this.icon,
    required this.values,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final RangeValues values;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.coral),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${values.start.round()} – ${values.end.round()}',
                  style: const TextStyle(
                    color: AppColors.deepPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: values,
              min: min,
              max: max,
              divisions: (max - min).round(),
              labels: RangeLabels(
                values.start.round().toString(),
                values.end.round().toString(),
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceFilterCard extends StatelessWidget {
  const _DistanceFilterCard({required this.distance, required this.onChanged});

  final double distance;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.coral),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Distance',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${distance.round()} km',
                  style: const TextStyle(
                    color: AppColors.deepPink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: distance,
              min: 5,
              max: 150,
              divisions: 29,
              label: '${distance.round()} km',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceFilterCard extends StatelessWidget {
  const _ChoiceFilterCard({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.nested = false,
    this.premium = false,
  });

  final String title;
  final IconData icon;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool nested;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(nested ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.coral, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                selected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (premium) ...[
                const SizedBox(width: 5),
                const Icon(Icons.workspace_premium, color: AppColors.warning),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    if (nested) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: content,
      );
    }
    return Card(margin: const EdgeInsets.only(bottom: 12), child: content);
  }
}

class _MultiChoiceFilterCard extends StatelessWidget {
  const _MultiChoiceFilterCard({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final IconData icon;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.coral),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: options
                  .map(
                    (option) => FilterChip(
                      label: Text(option),
                      selected: selected.contains(option),
                      onSelected: (_) => onToggle(option),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeightFilterCard extends StatelessWidget {
  const _HeightFilterCard({this.nested = false});

  final bool nested;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(nested ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.straighten, color: AppColors.coral),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Height',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('Any', style: TextStyle(color: AppColors.deepPink)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: 'Any',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'From'),
                  items: _heightOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (_) {},
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–'),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: 'Any',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'To'),
                  items: _heightOptions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (nested) return content;
    return Card(margin: const EdgeInsets.only(bottom: 12), child: content);
  }
}

class _FilterSwitchCard extends StatelessWidget {
  const _FilterSwitchCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.nested = false,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final tile = SwitchListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: nested ? 10 : 14),
      secondary: Icon(icon, color: AppColors.coral),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      value: value,
      onChanged: onChanged,
    );
    if (nested) return tile;
    return Card(margin: const EdgeInsets.only(bottom: 12), child: tile);
  }
}

class _ColorFilterCard extends StatelessWidget {
  const _ColorFilterCard({required this.title, required this.colors});

  final String title;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            children: colors
                .map(
                  (color) => Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AdvancedNotice extends StatelessWidget {
  const _AdvancedNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.palePink,
      margin: const EdgeInsets.only(bottom: 14),
      child: const ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.blush,
          child: Icon(Icons.lock_outline, color: AppColors.coral),
        ),
        title: Text('Advanced filters help you find better matches.'),
        subtitle: Text('Some options are available with MapLov Premium.'),
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(icon, color: AppColors.coral),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(subtitle),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

const _heightOptions = [
  'Any',
  '150 cm',
  '160 cm',
  '170 cm',
  '180 cm',
  '190 cm+',
];

class _NearMeFilter extends StatelessWidget {
  const _NearMeFilter({
    super.key,
    required this.distance,
    required this.onDistanceChanged,
  });

  final double distance;
  final ValueChanged<double> onDistanceChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _locationFilterDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, color: AppColors.coral),
              SizedBox(width: 8),
              Text(
                'Search radius',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Show profiles within ${distance.round()} km of your approximate location.',
            style: const TextStyle(color: AppColors.grayText),
          ),
          Slider(
            value: distance,
            min: 1,
            max: 100,
            divisions: 99,
            label: '${distance.round()} km',
            onChanged: onDistanceChanged,
          ),
          Wrap(
            spacing: 6,
            children: [5, 10, 25, 50, 100]
                .map(
                  (km) => ChoiceChip(
                    label: Text('$km km'),
                    selected: distance.round() == km,
                    onSelected: (_) => onDistanceChanged(km.toDouble()),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your exact location is never displayed.',
            style: TextStyle(color: AppColors.grayText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MyCountryFilter extends StatelessWidget {
  const _MyCountryFilter({
    super.key,
    required this.selectedCity,
    required this.onCityChanged,
  });

  final String selectedCity;
  final ValueChanged<String?> onCityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _locationFilterDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.palePink,
              child: Icon(Icons.flag_outlined, color: AppColors.coral),
            ),
            title: Text(
              'Canada',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('Your profile country'),
          ),
          DropdownButtonFormField<String>(
            key: const Key('my_country_city_dropdown'),
            initialValue: selectedCity,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'City in Canada',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: _canadianCities
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
            onChanged: onCityChanged,
          ),
          const SizedBox(height: 10),
          const Text(
            'Select Any city to search everywhere in Canada.',
            style: TextStyle(color: AppColors.grayText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InternationalFilter extends StatelessWidget {
  const _InternationalFilter({
    super.key,
    required this.selectedCountry,
    required this.onCountryChanged,
  });

  final String selectedCountry;
  final ValueChanged<String?> onCountryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _locationFilterDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: AppColors.coral),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'International search',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('international_country_dropdown'),
            initialValue: selectedCountry,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: _worldCountries
                .map(
                  (country) => DropdownMenuItem(
                    value: country,
                    child: Text(country, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: onCountryChanged,
          ),
          const SizedBox(height: 10),
          const Text(
            'International mode filters by country only, without a distance limit.',
            style: TextStyle(color: AppColors.grayText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

final _locationFilterDecoration = BoxDecoration(
  color: AppColors.palePink,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: AppColors.blush),
);

const _canadianCities = [
  'Any city',
  'Toronto',
  'Montréal',
  'Vancouver',
  'Calgary',
  'Edmonton',
  'Ottawa',
  'Winnipeg',
  'Québec City',
  'Hamilton',
  'Kitchener',
  'London',
  'Victoria',
  'Halifax',
  'Oshawa',
  'Windsor',
  'Saskatoon',
  'Regina',
  'St. John’s',
  'Kelowna',
  'Sherbrooke',
  'Trois-Rivières',
  'Moncton',
  'Fredericton',
  'Charlottetown',
  'Whitehorse',
  'Yellowknife',
  'Iqaluit',
];

const _worldCountries = [
  'Afghanistan',
  'Albania',
  'Algeria',
  'Andorra',
  'Angola',
  'Antigua and Barbuda',
  'Argentina',
  'Armenia',
  'Australia',
  'Austria',
  'Azerbaijan',
  'Bahamas',
  'Bahrain',
  'Bangladesh',
  'Barbados',
  'Belarus',
  'Belgium',
  'Belize',
  'Benin',
  'Bhutan',
  'Bolivia',
  'Bosnia and Herzegovina',
  'Botswana',
  'Brazil',
  'Brunei',
  'Bulgaria',
  'Burkina Faso',
  'Burundi',
  'Cabo Verde',
  'Cambodia',
  'Cameroon',
  'Canada',
  'Central African Republic',
  'Chad',
  'Chile',
  'China',
  'Colombia',
  'Comoros',
  'Congo',
  'Costa Rica',
  'Côte d’Ivoire',
  'Croatia',
  'Cuba',
  'Cyprus',
  'Czechia',
  'Democratic Republic of the Congo',
  'Denmark',
  'Djibouti',
  'Dominica',
  'Dominican Republic',
  'Ecuador',
  'Egypt',
  'El Salvador',
  'Equatorial Guinea',
  'Eritrea',
  'Estonia',
  'Eswatini',
  'Ethiopia',
  'Fiji',
  'Finland',
  'France',
  'Gabon',
  'Gambia',
  'Georgia',
  'Germany',
  'Ghana',
  'Greece',
  'Grenada',
  'Guatemala',
  'Guinea',
  'Guinea-Bissau',
  'Guyana',
  'Haiti',
  'Honduras',
  'Hungary',
  'Iceland',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Jamaica',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kiribati',
  'Kuwait',
  'Kyrgyzstan',
  'Laos',
  'Latvia',
  'Lebanon',
  'Lesotho',
  'Liberia',
  'Libya',
  'Liechtenstein',
  'Lithuania',
  'Luxembourg',
  'Madagascar',
  'Malawi',
  'Malaysia',
  'Maldives',
  'Mali',
  'Malta',
  'Marshall Islands',
  'Mauritania',
  'Mauritius',
  'Mexico',
  'Micronesia',
  'Moldova',
  'Monaco',
  'Mongolia',
  'Montenegro',
  'Morocco',
  'Mozambique',
  'Myanmar',
  'Namibia',
  'Nauru',
  'Nepal',
  'Netherlands',
  'New Zealand',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'North Korea',
  'North Macedonia',
  'Norway',
  'Oman',
  'Pakistan',
  'Palau',
  'Palestine',
  'Panama',
  'Papua New Guinea',
  'Paraguay',
  'Peru',
  'Philippines',
  'Poland',
  'Portugal',
  'Qatar',
  'Romania',
  'Russia',
  'Rwanda',
  'Saint Kitts and Nevis',
  'Saint Lucia',
  'Saint Vincent and the Grenadines',
  'Samoa',
  'San Marino',
  'São Tomé and Príncipe',
  'Saudi Arabia',
  'Senegal',
  'Serbia',
  'Seychelles',
  'Sierra Leone',
  'Singapore',
  'Slovakia',
  'Slovenia',
  'Solomon Islands',
  'Somalia',
  'South Africa',
  'South Korea',
  'South Sudan',
  'Spain',
  'Sri Lanka',
  'Sudan',
  'Suriname',
  'Sweden',
  'Switzerland',
  'Syria',
  'Taiwan',
  'Tajikistan',
  'Tanzania',
  'Thailand',
  'Timor-Leste',
  'Togo',
  'Tonga',
  'Trinidad and Tobago',
  'Tunisia',
  'Türkiye',
  'Turkmenistan',
  'Tuvalu',
  'Uganda',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Uruguay',
  'Uzbekistan',
  'Vanuatu',
  'Vatican City',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambia',
  'Zimbabwe',
];
