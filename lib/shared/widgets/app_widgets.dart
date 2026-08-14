part of '../../app.dart';

enum _SubscriptionRequirement { premiumPlus, vip }

Future<bool> _requireSubscriptionFeature(
  BuildContext context, {
  required _SubscriptionRequirement requirement,
  required String feature,
  ExternalPaymentProduct? passProduct,
}) async {
  final subscription = await MapLovRepository.instance.subscriptionInfo();
  var allowed = requirement == _SubscriptionRequirement.vip
      ? subscription.isVip
      : subscription.isPremium;
  final entitlementKind = switch (passProduct) {
    ExternalPaymentProduct.countryPass24h ||
    ExternalPaymentProduct.countryPass7d => 'country_pass',
    ExternalPaymentProduct.internationalPass24h ||
    ExternalPaymentProduct.internationalPass7d => 'international_pass',
    _ => null,
  };
  if (!allowed && entitlementKind != null) {
    allowed = await MapLovRepository.instance.hasActivePaymentEntitlement(
      entitlementKind,
    );
  }
  if (allowed || !context.mounted) return allowed;

  final level = requirement == _SubscriptionRequirement.vip
      ? 'Premium VIP'
      : 'Premium Plus';
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('$level required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$feature requires a $level subscription.'),
          if (passProduct != null) ...[
            const SizedBox(height: 12),
            Text('Choisissez ${passProduct.label} ou passez à $level.'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'cancel'),
          child: const Text('Cancel'),
        ),
        if (passProduct != null && AppConfig.externalCheckoutEnabled)
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, 'pass'),
            child: Text('Acheter ${passProduct.label}'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'upgrade'),
          child: const Text('Upgrade'),
        ),
      ],
    ),
  );
  if (choice == 'pass' && passProduct != null && context.mounted) {
    final launched = await ExternalCheckoutService.instance.startCheckout(
      provider: ExternalPaymentProvider.stripe,
      productId: passProduct.id,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ExternalCheckoutService.instance.error ??
                'Le paiement Stripe est indisponible.',
          ),
        ),
      );
    }
    return false;
  }
  if (choice == 'upgrade' && context.mounted) {
    await Navigator.pushNamed(context, AppRoutes.premium);
    if (!context.mounted) return false;
    final updated = await MapLovRepository.instance.subscriptionInfo();
    allowed = requirement == _SubscriptionRequirement.vip
        ? updated.isVip
        : updated.isPremium;
    if (!allowed && entitlementKind != null) {
      allowed = await MapLovRepository.instance.hasActivePaymentEntitlement(
        entitlementKind,
      );
    }
    return allowed;
  }
  return false;
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
      title: Text(
        context.tr(title),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
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
          AppRoutes.posts,
          AppRoutes.matches,
          AppRoutes.messages,
          AppRoutes.profile,
        ];
        if (index != selectedIndex) {
          Navigator.pushReplacementNamed(context, routes[index]);
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.search),
          selectedIcon: const Icon(Icons.search),
          label: MapLovLocalizations.of(context).text('discover'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.dynamic_feed_outlined),
          selectedIcon: const Icon(Icons.dynamic_feed),
          label: context.tr('Posts'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          label: context.tr('Likes & Matches'),
        ),
        NavigationDestination(
          icon: StreamBuilder<int>(
            stream: MapLovRepository.instance.watchUnreadMessageCount(),
            builder: (context, snapshot) => Badge(
              key: const Key('messages_navigation_badge'),
              label: Text('${snapshot.data ?? 0}'),
              isLabelVisible: (snapshot.data ?? 0) > 0,
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          selectedIcon: StreamBuilder<int>(
            stream: MapLovRepository.instance.watchUnreadMessageCount(),
            builder: (context, snapshot) => Badge(
              label: Text('${snapshot.data ?? 0}'),
              isLabelVisible: (snapshot.data ?? 0) > 0,
              child: const Icon(Icons.chat_bubble),
            ),
          ),
          label: MapLovLocalizations.of(context).text('messages'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: MapLovLocalizations.of(context).text('profile'),
        ),
      ],
    );
  }
}

class _AppPage extends StatelessWidget {
  const _AppPage({required this.title, required this.children, this.actions});
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        context.tr(title),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: actions,
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
      child: Text(
        context.tr(label),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
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
      context.tr(text),
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 7 : 9,
      vertical: compact ? 3 : 4,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFD14C9A), AppColors.deepPink],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.workspace_premium_rounded,
          size: compact ? 12 : 14,
          color: AppColors.white,
        ),
        const SizedBox(width: 4),
        Text(
          'VIP',
          style: TextStyle(
            color: AppColors.white,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
            profileImage(
              profile,
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

// Retained for the validated compact-message presentation variant.
// ignore: unused_element
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

Future<bool> _requireProfilePhotos(
  BuildContext context, {
  required int minimum,
}) async {
  final count = await MapLovRepository.instance.myPhotoCount();
  if (!context.mounted) return false;
  if (count >= minimum) return true;

  final message = minimum == 1
      ? 'Add a profile photo before using this action.'
      : 'Add at least 3 profile photos before viewing another member’s profile.';
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.add_a_photo_outlined,
        color: AppColors.coral,
        size: 42,
      ),
      title: const Text('Profile photos required'),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          key: Key('add_required_${minimum}_photos'),
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.pushNamed(context, AppRoutes.managePhotos);
          },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photos'),
        ),
      ],
    ),
  );
  return false;
}

Future<ProfileLikeResult?> _toggleProfileLikeFromDetails(
  BuildContext context,
  UserProfile profile,
) async {
  if (!await _requireProfilePhotos(context, minimum: 1) || !context.mounted) {
    return null;
  }
  try {
    final result = await MapLovRepository.instance.toggleProfileLike(
      profile.id,
    );
    if (!context.mounted) return result;
    if (result.matched) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewMatchScreen(profile: profile)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.liked ? 'Profile liked.' : 'Profile like removed.',
          ),
        ),
      );
    }
    return result;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update this like: $error')),
      );
    }
    return null;
  }
}
