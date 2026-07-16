part of '../../app.dart';

class LikesScreen extends StatefulWidget {
  const LikesScreen({super.key});

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

  @override
  Widget build(BuildContext context) => _MainPage(
    index: 1,
    title: 'Likes',
    children: [
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
          if (!result.canSeeProfiles) return const _LikesPremiumCard();
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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
    ],
  );
}

class _LikesPremiumCard extends StatelessWidget {
  const _LikesPremiumCard();

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
            'Upgrade to reveal the people who already liked your profile.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.premium),
            child: const Text('View plans'),
          ),
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
