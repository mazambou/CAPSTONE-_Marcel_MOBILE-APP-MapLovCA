part of '../../app.dart';

class ExternalCheckoutReturnScreen extends StatefulWidget {
  const ExternalCheckoutReturnScreen({super.key});

  @override
  State<ExternalCheckoutReturnScreen> createState() =>
      _ExternalCheckoutReturnScreenState();
}

class _ExternalCheckoutReturnScreenState
    extends State<ExternalCheckoutReturnScreen> {
  bool waiting = true;
  bool cancelled = false;
  bool failed = false;
  SubscriptionInfo? subscription;
  ExternalCheckoutStatus? checkout;

  @override
  void initState() {
    super.initState();
    final query = Uri.base.queryParameters;
    final providerStatus = query['status']?.toLowerCase();
    failed = providerStatus == 'failed';
    cancelled = query['cancelled'] == 'true' || providerStatus == 'cancelled';
    if (cancelled || failed) {
      waiting = false;
      if (cancelled) {
        final reference = query['reference'] ?? '';
        unawaited(
          ExternalCheckoutService.instance.markCheckoutCancelled(reference),
        );
      }
    } else {
      unawaited(_waitForVerification());
    }
  }

  Future<void> _waitForVerification() async {
    final reference = Uri.base.queryParameters['reference'] ?? '';
    for (var attempt = 0; attempt < 12; attempt += 1) {
      try {
        if (reference.isNotEmpty) {
          final currentCheckout = await ExternalCheckoutService.instance
              .checkoutStatus(reference);
          if (currentCheckout?.failed == true) {
            if (!mounted) return;
            setState(() {
              checkout = currentCheckout;
              failed = currentCheckout?.status != 'cancelled';
              cancelled = currentCheckout?.status == 'cancelled';
              waiting = false;
            });
            return;
          }
          if (currentCheckout?.completed == true &&
              currentCheckout?.billingMode == 'payment') {
            if (!mounted) return;
            setState(() {
              checkout = currentCheckout;
              waiting = false;
            });
            return;
          }
        }
        final current = await MapLovRepository.instance.subscriptionInfo();
        if (current.isPremium &&
            (current.status == 'active' || current.status == 'cancelled')) {
          if (!mounted) return;
          setState(() {
            subscription = current;
            waiting = false;
          });
          return;
        }
      } catch (_) {
        // Webhook delivery can briefly race the browser redirect.
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (mounted) setState(() => waiting = false);
  }

  @override
  Widget build(BuildContext context) {
    final purchaseVerified =
        checkout?.completed == true && checkout?.billingMode == 'payment';
    final subscriptionVerified = subscription?.isPremium == true;
    final verified = purchaseVerified || subscriptionVerified;
    final product = ExternalPaymentProduct.fromId(checkout?.productId ?? '');
    return _AppPage(
      title: 'Paiement',
      children: [
        Icon(
          cancelled || failed
              ? Icons.info_outline_rounded
              : verified
              ? purchaseVerified
                    ? Icons.check_circle_rounded
                    : Icons.workspace_premium_rounded
              : waiting
              ? Icons.verified_user_outlined
              : Icons.schedule_rounded,
          size: 92,
          color: verified ? AppColors.coral : AppColors.deepPink,
        ),
        const SizedBox(height: 18),
        Text(
          failed
              ? 'Paiement refusé ou expiré'
              : cancelled
              ? 'Paiement annulé'
              : verified
              ? purchaseVerified
                    ? 'Achat confirmé'
                    : 'Abonnement confirmé'
              : waiting
              ? 'Confirmation sécurisée en cours…'
              : 'Confirmation encore en attente',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          failed
              ? 'Stripe n’a confirmé aucun débit. Vous pouvez réessayer depuis la Boutique MapLov.'
              : cancelled
              ? 'Aucun achat n’a été activé et aucune fonctionnalité n’a été débloquée.'
              : verified
              ? purchaseVerified
                    ? '${product?.label ?? 'Votre achat MapLov'} est maintenant disponible sur votre compte.'
                    : 'MapLov ${subscription!.displayName} est maintenant actif sur votre compte.'
              : waiting
              ? 'Le prestataire confirme la transaction à MapLov. Cette étape peut prendre quelques secondes.'
              : 'Le paiement n’est pas encore confirmé. Ne recommencez pas le paiement : consultez plutôt votre abonnement dans quelques instants.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grayText),
        ),
        if (waiting) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 28),
        _PrimaryButton(
          verified ? 'Commencer' : 'Voir mon abonnement',
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            verified ? AppRoutes.home : AppRoutes.subscriptionManagement,
            (_) => false,
          ),
        ),
      ],
    );
  }
}
