part of '../../app.dart';

class NewMatchScreen extends StatelessWidget {
  const NewMatchScreen({super.key, this.profile});

  final UserProfile? profile;
  UserProfile get _match => profile ?? mockProfiles.first;

  Future<void> _openChat(BuildContext context) async {
    try {
      final id = await MapLovRepository.instance.startConversation(_match.id);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: id, profile: _match),
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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 34,
              ),
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
                    'You and ${_match.name} liked each other.\nStart a conversation!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 17,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _MatchedProfiles(match: _match),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('new_match_send_message'),
                      onPressed: () => _openChat(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.deepPink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        'Send Message',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('new_match_keep_swiping'),
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.home,
                      ),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
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
      ),
    );
  }
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
  const _MatchedProfiles({required this.match});

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
                  image: const AssetImage(
                    'assets/profile/profile_user_placeholder.png',
                  ),
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
            const Expanded(
              child: _MatchIdentity(
                name: 'Jamie',
                age: 29,
                city: 'Toronto, ON',
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
  const MatchScreen({super.key});

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

  @override
  Widget build(BuildContext context) => _MainPage(
    index: 2,
    title: 'Your matches',
    children: [
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
    ],
  );
}
