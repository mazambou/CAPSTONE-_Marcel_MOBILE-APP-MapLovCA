part of '../../app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 'Discover'});

  final String initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _onlineRefreshInterval = Duration(seconds: 30);
  static const _discoverPageSize = 30;

  late String selectedTab;
  final Set<String> likedProfiles = {};
  List<UserProfile> _profiles = AuthService.instance.isConfigured
      ? []
      : AppConfig.allowDemoData
      ? List.of(mockProfiles)
      : [];
  DiscoveryFilters _filters = const DiscoveryFilters();
  bool _loading = false;
  bool _loadingFirstPage = false;
  bool _refreshingOnline = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  Map<String, dynamic>? _nextCursor;
  int _loadGeneration = 0;
  bool _isForeground = true;
  Timer? _onlineRefreshTimer;
  MapLovLocationFailure? _locationFailure;
  final ScrollController _gridController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedTab = widget.initialTab;
    _gridController.addListener(_loadMoreNearGridEnd);
    _syncOnlineRefreshTimer();
    unawaited(_initializeDiscovery());
  }

  void _syncOnlineRefreshTimer() {
    _onlineRefreshTimer?.cancel();
    _onlineRefreshTimer = null;
    if (!_isForeground || selectedTab != 'Online') return;
    _onlineRefreshTimer = Timer.periodic(
      _onlineRefreshInterval,
      (_) => unawaited(_refreshOnlineProfiles()),
    );
  }

  Future<void> _refreshOnlineProfiles() async {
    if (!mounted ||
        !_isForeground ||
        !TickerMode.valuesOf(context).enabled ||
        selectedTab != 'Online' ||
        _refreshingOnline ||
        _loading) {
      return;
    }
    _refreshingOnline = true;
    try {
      await _loadProfiles(
        refreshNearbyLocation: false,
        showLoading: false,
        reportErrors: false,
        forceRefresh: true,
      );
    } finally {
      _refreshingOnline = false;
    }
  }

  Future<void> _initializeDiscovery() async {
    if (mounted) setState(() => _loading = true);
    try {
      final subscription = await MapLovRepository.instance.subscriptionInfo();
      if (MapLovRepository.instance.isLive) {
        final savedFilters = await MapLovRepository.instance.myPreferences();
        if (!mounted) return;
        _filters = !subscription.isPremium
            ? savedFilters.copyWith(
                locationMode: 'near_me',
                countries: const [],
                regions: const [],
                cities: const [],
                originCountries: const [],
                originRegions: const [],
                originCities: const [],
                premiumOnly: false,
                vipOnly: false,
              )
            : !subscription.isVip
            ? savedFilters.copyWith(vipOnly: false)
            : savedFilters;
        try {
          await LocationService.instance.updateMyLocation();
          _locationFailure = null;
        } on MapLovLocationFailure catch (error) {
          if (mounted) {
            setState(() {
              _locationFailure = error;
              _profiles = const [];
              _loading = false;
            });
          }
          return;
        } catch (error) {
          if (mounted) {
            setState(() {
              _profiles = const [];
              _loading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to update your location: $error')),
            );
          }
          return;
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to load your saved filters. Default filters will be used: $error',
            ),
          ),
        );
      }
    }
    if (mounted) await _loadProfiles(refreshNearbyLocation: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineRefreshTimer?.cancel();
    _gridController
      ..removeListener(_loadMoreNearGridEnd)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _syncOnlineRefreshTimer();
      if (MapLovRepository.instance.isLive) {
        unawaited(_refreshResidenceLocation());
      }
      if (selectedTab == 'Online') {
        unawaited(_refreshOnlineProfiles());
      } else if (_locationFailure != null && !_loading) {
        unawaited(
          selectedTab == 'Nearby' ? _loadProfiles() : _initializeDiscovery(),
        );
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isForeground = false;
      _onlineRefreshTimer?.cancel();
      _onlineRefreshTimer = null;
    }
  }

  Future<void> _refreshResidenceLocation() async {
    try {
      await LocationService.instance.updateMyLocation();
    } catch (_) {
      // Automatic residence refresh is retried on the next resume and must not
      // interrupt an already authenticated session.
    }
  }

  Future<void> _loadProfiles({
    bool refreshNearbyLocation = true,
    bool showLoading = true,
    bool reportErrors = true,
    bool append = false,
    bool forceRefresh = false,
  }) async {
    if (append) {
      if (_loadingFirstPage ||
          _loadingMore ||
          !_hasMore ||
          _nextCursor == null) {
        return;
      }
      _loadingMore = true;
    } else {
      _loadGeneration += 1;
      _loadingFirstPage = true;
      if (mounted && showLoading) setState(() => _loading = true);
    }
    final generation = _loadGeneration;
    final requestedTab = selectedTab;
    final requestedFilters = _filters;
    try {
      if (selectedTab == 'Nearby' &&
          refreshNearbyLocation &&
          !append &&
          MapLovRepository.instance.isLive) {
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
      } else if (_filters.locationMode != 'near_me' ||
          !_filters.requiredLocation) {
        _locationFailure = null;
      }
      final page = await MapLovRepository.instance.discoverProfilesPage(
        tab: requestedTab,
        filters: requestedFilters,
        cursor: append ? _nextCursor : null,
        pageSize: _discoverPageSize,
        forceRefresh: forceRefresh,
      );
      if (mounted &&
          generation == _loadGeneration &&
          requestedTab == selectedTab &&
          identical(requestedFilters, _filters)) {
        setState(() {
          if (append) {
            final existingIds = _profiles.map((profile) => profile.id).toSet();
            _profiles = [
              ..._profiles,
              ...page.profiles.where((profile) => existingIds.add(profile.id)),
            ];
          } else {
            _profiles = page.profiles;
            likedProfiles.clear();
          }
          likedProfiles.addAll(
            page.profiles.where((p) => p.likedByMe).map((p) => p.name),
          );
          _nextCursor = page.nextCursor;
          _hasMore = page.hasMore;
        });
      }
    } catch (error) {
      if (mounted && reportErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to refresh profiles: $error')),
        );
      }
    } finally {
      if (mounted && showLoading) setState(() => _loading = false);
      if (!append && generation == _loadGeneration) {
        _loadingFirstPage = false;
      }
      _loadingMore = false;
    }
  }

  void _loadMoreNearGridEnd() {
    if (!_gridController.hasClients ||
        _gridController.position.extentAfter > 700) {
      return;
    }
    unawaited(
      _loadProfiles(
        append: true,
        refreshNearbyLocation: false,
        showLoading: false,
      ),
    );
  }

  Future<void> _resolveLocationFailure() async {
    final failure = _locationFailure;
    if (failure == null) return;
    if (failure.requiresSettings) {
      await LocationService.instance.openRequiredSettings(failure);
      return;
    }
    if (selectedTab == 'Nearby') {
      await _loadProfiles();
    } else {
      await _initializeDiscovery();
    }
  }

  Future<void> _openFilters() async {
    final result = await Navigator.pushNamed(context, AppRoutes.filters);
    if (result is DiscoveryFilters) {
      _filters = result;
      await _loadProfiles();
    }
  }

  Future<void> _resetDiscoveryFilters() async {
    final resetFilters = _filters.resetOptionalCriteria();
    try {
      await MapLovRepository.instance.savePreferences(resetFilters);
      if (!mounted) return;
      setState(() => _filters = resetFilters);
      await _loadProfiles(
        refreshNearbyLocation: selectedTab == 'Nearby',
        forceRefresh: true,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to reset filters: $error')),
      );
    }
  }

  Future<void> _setMainDiscoveryFilter(String mode) async {
    if (mode == 'vip') {
      final allowed = await _requireSubscriptionFeature(
        context,
        requirement: _SubscriptionRequirement.vip,
        feature: 'Show VIP Profiles Only',
      );
      if (!allowed) return;
    }
    if (!mounted) return;
    if (mode == 'premium') {
      final allowed = await _requireSubscriptionFeature(
        context,
        requirement: _SubscriptionRequirement.premiumPlus,
        feature: 'Show Premium Plus & Premium VIP',
      );
      if (!allowed) return;
    }
    if (!mounted) return;
    setState(() {
      if (mode == 'vip') {
        final enabled = !_filters.vipOnly;
        _filters = _filters.copyWith(
          vipOnly: enabled,
          premiumOnly: enabled ? false : _filters.premiumOnly,
        );
      } else if (mode == 'premium') {
        final enabled = !_filters.premiumOnly;
        _filters = _filters.copyWith(
          premiumOnly: enabled,
          vipOnly: enabled ? false : _filters.vipOnly,
        );
      } else {
        _filters = _filters.copyWith(mostLikedFirst: !_filters.mostLikedFirst);
      }
    });
    try {
      await MapLovRepository.instance.savePreferences(_filters);
      await _loadProfiles(refreshNearbyLocation: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to apply discovery mode: $error')),
        );
      }
    }
  }

  List<UserProfile> get visibleProfiles {
    return switch (selectedTab) {
      'Nearby' =>
        _profiles
            .where(
              (profile) =>
                  profile.isArrivingSoon ||
                  profile.distanceKm <= _filters.distanceKm,
            )
            .toList(),
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
    final details = await MapLovRepository.instance.discoverProfileDetails(
      profile,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoViewerScreen(profile: details)),
    );
  }

  Future<void> _openProfile(UserProfile profile) async {
    if (!await _requireProfilePhotos(context, minimum: 3) || !mounted) return;
    final details = await MapLovRepository.instance.discoverProfileDetails(
      profile,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: details)),
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
    if (mounted) await _loadProfiles(forceRefresh: true);
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

  Future<void> _rewindLastLike() async {
    final allowed = await _requireSubscriptionFeature(
      context,
      requirement: _SubscriptionRequirement.premiumPlus,
      feature: 'Profile rewind',
    );
    if (!allowed || !mounted) return;
    try {
      final profileId = await MapLovRepository.instance.rewindLastProfileLike();
      if (!mounted) return;
      if (profileId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No profile like to rewind.')),
        );
        return;
      }
      setState(() {
        final profile = _profiles
            .where((item) => item.id == profileId)
            .firstOrNull;
        if (profile != null) likedProfiles.remove(profile.name);
      });
      await _loadProfiles(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your last profile like was restored.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to rewind this profile: $error')),
        );
      }
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
              onRewind: () => unawaited(_rewindLastLike()),
              onNotifications: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
            ),
            _DiscoverTabs(
              selectedTab: selectedTab,
              onSelected: (tab) {
                if (tab == 'Boutique MapLov') {
                  Navigator.pushNamed(context, AppRoutes.premium);
                  return;
                }
                setState(() {
                  selectedTab = tab;
                  if (tab != 'Nearby') _locationFailure = null;
                });
                _syncOnlineRefreshTimer();
                unawaited(
                  tab == 'Discover' &&
                          _filters.locationMode == 'near_me' &&
                          _filters.requiredLocation
                      ? _initializeDiscovery()
                      : _loadProfiles(),
                );
              },
            ),
            if (selectedTab == 'Discover')
              _MainDiscoveryControls(
                vipOnly: _filters.vipOnly,
                premiumOnly: _filters.premiumOnly,
                mostLiked: _filters.mostLikedFirst,
                onVip: () => unawaited(_setMainDiscoveryFilter('vip')),
                onPremium: () => unawaited(_setMainDiscoveryFilter('premium')),
                onMostLiked: () =>
                    unawaited(_setMainDiscoveryFilter('most_liked')),
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
              child: _locationFailure != null
                  ? _NearbyLocationAccessState(
                      failure: _locationFailure!,
                      onResolve: () => unawaited(_resolveLocationFailure()),
                    )
                  : RefreshIndicator(
                      key: Key('discover_refresh_$selectedTab'),
                      onRefresh: () => _loadProfiles(forceRefresh: true),
                      child: profiles.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: constraints.maxHeight,
                                    child: _EmptyDiscoverState(
                                      hasActiveFilters:
                                          _filters.hasOptionalCriteria,
                                      onResetFilters: () =>
                                          unawaited(_resetDiscoveryFilters()),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              key: Key('discover_grid_$selectedTab'),
                              controller: _gridController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                20,
                              ),
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
                                  onPhotoTap: () =>
                                      unawaited(_openPhoto(profile)),
                                  onNameTap: () =>
                                      unawaited(_openProfile(profile)),
                                  onLike: () => unawaited(_toggleLike(profile)),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _MapLovNavigationBar(selectedIndex: 0),
    );
  }
}

class _MainDiscoveryControls extends StatelessWidget {
  const _MainDiscoveryControls({
    required this.vipOnly,
    required this.premiumOnly,
    required this.mostLiked,
    required this.onVip,
    required this.onPremium,
    required this.onMostLiked,
  });

  final bool vipOnly;
  final bool premiumOnly;
  final bool mostLiked;
  final VoidCallback onVip;
  final VoidCallback onPremium;
  final VoidCallback onMostLiked;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: ListView(
      key: const Key('main_discovery_subscription_filters'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      children: [
        FilterChip(
          key: const Key('main_show_vip_only'),
          avatar: const Icon(Icons.diamond_outlined, size: 18),
          label: const Text('Show VIP Profiles Only'),
          selected: vipOnly,
          onSelected: (_) => onVip(),
        ),
        const SizedBox(width: 8),
        FilterChip(
          key: const Key('main_show_premium_profiles'),
          avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
          label: const Text('Show Premium Plus & Premium VIP'),
          selected: premiumOnly,
          onSelected: (_) => onPremium(),
        ),
        const SizedBox(width: 8),
        FilterChip(
          key: const Key('main_show_most_liked'),
          avatar: const Icon(Icons.favorite_border, size: 18),
          label: const Text('Show Most Liked Profiles'),
          selected: mostLiked,
          onSelected: (_) => onMostLiked(),
        ),
      ],
    ),
  );
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
    required this.onRewind,
    required this.onNotifications,
  });

  final VoidCallback onFilters;
  final VoidCallback onRewind;
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
            key: const Key('home_rewind_button'),
            tooltip: 'Rewind last profile like',
            onPressed: onRewind,
            icon: const Icon(Icons.undo_rounded, size: 27),
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
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        key: const Key('discover_tabs_scroll'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: ['Discover', 'Nearby', 'Online', 'Boutique MapLov', 'New']
              .map(
                (tab) => InkWell(
                  key: Key('discover_tab_$tab'),
                  onTap: () => onSelected(tab),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Column(
                      children: [
                        Text(
                          tab,
                          style: TextStyle(
                            color: tab == 'Boutique MapLov'
                                ? AppColors.deepPink
                                : selectedTab == tab
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
              )
              .toList(),
        ),
      ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: profile.isArrivingSoon
            ? Border.all(color: const Color(0xFFD4AF37), width: 3)
            : null,
      ),
      child: ClipRRect(
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
                  if (profile.isArrivingSoon)
                    const Flexible(
                      child: _GridStatusBadge(
                        label: '✈️ Arrive bientôt',
                        foregroundColor: Color(0xFF5C4300),
                        backgroundColor: Color(0xFFFFE89A),
                      ),
                    ),
                  if (profile.isArrivingSoon) const SizedBox(width: 5),
                  if (profile.isNew)
                    const Flexible(
                      child: _GridStatusBadge(
                        label: 'New ✨',
                        foregroundColor: AppColors.deepPink,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  if (profile.isNew) const SizedBox(width: 5),
                  if (!profile.isNew && !profile.isArrivingSoon) const Spacer(),
                  if (profile.isArrivingSoon) const Spacer(),
                  Flexible(
                    child: _GridStatusBadge(
                      statusKey: Key('profile_status_${profile.id}'),
                      label: profile.isOnline ? '● Online' : '● Offline',
                      foregroundColor: profile.isOnline
                          ? const Color(0xFF37E19A)
                          : const Color(0xFF9E9E9E),
                      backgroundColor: const Color(0xA6000000),
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
                          profile.isArrivingSoon
                              ? '✈️ ${profile.arrivalDestinationLabel}'
                              : '● ${profile.distanceKm} km away',
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
      ),
    );
  }
}

class _GridStatusBadge extends StatelessWidget {
  const _GridStatusBadge({
    this.statusKey,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final Key? statusKey;
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
        key: statusKey,
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
  const _EmptyDiscoverState({
    required this.hasActiveFilters,
    required this.onResetFilters,
  });

  final bool hasActiveFilters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.softPink),
            const SizedBox(height: 12),
            const Text(
              'No profiles found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              hasActiveFilters
                  ? 'Your saved filters also apply to Nearby.'
                  : 'Try another tab or adjust your filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayText),
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('reset_empty_discover_filters'),
                onPressed: onResetFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Reset filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
