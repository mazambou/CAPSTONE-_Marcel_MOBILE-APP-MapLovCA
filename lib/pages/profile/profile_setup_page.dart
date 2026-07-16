part of '../../app.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final bio = TextEditingController();
  String gender = 'Prefer not to say';
  bool saving = false;
  late Future<List<Map<String, dynamic>>> photos;

  @override
  void initState() {
    super.initState();
    photos = MapLovRepository.instance.myPhotos();
  }

  @override
  void dispose() {
    bio.dispose();
    super.dispose();
  }

  Future<void> _managePhotos() async {
    await Navigator.pushNamed(context, AppRoutes.managePhotos);
    if (mounted) {
      setState(() => photos = MapLovRepository.instance.myPhotos());
    }
  }

  Future<void> _continue() async {
    setState(() => saving = true);
    try {
      await MapLovRepository.instance.saveMyProfile({
        'gender': gender,
        'bio': bio.text.trim(),
        'spoken_languages': const ['English'],
      });
      await MapLovRepository.instance.completeProfileIfReady();
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
            FutureBuilder<List<Map<String, dynamic>>>(
              future: photos,
              builder: (context, snapshot) {
                final photo = snapshot.data?.firstOrNull?['url'] as String?;
                return ClipOval(
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: photo == null
                        ? const ColoredBox(
                            color: AppColors.palePink,
                            child: Icon(
                              Icons.person,
                              size: 70,
                              color: AppColors.softPink,
                            ),
                          )
                        : photo.startsWith('http')
                        ? Image.network(photo, fit: BoxFit.cover)
                        : Image.asset(photo, fit: BoxFit.cover),
                  ),
                );
              },
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'Add profile photo',
                onPressed: _managePhotos,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
          ],
        ),
      ),
      const _SectionTitle('About you'),
      const Text(
        'Your name, birth date and location are already saved. You can add photos now or after registration.',
        style: TextStyle(color: AppColors.grayText),
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
        controller: bio,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Tell people about yourself',
        ),
      ),
      const SizedBox(height: 20),
      KeyedSubtree(
        key: const Key('profile_setup_continue'),
        child: _PrimaryButton(
          saving ? 'Saving…' : 'Continue to preferences',
          onPressed: saving ? () {} : _continue,
        ),
      ),
    ],
  );
}
