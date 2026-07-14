part of '../../app.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final name = TextEditingController(text: 'Jamie');
  final city = TextEditingController(text: 'Toronto');
  final profession = TextEditingController(text: 'Product designer');
  final bio = TextEditingController();
  final birthDate = TextEditingController(text: '1997-01-01');

  String gender = 'Prefer not to say';
  String country = 'Canada';
  String goal = 'Long-term relationship';
  String religion = 'Prefer not to say';
  String childrenPreference = 'Not sure yet';
  String relationshipStatus = 'Single';
  String bodyType = 'Prefer not to say';
  String eyeColor = 'Prefer not to say';
  String hairColor = 'Prefer not to say';
  String beardStyle = 'Not applicable';
  String smokingStatus = 'Non-smoker';
  String educationLevel = 'Prefer not to say';
  String incomeLevel = 'Prefer not to say';
  double height = 170;
  bool saving = false;

  final Set<String> languages = {'English'};
  final Set<String> interests = {'Travel', 'Music', 'Hiking'};

  static const languageOptions = [
    'English',
    'French',
    'Spanish',
    'Arabic',
    'Mandarin',
    'Other',
  ];
  static const interestOptions = [
    'Travel',
    'Music',
    'Hiking',
    'Fitness',
    'Food',
    'Movies',
    'Reading',
    'Photography',
    'Cooking',
    'Art',
  ];
  static const goalOptions = [
    'Long-term relationship',
    'Marriage',
    'Dating',
    'Friendship',
    'Networking',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingProfile());
  }

  Future<void> _loadExistingProfile() async {
    try {
      final values = await MapLovRepository.instance.myProfileDetails();
      if (values == null || !mounted) return;
      setState(() {
        name.text = values['first_name'] as String? ?? name.text;
        city.text = values['city'] as String? ?? city.text;
        profession.text = values['profession'] as String? ?? profession.text;
        bio.text = values['bio'] as String? ?? bio.text;
        birthDate.text = values['date_of_birth'] as String? ?? birthDate.text;
        gender = values['gender'] as String? ?? gender;
        country = values['country_name'] as String? ?? country;
        goal = values['relationship_goal'] as String? ?? goal;
        religion = values['religion'] as String? ?? religion;
        childrenPreference =
            values['children_preference'] as String? ?? childrenPreference;
        relationshipStatus =
            values['relationship_status'] as String? ?? relationshipStatus;
        bodyType = values['body_type'] as String? ?? bodyType;
        eyeColor = values['eye_color'] as String? ?? eyeColor;
        hairColor = values['hair_color'] as String? ?? hairColor;
        beardStyle = values['beard_style'] as String? ?? beardStyle;
        smokingStatus = values['smoking_status'] as String? ?? smokingStatus;
        educationLevel = values['education_level'] as String? ?? educationLevel;
        incomeLevel = values['income_level'] as String? ?? incomeLevel;
        height = (values['height_cm'] as num?)?.toDouble() ?? height;

        final storedLanguages = values['spoken_languages'] as List<dynamic>?;
        if (storedLanguages != null && storedLanguages.isNotEmpty) {
          languages
            ..clear()
            ..addAll(storedLanguages.whereType<String>());
        }
        final storedInterests = values['interest_slugs'] as List<dynamic>?;
        if (storedInterests != null && storedInterests.isNotEmpty) {
          interests
            ..clear()
            ..addAll(storedInterests.whereType<String>().map(_displayFromSlug));
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load all profile details: $error')),
        );
      }
    }
  }

  String _displayFromSlug(String value) => value
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    profession.dispose();
    bio.dispose();
    birthDate.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(birthDate.text) ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (selected != null) {
      birthDate.text = selected.toIso8601String().split('T').first;
    }
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty || city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name and city are required.')),
      );
      return;
    }
    if (languages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one language.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await MapLovRepository.instance.saveMyProfile({
        'first_name': name.text.trim(),
        'date_of_birth': birthDate.text,
        'gender': gender,
        'city': city.text.trim(),
        'country_name': country,
        'country_code': country == 'Canada' ? 'CA' : null,
        'profession': profession.text.trim(),
        'education_level': educationLevel,
        'height_cm': height.round(),
        'relationship_goal': goal,
        'spoken_languages': languages.toList()..sort(),
        'religion': religion,
        'children_preference': childrenPreference,
        'relationship_status': relationshipStatus,
        'body_type': bodyType,
        'eye_color': eyeColor,
        'hair_color': hairColor,
        'beard_style': beardStyle,
        'smoking_status': smokingStatus,
        'income_level': incomeLevel,
        'interest_slugs':
            interests
                .map((value) => value.toLowerCase().replaceAll(' ', '-'))
                .toList()
              ..sort(),
        'bio': bio.text.trim(),
        'profile_completed_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Edit profile',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Basic info'),
              Tab(text: 'Profile details'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [_buildBasicInfo(), _buildFilterDetails()],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() => ListView(
    key: const Key('edit_profile_basic_tab'),
    padding: const EdgeInsets.all(20),
    children: [
      Center(
        child: CircleAvatar(
          radius: 62,
          backgroundImage: const AssetImage(
            'assets/profile/profile_user_placeholder.png',
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: IconButton.filled(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.managePhotos),
              icon: const Icon(Icons.camera_alt_outlined),
            ),
          ),
        ),
      ),
      const _SectionTitle('Profile information'),
      _textField(name, 'First name', Icons.person_outline),
      const SizedBox(height: 12),
      _textField(city, 'City', Icons.location_city_outlined),
      const SizedBox(height: 12),
      _textField(profession, 'Profession', Icons.work_outline),
      const SizedBox(height: 12),
      TextField(
        controller: bio,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Bio',
          hintText: 'Curious traveler, coffee enthusiast...',
        ),
      ),
      const _SectionTitle('Relationship goal'),
      _dropdown('Goal', goal, goalOptions, (value) => goal = value),
      const SizedBox(height: 20),
      _saveButton(),
    ],
  );

  Widget _buildFilterDetails() => ListView(
    key: const Key('edit_profile_filter_details_tab'),
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Complete the information that other members can use in Quick, Standard, and Advanced Filters.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const _SectionTitle('Basic matching information'),
      _dropdown('Gender', gender, const [
        'Woman',
        'Man',
        'Non-binary',
        'Prefer not to say',
      ], (value) => gender = value),
      const SizedBox(height: 12),
      TextField(
        controller: birthDate,
        readOnly: true,
        onTap: _pickBirthDate,
        decoration: const InputDecoration(
          labelText: 'Date of birth',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
      ),
      const SizedBox(height: 12),
      _dropdown('Country', country, const [
        'Canada',
        'United States',
        'France',
        'United Kingdom',
        'Other',
      ], (value) => country = value),
      const SizedBox(height: 12),
      _dropdown(
        'Relationship goal',
        goal,
        goalOptions,
        (value) => goal = value,
      ),
      const _SectionTitle('Languages'),
      _chips(languageOptions, languages),
      const _SectionTitle('Family & relationship'),
      _dropdown('Religion', religion, const [
        'Prefer not to say',
        'Christian',
        'Muslim',
        'Hindu',
        'Buddhist',
        'Jewish',
        'Spiritual',
        'Atheist',
        'Other',
      ], (value) => religion = value),
      const SizedBox(height: 12),
      _dropdown(
        'Children preference',
        childrenPreference,
        const [
          'Not sure yet',
          'Want children',
          'Have children',
          'Don’t want children',
          'Prefer not to say',
        ],
        (value) => childrenPreference = value,
      ),
      const SizedBox(height: 12),
      _dropdown(
        'Relationship status',
        relationshipStatus,
        const [
          'Single',
          'Divorced',
          'Separated',
          'Widowed',
          'Prefer not to say',
        ],
        (value) => relationshipStatus = value,
      ),
      const _SectionTitle('Appearance'),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Height: ${height.round()} cm',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: height,
                min: 100,
                max: 250,
                divisions: 150,
                label: '${height.round()} cm',
                onChanged: (value) => setState(() => height = value),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      _dropdown('Body type', bodyType, const [
        'Prefer not to say',
        'Slim',
        'Athletic',
        'Average',
        'Curvy',
        'Full-figured',
      ], (value) => bodyType = value),
      const SizedBox(height: 12),
      _dropdown('Eye color', eyeColor, const [
        'Prefer not to say',
        'Brown',
        'Blue',
        'Green',
        'Hazel',
        'Gray',
        'Other',
      ], (value) => eyeColor = value),
      const SizedBox(height: 12),
      _dropdown('Hair color', hairColor, const [
        'Prefer not to say',
        'Black',
        'Brown',
        'Auburn',
        'Blonde',
        'Red',
        'Gray',
        'Other',
      ], (value) => hairColor = value),
      const SizedBox(height: 12),
      _dropdown('Beard', beardStyle, const [
        'Not applicable',
        'No beard',
        'Short beard',
        'Full beard',
        'Prefer not to say',
      ], (value) => beardStyle = value),
      const SizedBox(height: 12),
      _dropdown('Smoking', smokingStatus, const [
        'Non-smoker',
        'Occasionally',
        'Smoker',
        'Prefer not to say',
      ], (value) => smokingStatus = value),
      const _SectionTitle('Education & career'),
      _dropdown('Education level', educationLevel, const [
        'Prefer not to say',
        'High school',
        'College',
        'Bachelor’s',
        'Master’s',
        'Doctorate',
      ], (value) => educationLevel = value),
      const SizedBox(height: 12),
      _textField(profession, 'Profession', Icons.work_outline),
      const SizedBox(height: 12),
      _dropdown('Income level', incomeLevel, const [
        'Prefer not to say',
        'Under 50k',
        '50k–100k',
        '100k–150k',
        '150k+',
      ], (value) => incomeLevel = value),
      const _SectionTitle('Interests'),
      _chips(interestOptions, interests),
      const _SectionTitle('Verification & activity'),
      const Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('Verified profile'),
              subtitle: Text('Managed by MapLov verification'),
              trailing: Chip(label: Text('Read only')),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.add_a_photo_outlined),
              title: Text('Photo verified'),
              subtitle: Text('Managed by MapLov verification'),
              trailing: Chip(label: Text('Read only')),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.circle, color: AppColors.success),
              title: Text('Activity status'),
              subtitle: Text('Updated automatically when you use MapLov'),
              trailing: Chip(label: Text('Automatic')),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _saveButton(),
      const SizedBox(height: 12),
      const Text(
        'Distance is calculated from your private location. Age is calculated from your date of birth. Neither can be edited manually.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText, fontSize: 12),
      ),
    ],
  );

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> update,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options
        .map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (selected) {
      if (selected != null) setState(() => update(selected));
    },
  );

  Widget _chips(List<String> options, Set<String> selected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((option) {
      return FilterChip(
        label: Text(option),
        selected: selected.contains(option),
        onSelected: (_) {
          setState(() {
            if (!selected.add(option)) selected.remove(option);
          });
        },
      );
    }).toList(),
  );

  Widget _saveButton() => _PrimaryButton(
    saving ? 'Saving…' : 'Save changes',
    onPressed: saving ? () {} : _save,
  );
}
