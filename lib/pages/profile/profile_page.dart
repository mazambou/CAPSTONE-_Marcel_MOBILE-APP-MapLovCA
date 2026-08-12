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
  bool allowInternationalDiscovery = true;
  bool savingInternationalDiscovery = false;
  bool showOriginOnProfile = true;
  bool savingOriginVisibility = false;
  bool discoverable = true;
  bool vip = false;
  bool savingDiscoverVisibility = false;
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
      final results = await Future.wait([
        MapLovRepository.instance.getProfile(id),
        MapLovRepository.instance.myProfileDetails(),
        MapLovRepository.instance.subscriptionInfo(),
      ]);
      final loaded = results[0] as UserProfile?;
      if (loaded == null) throw StateError('Your profile could not be loaded.');
      final profileDetails = results[1] as Map<String, dynamic>?;
      final subscription = results[2] as SubscriptionInfo;
      if (mounted) {
        setState(() {
          profile = loaded;
          allowInternationalDiscovery = loaded.allowsInternationalDiscovery;
          showOriginOnProfile = loaded.showsOriginOnProfile;
          discoverable = profileDetails?['is_discoverable'] as bool? ?? true;
          vip = subscription.isVip;
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

  Future<void> _setInternationalDiscovery(bool value) async {
    if (savingInternationalDiscovery) return;
    final previous = allowInternationalDiscovery;
    setState(() {
      allowInternationalDiscovery = value;
      savingInternationalDiscovery = true;
    });
    try {
      await MapLovRepository.instance.setInternationalDiscovery(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => allowInternationalDiscovery = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update international discovery: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => savingInternationalDiscovery = false);
    }
  }

  Future<void> _setOriginVisibility(bool value) async {
    if (savingOriginVisibility) return;
    final previous = showOriginOnProfile;
    setState(() {
      showOriginOnProfile = value;
      savingOriginVisibility = true;
    });
    try {
      await MapLovRepository.instance.setOriginProfileVisibility(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => showOriginOnProfile = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update origin visibility: $error')),
      );
    } finally {
      if (mounted) setState(() => savingOriginVisibility = false);
    }
  }

  Future<void> _setDiscoverVisibility(bool value) async {
    if (!vip) {
      await _requireSubscriptionFeature(
        context,
        requirement: _SubscriptionRequirement.vip,
        feature: 'Invisible navigation',
      );
      return;
    }
    if (savingDiscoverVisibility) return;
    final previous = discoverable;
    setState(() {
      discoverable = value;
      savingDiscoverVisibility = true;
    });
    try {
      await MapLovRepository.instance.setDiscoverable(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => discoverable = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update Discover visibility: $error')),
      );
    } finally {
      if (mounted) setState(() => savingDiscoverVisibility = false);
    }
  }

  Future<bool> _requirePremium({bool vip = false}) async {
    return _requireSubscriptionFeature(
      context,
      requirement: vip
          ? _SubscriptionRequirement.vip
          : _SubscriptionRequirement.premiumPlus,
      feature: vip ? 'Profile statistics' : 'Profile visitors',
    );
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
        '${profile.country}${profile.city.isEmpty ? '' : ', ${profile.city}'}',
        style: const TextStyle(color: AppColors.grayText),
      ),
      if (showOriginOnProfile && profile.originCountry.isNotEmpty)
        Text(
          'Originally from ${profile.originCountry}${profile.originCity.isEmpty ? '' : ', ${profile.originCity}'}',
          style: const TextStyle(color: AppColors.grayText),
        ),
      const SizedBox(height: 14),
      Card(
        color: AppColors.palePink,
        child: SwitchListTile.adaptive(
          key: const Key('profile_discover_visibility_switch'),
          secondary: Icon(
            discoverable
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.coral,
          ),
          value: discoverable,
          onChanged: savingDiscoverVisibility ? null : _setDiscoverVisibility,
          title: const Text(
            'Show my profile in Discover',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'VIP members can choose whether their profile appears in Discover.',
          ),
        ),
      ),
      Card(
        color: AppColors.palePink,
        child: SwitchListTile.adaptive(
          key: const Key('origin_profile_visibility_switch'),
          secondary: const Icon(
            Icons.home_work_outlined,
            color: AppColors.coral,
          ),
          value: showOriginOnProfile,
          onChanged: savingOriginVisibility ? null : _setOriginVisibility,
          title: const Text(
            'Show my origin on my profile',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Displays only your country and city of origin. Your origin region always remains hidden.',
          ),
        ),
      ),
      Card(
        color: AppColors.palePink,
        child: SwitchListTile.adaptive(
          key: const Key('international_discovery_switch'),
          secondary: const Icon(Icons.public_outlined, color: AppColors.coral),
          value: allowInternationalDiscovery,
          onChanged: savingInternationalDiscovery
              ? null
              : _setInternationalDiscovery,
          title: const Text(
            'Allow international discovery',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'When disabled, your profile is hidden from searches that use the International option.',
          ),
        ),
      ),
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
          subtitle: const Text('See who viewed your profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showVisitors,
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.analytics_outlined, color: AppColors.coral),
          title: const Text('Profile statistics'),
          subtitle: const Text('View your profile performance'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showStatistics,
        ),
      ),
      const SizedBox(height: 10),
      const _QuickCard('Dating preferences', Icons.tune, AppRoutes.preferences),
      const _SectionTitle('My community'),
      const _QuickCard('My Friends', Icons.groups_outlined, AppRoutes.friends),
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
