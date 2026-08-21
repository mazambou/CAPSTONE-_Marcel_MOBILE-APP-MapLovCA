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
        'Profile and public photos',
        'Discover, send likes and create matches',
        'Text, photo, voice and document messages',
        'Quick and standard filters',
        'Friends and community posts',
        '1 Secret Garden album and 10 photos',
        'Blocking, reporting and photo moderation',
      ],
      isCurrent: true,
    ),
    _PremiumPlan(
      name: 'PREMIUM\nPLUS',
      tagline: 'See more,\nsearch better',
      monthlyPrice: r'12,99 $ CAD',
      yearlyPrice: r'99,99 $ CAD / an',
      saving: r'Économisez 55,89 $ (36 %)',
      icon: Icons.diamond_rounded,
      featuresTitle: 'Everything in Free, plus:',
      features: [
        'See who liked your profile',
        'See who viewed your profile',
        'Advanced filters',
        'Country search by region and city',
        'Clear your unread messages for everyone',
        '3 Secret Garden albums and 30 photos',
        '20 Secret Garden requests per day',
        'Early access to New Accounts after 7 days',
        'Unlimited profile rewinds',
        'Priority placement in received Likes',
        'Read receipts for conversations',
      ],
      buttonLabel: 'Choose Plus',
      productId: PremiumProductIds.plusMonthly,
    ),
    _PremiumPlan(
      name: 'PREMIUM\nVIP',
      tagline: 'The king of\nprivacy and control',
      monthlyPrice: r'19,99 $ CAD',
      yearlyPrice: r'149,99 $ CAD / an',
      saving: r'Économisez 89,89 $ (37 %)',
      icon: Icons.workspace_premium_rounded,
      featuresTitle: 'Everything in Plus, plus:',
      features: [
        'Your profile appears after you like or message',
        'Exclusive VIP profile badge',
        'International search by country and region',
        'Advanced statistics',
        'Delete a message for everyone after it is read',
        'Clear a full conversation on both accounts',
        '10 Secret Garden albums and 100 photos',
        '100 Secret Garden requests per day',
        'Exclusive access to New Accounts during their first 7 days',
        'Priority customer support',
      ],
      buttonLabel: 'Become VIP',
      badge: 'KING',
      badgeIcon: Icons.workspace_premium_rounded,
      highlighted: true,
      productId: PremiumProductIds.eliteMonthly,
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
                      const _StoreCatalog(),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Comparer les niveaux',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 16),
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
              const Text(
                'Boutique MapLov',
                style: TextStyle(
                  color: AppColors.deepPink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: const Color(0xFF333744),
                    fontSize: isWide ? 23 : 16,
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(
                      text: context.tr(
                        'Abonnements, Pass, Boosts et Super Likes\nau même endroit. Découvrez toute l’expérience ',
                      ),
                    ),
                    const TextSpan(
                      text: 'MapLov',
                      style: TextStyle(color: AppColors.deepPink),
                    ),
                    TextSpan(text: context.tr(' experience.')),
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
          if (plan.name.contains('VIP')) ...[const _VipInvisibleModeControl()],
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
    if (AppConfig.externalCheckoutEnabled) {
      final product = await _chooseSubscriptionPeriod(context);
      if (product == null || !context.mounted) return;
      final provider = await _chooseExternalProvider(context, product: product);
      if (provider == null || !context.mounted) return;
      final launched = await ExternalCheckoutService.instance.startCheckout(
        provider: provider,
        productId: product.id,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ExternalCheckoutService.instance.error ??
                  'Le paiement sécurisé est indisponible.',
            ),
          ),
        );
      }
      return;
    }

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

  Future<ExternalPaymentProvider?> _chooseExternalProvider(
    BuildContext context, {
    required ExternalPaymentProduct product,
  }) {
    return showModalBottomSheet<ExternalPaymentProvider>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choisir un moyen de paiement',
              textAlign: TextAlign.center,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous serez redirigé vers la page sécurisée du prestataire. '
              'MapLov ne reçoit jamais les données de votre carte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayText),
            ),
            const SizedBox(height: 18),
            for (final provider in ExternalPaymentProvider.values.where(
              product.supports,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, provider),
                  icon: Icon(switch (provider) {
                    ExternalPaymentProvider.stripe => Icons.credit_card_rounded,
                    ExternalPaymentProvider.paypal =>
                      Icons.account_balance_wallet_outlined,
                    ExternalPaymentProvider.flutterwave => Icons.public_rounded,
                  }),
                  label: Text(provider.label),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<ExternalPaymentProduct?> _chooseSubscriptionPeriod(
    BuildContext context,
  ) {
    final plus = plan.productId == PremiumProductIds.plusMonthly;
    final monthly = plus
        ? ExternalPaymentProduct.plusMonthly
        : ExternalPaymentProduct.vipMonthly;
    final yearly = plus
        ? ExternalPaymentProduct.plusYearly
        : ExternalPaymentProduct.vipYearly;
    return showModalBottomSheet<ExternalPaymentProduct>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choisir la période',
              textAlign: TextAlign.center,
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext, monthly),
              child: Text('Mensuel — ${plan.monthlyPrice} / mois'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(sheetContext, yearly),
              child: Text('Annuel — ${plan.yearlyPrice}'),
            ),
            const SizedBox(height: 8),
            const Text(
              'L’abonnement annuel est traité par Stripe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayText),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCatalogItem {
  const _StoreCatalogItem({
    required this.product,
    required this.category,
    required this.price,
    required this.summary,
    required this.details,
    required this.icon,
    this.badge,
    this.monthlyEquivalent,
  });

  final ExternalPaymentProduct product;
  final String category;
  final String price;
  final String summary;
  final String details;
  final IconData icon;
  final String? badge;
  final String? monthlyEquivalent;

  List<String> get benefits => switch (product) {
    ExternalPaymentProduct.plusMonthly => const [
      'Voir qui a aimé et consulté votre profil',
      'Filtres avancés et recherche Country par région et ville',
      '3 albums Secret Garden et 30 photos',
      '20 demandes Secret Garden par jour',
      'Retours illimités sur les profils',
      'Likes prioritaires dans la liste reçue et confirmations de lecture',
    ],
    ExternalPaymentProduct.plusYearly => const [
      'Tous les avantages MapLov Plus',
      'Accès pendant une année complète',
      r'Économie de 55,89 $ CAD par rapport au paiement mensuel',
      'Renouvellement annuel pouvant être annulé',
    ],
    ExternalPaymentProduct.vipMonthly => const [
      'Tous les avantages MapLov Plus',
      'Recherche internationale par pays et région',
      'Mode de navigation invisible et badge VIP',
      'Statistiques avancées',
      'Suppression étendue des messages et conversations',
      '10 albums Secret Garden et 100 photos',
      '100 demandes Secret Garden par jour',
      'Accès prioritaire aux nouveaux comptes',
      'Assistance client prioritaire',
    ],
    ExternalPaymentProduct.vipYearly => const [
      'Tous les avantages MapLov Plus et VIP',
      'Recherche internationale par pays et région',
      'Accès pendant une année complète',
      r'Économie de 89,89 $ CAD par rapport au paiement mensuel',
      'Renouvellement annuel pouvant être annulé',
    ],
    ExternalPaymentProduct.countryPass24h => const [
      'Recherche Country pendant 24 heures',
      'Recherche par région et ville dans votre pays',
      'Aucun abonnement ni renouvellement automatique',
      'Retour automatique à votre niveau précédent après 24 heures',
    ],
    ExternalPaymentProduct.countryPass7d => const [
      'Recherche Country pendant 7 jours',
      'Recherche par région et ville dans votre pays',
      'Aucun abonnement ni renouvellement automatique',
      'Retour automatique à votre niveau précédent après 7 jours',
    ],
    ExternalPaymentProduct.internationalPass24h => const [
      'Recherche internationale pendant 24 heures',
      'Recherche dans un autre pays',
      'Contact avec les membres ouverts à la découverte internationale',
      'Retour automatique à votre niveau précédent après 24 heures',
    ],
    ExternalPaymentProduct.internationalPass7d => const [
      'Recherche internationale pendant 7 jours',
      'Recherche dans un autre pays',
      'Contact avec les membres ouverts à la découverte internationale',
      'Retour automatique à votre niveau précédent après 7 jours',
    ],
    ExternalPaymentProduct.boost30m => const [
      'Mise en avant du profil pendant 30 minutes',
      'Visibilité renforcée dans la découverte',
      'Aucun renouvellement automatique',
    ],
    ExternalPaymentProduct.boost3h => const [
      'Mise en avant du profil pendant 3 heures',
      'Visibilité renforcée dans la découverte',
      'Aucun renouvellement automatique',
    ],
    ExternalPaymentProduct.boost24h => const [
      'Mise en avant du profil pendant 24 heures',
      'Visibilité renforcée dans la découverte',
      'Aucun renouvellement automatique',
    ],
    ExternalPaymentProduct.superLikes5 => const [
      '5 crédits Super Likes',
      'Crédits ajoutés au solde après confirmation',
      'Aucun abonnement ni renouvellement automatique',
    ],
    ExternalPaymentProduct.superLikes15 => const [
      '15 crédits Super Likes',
      'Crédits ajoutés au solde après confirmation',
      'Aucun abonnement ni renouvellement automatique',
    ],
    ExternalPaymentProduct.superLikes30 => const [
      '30 crédits Super Likes',
      'Crédits ajoutés au solde après confirmation',
      'Aucun abonnement ni renouvellement automatique',
    ],
  };
}

class _StoreCatalog extends StatefulWidget {
  const _StoreCatalog();

  @override
  State<_StoreCatalog> createState() => _StoreCatalogState();
}

String? storeProductIncludedLabel(
  SubscriptionInfo subscription,
  ExternalPaymentProduct product,
) {
  final productName = product.name;
  if (subscription.isVip &&
      (product.isSubscription ||
          productName.startsWith('countryPass') ||
          productName.startsWith('internationalPass'))) {
    return 'Inclus avec MapLov VIP';
  }
  if (subscription.tier == 'plus' &&
      (productName.startsWith('plus') ||
          productName.startsWith('countryPass'))) {
    return 'Inclus avec MapLov Plus';
  }
  return null;
}

class _StoreCatalogState extends State<_StoreCatalog> {
  static const items = [
    _StoreCatalogItem(
      product: ExternalPaymentProduct.plusMonthly,
      category: 'Abonnements',
      price: r'12,99 $ CAD / mois',
      summary: 'Les avantages MapLov Plus avec paiement mensuel.',
      details:
          'Accédez aux fonctions Plus déjà disponibles dans MapLov. '
          'L’abonnement se renouvelle chaque mois jusqu’à son annulation.',
      icon: Icons.diamond_outlined,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.plusYearly,
      category: 'Abonnements',
      price: r'99,99 $ CAD / an',
      summary: r'Économisez 55,89 $ CAD, soit 36 %.',
      badge: '🏆 LE PLUS POPULAIRE',
      monthlyEquivalent: r'Seulement 8,33 $ CAD / mois',
      details:
          'Les mêmes avantages MapLov Plus pendant un an, avec une économie '
          'par rapport à douze paiements mensuels.',
      icon: Icons.diamond_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.vipMonthly,
      category: 'Abonnements',
      price: r'19,99 $ CAD / mois',
      summary: 'L’expérience MapLov complète avec paiement mensuel.',
      details:
          'Accédez aux fonctions VIP déjà disponibles dans MapLov. '
          'L’abonnement se renouvelle chaque mois jusqu’à son annulation.',
      icon: Icons.workspace_premium_outlined,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.vipYearly,
      category: 'Abonnements',
      price: r'149,99 $ CAD / an',
      summary: r'Économisez 89,89 $ CAD, soit 37 %.',
      badge: '⭐ MEILLEURE OFFRE',
      monthlyEquivalent: r'Seulement 12,50 $ CAD / mois',
      details:
          'Les avantages MapLov VIP pendant un an au meilleur tarif annuel.',
      icon: Icons.workspace_premium_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.countryPass24h,
      category: 'Produits à achat unique',
      price: r'2,99 $ CAD',
      summary: 'Recherche Country pendant 24 heures.',
      details:
          'Débloque temporairement la recherche dans votre pays. À '
          'l’expiration, votre accès revient automatiquement à son niveau précédent.',
      icon: Icons.travel_explore_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.countryPass7d,
      category: 'Produits à achat unique',
      price: r'6,99 $ CAD',
      summary: 'Recherche Country pendant 7 jours.',
      details: 'Idéal pour préparer un déplacement sans souscrire à Plus.',
      icon: Icons.travel_explore_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.internationalPass24h,
      category: 'Produits à achat unique',
      price: r'4,99 $ CAD',
      summary: 'Recherche internationale pendant 24 heures.',
      details:
          'Débloque temporairement la recherche internationale normalement '
          'réservée à VIP.',
      icon: Icons.public_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.internationalPass7d,
      category: 'Produits à achat unique',
      price: r'9,99 $ CAD',
      summary: 'Recherche internationale pendant 7 jours.',
      details:
          'Recherchez dans un autre pays pendant sept jours, sans abonnement.',
      icon: Icons.public_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.boost30m,
      category: 'Produits à achat unique',
      price: r'2,99 $ CAD',
      summary: 'Visibilité renforcée pendant 30 minutes.',
      details: 'Votre profil bénéficie temporairement d’une mise en avant.',
      icon: Icons.rocket_launch_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.boost3h,
      category: 'Produits à achat unique',
      price: r'4,99 $ CAD',
      summary: 'Visibilité renforcée pendant 3 heures.',
      details:
          'Une mise en avant prolongée de votre profil pendant trois heures.',
      icon: Icons.rocket_launch_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.boost24h,
      category: 'Produits à achat unique',
      price: r'7,99 $ CAD',
      summary: 'Visibilité renforcée pendant 24 heures.',
      details: 'Votre profil reste mis en avant pendant une journée complète.',
      icon: Icons.rocket_launch_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.superLikes5,
      category: 'Produits à achat unique',
      price: r'2,99 $ CAD',
      summary: r'Pack de 5 • 0,60 $ par Super Like.',
      details:
          'Cinq crédits ajoutés à votre solde après confirmation du paiement.',
      icon: Icons.favorite_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.superLikes15,
      category: 'Produits à achat unique',
      price: r'6,99 $ CAD',
      summary: r'Pack de 15 • 0,47 $ par Super Like.',
      details: 'Quinze crédits ajoutés à votre solde après confirmation.',
      icon: Icons.favorite_rounded,
    ),
    _StoreCatalogItem(
      product: ExternalPaymentProduct.superLikes30,
      category: 'Produits à achat unique',
      price: r'11,99 $ CAD',
      summary: r'Pack de 30 • 0,40 $ par Super Like.',
      details: 'Trente crédits ajoutés à votre solde après confirmation.',
      icon: Icons.favorite_rounded,
    ),
  ];

  late final Future<SubscriptionInfo> _subscription;
  late final Future<List<Map<String, dynamic>>> _entitlements;
  late final Future<int> _superLikes;
  Map<String, Map<String, dynamic>> _promotions = const {};

  @override
  void initState() {
    super.initState();
    _subscription = MapLovRepository.instance.subscriptionInfo();
    _entitlements = MapLovRepository.instance.activePaymentEntitlements();
    _superLikes = MapLovRepository.instance.superLikesBalance();
    unawaited(_loadPromotions());
  }

  Future<void> _loadPromotions() async {
    // These campaigns are backed by promotional Stripe Price IDs. Mobile
    // builds use the native stores, so advertising the Stripe amount there
    // would create a price mismatch at checkout.
    if (!AppConfig.externalCheckoutEnabled) return;
    final values = await MapLovRepository.instance.activeBillingPromotions();
    if (!mounted) return;
    setState(() {
      _promotions = {
        for (final value in values) value['product_id'].toString(): value,
      };
    });
  }

  String _promotionPrice(Map<String, dynamic> promotion) {
    final amount = (promotion['promotional_amount_minor'] as num).toInt();
    return '${(amount / 100).toStringAsFixed(2).replaceAll('.', ',')} \$ CAD';
  }

  Future<ExternalPaymentProvider?> _provider(BuildContext context) {
    return showModalBottomSheet<ExternalPaymentProvider>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choisir le moyen de paiement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            for (final provider in ExternalPaymentProvider.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext, provider),
                  child: Text(provider.label),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(
    BuildContext context,
    ExternalPaymentProduct product,
  ) async {
    if (AppConfig.externalCheckoutEnabled) {
      final provider = product.id.endsWith('_monthly')
          ? await _provider(context)
          : ExternalPaymentProvider.stripe;
      if (provider == null || !context.mounted) return;
      final opened = await ExternalCheckoutService.instance.startCheckout(
        provider: provider,
        productId: product.id,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ExternalCheckoutService.instance.error ??
                  'Le paiement sécurisé est indisponible.',
            ),
          ),
        );
      }
      return;
    }

    final nativeProduct = switch (product) {
      ExternalPaymentProduct.plusMonthly => PremiumProductIds.plusMonthly,
      ExternalPaymentProduct.vipMonthly => PremiumProductIds.eliteMonthly,
      _ => null,
    };
    if (nativeProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cet achat Stripe est disponible sur la version Web de MapLov.',
          ),
        ),
      );
      return;
    }
    final opened = await PurchaseService.instance.buy(nativeProduct);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PurchaseService.instance.error ?? 'La boutique est indisponible.',
          ),
        ),
      );
    }
  }

  Future<void> _details(
    BuildContext context,
    _StoreCatalogItem item,
    Map<String, dynamic>? promotion,
    String? includedLabel,
  ) async {
    final buy = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ListView(
            key: Key('store_details_${item.product.id}'),
            children: [
              if (item.badge != null) ...[
                Center(
                  child: Chip(
                    backgroundColor: AppColors.deepPink,
                    label: Text(
                      item.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Icon(item.icon, size: 54, color: AppColors.deepPink),
              const SizedBox(height: 12),
              Text(
                item.product.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (promotion != null) ...[
                Text(
                  item.price,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.grayText,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  _promotionPrice(promotion),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deepPink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${promotion['name']} • jusqu’au ${_adminDate(promotion['ends_at'])}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ] else
                Text(
                  item.price,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deepPink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (item.monthlyEquivalent != null) ...[
                const SizedBox(height: 6),
                Text(
                  item.monthlyEquivalent!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
              const SizedBox(height: 18),
              Text(item.details, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const Text(
                'Ce que vous obtenez',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final benefit in item.benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.deepPink,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(benefit)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.palePink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.product.isSubscription
                      ? 'Paiement récurrent. Vous pouvez gérer ou annuler le renouvellement depuis votre compte.'
                      : 'Paiement unique. Aucun abonnement ni renouvellement automatique.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: Key('store_buy_${item.product.id}'),
                onPressed: includedLabel == null
                    ? () => Navigator.pop(sheetContext, true)
                    : null,
                icon: Icon(
                  includedLabel == null
                      ? Icons.lock_outline_rounded
                      : Icons.check_circle_rounded,
                ),
                label: Text(
                  includedLabel ??
                      (item.product.isSubscription ? 'S’abonner' : 'Acheter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (buy == true && context.mounted) await _purchase(context, item.product);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SubscriptionInfo>(
      future: _subscription,
      builder: (context, snapshot) {
        final subscription = snapshot.data ?? const SubscriptionInfo();
        const visibleItems = items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.palePink,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFC8D8)),
              ),
              child: const Text(
                '⭐ Les formules annuelles offrent les économies les plus importantes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (subscription.isPremium) ...[
              const SizedBox(height: 14),
              Card(
                color: const Color(0xFFEAF8EF),
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF168447),
                  ),
                  title: Text(
                    subscription.isPromotionalVip
                        ? 'Votre accès actuel : VIP fondateur offert'
                        : 'Votre abonnement actuel : MapLov ${subscription.displayName}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    subscription.isPromotionalVip
                        ? '${subscription.promotionMemberCount}/${subscription.promotionThreshold} membres • '
                              'Au 1 001ᵉ compte, votre forfait ${subscription.baseDisplayName} reprendra automatiquement.'
                        : subscription.renewsAt == null
                        ? 'Actif sur votre compte'
                        : 'Accès jusqu’au ${DateFormat.yMMMd().format(subscription.renewsAt!)}',
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.subscriptionManagement,
                    ),
                    child: const Text('Gérer'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FutureBuilder<int>(
                  future: _superLikes,
                  builder: (context, balance) => Chip(
                    avatar: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.deepPink,
                    ),
                    label: Text(
                      '${balance.data ?? 0} Super Like${(balance.data ?? 0) == 1 ? '' : 's'} disponible${(balance.data ?? 0) == 1 ? '' : 's'}',
                    ),
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _entitlements,
                  builder: (context, entitlements) {
                    final activeBoost = (entitlements.data ?? const [])
                        .where((item) => item['entitlement_kind'] == 'boost')
                        .firstOrNull;
                    final expiry = DateTime.tryParse(
                      activeBoost?['expires_at']?.toString() ?? '',
                    );
                    return Chip(
                      avatar: const Icon(
                        Icons.rocket_launch_rounded,
                        color: AppColors.deepPink,
                      ),
                      label: Text(
                        expiry == null
                            ? 'Aucun Boost actif'
                            : 'Boost actif jusqu’à ${DateFormat.Hm().format(expiry)}',
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (final category in const [
              'Abonnements',
              'Produits à achat unique',
            ])
              if (visibleItems.any((item) => item.category == category)) ...[
                Text(
                  category,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  category == 'Abonnements'
                      ? 'Choisissez une formule mensuelle ou annuelle.'
                      : 'Achetez uniquement ce dont vous avez besoin, sans engagement.',
                  style: const TextStyle(color: AppColors.grayText),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 14) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        for (final item in visibleItems.where(
                          (item) => item.category == category,
                        ))
                          SizedBox(
                            width: width,
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: Key('store_product_${item.product.id}'),
                                onTap: () => _details(
                                  context,
                                  item,
                                  _promotions[item.product.id],
                                  storeProductIncludedLabel(
                                    subscription,
                                    item.product,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.palePink,
                                        child: Icon(
                                          item.icon,
                                          color: AppColors.deepPink,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (item.badge != null) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.deepPink,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  item.badge!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            Text(
                                              item.product.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (storeProductIncludedLabel(
                                                  subscription,
                                                  item.product,
                                                )
                                                case final includedLabel?) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                includedLabel,
                                                style: const TextStyle(
                                                  color: Color(0xFF168447),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 3),
                                            if (_promotions[item.product.id]
                                                case final promotion?) ...[
                                              Text(
                                                item.price,
                                                style: const TextStyle(
                                                  color: AppColors.grayText,
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                ),
                                              ),
                                              Text(
                                                _promotionPrice(promotion),
                                                style: const TextStyle(
                                                  color: AppColors.deepPink,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Text(
                                                promotion['name'].toString(),
                                                style: const TextStyle(
                                                  color: AppColors.deepPink,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ] else
                                              Text(
                                                item.price,
                                                style: const TextStyle(
                                                  color: AppColors.deepPink,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            if (item.monthlyEquivalent !=
                                                null) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                item.monthlyEquivalent!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 3),
                                            Text(
                                              item.summary,
                                              style: const TextStyle(
                                                color: AppColors.grayText,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        storeProductIncludedLabel(
                                                  subscription,
                                                  item.product,
                                                ) ==
                                                null
                                            ? Icons.chevron_right_rounded
                                            : Icons.check_circle_rounded,
                                        color:
                                            storeProductIncludedLabel(
                                                  subscription,
                                                  item.product,
                                                ) ==
                                                null
                                            ? null
                                            : const Color(0xFF168447),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
              ],
          ],
        );
      },
    );
  }
}

// Kept as a compact reusable grouping for legacy premium layouts.
// ignore: unused_element
class _OneTimePurchaseSection extends StatelessWidget {
  const _OneTimePurchaseSection();

  static const groups =
      <(String, String, IconData, List<ExternalPaymentProduct>)>[
        (
          'Country Pass',
          'Avantages de recherche Plus pendant une durée limitée.',
          Icons.travel_explore_rounded,
          [
            ExternalPaymentProduct.countryPass24h,
            ExternalPaymentProduct.countryPass7d,
          ],
        ),
        (
          'International Pass',
          'Recherche internationale VIP pendant une durée limitée.',
          Icons.public_rounded,
          [
            ExternalPaymentProduct.internationalPass24h,
            ExternalPaymentProduct.internationalPass7d,
          ],
        ),
        (
          'Boost',
          'Mettez temporairement votre profil en avant.',
          Icons.rocket_launch_rounded,
          [
            ExternalPaymentProduct.boost30m,
            ExternalPaymentProduct.boost3h,
            ExternalPaymentProduct.boost24h,
          ],
        ),
        (
          'Super Likes',
          'Crédits disponibles en packs indépendants.',
          Icons.star_rounded,
          [
            ExternalPaymentProduct.superLikes5,
            ExternalPaymentProduct.superLikes15,
            ExternalPaymentProduct.superLikes30,
          ],
        ),
      ];

  Future<void> _buy(
    BuildContext context,
    ExternalPaymentProduct product,
  ) async {
    final launched = await ExternalCheckoutService.instance.startCheckout(
      provider: ExternalPaymentProvider.stripe,
      productId: product.id,
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFD),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF2DCE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achats ponctuels',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sans abonnement. Le prix exact est affiché dans le paiement sécurisé Stripe.',
            style: TextStyle(color: AppColors.grayText),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final group in groups)
                SizedBox(
                  width: 260,
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(group.$3, color: AppColors.deepPink, size: 34),
                          const SizedBox(height: 8),
                          Text(
                            group.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            group.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.grayText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final product in group.$4)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                onPressed: () => _buy(context, product),
                                child: Text(product.label),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VipInvisibleModeControl extends StatefulWidget {
  const _VipInvisibleModeControl();

  @override
  State<_VipInvisibleModeControl> createState() =>
      _VipInvisibleModeControlState();
}

class _VipInvisibleModeControlState extends State<_VipInvisibleModeControl> {
  bool loading = true;
  bool saving = false;
  bool vip = false;
  bool invisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final results = await Future.wait([
      MapLovRepository.instance.subscriptionInfo(),
      MapLovRepository.instance.myProfileDetails(),
    ]);
    if (!mounted) return;
    final subscription = results[0] as SubscriptionInfo;
    final profile = results[1] as Map<String, dynamic>?;
    setState(() {
      vip = subscription.isVip;
      invisible = !(profile?['is_discoverable'] as bool? ?? true);
      loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (saving) return;
    if (!vip) {
      final allowed = await _requireSubscriptionFeature(
        context,
        requirement: _SubscriptionRequirement.vip,
        feature: 'Invisible navigation',
      );
      if (!allowed || !mounted) return;
      setState(() => vip = true);
    }
    final previous = invisible;
    setState(() {
      invisible = value;
      saving = true;
    });
    try {
      await MapLovRepository.instance.setDiscoverable(!value);
    } catch (error) {
      if (mounted) {
        setState(() => invisible = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update invisible navigation: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: const Key('vip_invisible_mode_control'),
      onPressed: loading || saving ? null : () => _toggle(!invisible),
      icon: Icon(invisible ? Icons.visibility_off : Icons.visibility_outlined),
      label: const Text('Invisible navigation in Discover'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    ),
  );
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
