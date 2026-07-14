part of '../../app.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile profile = const UserProfile(
    id: 'me',
    name: 'Jamie',
    age: 29,
    city: 'Toronto',
    compatibilityScore: 100,
    imagePath: 'assets/profile/profile_user_placeholder.png',
    photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    profession: 'Product designer',
    bio:
        'Curious traveler, coffee enthusiast, and always ready for a live concert.',
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = MapLovRepository.instance.currentUserId;
    if (id == null) return;
    final loaded = await MapLovRepository.instance.getProfile(id);
    if (loaded != null && mounted) setState(() => profile = loaded);
  }

  @override
  Widget build(BuildContext context) => _MainPage(
    index: 4,
    title: 'My profile',
    actions: [
      IconButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.editProfile),
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
        icon: const Icon(Icons.settings_outlined),
      ),
    ],
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: profileImage(profile, height: 280, width: double.infinity),
      ),
      const SizedBox(height: 16),
      Text(
        '${profile.name}, ${profile.age}',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        '${profile.city}, ${profile.country}',
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
      Text(profile.bio),
      const _SectionTitle('Interests'),
      const Wrap(
        spacing: 8,
        children: [
          Chip(label: Text('Travel')),
          Chip(label: Text('Music')),
          Chip(label: Text('Cooking')),
          Chip(label: Text('Hiking')),
        ],
      ),
      const _SectionTitle('Photos'),
      Card(
        color: AppColors.palePink,
        child: ListTile(
          key: const Key('manage_album_button'),
          leading: const CircleAvatar(
            backgroundColor: AppColors.deepPink,
            foregroundColor: Colors.white,
            child: Icon(Icons.add_photo_alternate_outlined),
          ),
          title: const Text(
            'Manage my album',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('Add or remove profile photos'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, AppRoutes.managePhotos),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: profile.photoUrls.isEmpty
              ? mockProfiles.length
              : profile.photoUrls.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.photoViewer),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: profile.photoUrls.isEmpty
                  ? profileImage(mockProfiles[i], width: 100)
                  : mediaImage(profile.photoUrls[i], width: 100),
            ),
          ),
        ),
      ),
      const _QuickCard(
        'Secret Garden',
        Icons.lock_outline,
        AppRoutes.gardenManagement,
      ),
      const SizedBox(height: 10),
      const _QuickCard('Dating preferences', Icons.tune, AppRoutes.preferences),
      const _SectionTitle('My community'),
      const Row(
        children: [
          Expanded(
            child: _QuickCard(
              'My Friends',
              Icons.groups_outlined,
              AppRoutes.friends,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _QuickCard(
              'Friends Posts',
              Icons.dynamic_feed_outlined,
              AppRoutes.posts,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const _QuickCard(
        'Friend Requests',
        Icons.person_add_alt,
        AppRoutes.friendRequests,
      ),
      const KeyedSubtree(
        key: Key('personal_recent_activity'),
        child: _SectionTitle('Recent activity'),
      ),
      const Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.palePink,
            child: Icon(Icons.favorite, color: AppColors.coral),
          ),
          title: Text('New compatible profiles'),
          subtitle: Text('3 suggestions were added today'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
      const Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.palePink,
            child: Icon(Icons.person_add_alt, color: AppColors.coral),
          ),
          title: Text('Friend request accepted'),
          subtitle: Text('Sophie is now your friend'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    ],
  );
}
