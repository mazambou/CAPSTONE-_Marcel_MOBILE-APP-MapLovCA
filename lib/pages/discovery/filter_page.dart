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

  void _resetFilters() {
    setState(() {
      ages = const RangeValues(18, 80);
      locationMode = 'Near me';
      distance = 10;
      selectedCity = 'Any city';
      selectedCountry = 'Canada';
    });
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Filters',
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
          FilterChip(label: Text('Sports'), selected: false, onSelected: null),
        ],
      ),
      const SizedBox(height: 24),
      _PrimaryButton('Apply Filters', onPressed: () => Navigator.pop(context)),
      TextButton(onPressed: _resetFilters, child: const Text('Reset')),
    ],
  );
}

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
