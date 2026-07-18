part of '../../app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 'Discover'});

  final String initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late String selectedTab;
  final Set<String> likedProfiles = {};
  List<UserProfile> _profiles = AuthService.instance.isConfigured
      ? []
      : AppConfig.allowDemoData
      ? List.of(mockProfiles)
      : [];
  DiscoveryFilters _filters = const DiscoveryFilters();
  bool _loading = false;
  MapLovLocationFailure? _locationFailure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedTab = widget.initialTab;
    unawaited(_loadProfiles());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        selectedTab == 'Nearby' &&
        _locationFailure != null &&
        !_loading) {
      unawaited(_loadProfiles());
    }
  }

  Future<void> _loadProfiles() async {
    if (mounted) setState(() => _loading = true);
    try {
      if (selectedTab == 'Nearby' && MapLovRepository.instance.isLive) {
        try {
          await LocationService.instance.updateMyLocation();
          _locationFailure = null;
        } on MapLovLocationFailure catch (error) {
          if (mounted) {
            setState(() {
              _locationFailure = error;
              _profiles = const [];
            });
          }
          return;
        }
      } else {
        _locationFailure = null;
      }
      final profiles = await MapLovRepository.instance.discoverProfiles(
        tab: selectedTab,
        filters: _filters,
      );
      if (mounted) {
        setState(() {
          _profiles = profiles;
          likedProfiles
            ..clear()
            ..addAll(profiles.where((p) => p.likedByMe).map((p) => p.name));
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to refresh profiles: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveLocationFailure() async {
    final failure = _locationFailure;
    if (failure == null) return;
    if (failure.requiresSettings) {
      await LocationService.instance.openRequiredSettings(failure);
      return;
    }
    await _loadProfiles();
  }

  Future<void> _openFilters() async {
    final result = await Navigator.pushNamed(context, AppRoutes.filters);
    if (result is DiscoveryFilters) {
      _filters = result;
      await _loadProfiles();
    }
  }

  List<UserProfile> get visibleProfiles {
    return switch (selectedTab) {
      'Nearby' =>
        _profiles.where((profile) => profile.distanceKm <= 10).toList(),
      'Online' => _profiles.where((profile) => profile.isOnline).toList(),
      'New' => _profiles.where((profile) => profile.isNew).toList(),
      _ => _profiles,
    };
  }

  List<PopularPhotoEntry> get popularPhotos {
    final entries = <PopularPhotoEntry>[];
    for (final profile in visibleProfiles) {
      final photoCount = profile.photoUrls.isEmpty
          ? 1
          : profile.photoUrls.length;
      var bestIndex = 0;
      for (var index = 1; index < photoCount; index++) {
        final likes = profile.photoLikeCount(index);
        final bestLikes = profile.photoLikeCount(bestIndex);
        final createdAt = profile.photoCreatedAt(index);
        final bestCreatedAt = profile.photoCreatedAt(bestIndex);
        if (likes > bestLikes ||
            (likes == bestLikes &&
                createdAt != null &&
                (bestCreatedAt == null || createdAt.isAfter(bestCreatedAt)))) {
          bestIndex = index;
        }
      }
      entries.add(PopularPhotoEntry(profile: profile, photoIndex: bestIndex));
    }
    entries.sort((a, b) {
      final likes = b.likeCount.compareTo(a.likeCount);
      if (likes != 0) return likes;
      final recent = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      if (recent != 0) return recent;
      return b.profile.compatibilityScore.compareTo(
        a.profile.compatibilityScore,
      );
    });
    return entries;
  }

  Future<void> _openPhoto(UserProfile profile) async {
    if (!await _requireProfilePhotos(context, minimum: 1) || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoViewerScreen(profile: profile)),
    );
  }

  Future<void> _openProfile(UserProfile profile) async {
    if (!await _requireProfilePhotos(context, minimum: 3) || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
    );
  }

  Future<void> _openPopularPhoto(
    List<PopularPhotoEntry> photos,
    int initialIndex,
  ) async {
    if (!await _requireProfilePhotos(context, minimum: 1) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          popularPhotos: photos,
          popularInitialIndex: initialIndex,
        ),
      ),
    );
    if (mounted) await _loadProfiles();
  }

  Future<void> _toggleLike(UserProfile profile) async {
    if (!await _requireProfilePhotos(context, minimum: 1) || !mounted) return;
    final previous = likedProfiles.contains(profile.name);
    setState(() {
      if (previous) {
        likedProfiles.remove(profile.name);
      } else {
        likedProfiles.add(profile.name);
      }
    });
    try {
      final result = await MapLovRepository.instance.toggleProfileLike(
        profile.id,
      );
      if (!mounted) return;
      if (result.matched) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewMatchScreen(profile: profile)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previous) {
          likedProfiles.add(profile.name);
        } else {
          likedProfiles.remove(profile.name);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update this like: $error')),
      );
    }
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
              onFilters: _openFilters,
              onNotifications: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            ),
            _DiscoverTabs(
              selectedTab: selectedTab,
              onSelected: (tab) {
                setState(() {
                  selectedTab = tab;
                  if (tab != 'Nearby') _locationFailure = null;
                });
                unawaited(_loadProfiles());
              },
            ),
            const Divider(height: 1),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (selectedTab == 'Discover' && popularPhotos.isNotEmpty)
              _PopularPhotosStrip(
                key: const Key('popular_photos_strip'),
                photos: popularPhotos,
                onOpen: _openPopularPhoto,
              ),
            Expanded(
              child: selectedTab == 'Nearby' && _locationFailure != null
                  ? _NearbyLocationAccessState(
                      failure: _locationFailure!,
                      onResolve: () => unawaited(_resolveLocationFailure()),
                    )
                  : profiles.isEmpty
                  ? const _EmptyDiscoverState()
                  : GridView.builder(
                      key: Key('discover_grid_$selectedTab'),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.66,
                          ),
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return _DiscoverGridCard(
                          profile: profile,
                          liked: likedProfiles.contains(profile.name),
                          onPhotoTap: () => unawaited(_openPhoto(profile)),
                          onNameTap: () => unawaited(_openProfile(profile)),
                          onLike: () => unawaited(_toggleLike(profile)),
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

class _NearbyLocationAccessState extends StatelessWidget {
  const _NearbyLocationAccessState({
    required this.failure,
    required this.onResolve,
  });

  final MapLovLocationFailure failure;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final disabled =
        failure.reason == MapLovLocationFailureReason.serviceDisabled;
    final permanentlyDenied =
        failure.reason == MapLovLocationFailureReason.deniedForever;
    final message = disabled
        ? 'Turn on device location to discover members near you.'
        : permanentlyDenied
        ? 'Location access is blocked. Open MapLov settings and allow location while using the app.'
        : 'MapLov needs location access to show nearby members. Your exact position is never displayed.';
    final action = failure.requiresSettings ? 'Open settings' : 'Try again';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 64,
              color: AppColors.softPink,
            ),
            const SizedBox(height: 14),
            const Text(
              'Location access needed',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayText),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('nearby_location_action'),
              onPressed: onResolve,
              icon: Icon(
                failure.requiresSettings
                    ? Icons.settings_outlined
                    : Icons.my_location,
              ),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularPhotosStrip extends StatefulWidget {
  const _PopularPhotosStrip({
    super.key,
    required this.photos,
    required this.onOpen,
  });

  final List<PopularPhotoEntry> photos;
  final Future<void> Function(List<PopularPhotoEntry>, int) onOpen;

  @override
  State<_PopularPhotosStrip> createState() => _PopularPhotosStripState();
}

class _PopularPhotosStripState extends State<_PopularPhotosStrip> {
  static const _itemExtent = 94.0;
  final ScrollController _controller = ScrollController();
  Timer? _autoScroll;
  Timer? _resumeTimer;
  int _visibleCount = 20;
  bool _paused = false;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _autoScroll = Timer.periodic(const Duration(seconds: 3), (_) => _advance());
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_paused ||
        !_controller.hasClients ||
        !mounted ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;
    final next = _controller.offset + _itemExtent;
    if (next >= max) {
      _controller.jumpTo(0);
      return;
    }
    unawaited(
      _controller.animateTo(
        next,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  void _pause() {
    _resumeTimer?.cancel();
    _paused = true;
  }

  void _resumeLater() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _paused = false;
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _pause();
    }
    if (notification is ScrollEndNotification) {
      _resumeLater();
      if (_controller.hasClients &&
          _controller.position.extentAfter < _itemExtent * 3 &&
          _visibleCount < widget.photos.length) {
        setState(() {
          _visibleCount = (_visibleCount + 20).clamp(0, widget.photos.length);
        });
      }
    }
    return false;
  }

  Future<void> _open(int index) async {
    _pause();
    final selectedId = widget.photos[index].stableId;
    await widget.onOpen(widget.photos, index);
    if (!mounted || !_controller.hasClients) return;
    final updatedIndex = widget.photos.indexWhere(
      (entry) => entry.stableId == selectedId,
    );
    final returnIndex = updatedIndex < 0 ? index : updatedIndex;
    final target = (returnIndex * _itemExtent).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _resumeLater();
  }

  @override
  Widget build(BuildContext context) {
    final count = _visibleCount.clamp(0, widget.photos.length);
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.only(top: 6, bottom: _expanded ? 10 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: AppColors.deepPink,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Most liked photos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  key: const Key('popular_photos_toggle'),
                  visualDensity: VisualDensity.compact,
                  tooltip: _expanded
                      ? 'Hide most liked photos'
                      : 'Show most liked photos',
                  onPressed: () => setState(() {
                    _expanded = !_expanded;
                    if (!_expanded) _pause();
                    if (_expanded) _resumeLater();
                  }),
                  icon: Icon(
                    Icons.view_carousel_outlined,
                    size: 22,
                    color: _expanded ? AppColors.deepPink : AppColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            Listener(
              onPointerDown: (_) => _pause(),
              onPointerUp: (_) => _resumeLater(),
              onPointerCancel: (_) => _resumeLater(),
              child: SizedBox(
                height: 94,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView.builder(
                    key: const Key('popular_photos_list'),
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: count,
                    itemExtent: _itemExtent,
                    itemBuilder: (context, index) {
                      final entry = widget.photos[index];
                      return Semantics(
                        button: true,
                        label:
                            '${entry.profile.name}, ${entry.likeCount} likes, photo ${index + 1} of ${widget.photos.length}',
                        child: GestureDetector(
                          key: Key('popular_photo_${entry.stableId}'),
                          onTap: () => unawaited(_open(index)),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: mediaImage(entry.photoUrl),
                                ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(16),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0xB8000000),
                                      ],
                                      stops: [.45, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 7,
                                  right: 7,
                                  bottom: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.profile.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.favorite,
                                            color: AppColors.softPink,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${entry.likeCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (entry.profile.isNew)
                                            const Text(
                                              'NEW',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            )
                                          else if (entry.profile.isVip)
                                            const Icon(
                                              Icons.workspace_premium,
                                              color: Color(0xFFFFD86B),
                                              size: 13,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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
            icon: StreamBuilder<List<MapLovNotification>>(
              stream: MapLovRepository.instance.watchNotifications(),
              builder: (context, snapshot) {
                final unread = (snapshot.data ?? const <MapLovNotification>[])
                    .where((item) => !item.isRead)
                    .length;
                return Badge(
                  key: const Key('discover_notification_badge'),
                  label: Text('$unread'),
                  isLabelVisible: unread > 0,
                  child: const Icon(Icons.notifications_none, size: 29),
                );
              },
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
            child: ClipRect(
              child: Transform.scale(
                scale: 1.48,
                alignment: const Alignment(0, -0.12),
                child: profileImage(profile),
              ),
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
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Row(
              children: [
                if (profile.isNew)
                  const Flexible(
                    child: _GridStatusBadge(
                      label: 'New ✨',
                      foregroundColor: AppColors.deepPink,
                      backgroundColor: Colors.white,
                    ),
                  ),
                if (profile.isNew && profile.isOnline) const SizedBox(width: 5),
                if (!profile.isNew) const Spacer(),
                if (profile.isOnline)
                  const Flexible(
                    child: _GridStatusBadge(
                      label: '● Online',
                      foregroundColor: Color(0xFF37E19A),
                      backgroundColor: Color(0xA6000000),
                    ),
                  ),
              ],
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
                                  fontSize: 18,
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
                            if (profile.isVip) ...[
                              const SizedBox(width: 5),
                              const _VipBadge(compact: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '● ${profile.distanceKm} km away',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '▣ ${profile.profession}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton.filled(
                    key: Key('grid_like_${profile.name}'),
                    onPressed: onLike,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: liked
                          ? AppColors.deepPink
                          : AppColors.softCoral,
                    ),
                    icon: Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 22,
                    ),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 10,
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
