part of '../../app.dart';

class NewMatchScreen extends StatelessWidget {
  const NewMatchScreen({super.key, this.profile});

  final UserProfile? profile;
  static const _demoCurrentUser = UserProfile(
    id: 'me',
    name: 'Jamie',
    age: 29,
    city: 'Toronto, ON',
    compatibilityScore: 100,
    imagePath: 'assets/profile/profile_user_placeholder.png',
    photoDisplayStyle: PhotoDisplayStyle.profileDetails,
  );

  Future<(UserProfile, UserProfile)?> _loadProfiles() async {
    final repository = MapLovRepository.instance;
    final currentId = repository.currentUserId;
    if (currentId == null) return null;
    final results = await Future.wait([
      repository.getProfile(currentId),
      repository.resolveMatchPartner(profile),
    ]);
    final current = results[0];
    final partner = results[1];
    if (current == null || partner == null || current.id == partner.id) {
      return null;
    }
    return (current, partner);
  }

  Future<void> _openChat(BuildContext context, UserProfile match) async {
    try {
      final id = await MapLovRepository.instance.startConversation(match.id);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: id, profile: match),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start the conversation: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      bottomNavigationBar: const _MapLovNavigationBar(selectedIndex: 2),
      body: MapLovRepository.instance.isLive
          ? FutureBuilder<(UserProfile, UserProfile)?>(
              future: _loadProfiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profiles = snapshot.data;
                if (snapshot.hasError || profiles == null) {
                  return _UnavailableMatch(
                    onBack: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.matches,
                    ),
                  );
                }
                return _buildMatchBody(context, profiles.$1, profiles.$2);
              },
            )
          : _buildMatchBody(
              context,
              _demoCurrentUser,
              profile ?? demoProfileOrUnavailable,
            ),
    );
  }

  Widget _buildMatchBody(
    BuildContext context,
    UserProfile current,
    UserProfile match,
  ) => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 34),
          child: Column(
            children: [
              _NewMatchHeader(
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.home);
                  }
                },
              ),
              const SizedBox(height: 18),
              const _MatchCelebrationTitle(),
              const SizedBox(height: 10),
              Text(
                'You and ${match.name} liked each other.\nStart a conversation!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 17,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              _MatchedProfiles(current: current, match: match),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('new_match_send_message'),
                  onPressed: () => _openChat(context, match),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepPink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text(
                    'Send Message',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('new_match_keep_swiping'),
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.home),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepPink,
                    side: const BorderSide(
                      color: AppColors.deepPink,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.style_outlined),
                  label: const Text(
                    'Keep Swiping',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Material(
                color: AppColors.palePink,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  key: const Key('new_match_complete_profile'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  leading: const Icon(
                    Icons.favorite,
                    color: AppColors.deepPink,
                    size: 34,
                  ),
                  title: const Text(
                    'Increase your chances',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Complete your profile to get more matches!',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _UnavailableMatch extends StatelessWidget {
  const _UnavailableMatch({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 54),
            const SizedBox(height: 16),
            const Text(
              'This match is no longer available.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('View matches')),
          ],
        ),
      ),
    ),
  );
}

class _NewMatchHeader extends StatelessWidget {
  const _NewMatchHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back, size: 28),
      ),
      const Expanded(
        child: Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Map',
                  style: TextStyle(color: Colors.black),
                ),
                TextSpan(
                  text: 'Lov',
                  style: TextStyle(color: AppColors.deepPink),
                ),
              ],
            ),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ),
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, size: 28),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'report', child: Text('Report a problem')),
        ],
      ),
    ],
  );
}

class _MatchCelebrationTitle extends StatelessWidget {
  const _MatchCelebrationTitle();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite, color: AppColors.softPink, size: 22),
          SizedBox(width: 210),
          Icon(Icons.favorite, color: AppColors.deepPink, size: 27),
        ],
      ),
      Text(
        "It's a Match!",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.deepPink,
          fontSize: 43,
          height: 1,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
      ),
    ],
  );
}

class _MatchedProfiles extends StatelessWidget {
  const _MatchedProfiles({required this.current, required this.match});

  final UserProfile current;
  final UserProfile match;

  @override
  Widget build(BuildContext context) {
    final diameter = (MediaQuery.sizeOf(context).width * .39).clamp(
      132.0,
      184.0,
    );
    return Column(
      children: [
        SizedBox(
          height: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _MatchPortrait(
                  diameter: diameter,
                  image: profileImageProvider(current),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _MatchPortrait(
                  diameter: diameter,
                  image: profileImageProvider(match),
                ),
              ),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.deepPink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 10),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MatchIdentity(
                name: current.name,
                age: current.age,
                city: current.city,
              ),
            ),
            Expanded(
              child: _MatchIdentity(
                name: match.name,
                age: match.age,
                city: match.city,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MatchPortrait extends StatelessWidget {
  const _MatchPortrait({required this.diameter, required this.image});

  final double diameter;
  final ImageProvider<Object> image;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 7),
      boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 16)],
      image: DecorationImage(image: image, fit: BoxFit.cover),
    ),
  );
}

class _MatchIdentity extends StatelessWidget {
  const _MatchIdentity({
    required this.name,
    required this.age,
    required this.city,
  });

  final String name;
  final int age;
  final String city;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '$name, $age',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.verified, color: AppColors.deepPink, size: 18),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: AppColors.grayText, size: 16),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              city,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.grayText),
            ),
          ),
        ],
      ),
    ],
  );
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late Future<List<MatchItem>> matches;

  @override
  void initState() {
    super.initState();
    matches = MapLovRepository.instance.myMatches();
  }

  List<Widget> _children() => [
    const Text(
      'Compatibility helps you discover people. Messaging remains available to everyone.',
      style: TextStyle(color: AppColors.grayText),
    ),
    const SizedBox(height: 16),
    FutureBuilder<List<MatchItem>>(
      future: matches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <MatchItem>[];
        if (items.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.favorite_border),
            title: Text('No mutual matches yet'),
            subtitle: Text('Keep discovering people you like.'),
          );
        }
        return Column(
          children: items
              .map(
                (item) => Card(
                  child: ListTile(
                    onTap: () async {
                      if (!await _requireProfilePhotos(context, minimum: 3) ||
                          !context.mounted) {
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(profile: item.profile),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundImage: profileImageProvider(item.profile),
                    ),
                    title: Text('${item.profile.name}, ${item.profile.age}'),
                    subtitle: Text(
                      '${item.profile.compatibilityScore}% compatible • Matched ${DateFormat.yMMMd().format(item.date)}',
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        final id = await MapLovRepository.instance
                            .startConversation(item.profile.id);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: id,
                                profile: item.profile,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                    ),
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
          key: const PageStorageKey('matches_tab'),
          padding: const EdgeInsets.all(18),
          children: _children(),
        ),
      );
    }
    return _MainPage(index: 2, title: 'Your matches', children: _children());
  }
}
