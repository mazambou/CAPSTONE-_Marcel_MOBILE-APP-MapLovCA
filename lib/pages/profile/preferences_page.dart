part of '../../app.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  RangeValues ages = const RangeValues(24, 38);
  String searchMode = 'Around me';

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Dating preferences',
    children: [
      const Text(
        'Tell MapLov who you would like to meet. These preferences improve your compatibility results.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const _SectionTitle('Who you want to meet'),
      const _Dropdown('Gender', ['Everyone', 'Women', 'Men', 'Non-binary']),
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
          ButtonSegment(value: 'Worldwide', label: Text('World')),
        ],
        selected: {searchMode},
        onSelectionChanged: (value) => setState(() => searchMode = value.first),
      ),
      const SizedBox(height: 14),
      const _Field('Preferred country', Icons.public),
      const _SectionTitle('Compatibility priorities'),
      const _Dropdown('Relationship goal', [
        'Long-term',
        'Dating',
        'Friendship',
        'Networking',
      ]),
      const SizedBox(height: 12),
      const _Dropdown('Languages', [
        'English & French',
        'English',
        'French',
        'Any language',
      ]),
      const SizedBox(height: 12),
      const _Dropdown('Personality', [
        'Any personality',
        'Calm',
        'Creative',
        'Adventurous',
        'Intellectual',
      ]),
      const SizedBox(height: 20),
      _PrimaryButton(
        'Save preferences',
        onPressed: () async {
          await MapLovRepository.instance.savePreferences(
            DiscoveryFilters(
              minimumAge: ages.start.round(),
              maximumAge: ages.end.round(),
              locationMode: switch (searchMode) {
                'Country' => 'my_country',
                'Worldwide' => 'worldwide',
                _ => 'near_me',
              },
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
