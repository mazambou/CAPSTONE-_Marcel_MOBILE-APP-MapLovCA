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
  bool loading = AuthService.instance.isConfigured;
  String? loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!AuthService.instance.isConfigured) return;
    final id = MapLovRepository.instance.currentUserId;
    if (mounted) setState(() => loading = true);
    try {
      if (id == null) throw StateError('No authenticated account was found.');
      final loaded = await MapLovRepository.instance.getProfile(id);
      if (loaded == null) throw StateError('Your profile could not be loaded.');
      if (mounted) {
        setState(() {
          profile = loaded;
          loadError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => loadError = '$error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editProfile() async {
    await Navigator.pushNamed(context, AppRoutes.editProfile);
    await _load();
  }

  Future<void> _managePhotos() async {
    await Navigator.pushNamed(context, AppRoutes.managePhotos);
    await _load();
  }

  Future<void> _choosePhotoDisplay() async {
    await Navigator.pushNamed(context, AppRoutes.photoDisplaySettings);
    await _load();
  }

  Future<bool> _requirePremium({bool vip = false}) async {
    final info = await MapLovRepository.instance.subscriptionInfo();
    final allowed = vip ? info.isVip : info.isPremium;
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vip
                ? 'Profile statistics require Premium VIP.'
                : 'Profile visitors require Premium Plus.',
          ),
        ),
      );
      await Navigator.pushNamed(context, AppRoutes.premium);
    }
    return allowed;
  }

  Future<void> _showVisitors() async {
    if (!await _requirePremium()) return;
    final visitors = await MapLovRepository.instance.profileVisitors();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Profile visitors',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (visitors.isEmpty) const ListTile(title: Text('No visitors yet.')),
          ...visitors.map(
            (visitor) => ListTile(
              leading: CircleAvatar(
                backgroundImage: profileImageProvider(visitor),
              ),
              title: Text('${visitor.name}, ${visitor.age}'),
              subtitle: Text(visitor.city),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatistics() async {
    if (!await _requirePremium(vip: true)) return;
    final statistics = await MapLovRepository.instance.profileStatistics();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statistics.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _MainPage(
        index: 4,
        title: 'My profile',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    if (loadError != null && AuthService.instance.isConfigured) {
      return _MainPage(
        index: 4,
        title: 'My profile',
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 70,
            color: AppColors.coral,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load your MapLov profile.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grayText),
          ),
          const SizedBox(height: 16),
          _PrimaryButton('Try again', onPressed: _load),
        ],
      );
    }
    return _buildProfile(context);
  }

  Widget _buildProfile(BuildContext context) => _MainPage(
    index: 4,
    title: 'My profile',
    actions: [
      IconButton(
        onPressed: _editProfile,
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
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${profile.name}, ${profile.age}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (profile.isVip) const _VipBadge(),
        ],
      ),
      Text(
        '${profile.city}, ${profile.country}',
        style: const TextStyle(color: AppColors.grayText),
      ),
      if (profile.originCountry.isNotEmpty)
        Text(
          'Originally from ${profile.originCity.isEmpty ? '' : '${profile.originCity}, '}${profile.originCountry}',
          style: const TextStyle(color: AppColors.grayText),
        ),
      const SizedBox(height: 14),
      Text(profile.bio),
      const _SectionTitle('Interests'),
      if (profile.interests.isEmpty && AuthService.instance.isConfigured)
        const Text('No interests added yet.')
      else
        Wrap(
          spacing: 8,
          children:
              (profile.interests.isEmpty
                      ? const ['Travel', 'Music', 'Cooking', 'Hiking']
                      : profile.interests)
                  .map((interest) => Chip(label: Text(interest)))
                  .toList(),
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
          onTap: _managePhotos,
        ),
      ),
      Card(
        color: AppColors.palePink,
        child: ListTile(
          key: const Key('profile_photo_display_button'),
          leading: const CircleAvatar(
            backgroundColor: AppColors.coral,
            foregroundColor: Colors.white,
            child: Icon(Icons.view_carousel_outlined),
          ),
          title: const Text(
            'Photo display',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            profile.photoDisplayStyle == PhotoDisplayStyle.social
                ? 'Social interactions'
                : 'Profile details',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _choosePhotoDisplay,
        ),
      ),
      const _QuickCard(
        'Secret Garden',
        Icons.lock_outline,
        AppRoutes.gardenManagement,
      ),
      const SizedBox(height: 10),
      Card(
        child: ListTile(
          leading: const Icon(
            Icons.visibility_outlined,
            color: AppColors.coral,
          ),
          title: const Text('Profile visitors'),
          subtitle: const Text('Premium Plus'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showVisitors,
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.analytics_outlined, color: AppColors.coral),
          title: const Text('Profile statistics'),
          subtitle: const Text('Premium VIP'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showStatistics,
        ),
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
      if (!AuthService.instance.isConfigured) ...[
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
    ],
  );
}
