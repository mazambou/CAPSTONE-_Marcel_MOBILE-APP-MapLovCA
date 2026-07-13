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
  String goal = 'Long-term relationship';
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    profession.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await MapLovRepository.instance.saveMyProfile({
        'first_name': name.text.trim(),
        'city': city.text.trim(),
        'profession': profession.text.trim(),
        'bio': bio.text.trim(),
        'relationship_goal': goal,
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
  Widget build(BuildContext context) => _AppPage(
    title: 'Edit profile',
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
      TextField(
        controller: name,
        decoration: const InputDecoration(
          labelText: 'First name',
          prefixIcon: Icon(Icons.person_outline),
        ),
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
        controller: profession,
        decoration: const InputDecoration(
          labelText: 'Profession',
          prefixIcon: Icon(Icons.work_outline),
        ),
      ),
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
      DropdownButtonFormField<String>(
        initialValue: goal,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Goal'),
        items:
            const [
                  'Long-term relationship',
                  'Dating',
                  'Friendship',
                  'Networking',
                ]
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
        onChanged: (value) => setState(() => goal = value ?? goal),
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        saving ? 'Saving…' : 'Save changes',
        onPressed: saving ? () {} : _save,
      ),
    ],
  );
}
