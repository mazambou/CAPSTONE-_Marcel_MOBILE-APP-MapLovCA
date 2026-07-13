part of '../../app.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _plans = [
    _PremiumPlan(
      name: 'FREE',
      tagline: 'Discover\nand connect',
      monthlyPrice: r'$0',
      icon: Icons.favorite_border_rounded,
      iconColor: AppColors.blush,
      features: [
        'Complete profile',
        'Messaging',
        'Match & Compatibility',
        'Search (4 modes)',
        'Friend requests',
        'Posts',
        'Secret Garden',
        'Blocking & Reporting',
      ],
      isCurrent: true,
    ),
    _PremiumPlan(
      name: 'PREMIUM\nPLUS',
      tagline: 'Better\nsearching',
      monthlyPrice: r'$9.99',
      yearlyPrice: r'$89.99 / year',
      saving: 'Save 25%',
      icon: Icons.diamond_rounded,
      featuresTitle: 'Everything in Free, plus:',
      features: [
        'Incognito mode',
        'See who viewed you',
        'Advanced filters',
        'Moderate priority',
        'Premium Plus badge',
        'More Secret Garden requests',
      ],
      buttonLabel: 'Choose Plus',
      productId: PremiumProductIds.plusMonthly,
    ),
    _PremiumPlan(
      name: 'PREMIUM\nELITE',
      tagline: 'Be your best,\nget found',
      monthlyPrice: r'$19.99',
      yearlyPrice: r'$179.99 / year',
      saving: 'Save 25%',
      icon: Icons.workspace_premium_rounded,
      featuresTitle: 'Everything in Plus, plus:',
      features: [
        'Maximum priority',
        'Smart suggestions',
        'Advanced statistics',
        'Advanced Secret Garden management',
        'Priority support',
        'Early access to new features',
      ],
      buttonLabel: 'Choose Elite',
      badge: 'MOST POPULAR',
      highlighted: true,
      productId: PremiumProductIds.eliteMonthly,
    ),
    _PremiumPlan(
      name: 'PREMIUM\nVIP',
      tagline: 'Total privacy\nand control',
      monthlyPrice: r'$29.99',
      yearlyPrice: r'$299.99 / year',
      saving: 'Save 30%',
      icon: Icons.diamond_rounded,
      iconColor: Color(0xFFD14C9A),
      featuresTitle: 'Everything in Elite, plus:',
      features: [
        'Granular profile control',
        'Privacy Control Center',
        'Fully invisible',
        'Private navigation',
        'Control incoming messages',
        'Incognito conversation mode',
        'Ephemeral messages',
        'Hide from all',
        'Auto-delete conversations',
        'Temporary profile visibility',
        'Advanced photo management',
        'Trusted contacts list',
        'Instant account recovery',
        'Private vault',
        'Screenshot protection',
      ],
      buttonLabel: 'Choose VIP',
      badge: 'NEW',
      badgeIcon: Icons.diamond_outlined,
      productId: PremiumProductIds.vipMonthly,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? 22 : 16,
                12,
                isWide ? 22 : 16,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1220),
                  child: Column(
                    children: [
                      _PremiumHeader(isWide: isWide),
                      const SizedBox(height: 22),
                      if (isWide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: _plans
                                .map(
                                  (plan) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                      ),
                                      child: _PremiumPlanCard(
                                        plan: plan,
                                        isWide: true,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                      else
                        ..._plans.map(
                          (plan) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _PremiumPlanCard(plan: plan),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const _PremiumSecurityCard(),
                      const SizedBox(height: 20),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite,
                            color: AppColors.deepPink,
                            size: 21,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'MapLov',
                            style: TextStyle(
                              color: AppColors.deepPink,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            ' – Connecting hearts, everywhere.',
                            style: TextStyle(color: AppColors.grayText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    void close() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            children: [
              Text(
                'Upgrade to Premium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF171A24),
                  fontSize: isWide ? 38 : 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: const Color(0xFF333744),
                    fontSize: isWide ? 23 : 16,
                    height: 1.35,
                  ),
                  children: const [
                    TextSpan(
                      text:
                          'Choose the plan that fits your needs\nand enjoy the full ',
                    ),
                    TextSpan(
                      text: 'MapLov',
                      style: TextStyle(color: AppColors.deepPink),
                    ),
                    TextSpan(text: ' experience.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: AppColors.deepPink,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Secure payment  •  Cancel anytime',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF3F4350)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: IconButton(
            tooltip: 'Back',
            onPressed: close,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: 'Close',
            onPressed: close,
            icon: const Icon(Icons.close_rounded, size: 30),
          ),
        ),
      ],
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({required this.plan, this.isWide = false});

  final _PremiumPlan plan;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.fromLTRB(isWide ? 16 : 22, 30, isWide ? 16 : 22, 20),
      decoration: BoxDecoration(
        color: plan.name.contains('VIP')
            ? const Color(0xFFFFFBFD)
            : AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: plan.highlighted
              ? AppColors.deepPink
              : const Color(0xFFF2DCE4),
          width: plan.highlighted ? 1.6 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: plan.isCurrent
                  ? const Color(0xFF3D414D)
                  : plan.name.contains('VIP')
                  ? const Color(0xFFB33E87)
                  : AppColors.deepPink,
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Icon(plan.icon, size: 78, color: plan.iconColor),
          const SizedBox(height: 14),
          Text(
            plan.tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.25),
          ),
          const SizedBox(height: 36),
          Text(
            plan.monthlyPrice,
            style: TextStyle(
              color: plan.isCurrent
                  ? const Color(0xFF4B4F5B)
                  : plan.name.contains('VIP')
                  ? const Color(0xFFC94F95)
                  : AppColors.deepPink,
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text('/ month', style: TextStyle(fontSize: 17)),
          if (plan.yearlyPrice != null) ...[
            const SizedBox(height: 26),
            Text(plan.yearlyPrice!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              plan.saving!,
              style: const TextStyle(color: AppColors.deepPink, fontSize: 16),
            ),
          ] else
            const SizedBox(height: 71),
          const SizedBox(height: 34),
          if (plan.featuresTitle != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                plan.featuresTitle!,
                style: const TextStyle(
                  color: AppColors.deepPink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 10),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(
                      color: AppColors.softCoral,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(feature, style: const TextStyle(height: 1.25)),
                  ),
                ],
              ),
            ),
          ),
          if (isWide) const Spacer() else const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: plan.isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Current plan'),
                  )
                : plan.highlighted
                ? FilledButton(
                    onPressed: () => _openPurchaseStatus(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: AppColors.deepPink,
                    ),
                    child: Text(plan.buttonLabel!),
                  )
                : OutlinedButton(
                    onPressed: () => _openPurchaseStatus(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      foregroundColor: AppColors.deepPink,
                      side: const BorderSide(color: AppColors.deepPink),
                    ),
                    child: Text(plan.buttonLabel!),
                  ),
          ),
        ],
      ),
    );

    if (plan.badge == null) return content;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        content,
        Positioned(
          top: -15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFC8D8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  plan.badgeIcon ?? Icons.star_rounded,
                  size: 18,
                  color: plan.name.contains('VIP')
                      ? const Color(0xFFD14C9A)
                      : AppColors.deepPink,
                ),
                const SizedBox(width: 7),
                Text(
                  plan.badge!,
                  style: TextStyle(
                    color: plan.name.contains('VIP')
                        ? const Color(0xFFB33E87)
                        : AppColors.deepPink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPurchaseStatus(BuildContext context) async {
    final selectedPlan = plan.name.replaceAll('\n', ' ');
    final launched = await PurchaseService.instance.buy(plan.productId!);
    if (!context.mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PurchaseService.instance.error ?? 'The store is unavailable.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseStatusScreen(planName: selectedPlan),
      ),
    );
  }
}

class _PremiumSecurityCard extends StatelessWidget {
  const _PremiumSecurityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: AppColors.palePink,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.security_rounded,
              size: 42,
              color: AppColors.deepPink,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your security, our priority',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 5),
                Text(
                  'At MapLov, we protect your privacy and your data.\n'
                  'We never share your information without your consent.',
                  style: TextStyle(color: AppColors.grayText, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPlan {
  const _PremiumPlan({
    required this.name,
    required this.tagline,
    required this.monthlyPrice,
    required this.icon,
    required this.features,
    this.yearlyPrice,
    this.saving,
    this.featuresTitle,
    this.buttonLabel,
    this.badge,
    this.badgeIcon,
    this.iconColor = AppColors.softCoral,
    this.highlighted = false,
    this.isCurrent = false,
    this.productId,
  });

  final String name;
  final String tagline;
  final String monthlyPrice;
  final String? yearlyPrice;
  final String? saving;
  final IconData icon;
  final Color iconColor;
  final String? featuresTitle;
  final List<String> features;
  final String? buttonLabel;
  final String? badge;
  final IconData? badgeIcon;
  final bool highlighted;
  final bool isCurrent;
  final String? productId;
}
