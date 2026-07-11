import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'core/navigation/app_routes.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/splash/screens/splash_screen.dart';

class MapLoveApp extends StatelessWidget {
  const MapLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MapLov',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          primary: AppColors.coral,
          surface: AppColors.white,
        ),
        scaffoldBackgroundColor: AppColors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightGray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.onboarding: (_) => const OnboardingScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.discover: (_) => const DiscoverScreen(),
        AppRoutes.nearMe: (_) => const NearMeScreen(),
        AppRoutes.filters: (_) => const FilterScreen(),
        AppRoutes.matches: (_) => const MatchScreen(),
        AppRoutes.messages: (_) => const MessagesScreen(),
        AppRoutes.chat: (_) => const ChatScreen(),
        AppRoutes.reportUser: (_) => const ReportUserScreen(),
        AppRoutes.blockUser: (_) => const BlockUserScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.photoViewer: (_) => const PhotoViewerScreen(),
        AppRoutes.friendRequests: (_) => const FriendRequestsScreen(),
        AppRoutes.posts: (_) => const PostsScreen(),
        AppRoutes.secretGarden: (_) => const SecretGardenScreen(),
        AppRoutes.premium: (_) => const PremiumScreen(),
      },
    );
  }
}

// TODO(Supabase): Replace all mock profiles, messages, posts and plans below.
const _profiles = [
  _Profile('Sophie', 27, 'Toronto', 94, 'assets/avatars/story_sophie.png'),
  _Profile('Alex', 30, 'Montréal', 89, 'assets/avatars/story_02.png'),
  _Profile('Taylor', 29, 'Vancouver', 86, 'assets/avatars/Star_Match.png'),
];

class _Profile {
  const _Profile(this.name, this.age, this.city, this.score, this.image);
  final String name;
  final int age;
  final String city;
  final int score;
  final String image;
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Welcome back',
      subtitle: 'Sign in to continue finding meaningful connections.',
      image: 'assets/login/login_couple_placeholder.png',
      fields: const [
        _Field('Email or phone number', Icons.person_outline),
        _Field('Password', Icons.lock_outline, secret: true),
      ],
      primaryLabel: 'Login',
      onPrimary: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
      footer: TextButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
        child: const Text('Create Account'),
      ),
      extras: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('Forgot Password?'),
          ),
        ),
        const _SocialButton('Continue with Google', Icons.g_mobiledata),
        const SizedBox(height: 10),
        const _SocialButton('Continue with Apple', Icons.apple),
      ],
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Create your account',
      subtitle: 'Tell us a little about yourself.',
      image: 'assets/register/register.png',
      fields: const [
        _Field('Full name', Icons.badge_outlined),
        _Field('Email', Icons.email_outlined),
        _Field('Password', Icons.lock_outline, secret: true),
        _Field('Confirm password', Icons.lock_outline, secret: true),
        _Field('Country', Icons.public),
        _Field('City', Icons.location_city_outlined),
      ],
      primaryLabel: 'Create Account',
      onPrimary: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
    );
  }
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.fields,
    required this.primaryLabel,
    required this.onPrimary,
    this.extras = const [],
    this.footer,
  });
  final String title;
  final String subtitle;
  final String image;
  final List<_Field> fields;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<Widget> extras;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(
                height: 180,
                child: Image.asset(image, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppColors.grayText)),
              const SizedBox(height: 24),
              ...fields.expand((field) => [field, const SizedBox(height: 12)]),
              ...extras,
              const SizedBox(height: 18),
              _PrimaryButton(primaryLabel, onPressed: onPrimary),
              if (footer != null) Center(child: footer),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.icon, {this.secret = false});
  final String label;
  final IconData icon;
  final bool secret;
  @override
  Widget build(BuildContext context) => TextField(
    obscureText: secret,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 0,
    title: 'Good evening, Jamie',
    actions: [
      IconButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
        icon: const Icon(Icons.settings_outlined),
      ),
    ],
    children: [
      const _HeroCard(
        title: 'Love is closer than you think',
        subtitle: 'Explore people nearby',
        icon: Icons.favorite,
        route: AppRoutes.nearMe,
      ),
      const _SectionTitle('Recommended for you'),
      SizedBox(
        height: 245,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _profiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _ProfileCard(_profiles[i]),
        ),
      ),
      const _SectionTitle('Quick access'),
      const Row(
        children: [
          Expanded(
            child: _QuickCard(
              'Requests',
              Icons.person_add_alt,
              AppRoutes.friendRequests,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _QuickCard(
              'Friends posts',
              Icons.dynamic_feed,
              AppRoutes.posts,
            ),
          ),
        ],
      ),
      const _SectionTitle('Recent activity'),
      const ListTile(
        leading: CircleAvatar(child: Icon(Icons.favorite)),
        title: Text('New compatible profiles'),
        subtitle: Text('3 suggestions were added today'),
      ),
    ],
  );
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 1,
    title: 'Discover',
    actions: [
      IconButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.filters),
        icon: const Icon(Icons.tune),
      ),
    ],
    children: _profiles
        .map(
          (profile) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _DiscoverCard(profile),
          ),
        )
        .toList(),
  );
}

class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});
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
      ..._profiles.map(
        (p) => Card(
          child: ListTile(
            leading: CircleAvatar(backgroundImage: AssetImage(p.image)),
            title: Text('${p.name}, ${p.age}'),
            subtitle: Text('${p.score}% compatible • Travel, music'),
            trailing: IconButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
        ),
      ),
    ],
  );
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 3,
    title: 'Messages',
    children: [
      SizedBox(
        height: 150,
        child: Image.asset('assets/chat/chat_conversation_placeholder.png'),
      ),
      ..._profiles.asMap().entries.map(
        (entry) => ListTile(
          onTap: () => Navigator.pushNamed(context, AppRoutes.chat),
          leading: CircleAvatar(backgroundImage: AssetImage(entry.value.image)),
          title: Text(
            entry.value.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            entry.key == 0 ? 'That sounds perfect! 😊' : 'See you soon',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.key == 0 ? '18:42' : 'Yesterday',
                style: const TextStyle(fontSize: 12),
              ),
              if (entry.key == 0) const Badge(label: Text('2')),
            ],
          ),
        ),
      ),
    ],
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 4,
    title: 'My profile',
    actions: [
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
          itemCount: _profiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.photoViewer),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                _profiles[i].image,
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
        AppRoutes.secretGarden,
      ),
      const SizedBox(height: 10),
      const _QuickCard(
        'Friends-only posts',
        Icons.groups_outlined,
        AppRoutes.posts,
      ),
    ],
  );
}

class NearMeScreen extends StatefulWidget {
  const NearMeScreen({super.key});
  @override
  State<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends State<NearMeScreen> {
  double distance = 10;
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Near me',
    children: [
      const Text(
        'Only approximate distance is shown. Exact locations stay private.',
      ),
      Slider(
        value: distance,
        min: 1,
        max: 50,
        divisions: 49,
        label: '${distance.round()} km',
        onChanged: (v) => setState(() => distance = v),
      ),
      Wrap(
        spacing: 8,
        children: [1, 2, 5, 10, 25, 50]
            .map(
              (km) => ChoiceChip(
                label: Text('$km km'),
                selected: distance == km,
                onSelected: (_) => setState(() => distance = km.toDouble()),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      ..._profiles.map(
        (p) => ListTile(
          leading: CircleAvatar(backgroundImage: AssetImage(p.image)),
          title: Text('${p.name}, ${p.age}'),
          subtitle: Text('${p.city} • About ${(p.age % 5) + 1} km away'),
        ),
      ),
    ],
  );
}

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});
  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  RangeValues ages = const RangeValues(24, 38);
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Filters',
    children: [
      const _Dropdown('Gender', ['Everyone', 'Women', 'Men', 'Non-binary']),
      const SizedBox(height: 12),
      Text('Age ${ages.start.round()}–${ages.end.round()}'),
      RangeSlider(
        values: ages,
        min: 18,
        max: 80,
        onChanged: (v) => setState(() => ages = v),
      ),
      const _Field('Country', Icons.public),
      const SizedBox(height: 12),
      const _Field('City', Icons.location_city),
      const SizedBox(height: 12),
      const _Dropdown('Languages', ['English', 'French', 'Spanish']),
      const SizedBox(height: 12),
      const _Dropdown('Relationship goal', [
        'Long-term',
        'Dating',
        'Friendship',
      ]),
      const SizedBox(height: 12),
      const Text('Interests'),
      const Wrap(
        spacing: 8,
        children: [
          FilterChip(label: Text('Travel'), selected: true, onSelected: null),
          FilterChip(label: Text('Music'), selected: false, onSelected: null),
          FilterChip(label: Text('Sports'), selected: false, onSelected: null),
        ],
      ),
      const SizedBox(height: 24),
      _PrimaryButton('Apply Filters', onPressed: () => Navigator.pop(context)),
      TextButton(
        onPressed: () => setState(() => ages = const RangeValues(18, 80)),
        child: const Text('Reset'),
      ),
    ],
  );
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sophie'),
      actions: [
        PopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'block', child: Text('Block user')),
            PopupMenuItem(value: 'report', child: Text('Report user')),
          ],
          onSelected: (v) => Navigator.pushNamed(
            context,
            v == 'block' ? AppRoutes.blockUser : AppRoutes.reportUser,
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: const [
                _Bubble('Hi! How was your day?', false),
                _Bubble('Great! I found a new café downtown.', true),
                _Bubble('Want to try it this weekend?', true),
                _Bubble('Absolutely 😊', false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Message...'),
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.mic_none)),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.send, color: AppColors.coral),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ReportUserScreen extends StatelessWidget {
  const ReportUserScreen({super.key});
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Report user',
    children: [
      const _UserSafetyCard(),
      const _SectionTitle('Why are you reporting this user?'),
      ...[
        'Harassment',
        'Fake profile',
        'Inappropriate content',
        'Spam or scam',
        'Other',
      ].map(
        (reason) => ListTile(
          onTap: () {},
          leading: Icon(
            reason == 'Fake profile'
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: AppColors.coral,
          ),
          title: Text(reason),
        ),
      ),
      const TextField(
        maxLines: 4,
        decoration: InputDecoration(labelText: 'Optional comment'),
      ),
      const SizedBox(height: 20),
      _PrimaryButton('Submit report', onPressed: () => Navigator.pop(context)),
    ],
  );
}

class BlockUserScreen extends StatelessWidget {
  const BlockUserScreen({super.key});
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Block user',
    children: [
      const _UserSafetyCard(),
      const SizedBox(height: 18),
      const Text(
        'After blocking, you will no longer see each other, exchange messages, or receive notifications. You can unblock this person later in Settings.',
      ),
      const SizedBox(height: 24),
      _PrimaryButton('Confirm block', onPressed: () => Navigator.pop(context)),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Edit Profile', Icons.edit_outlined),
      ('Privacy', Icons.visibility_outlined),
      ('Security', Icons.security),
      ('Notifications', Icons.notifications_outlined),
      ('Language', Icons.language),
      ('Subscription', Icons.workspace_premium_outlined),
      ('Blocked Users', Icons.block),
      ('Help Center', Icons.help_outline),
    ];
    return _AppPage(
      title: 'Settings',
      children: [
        ...items.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(item.$2, color: AppColors.coral),
              title: Text(item.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.$1 == 'Subscription'
                  ? () => Navigator.pushNamed(context, AppRoutes.premium)
                  : null,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log Out'),
          onTap: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (_) => false,
          ),
        ),
        const ListTile(
          leading: Icon(Icons.delete_outline, color: AppColors.error),
          title: Text(
            'Delete Account',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: const Text('Sophie'),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.reportUser),
          icon: const Icon(Icons.flag_outlined),
        ),
      ],
    ),
    body: PageView(
      children: _profiles
          .map(
            (p) => InteractiveViewer(
              child: Image.asset(p.image, fit: BoxFit.contain),
            ),
          )
          .toList(),
    ),
  );
}

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Friend requests'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ListView(
            children: _profiles
                .map(
                  (p) => ListTile(
                    leading: CircleAvatar(backgroundImage: AssetImage(p.image)),
                    title: Text(p.name),
                    subtitle: const Text('Wants to connect'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.check,
                            color: AppColors.success,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          ListView(
            children: _profiles
                .take(2)
                .map(
                  (p) => ListTile(
                    leading: CircleAvatar(backgroundImage: AssetImage(p.image)),
                    title: Text(p.name),
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('Cancel'),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

class PostsScreen extends StatelessWidget {
  const PostsScreen({super.key});
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Friends posts',
    children: _profiles
        .map(
          (p) => Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: CircleAvatar(backgroundImage: AssetImage(p.image)),
                  title: Text(p.name),
                  subtitle: const Text('Friends only'),
                  trailing: IconButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.reportUser),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
                Image.asset(
                  p.image,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('A perfect day exploring the city ✨'),
                ),
                const Row(
                  children: [
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.favorite_border),
                    ),
                    Text('Like'),
                    SizedBox(width: 20),
                    Icon(Icons.chat_bubble_outline),
                    SizedBox(width: 6),
                    Text('Comment'),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class SecretGardenScreen extends StatefulWidget {
  const SecretGardenScreen({super.key});
  @override
  State<SecretGardenScreen> createState() => _SecretGardenScreenState();
}

class _SecretGardenScreenState extends State<SecretGardenScreen> {
  String duration = '10 min';
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Secret Garden',
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/secret_garden/secret_garden_locked_placeholder.png',
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
      const _SectionTitle('Private album'),
      const Text(
        'Request time-limited access. The owner can revoke access at any time.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: ['5 min', '10 min', '20 min', '1 hour', 'Permanent']
            .map(
              (d) => ChoiceChip(
                label: Text(d),
                selected: duration == d,
                onSelected: (_) => setState(() => duration = d),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 20),
      _PrimaryButton('Request access', onPressed: () {}),
      const _SectionTitle('Access history'),
      const ListTile(
        leading: Icon(Icons.history),
        title: Text('Sophie’s album'),
        subtitle: Text('10 min • Expired yesterday'),
      ),
    ],
  );
}

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const plans = [
      (
        'Free',
        '0 CAD/month',
        [
          'Profile, search and messaging',
          'Friendship and posts',
          'Secret Garden',
          'Block and report',
        ],
      ),
      (
        'Premium Plus',
        '9.99 CAD/month • 89.99 CAD/year',
        [
          'Invisible mode and visitors',
          'Advanced filters',
          'Moderate priority',
          'More Garden requests',
        ],
      ),
      (
        'Premium Elite',
        '19.99 CAD/month • 179.99 CAD/year',
        [
          'Maximum priority',
          'Advanced suggestions',
          'Detailed statistics',
          'Priority support',
        ],
      ),
      (
        'Premium VIP',
        '29.99 CAD/month • 299.99 CAD/year',
        [
          'Privacy Control Center',
          'Absolute invisible mode',
          'Incognito and ephemeral chat',
          'Private vault and trust lists',
          'Advanced photo visibility',
          'Instant access revocation',
        ],
      ),
    ];
    return _AppPage(
      title: 'MapLov Premium',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/premium/premium_pricing_placeholder.png',
            height: 230,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        ...plans.map(
          (plan) => Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.$1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    plan.$2,
                    style: const TextStyle(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(),
                  ...plan.$3.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    plan.$1 == 'Free' ? 'Current plan' : 'Choose ${plan.$1}',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainPage extends StatelessWidget {
  const _MainPage({
    required this.index,
    required this.title,
    required this.children,
    this.actions,
  });
  final int index;
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      actions: actions,
    ),
    body: _ResponsiveBody(
      child: ListView(padding: const EdgeInsets.all(18), children: children),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        const routes = [
          AppRoutes.home,
          AppRoutes.discover,
          AppRoutes.matches,
          AppRoutes.messages,
          AppRoutes.profile,
        ];
        if (i != index) Navigator.pushReplacementNamed(context, routes[i]);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite),
          label: 'Matches',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class _AppPage extends StatelessWidget {
  const _AppPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: SafeArea(
      child: _ResponsiveBody(
        child: ListView(padding: const EdgeInsets.all(20), children: children),
      ),
    ),
  );
}

class _ResponsiveBody extends StatelessWidget {
  const _ResponsiveBody({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: constraints.maxWidth > 720 ? 680 : constraints.maxWidth,
        child: child,
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(this.label, {required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard(this.profile);
  final _Profile profile;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 175,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            profile.image,
            height: 155,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profile.name}, ${profile.age}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('${profile.city} • ${profile.score}%'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard(this.profile);
  final _Profile profile;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Stack(
          children: [
            Image.asset(
              profile.image,
              height: 310,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Chip(label: Text('${profile.score}% match')),
            ),
          ],
        ),
        ListTile(
          title: Text(
            '${profile.name}, ${profile.age}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(profile.city),
          trailing: Wrap(
            children: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
                icon: const Icon(Icons.message_outlined),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.favorite_border, color: AppColors.coral),
              ),
              IconButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.profile),
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.palePink,
    child: ListTile(
      contentPadding: const EdgeInsets.all(18),
      leading: CircleAvatar(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward),
      onTap: () => Navigator.pushNamed(context, route),
    ),
  );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(this.title, this.icon, this.route);
  final String title;
  final IconData icon;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pushNamed(context, route),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.coral),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown(this.label, this.items);
  final String label;
  final List<String> items;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: items.first,
    decoration: InputDecoration(labelText: label),
    items: items
        .map((i) => DropdownMenuItem(value: i, child: Text(i)))
        .toList(),
    onChanged: (_) {},
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, this.mine);
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: mine ? AppColors.coral : AppColors.lightGray,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(color: mine ? Colors.white : AppColors.darkText),
      ),
    ),
  );
}

class _UserSafetyCard extends StatelessWidget {
  const _UserSafetyCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundImage: AssetImage('assets/avatars/story_sophie.png'),
      ),
      title: Text('Sophie, 27'),
      subtitle: Text('Toronto, Canada'),
    ),
  );
}
