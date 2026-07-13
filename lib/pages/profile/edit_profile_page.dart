part of '../../app.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

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
      const _Field('Jamie', Icons.person_outline),
      const SizedBox(height: 12),
      const _Field('Toronto', Icons.location_city_outlined),
      const SizedBox(height: 12),
      const _Field('Product designer', Icons.work_outline),
      const SizedBox(height: 12),
      const TextField(
        maxLines: 4,
        decoration: InputDecoration(
          labelText: 'Bio',
          hintText: 'Curious traveler, coffee enthusiast...',
        ),
      ),
      const _SectionTitle('Relationship goal'),
      const _Dropdown('Goal', [
        'Long-term relationship',
        'Dating',
        'Friendship',
        'Networking',
      ]),
      const SizedBox(height: 20),
      _PrimaryButton('Save changes', onPressed: () => Navigator.pop(context)),
    ],
  );
}
