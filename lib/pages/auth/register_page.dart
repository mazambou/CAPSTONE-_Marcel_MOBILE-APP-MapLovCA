part of '../../app.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.gateData, this.dateOfBirth});

  final RegistrationGateData? gateData;
  final DateTime? dateOfBirth;

  DateTime? get effectiveDateOfBirth => gateData?.dateOfBirth ?? dateOfBirth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _country = 'Canada';
  String _countryCode = 'CA';
  String _phoneCountry = 'Canada';
  String _region = 'Ontario';
  String _city = 'Toronto';
  bool _isLoading = false;
  bool _detectingResidence = AuthService.instance.isConfigured;
  bool _residenceDetected = !AuthService.instance.isConfigured;
  DetectedResidence? _detectedResidence;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (AuthService.instance.isConfigured) {
      unawaited(_detectResidence());
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _phoneNumber {
    final national = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+${_countryCallingCodes[_phoneCountry]}${national.replaceFirst(RegExp(r'^0+'), '')}';
  }

  String? _supportedCountry(String detected) {
    if (_worldCountries.contains(detected)) return detected;
    return const {
      'United States of America': 'United States',
      'Ivory Coast': 'Côte d’Ivoire',
      'Democratic Republic of Congo': 'Democratic Republic of the Congo',
      'Republic of the Congo': 'Congo',
    }[detected];
  }

  String _detectedRegionSelection(
    String country,
    String detectedRegion,
    String detectedCity,
  ) {
    final options = _regionsByCountry[country] ?? const <String>[];
    for (final option in options) {
      if (option.toLowerCase() == detectedRegion.toLowerCase()) return option;
    }
    return _regionForKnownCity(country, detectedCity) ??
        (options.isEmpty ? 'Other region' : options.first);
  }

  Future<void> _detectResidence() async {
    if (mounted) {
      setState(() {
        _detectingResidence = true;
        _errorText = null;
      });
    }
    try {
      final detected = await LocationService.instance.detectResidence();
      final country = _supportedCountry(detected.country);
      if (country == null) {
        throw ResidenceDetectionFailure(
          'MapLov does not yet support registration from ${detected.country}.',
        );
      }
      final region = _detectedRegionSelection(
        country,
        detected.region,
        detected.city,
      );
      final knownCities = _citiesForCountryRegion(country, region);
      final matchingCity = knownCities
          .where((city) => city.toLowerCase() == detected.city.toLowerCase())
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _detectedResidence = detected;
        _country = country;
        _countryCode = detected.countryCode;
        _region = region == 'Other region' ? detected.region : region;
        _city = matchingCity ?? detected.city;
        _phoneCountry = country;
        _residenceDetected = true;
        _detectingResidence = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _residenceDetected = false;
        _detectingResidence = false;
        _errorText =
            'Location is required to verify your country of residence. $error';
      });
    }
  }

  Future<void> _register() async {
    if (_isLoading) return;
    if (!_residenceDetected) {
      await _detectResidence();
      if (!_residenceDetected) return;
    }
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
        phoneCountry: _phoneCountry,
        callingCode: _countryCallingCodes[_phoneCountry]!,
        password: _passwordController.text,
        country: _country,
        countryCode: _countryCode,
        region: _region,
        originCountry: '',
        originRegion: '',
        originCity: '',
        city: _city,
        dateOfBirth: widget.effectiveDateOfBirth!,
        acceptedDocuments:
            widget.gateData?.acceptedDocuments ?? _legalDocumentVersions,
        legalAcceptedAt: widget.gateData?.acceptedAt ?? DateTime.now().toUtc(),
      );
      if (!mounted) return;
      final detectedResidence = _detectedResidence;
      if (!result.requiresEmailConfirmation && detectedResidence != null) {
        await MapLovRepository.instance.updateLocation(
          latitude: detectedResidence.position.latitude,
          longitude: detectedResidence.position.longitude,
          accuracy: detectedResidence.position.accuracy,
        );
        await MapLovRepository.instance.syncResidenceFromLocation(
          country: _country,
          countryCode: _countryCode,
          region: _region,
          city: _city,
        );
        if (!mounted) return;
      }
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
    if (widget.effectiveDateOfBirth == null) {
      return 'Confirm your age and accept every required agreement first.';
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
              child: InputDecorator(
                key: const Key('phone_country_indicator'),
                decoration: InputDecoration(
                  labelText: context.tr('Code'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: _detectingResidence
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const Key('retry_phone_country_detection'),
                          tooltip: 'Refresh GPS country',
                          onPressed: _isLoading
                              ? null
                              : () => unawaited(_detectResidence()),
                          icon: const Icon(Icons.my_location, size: 20),
                        ),
                ),
                child: Text(
                  _detectingResidence
                      ? '…'
                      : '+${_countryCallingCodes[_phoneCountry]}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
                enabled: !_isLoading && _residenceDetected,
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
  'Cameroon': [
    'Ngaoundéré',
    'Meiganga',
    'Banyo',
    'Tibati',
    'Tignère',
    'Yaoundé',
    'Mbalmayo',
    'Bafia',
    'Obala',
    'Mfou',
    'Nanga-Eboko',
    'Akonolinga',
    'Eséka',
    'Monatélé',
    'Ntui',
    'Bertoua',
    'Batouri',
    'Yokadouma',
    'Abong-Mbang',
    'Garoua-Boulaï',
    'Bélabo',
    'Kétté',
    'Lomié',
    'Maroua',
    'Kousséri',
    'Mokolo',
    'Yagoua',
    'Mora',
    'Kaélé',
    'Bogo',
    'Maga',
    'Waza',
    'Douala',
    'Nkongsamba',
    'Edéa',
    'Loum',
    'Manjo',
    'Melong',
    'Mbanga',
    'Dibombari',
    'Garoua',
    'Guider',
    'Figuil',
    'Pitoa',
    'Poli',
    'Lagdo',
    'Touboro',
    'Rey-Bouba',
    'Tcholliré',
    'Bamenda',
    'Kumbo',
    'Wum',
    'Nkambe',
    'Fundong',
    'Ndop',
    'Bali',
    'Bafut',
    'Batibo',
    'Mbengwi',
    'Ebolowa',
    'Kribi',
    'Sangmélima',
    'Ambam',
    'Lolodorf',
    'Akom II',
    'Djoum',
    'Zoétélé',
    'Meyomessala',
    'Buea',
    'Limbe',
    'Kumba',
    'Tiko',
    'Mamfe',
    'Muyuka',
    'Mutengene',
    'Bangem',
    'Mundemba',
    'Tombel',
    'Ekondo-Titi',
    'Bafoussam',
    'Dschang',
    'Foumban',
    'Mbouda',
    'Bafang',
    'Bangangté',
    'Foumbot',
    'Bandjoun',
    'Baham',
    'Tonga',
    'Batcham',
  ],
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
  'Abbotsford',
  'Airdrie',
  'Ajax',
  'Alma',
  'Amos',
  'Aurora',
  'Barrie',
  'Bathurst',
  'Belleville',
  'Blainville',
  'Boisbriand',
  'Boucherville',
  'Brampton',
  'Brandon',
  'Brantford',
  'Brockville',
  'Brossard',
  'Burlington',
  'Burnaby',
  'Calgary',
  'Cambridge',
  'Campbell River',
  'Campbellton',
  'Camrose',
  'Charlottetown',
  'Châteauguay',
  'Chatham-Kent',
  'Chilliwack',
  'Clarence-Rockland',
  'Cold Lake',
  'Collingwood',
  'Coquitlam',
  'Corner Brook',
  'Cornwall',
  'Côte Saint-Luc',
  'Courtenay',
  'Cranbrook',
  'Dartmouth',
  'Dauphin',
  'Delta',
  'Dieppe',
  'Dollard-des-Ormeaux',
  'Drummondville',
  'Edmonton',
  'Edmundston',
  'Elliot Lake',
  'Estevan',
  'Flin Flon',
  'Fort McMurray',
  'Fort Saskatchewan',
  'Fort St. John',
  'Fredericton',
  'Gatineau',
  'Grande Prairie',
  'Granby',
  'Greater Sudbury',
  'Guelph',
  'Halifax',
  'Hamilton',
  'Iqaluit',
  'Joliette',
  'Kamloops',
  'Kawartha Lakes',
  'Kelowna',
  'Kenora',
  'Kingston',
  'Kirkland',
  'Kitchener',
  'La Prairie',
  'Lacombe',
  'Langford',
  'Langley',
  'Laval',
  'Leduc',
  'Lethbridge',
  'Lévis',
  'Lloydminster',
  'London',
  'Longueuil',
  'Maple Ridge',
  'Markham',
  'Medicine Hat',
  'Miramichi',
  'Mirabel',
  'Mississauga',
  'Moncton',
  'Mont-Laurier',
  'Montréal',
  'Moose Jaw',
  'Morden',
  'Mount Pearl',
  'Nanaimo',
  'Nelson',
  'New Glasgow',
  'New Westminster',
  'Niagara Falls',
  'North Bay',
  'North Vancouver',
  'Oakville',
  'Okotoks',
  'Orangeville',
  'Orillia',
  'Oshawa',
  'Ottawa',
  'Owen Sound',
  'Parksville',
  'Pembroke',
  'Penticton',
  'Peterborough',
  'Pickering',
  'Port Alberni',
  'Port Coquitlam',
  'Port Moody',
  'Portage la Prairie',
  'Powell River',
  'Prince Albert',
  'Prince George',
  'Prince Rupert',
  'Québec City',
  'Quesnel',
  'Quinte West',
  'Red Deer',
  'Regina',
  'Repentigny',
  'Richmond',
  'Richmond Hill',
  'Rimouski',
  'Rivière-du-Loup',
  'Rouyn-Noranda',
  'Saguenay',
  'Saint John',
  'Saint-Bruno-de-Montarville',
  'Saint-Constant',
  'Saint-Eustache',
  'Saint-Georges',
  'Saint-Hyacinthe',
  'Saint-Jean-sur-Richelieu',
  'Saint-Jérôme',
  'Saint-Lambert',
  'Sainte-Julie',
  'Salmon Arm',
  'Sarnia',
  'Saskatoon',
  'Sault Ste. Marie',
  'Selkirk',
  'Sept-Îles',
  'Sherbrooke',
  'Spruce Grove',
  'St. Albert',
  'St. Catharines',
  'St. John’s',
  'St. Thomas',
  'Steinbach',
  'Stratford',
  'Surrey',
  'Swift Current',
  'Sydney',
  'Terrace',
  'Terrebonne',
  'Thetford Mines',
  'Thompson',
  'Thunder Bay',
  'Timmins',
  'Toronto',
  'Trail',
  'Trois-Rivières',
  'Val-d’Or',
  'Vancouver',
  'Vaughan',
  'Vernon',
  'Victoria',
  'Waterloo',
  'Welland',
  'West Kelowna',
  'White Rock',
  'Whitehorse',
  'Williams Lake',
  'Windsor',
  'Winkler',
  'Winnipeg',
  'Woodstock',
  'Yellowknife',
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
