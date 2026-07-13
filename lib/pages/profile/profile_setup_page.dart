part of '../../app.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

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
      const _Field('First name', Icons.badge_outlined),
      const SizedBox(height: 12),
      const _Field('Date of birth', Icons.calendar_month_outlined),
      const SizedBox(height: 12),
      const _Dropdown('Gender', [
        'Woman',
        'Man',
        'Non-binary',
        'Prefer not to say',
      ]),
      const SizedBox(height: 12),
      const _Field('City', Icons.location_city_outlined),
      const SizedBox(height: 12),
      const _Field('Country', Icons.public),
      const SizedBox(height: 12),
      const TextField(
        maxLines: 4,
        decoration: InputDecoration(labelText: 'Tell people about yourself'),
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        'Continue to preferences',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.preferences),
      ),
    ],
  );
}
