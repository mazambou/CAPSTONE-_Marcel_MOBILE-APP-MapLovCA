part of '../../app.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.dateOfBirth});

  final DateTime? dateOfBirth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _customCityController = TextEditingController();
  String _country = 'Canada';
  String _city = 'Toronto';
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _customCityController.dispose();
    super.dispose();
  }

  List<String> get _availableCities {
    final known = _registrationCitiesByCountry[_country];
    if (known == null) return const ['Other city'];
    return [...known, 'Other city'];
  }

  String get _selectedCity =>
      _city == 'Other city' ? _customCityController.text.trim() : _city;

  String get _phoneNumber {
    final national = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+${_countryCallingCodes[_country]}${national.replaceFirst(RegExp(r'^0+'), '')}';
  }

  void _selectCountry(String country) {
    setState(() {
      _country = country;
      _city = _registrationCitiesByCountry[country]?.first ?? 'Other city';
      _customCityController.clear();
    });
  }

  Future<void> _register() async {
    if (_isLoading) return;
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final result = await AuthService.instance.signUp(
        fullName: _fullNameController.text,
        email: _emailController.text,
        phone: _phoneNumber,
        password: _passwordController.text,
        country: _country,
        city: _selectedCity,
        dateOfBirth: widget.dateOfBirth!,
      );
      if (!mounted) return;
      if (result.requiresEmailConfirmation) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              email: _emailController.text.trim().toLowerCase(),
            ),
          ),
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.profileSetup,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = AuthService.instance.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validate() {
    if (widget.dateOfBirth == null) {
      return 'Confirm your date of birth before creating an account.';
    }
    if (_fullNameController.text.trim().length < 2) {
      return 'Enter your full name.';
    }
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_phoneNumber)) {
      return 'Enter a valid phone number.';
    }
    final password = _passwordController.text;
    if (password.length < 8 ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Use at least 8 characters, including a number and a symbol.';
    }
    if (password != _confirmPasswordController.text) {
      return 'Passwords do not match.';
    }
    if (_selectedCity.isEmpty) {
      return 'Enter your city.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Create your account',
      subtitle: 'Tell us a little about yourself.',
      image: 'assets/register/register.png',
      fields: [
        _Field(
          'Full name',
          Icons.badge_outlined,
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          enabled: !_isLoading,
        ),
        _Field(
          'Email',
          Icons.email_outlined,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          enabled: !_isLoading,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 126,
              child: KeyedSubtree(
                key: const Key('phone_country_indicator'),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('phone_country_indicator_$_country'),
                  initialValue: _country,
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: const InputDecoration(labelText: 'Code'),
                  selectedItemBuilder: (context) => _worldCountries
                      .map(
                        (country) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text('+${_countryCallingCodes[country]}'),
                        ),
                      )
                      .toList(),
                  items: _worldCountries
                      .map(
                        (country) => DropdownMenuItem(
                          value: country,
                          child: Text(
                            '$country (+${_countryCallingCodes[country]})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value != null) _selectCountry(value);
                        },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Field(
                'Phone number',
                Icons.phone_outlined,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                enabled: !_isLoading,
              ),
            ),
          ],
        ),
        _Field(
          'Password',
          Icons.lock_outline,
          secret: true,
          controller: _passwordController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_isLoading,
        ),
        _Field(
          'Confirm password',
          Icons.lock_outline,
          secret: true,
          controller: _confirmPasswordController,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_isLoading,
        ),
        KeyedSubtree(
          key: const Key('registration_country_dropdown'),
          child: DropdownButtonFormField<String>(
            key: ValueKey('registration_country_dropdown_$_country'),
            initialValue: _country,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.public),
            ),
            items: _worldCountries
                .map(
                  (country) => DropdownMenuItem(
                    value: country,
                    child: Text(country, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _isLoading
                ? null
                : (value) {
                    if (value == null) return;
                    _selectCountry(value);
                  },
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('registration_city_dropdown_$_country'),
          initialValue: _city,
          isExpanded: true,
          menuMaxHeight: 360,
          decoration: const InputDecoration(
            labelText: 'City',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: _availableCities
              .map(
                (city) => DropdownMenuItem(
                  value: city,
                  child: Text(city, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: _isLoading || _country.isEmpty
              ? null
              : (value) => setState(() {
                  _city = value ?? _city;
                  if (_city != 'Other city') _customCityController.clear();
                }),
        ),
        if (_city == 'Other city')
          _Field(
            'City name',
            Icons.edit_location_alt_outlined,
            controller: _customCityController,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.addressCity],
            enabled: !_isLoading,
            onSubmitted: (_) => _register(),
          ),
      ],
      primaryLabel: 'Create Account',
      onPrimary: _register,
      errorText: _errorText,
      isLoading: _isLoading,
    );
  }
}

const _registrationCitiesByCountry = <String, List<String>>{
  'Canada': _canadianCitiesWithoutAny,
  'United States': [
    'New York',
    'Los Angeles',
    'Chicago',
    'Houston',
    'Phoenix',
    'Philadelphia',
    'San Antonio',
    'San Diego',
    'Dallas',
    'Austin',
    'San Francisco',
    'Seattle',
    'Boston',
    'Miami',
    'Washington',
  ],
  'Mexico': ['Mexico City', 'Guadalajara', 'Monterrey', 'Puebla', 'Tijuana'],
  'Brazil': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Recife'],
  'United Kingdom': [
    'London',
    'Birmingham',
    'Manchester',
    'Glasgow',
    'Edinburgh',
  ],
  'France': ['Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice', 'Bordeaux'],
  'Germany': ['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt'],
  'Spain': ['Madrid', 'Barcelona', 'Valencia', 'Seville', 'Bilbao'],
  'Italy': ['Rome', 'Milan', 'Naples', 'Turin', 'Florence'],
  'Belgium': ['Brussels', 'Antwerp', 'Ghent', 'Liège', 'Bruges'],
  'Switzerland': ['Zürich', 'Geneva', 'Basel', 'Lausanne', 'Bern'],
  'Morocco': ['Casablanca', 'Rabat', 'Marrakesh', 'Tangier', 'Fez'],
  'Algeria': ['Algiers', 'Oran', 'Constantine', 'Annaba', 'Blida'],
  'Tunisia': ['Tunis', 'Sfax', 'Sousse', 'Kairouan', 'Bizerte'],
  'Senegal': ['Dakar', 'Thiès', 'Saint-Louis', 'Rufisque', 'Ziguinchor'],
  'Cameroon': ['Douala', 'Yaoundé', 'Bafoussam', 'Garoua', 'Bamenda'],
  'Côte d’Ivoire': ['Abidjan', 'Bouaké', 'Yamoussoukro', 'Daloa', 'San-Pédro'],
  'Democratic Republic of the Congo': [
    'Kinshasa',
    'Lubumbashi',
    'Mbuji-Mayi',
    'Goma',
    'Kisangani',
  ],
  'Nigeria': ['Lagos', 'Abuja', 'Kano', 'Ibadan', 'Port Harcourt'],
  'South Africa': ['Johannesburg', 'Cape Town', 'Durban', 'Pretoria', 'Soweto'],
  'India': ['Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad', 'Chennai'],
  'China': ['Shanghai', 'Beijing', 'Shenzhen', 'Guangzhou', 'Chengdu'],
  'Japan': ['Tokyo', 'Yokohama', 'Osaka', 'Nagoya', 'Sapporo'],
  'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
  'New Zealand': [
    'Auckland',
    'Wellington',
    'Christchurch',
    'Hamilton',
    'Dunedin',
  ],
};

const _canadianCitiesWithoutAny = [
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
  'Windsor',
  'Saskatoon',
  'Regina',
  'St. John’s',
  'Kelowna',
  'Sherbrooke',
  'Moncton',
];

const _countryCallingCodes = <String, String>{
  'Afghanistan': '93',
  'Albania': '355',
  'Algeria': '213',
  'Andorra': '376',
  'Angola': '244',
  'Antigua and Barbuda': '1268',
  'Argentina': '54',
  'Armenia': '374',
  'Australia': '61',
  'Austria': '43',
  'Azerbaijan': '994',
  'Bahamas': '1242',
  'Bahrain': '973',
  'Bangladesh': '880',
  'Barbados': '1246',
  'Belarus': '375',
  'Belgium': '32',
  'Belize': '501',
  'Benin': '229',
  'Bhutan': '975',
  'Bolivia': '591',
  'Bosnia and Herzegovina': '387',
  'Botswana': '267',
  'Brazil': '55',
  'Brunei': '673',
  'Bulgaria': '359',
  'Burkina Faso': '226',
  'Burundi': '257',
  'Cabo Verde': '238',
  'Cambodia': '855',
  'Cameroon': '237',
  'Canada': '1',
  'Central African Republic': '236',
  'Chad': '235',
  'Chile': '56',
  'China': '86',
  'Colombia': '57',
  'Comoros': '269',
  'Congo': '242',
  'Costa Rica': '506',
  'Côte d’Ivoire': '225',
  'Croatia': '385',
  'Cuba': '53',
  'Cyprus': '357',
  'Czechia': '420',
  'Democratic Republic of the Congo': '243',
  'Denmark': '45',
  'Djibouti': '253',
  'Dominica': '1767',
  'Dominican Republic': '1809',
  'Ecuador': '593',
  'Egypt': '20',
  'El Salvador': '503',
  'Equatorial Guinea': '240',
  'Eritrea': '291',
  'Estonia': '372',
  'Eswatini': '268',
  'Ethiopia': '251',
  'Fiji': '679',
  'Finland': '358',
  'France': '33',
  'Gabon': '241',
  'Gambia': '220',
  'Georgia': '995',
  'Germany': '49',
  'Ghana': '233',
  'Greece': '30',
  'Grenada': '1473',
  'Guatemala': '502',
  'Guinea': '224',
  'Guinea-Bissau': '245',
  'Guyana': '592',
  'Haiti': '509',
  'Honduras': '504',
  'Hungary': '36',
  'Iceland': '354',
  'India': '91',
  'Indonesia': '62',
  'Iran': '98',
  'Iraq': '964',
  'Ireland': '353',
  'Israel': '972',
  'Italy': '39',
  'Jamaica': '1876',
  'Japan': '81',
  'Jordan': '962',
  'Kazakhstan': '7',
  'Kenya': '254',
  'Kiribati': '686',
  'Kuwait': '965',
  'Kyrgyzstan': '996',
  'Laos': '856',
  'Latvia': '371',
  'Lebanon': '961',
  'Lesotho': '266',
  'Liberia': '231',
  'Libya': '218',
  'Liechtenstein': '423',
  'Lithuania': '370',
  'Luxembourg': '352',
  'Madagascar': '261',
  'Malawi': '265',
  'Malaysia': '60',
  'Maldives': '960',
  'Mali': '223',
  'Malta': '356',
  'Marshall Islands': '692',
  'Mauritania': '222',
  'Mauritius': '230',
  'Mexico': '52',
  'Micronesia': '691',
  'Moldova': '373',
  'Monaco': '377',
  'Mongolia': '976',
  'Montenegro': '382',
  'Morocco': '212',
  'Mozambique': '258',
  'Myanmar': '95',
  'Namibia': '264',
  'Nauru': '674',
  'Nepal': '977',
  'Netherlands': '31',
  'New Zealand': '64',
  'Nicaragua': '505',
  'Niger': '227',
  'Nigeria': '234',
  'North Korea': '850',
  'North Macedonia': '389',
  'Norway': '47',
  'Oman': '968',
  'Pakistan': '92',
  'Palau': '680',
  'Palestine': '970',
  'Panama': '507',
  'Papua New Guinea': '675',
  'Paraguay': '595',
  'Peru': '51',
  'Philippines': '63',
  'Poland': '48',
  'Portugal': '351',
  'Qatar': '974',
  'Romania': '40',
  'Russia': '7',
  'Rwanda': '250',
  'Saint Kitts and Nevis': '1869',
  'Saint Lucia': '1758',
  'Saint Vincent and the Grenadines': '1784',
  'Samoa': '685',
  'San Marino': '378',
  'São Tomé and Príncipe': '239',
  'Saudi Arabia': '966',
  'Senegal': '221',
  'Serbia': '381',
  'Seychelles': '248',
  'Sierra Leone': '232',
  'Singapore': '65',
  'Slovakia': '421',
  'Slovenia': '386',
  'Solomon Islands': '677',
  'Somalia': '252',
  'South Africa': '27',
  'South Korea': '82',
  'South Sudan': '211',
  'Spain': '34',
  'Sri Lanka': '94',
  'Sudan': '249',
  'Suriname': '597',
  'Sweden': '46',
  'Switzerland': '41',
  'Syria': '963',
  'Taiwan': '886',
  'Tajikistan': '992',
  'Tanzania': '255',
  'Thailand': '66',
  'Timor-Leste': '670',
  'Togo': '228',
  'Tonga': '676',
  'Trinidad and Tobago': '1868',
  'Tunisia': '216',
  'Türkiye': '90',
  'Turkmenistan': '993',
  'Tuvalu': '688',
  'Uganda': '256',
  'Ukraine': '380',
  'United Arab Emirates': '971',
  'United Kingdom': '44',
  'United States': '1',
  'Uruguay': '598',
  'Uzbekistan': '998',
  'Vanuatu': '678',
  'Vatican City': '39',
  'Venezuela': '58',
  'Vietnam': '84',
  'Yemen': '967',
  'Zambia': '260',
  'Zimbabwe': '263',
};
