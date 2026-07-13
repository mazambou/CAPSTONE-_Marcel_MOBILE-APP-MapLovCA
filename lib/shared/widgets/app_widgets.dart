part of '../../app.dart';

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
    bottomNavigationBar: _MapLovNavigationBar(selectedIndex: index),
  );
}

class _MapLovNavigationBar extends StatelessWidget {
  const _MapLovNavigationBar({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        const routes = [
          AppRoutes.home,
          AppRoutes.messages,
          AppRoutes.nearMe,
          AppRoutes.matches,
          AppRoutes.profile,
        ];
        if (index != selectedIndex) {
          Navigator.pushReplacementNamed(context, routes[index]);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Badge(label: Text('2'), child: Icon(Icons.chat_bubble_outline)),
          selectedIcon: Badge(label: Text('2'), child: Icon(Icons.chat_bubble)),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Badge(label: Text('7'), child: Icon(Icons.favorite_border)),
          selectedIcon: Badge(label: Text('7'), child: Icon(Icons.favorite)),
          label: 'Likes',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
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

// Kept for legacy layouts that may reuse the horizontal recommendation card.
// ignore: unused_element
class _ProfileCard extends StatelessWidget {
  const _ProfileCard(this.profile);
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 175,
    child: GestureDetector(
      key: Key('profile_photo_${profile.name}'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PhotoViewerScreen(profile: profile)),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              profile.imagePath,
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
                  Text('${profile.city} • ${profile.compatibilityScore}%'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard(this.profile);
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              key: Key('discover_photo_${profile.name}'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewerScreen(profile: profile),
                ),
              ),
              child: Image.asset(
                profile.imagePath,
                height: 310,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Chip(label: Text('${profile.compatibilityScore}% match')),
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
                    Navigator.pushNamed(context, AppRoutes.publicProfile),
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Kept for legacy layouts that may reuse the highlighted navigation card.
// ignore: unused_element
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
    isExpanded: true,
    initialValue: items.first,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (i) => DropdownMenuItem(
            value: i,
            child: Text(i, overflow: TextOverflow.ellipsis),
          ),
        )
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
