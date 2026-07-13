part of '../../app.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
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
        child: Image.asset(
          'assets/profile/profile_user_placeholder.png',
          height: 280,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Jamie, 29',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const Text(
        'Toronto, Canada',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
      const Text(
        'Curious traveler, coffee enthusiast, and always ready for a live concert.',
      ),
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
      SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: mockProfiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.photoViewer),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                mockProfiles[i].imagePath,
                width: 100,
                fit: BoxFit.cover,
              ),
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
