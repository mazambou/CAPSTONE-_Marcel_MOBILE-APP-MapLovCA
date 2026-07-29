part of '../../app.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late int selectedTab;

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr('Likes & Matches'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<int>(
            key: const Key('likes_matches_tabs'),
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.favorite_border),
                label: Text('Likes'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.handshake_outlined),
                label: Text('Matches'),
              ),
            ],
            selected: {selectedTab},
            onSelectionChanged: (selection) =>
                setState(() => selectedTab = selection.first),
          ),
        ),
      ),
    ),
    body: IndexedStack(
      index: selectedTab,
      children: const [
        LikesScreen(embedded: true),
        MatchScreen(embedded: true),
      ],
    ),
    bottomNavigationBar: const _MapLovNavigationBar(selectedIndex: 2),
  );
}

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LikesScreen> createState() => _LikesScreenState();
}

class _LikesScreenState extends State<LikesScreen> {
  late Future<_LikesPageData> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<_LikesPageData> _load() async {
    final subscription = await MapLovRepository.instance.subscriptionInfo();
    final canSeeProfiles =
        !MapLovRepository.instance.isLive || subscription.isPremium;
    final profiles = canSeeProfiles
        ? await MapLovRepository.instance.profilesWhoLikedMe()
        : const <UserProfile>[];
    return _LikesPageData(canSeeProfiles: canSeeProfiles, profiles: profiles);
  }

  Future<void> _openPhoto(UserProfile profile) async {
    if (!await _requireProfilePhotos(context, minimum: 1) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoViewerScreen(profile: profile)),
    );
    if (mounted) setState(() => data = _load());
  }

  Future<void> _openProfile(UserProfile profile) async {
    if (!await _requireProfilePhotos(context, minimum: 3) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(profile: profile)),
    );
    if (mounted) setState(() => data = _load());
  }

  List<Widget> _children() => [
    const Text(
      'People who liked your profile appear here. Open a photo or profile before deciding whether to like them back.',
      style: TextStyle(color: AppColors.grayText),
    ),
    const SizedBox(height: 18),
    FutureBuilder<_LikesPageData>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.error_outline, color: AppColors.error),
            title: const Text('Unable to load your likes'),
            subtitle: Text('${snapshot.error}'),
            trailing: IconButton(
              onPressed: () => setState(() => data = _load()),
              icon: const Icon(Icons.refresh),
            ),
          );
        }
        final result = snapshot.data!;
        if (!result.canSeeProfiles) {
          return _LikesPremiumCard(
            onOpen: () async {
              final allowed = await _requireSubscriptionFeature(
                context,
                requirement: _SubscriptionRequirement.premiumPlus,
                feature: 'Seeing who liked your profile',
              );
              if (allowed && mounted) setState(() => data = _load());
            },
          );
        }
        if (result.profiles.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.favorite_border, color: AppColors.coral),
            title: Text('No new likes yet'),
            subtitle: Text(
              'New people who like your profile will appear here.',
            ),
          );
        }
        return Column(
          children: result.profiles
              .map(
                (profile) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      GestureDetector(
                        key: Key('incoming_like_photo_${profile.name}'),
                        onTap: () => unawaited(_openPhoto(profile)),
                        child: SizedBox(
                          width: 116,
                          height: 132,
                          child: profileImage(profile),
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          key: Key('incoming_like_profile_${profile.name}'),
                          onTap: () => unawaited(_openProfile(profile)),
                          title: Text(
                            '${profile.name}, ${profile.age}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${profile.city}\n${profile.compatibilityScore}% compatible',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _ResponsiveBody(
        child: ListView(
          key: const PageStorageKey('likes_tab'),
          padding: const EdgeInsets.all(18),
          children: _children(),
        ),
      );
    }
    return _MainPage(index: 2, title: 'Likes', children: _children());
  }
}

class _LikesPremiumCard extends StatelessWidget {
  const _LikesPremiumCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.palePink,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.favorite, size: 58, color: AppColors.deepPink),
          const SizedBox(height: 12),
          const Text(
            'See who likes you',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open the list of people who liked your profile.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onOpen, child: const Text('View likes')),
        ],
      ),
    ),
  );
}

class _LikesPageData {
  const _LikesPageData({required this.canSeeProfiles, required this.profiles});

  final bool canSeeProfiles;
  final List<UserProfile> profiles;
}
