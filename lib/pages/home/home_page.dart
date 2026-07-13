part of '../../app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedTab = 'Discover';
  final Set<String> likedProfiles = {};

  List<UserProfile> get visibleProfiles {
    return switch (selectedTab) {
      'Nearby' =>
        mockProfiles.where((profile) => profile.distanceKm <= 10).toList(),
      'Online' => mockProfiles.where((profile) => profile.isOnline).toList(),
      'New' => mockProfiles.where((profile) => profile.isNew).toList(),
      _ => mockProfiles,
    };
  }

  void _openPhoto(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoViewerScreen(profile: profile)),
    );
  }

  void _openProfile(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
    );
  }

  void _toggleLike(UserProfile profile) {
    setState(() {
      if (!likedProfiles.add(profile.name)) {
        likedProfiles.remove(profile.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profiles = visibleProfiles;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DiscoverHeader(
              onFilters: () => Navigator.pushNamed(context, AppRoutes.filters),
              onNotifications: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            ),
            _DiscoverTabs(
              selectedTab: selectedTab,
              onSelected: (tab) => setState(() => selectedTab = tab),
            ),
            const Divider(height: 1),
            Expanded(
              child: profiles.isEmpty
                  ? const _EmptyDiscoverState()
                  : GridView.builder(
                      key: Key('discover_grid_$selectedTab'),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.70,
                          ),
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return _DiscoverGridCard(
                          profile: profile,
                          liked: likedProfiles.contains(profile.name),
                          onPhotoTap: () => _openPhoto(profile),
                          onNameTap: () => _openProfile(profile),
                          onLike: () => _toggleLike(profile),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _MapLovNavigationBar(selectedIndex: 0),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.onFilters,
    required this.onNotifications,
  });

  final VoidCallback onFilters;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          TextButton.icon(
            key: const Key('home_filters_button'),
            onPressed: onFilters,
            icon: const Icon(Icons.tune, color: AppColors.darkText),
            label: const Text(
              'Filters',
              style: TextStyle(
                color: AppColors.darkText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Map',
                      style: TextStyle(color: AppColors.darkText),
                    ),
                    TextSpan(
                      text: 'Lov',
                      style: TextStyle(color: AppColors.deepPink),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('home_notifications_button'),
            onPressed: onNotifications,
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_none, size: 29),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverTabs extends StatelessWidget {
  const _DiscoverTabs({required this.selectedTab, required this.onSelected});

  final String selectedTab;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['Discover', 'Nearby', 'Online', 'New']
          .map(
            (tab) => Expanded(
              child: InkWell(
                key: Key('discover_tab_$tab'),
                onTap: () => onSelected(tab),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      Text(
                        tab,
                        style: TextStyle(
                          color: selectedTab == tab
                              ? AppColors.deepPink
                              : AppColors.grayText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 3,
                        width: selectedTab == tab ? 54 : 0,
                        decoration: BoxDecoration(
                          color: AppColors.deepPink,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DiscoverGridCard extends StatelessWidget {
  const _DiscoverGridCard({
    required this.profile,
    required this.liked,
    required this.onPhotoTap,
    required this.onNameTap,
    required this.onLike,
  });

  final UserProfile profile;
  final bool liked;
  final VoidCallback onPhotoTap;
  final VoidCallback onNameTap;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: Key('profile_photo_${profile.name}'),
            onTap: onPhotoTap,
            child: Image.asset(
              profile.imagePath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD000000)],
                  stops: [0.46, 1],
                ),
              ),
            ),
          ),
          if (profile.isNew)
            const Positioned(
              left: 9,
              top: 9,
              child: _GridStatusBadge(
                label: 'New here ✨',
                foregroundColor: AppColors.deepPink,
                backgroundColor: Colors.white,
              ),
            ),
          if (profile.isOnline)
            const Positioned(
              right: 9,
              top: 9,
              child: _GridStatusBadge(
                label: '● Online',
                foregroundColor: Color(0xFF37E19A),
                backgroundColor: Color(0xA6000000),
              ),
            ),
          Positioned(
            left: 12,
            right: 8,
            bottom: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        key: Key('profile_name_${profile.name}'),
                        onTap: onNameTap,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${profile.name}, ${profile.age}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: AppColors.deepPink,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '● ${profile.distanceKm} km away',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '▣ ${profile.profession}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  key: Key('grid_like_${profile.name}'),
                  onPressed: onLike,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: liked
                        ? AppColors.deepPink
                        : AppColors.softCoral,
                  ),
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridStatusBadge extends StatelessWidget {
  const _GridStatusBadge({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyDiscoverState extends StatelessWidget {
  const _EmptyDiscoverState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.softPink),
            SizedBox(height: 12),
            Text(
              'No profiles found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              'Try another tab or adjust your filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayText),
            ),
          ],
        ),
      ),
    );
  }
}
