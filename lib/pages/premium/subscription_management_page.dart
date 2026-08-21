part of '../../app.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends State<SubscriptionManagementScreen> {
  late Future<SubscriptionInfo> subscription;
  late Future<List<Map<String, dynamic>>> purchases;
  late Future<List<Map<String, dynamic>>> entitlements;
  late Future<int> superLikes;

  @override
  void initState() {
    super.initState();
    _reload();
    PurchaseService.instance.addListener(_purchaseUpdated);
  }

  String? _lastVerifiedPurchase;

  void _reload() {
    subscription = MapLovRepository.instance.subscriptionInfo();
    purchases = MapLovRepository.instance.oneTimePurchases();
    entitlements = MapLovRepository.instance.activePaymentEntitlements();
    superLikes = MapLovRepository.instance.superLikesBalance();
  }

  void _purchaseUpdated() {
    final verified = PurchaseService.instance.lastVerifiedProductId;
    if (!mounted || verified == null || verified == _lastVerifiedPurchase) {
      return;
    }
    _lastVerifiedPurchase = verified;
    setState(_reload);
  }

  ExternalPaymentProvider? _externalProvider(String? value) {
    for (final provider in ExternalPaymentProvider.values) {
      if (provider.apiName == value) return provider;
    }
    return null;
  }

  Future<void> _manageExternalSubscription(
    ExternalPaymentProvider provider,
  ) async {
    if (!AppConfig.externalCheckoutEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gérez cet abonnement sur la version Web sécurisée de MapLov.',
          ),
        ),
      );
      return;
    }

    if (provider == ExternalPaymentProvider.flutterwave) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Annuler le renouvellement ?'),
          content: const Text(
            'Flutterwave ne prélèvera plus les prochains mois. Vos avantages '
            'restent actifs jusqu’à la fin de la période déjà payée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Conserver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmer l’annulation'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final cancelled = await ExternalCheckoutService.instance
          .cancelFlutterwaveSubscription();
      if (!mounted) return;
      if (cancelled) {
        setState(_reload);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Renouvellement annulé.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ExternalCheckoutService.instance.error ??
                  'Impossible d’annuler le renouvellement.',
            ),
          ),
        );
      }
      return;
    }

    final opened = await ExternalCheckoutService.instance
        .openSubscriptionManagement(provider);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ExternalCheckoutService.instance.error ??
                'Impossible d’ouvrir la gestion de l’abonnement.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    PurchaseService.instance.removeListener(_purchaseUpdated);
    super.dispose();
  }

  String _remaining(dynamic value) {
    final end = DateTime.tryParse(value?.toString() ?? '');
    if (end == null) return 'Échéance indisponible';
    final duration = end.difference(DateTime.now());
    if (duration.isNegative) return 'Expiré';
    if (duration.inDays > 0) {
      return 'Encore ${duration.inDays} jour${duration.inDays == 1 ? '' : 's'}';
    }
    if (duration.inHours > 0) {
      return 'Encore ${duration.inHours} h ${duration.inMinutes.remainder(60)} min';
    }
    return 'Encore ${duration.inMinutes.clamp(0, 59)} min';
  }

  Future<void> _manageCurrent(SubscriptionInfo info) async {
    final provider = _externalProvider(info.provider);
    if (provider != null) {
      await _manageExternalSubscription(provider);
      return;
    }
    await PurchaseService.instance.openSubscriptionManagement();
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Mon abonnement et mes achats',
    children: [
      FutureBuilder<SubscriptionInfo>(
        future: subscription,
        builder: (context, snapshot) {
          final info = snapshot.data ?? const SubscriptionInfo();
          return Card(
            color: AppColors.palePink,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mon abonnement',
                    style: TextStyle(color: AppColors.grayText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.isPromotionalVip
                        ? 'MapLov VIP fondateur offert'
                        : 'MapLov ${info.displayName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    info.isPromotionalVip
                        ? '${info.promotionMemberCount}/${info.promotionThreshold} membres. '
                              'Votre forfait ${info.baseDisplayName} reprendra au 1 001ᵉ compte.'
                        : info.renewsAt == null
                        ? 'Aucune date d’échéance'
                        : info.autoRenewEnabled
                        ? 'Renouvellement le ${DateFormat.yMMMd().format(info.renewsAt!)}'
                        : 'Expire le ${DateFormat.yMMMd().format(info.renewsAt!)}',
                  ),
                  if (!info.isPromotionalVip || info.hasPaidSubscription) ...[
                    Text('Paiement : ${info.provider ?? 'Boutique mobile'}'),
                    Text(
                      'Renouvellement : ${info.autoRenewEnabled ? 'Activé' : 'Désactivé'}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: info.hasPaidSubscription
                        ? () => _manageCurrent(info)
                        : null,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Gérer'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const _SectionTitle('Mes achats'),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: entitlements,
        builder: (context, snapshot) {
          final active = snapshot.data ?? const [];
          return Column(
            children: [
              for (final item in active)
                Card(
                  child: ListTile(
                    leading: Icon(
                      item['entitlement_kind'] == 'boost'
                          ? Icons.rocket_launch_rounded
                          : Icons.public_rounded,
                      color: AppColors.coral,
                    ),
                    title: Text(
                      ExternalPaymentProduct.fromId(
                            item['product_id']?.toString() ?? '',
                          )?.label ??
                          'Achat MapLov',
                    ),
                    subtitle: Text(
                      '${item['entitlement_kind'] == 'boost' ? 'Actif • ' : ''}'
                      '${_remaining(item['expires_at'])}\n'
                      'Expire le ${_purchaseDate(item['expires_at'])}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              FutureBuilder<int>(
                future: superLikes,
                builder: (context, balanceSnapshot) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.coral,
                    ),
                    title: const Text('Super Likes'),
                    subtitle: Text(
                      '${balanceSnapshot.data ?? 0} restant${(balanceSnapshot.data ?? 0) == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              ),
              if (active.isEmpty &&
                  snapshot.connectionState == ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucun Pass ou Boost actif.',
                    style: TextStyle(color: AppColors.grayText),
                  ),
                ),
            ],
          );
        },
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: purchases,
        builder: (context, snapshot) {
          final history = snapshot.data ?? const [];
          if (history.isEmpty) return const SizedBox.shrink();
          return ExpansionTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Historique des achats ponctuels'),
            children: [
              for (final item in history)
                ListTile(
                  title: Text(
                    ExternalPaymentProduct.fromId(
                          item['product_id']?.toString() ?? '',
                        )?.label ??
                        'Achat MapLov',
                  ),
                  subtitle: Text(_purchaseDate(item['created_at'])),
                ),
            ],
          );
        },
      ),
      const _SectionTitle('Actions'),
      ListTile(
        leading: const Icon(Icons.upgrade, color: AppColors.coral),
        title: const Text('Découvrir les offres Premium'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.premium),
      ),
      FutureBuilder<SubscriptionInfo>(
        future: subscription,
        builder: (context, snapshot) {
          final provider = _externalProvider(snapshot.data?.provider);
          return ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: const Text('Cancel automatic renewal'),
            subtitle: Text(
              provider == null
                  ? 'Open your store subscription settings. Benefits remain active until the paid period ends.'
                  : 'Manage this subscription with ${provider.label}. Benefits remain active until the paid period ends.',
            ),
            onTap: provider == null
                ? () async {
                    final opened = await PurchaseService.instance
                        .openSubscriptionManagement();
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to open the store subscription settings.',
                          ),
                        ),
                      );
                    }
                  }
                : () => _manageExternalSubscription(provider),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const Text('Restore purchases'),
        subtitle: const Text(
          'Restore a subscription purchased on this store account.',
        ),
        onTap: () async {
          await PurchaseService.instance.restore();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Restore request sent to the store.'),
              ),
            );
          }
        },
      ),
      FutureBuilder<SubscriptionInfo>(
        future: subscription,
        builder: (context, snapshot) {
          final history = snapshot.data?.history ?? const [];
          return ExpansionTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Billing history'),
            children: history.isEmpty
                ? const [ListTile(title: Text('No payment transactions yet.'))]
                : history
                      .map(
                        (item) => ListTile(
                          title: Text(
                            '${item['tier']} • ${item['event_type']} • ${item['status']}',
                          ),
                          subtitle: Text(
                            '${item['provider']} • '
                                    '${item['created_at'] ?? ''}'
                                .split('T')
                                .first,
                          ),
                        ),
                      )
                      .toList(),
          );
        },
      ),
    ],
  );

  String _purchaseDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? '—' : DateFormat.yMMMd().add_Hm().format(parsed);
  }
}
