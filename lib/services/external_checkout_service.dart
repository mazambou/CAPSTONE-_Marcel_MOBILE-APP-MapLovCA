import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../config/supabase_config.dart';
import 'purchase_service.dart';

enum ExternalPaymentProvider {
  stripe('stripe', 'Carte bancaire (Stripe)'),
  paypal('paypal', 'PayPal'),
  flutterwave('flutterwave', 'Flutterwave');

  const ExternalPaymentProvider(this.apiName, this.label);

  final String apiName;
  final String label;
}

enum ExternalPaymentProduct {
  plusMonthly('maplov_plus_monthly', 'MapLov Plus mensuel', true),
  plusYearly('maplov_plus_yearly', 'MapLov Plus annuel', true),
  vipMonthly('maplov_vip_monthly', 'MapLov VIP mensuel', true),
  vipYearly('maplov_vip_yearly', 'MapLov VIP annuel', true),
  countryPass24h('maplov_country_pass_24h', 'Country Pass 24 h', false),
  countryPass7d('maplov_country_pass_7d', 'Country Pass 7 jours', false),
  internationalPass24h(
    'maplov_international_pass_24h',
    'International Pass 24 h',
    false,
  ),
  internationalPass7d(
    'maplov_international_pass_7d',
    'International Pass 7 jours',
    false,
  ),
  boost30m('maplov_boost_30m', 'Boost 30 min', false),
  boost3h('maplov_boost_3h', 'Boost 3 h', false),
  boost24h('maplov_boost_24h', 'Boost 24 h', false),
  superLikes5('maplov_super_likes_5', '5 Super Likes', false),
  superLikes15('maplov_super_likes_15', '15 Super Likes', false),
  superLikes30('maplov_super_likes_30', '30 Super Likes', false);

  const ExternalPaymentProduct(this.id, this.label, this.isSubscription);

  final String id;
  final String label;
  final bool isSubscription;

  bool supports(ExternalPaymentProvider provider) =>
      provider == ExternalPaymentProvider.stripe ||
      (isSubscription && !id.endsWith('_yearly'));

  static ExternalPaymentProduct? fromId(String productId) {
    final normalized = productId == PremiumProductIds.eliteMonthly
        ? PremiumProductIds.vipMonthly
        : productId;
    for (final product in values) {
      if (product.id == normalized) return product;
    }
    return null;
  }
}

class ExternalCheckoutStatus {
  const ExternalCheckoutStatus({
    required this.status,
    required this.billingMode,
    required this.productId,
  });

  final String status;
  final String billingMode;
  final String productId;

  bool get completed => status == 'completed';
  bool get failed => const {'cancelled', 'failed', 'expired'}.contains(status);
}

class ExternalCheckoutService extends ChangeNotifier {
  ExternalCheckoutService._();

  static final instance = ExternalCheckoutService._();

  bool loading = false;
  String? error;

  bool get available => AppConfig.externalCheckoutEnabled;

  static String? tierForProduct(String productId) => switch (productId) {
    PremiumProductIds.plusMonthly || 'maplov_plus_yearly' => 'plus',
    PremiumProductIds.eliteMonthly ||
    PremiumProductIds.vipMonthly ||
    'maplov_vip_yearly' => 'vip',
    _ => null,
  };

  static bool isTrustedCheckoutUrl(Uri uri, ExternalPaymentProvider provider) {
    if (uri.scheme != 'https') return false;
    final domain = switch (provider) {
      ExternalPaymentProvider.stripe => 'stripe.com',
      ExternalPaymentProvider.paypal => 'paypal.com',
      ExternalPaymentProvider.flutterwave => 'flutterwave.com',
    };
    return uri.host == domain || uri.host.endsWith('.$domain');
  }

  Future<bool> startCheckout({
    required ExternalPaymentProvider provider,
    required String productId,
  }) async {
    if (!available || !kIsWeb) {
      error = 'Le paiement web externe n’est pas disponible sur cet appareil.';
      notifyListeners();
      return false;
    }
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null) {
      error = 'Connectez-vous avant de choisir un abonnement.';
      notifyListeners();
      return false;
    }
    final product = ExternalPaymentProduct.fromId(productId);
    if (product == null) {
      error = 'Ce produit MapLov n’est pas reconnu.';
      notifyListeners();
      return false;
    }
    if (!product.supports(provider)) {
      error = 'Ce produit est disponible avec Stripe uniquement.';
      notifyListeners();
      return false;
    }

    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await client!.functions.invoke(
        'create-external-checkout',
        body: {'provider': provider.apiName, 'productId': product.id},
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError(
          'Le service de paiement a répondu avec le code ${response.status}.',
        );
      }
      final data = response.data;
      final value = data is Map ? data['checkoutUrl'] : null;
      final uri = Uri.tryParse(value?.toString() ?? '');
      if (uri == null || !isTrustedCheckoutUrl(uri, provider)) {
        throw StateError('Le lien de paiement reçu n’est pas fiable.');
      }
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!opened) {
        throw StateError('Impossible d’ouvrir la page de paiement.');
      }
      return true;
    } catch (exception) {
      error = exception is StateError
          ? exception.message
          : 'Impossible de préparer le paiement sécurisé.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<ExternalCheckoutStatus?> checkoutStatus(String reference) async {
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null || reference.isEmpty) return null;
    final data = await client!
        .from('external_checkout_sessions')
        .select('status, billing_mode, product_id')
        .eq('checkout_reference', reference)
        .maybeSingle();
    if (data == null) return null;
    return ExternalCheckoutStatus(
      status: data['status']?.toString() ?? 'pending',
      billingMode: data['billing_mode']?.toString() ?? 'subscription',
      productId: data['product_id']?.toString() ?? '',
    );
  }

  Future<void> markCheckoutCancelled(String reference) async {
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null || reference.length < 16) return;
    await client!.rpc(
      'cancel_own_external_checkout',
      params: {'checkout_reference_value': reference},
    );
  }

  Future<bool> openSubscriptionManagement(
    ExternalPaymentProvider provider,
  ) async {
    final uri = await _managementRequest(
      action: 'portal',
      provider: provider,
      expectsUrl: true,
    );
    if (uri == null) return false;
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );
    if (!opened) {
      error = 'Impossible d’ouvrir la gestion de l’abonnement.';
      notifyListeners();
    }
    return opened;
  }

  Future<bool> cancelFlutterwaveSubscription() async {
    final result = await _managementRequest(
      action: 'cancel',
      provider: ExternalPaymentProvider.flutterwave,
      expectsUrl: false,
    );
    return result != null;
  }

  Future<Uri?> _managementRequest({
    required String action,
    required ExternalPaymentProvider provider,
    required bool expectsUrl,
  }) async {
    if (!available || SupabaseConfig.client?.auth.currentUser == null) {
      error = 'La gestion du paiement web n’est pas disponible.';
      notifyListeners();
      return null;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await SupabaseConfig.client!.functions.invoke(
        'manage-external-subscription',
        body: {'action': action},
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError(
          'Le service de facturation a répondu avec le code ${response.status}.',
        );
      }
      if (!expectsUrl) return Uri.parse('maplov://billing-updated');
      final data = response.data;
      final value = data is Map ? data['portalUrl'] : null;
      final uri = Uri.tryParse(value?.toString() ?? '');
      if (uri == null || !isTrustedCheckoutUrl(uri, provider)) {
        throw StateError('Le lien de gestion reçu n’est pas fiable.');
      }
      return uri;
    } catch (exception) {
      error = exception is StateError
          ? exception.message.toString()
          : 'Impossible de gérer cet abonnement.';
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
