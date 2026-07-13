part of '../../app.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final firstName = TextEditingController();
  final birthDate = TextEditingController();
  final city = TextEditingController();
  final country = TextEditingController(text: 'Canada');
  final bio = TextEditingController();
  String gender = 'Prefer not to say';
  bool saving = false;

  @override
  void dispose() {
    firstName.dispose();
    birthDate.dispose();
    city.dispose();
    country.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (selected != null) {
      birthDate.text = selected.toIso8601String().split('T').first;
    }
  }

  Future<void> _continue() async {
    if (firstName.text.trim().isEmpty ||
        city.text.trim().isEmpty ||
        DateTime.tryParse(birthDate.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your first name, birth date, and city.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await MapLovRepository.instance.saveMyProfile({
        'first_name': firstName.text.trim(),
        'date_of_birth': birthDate.text,
        'gender': gender,
        'city': city.text.trim(),
        'country_name': country.text.trim(),
        'country_code': country.text.trim().toLowerCase() == 'canada'
            ? 'CA'
            : null,
        'bio': bio.text.trim(),
      });
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
            const CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.palePink,
              child: Icon(Icons.person, size: 70, color: AppColors.softPink),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.managePhotos),
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
          ],
        ),
      ),
      const _SectionTitle('About you'),
      TextField(
        controller: firstName,
        decoration: const InputDecoration(
          labelText: 'First name',
          prefixIcon: Icon(Icons.badge_outlined),
        ),
      ),
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
      DropdownButtonFormField<String>(
        initialValue: gender,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Gender'),
        items: const ['Woman', 'Man', 'Non-binary', 'Prefer not to say']
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => gender = value ?? gender),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: city,
        decoration: const InputDecoration(
          labelText: 'City',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: country,
        decoration: const InputDecoration(
          labelText: 'Country',
          prefixIcon: Icon(Icons.public),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: bio,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Tell people about yourself',
        ),
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        saving ? 'Saving…' : 'Continue to preferences',
        onPressed: saving ? () {} : _continue,
      ),
    ],
  );
}
