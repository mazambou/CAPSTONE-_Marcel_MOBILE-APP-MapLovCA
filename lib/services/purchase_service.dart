import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/supabase_config.dart';

class PremiumProductIds {
  const PremiumProductIds._();
  static const plusMonthly = 'maplov_plus_monthly';
  static const eliteMonthly = 'maplov_elite_monthly';
  static const vipMonthly = 'maplov_vip_monthly';
  // The former Elite store product now activates the public VIP plan.
  // The legacy VIP identifier remains accepted by the verifier for restores.
  static const all = {plusMonthly, eliteMonthly};
}

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final instance = PurchaseService._();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> products = const [];
  bool storeAvailable = false;
  bool loading = false;
  String? error;
  String? lastVerifiedProductId;

  Future<void> initialize() async {
    if (_subscription != null) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchases,
      onError: (Object value) {
        error = value.toString();
        notifyListeners();
      },
    );
    loading = true;
    notifyListeners();
    storeAvailable = await InAppPurchase.instance.isAvailable();
    if (storeAvailable) {
      final response = await InAppPurchase.instance.queryProductDetails(
        PremiumProductIds.all,
      );
      products = response.productDetails;
      error = response.error?.message;
      if (response.notFoundIDs.isNotEmpty) {
        error ??=
            'Store products are not configured: ${response.notFoundIDs.join(', ')}';
      }
    }
    loading = false;
    notifyListeners();
  }

  ProductDetails? product(String id) =>
      products.where((item) => item.id == id).firstOrNull;

  Future<bool> buy(String productId) async {
    final selected = product(productId);
    if (selected == null) {
      error = 'This subscription is not available in the store yet.';
      notifyListeners();
      return false;
    }
    return InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: selected),
    );
  }

  Future<void> restore() => InAppPurchase.instance.restorePurchases();

  Future<void> _handlePurchases(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.error) {
        error = purchase.error?.message ?? 'Purchase failed.';
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          await _verifyOnServer(purchase);
          lastVerifiedProductId = purchase.productID;
          error = null;
        } catch (exception) {
          error = 'The store purchase could not be verified: $exception';
        }
      }
      if (purchase.pendingCompletePurchase && error == null) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  Future<void> _verifyOnServer(PurchaseDetails purchase) async {
    final client = SupabaseConfig.client;
    if (client?.auth.currentUser == null) {
      throw StateError('Sign in and configure Supabase before purchasing.');
    }
    final response = await client!.functions.invoke(
      'verify-store-purchase',
      body: {
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'source': purchase.verificationData.source,
        'serverVerificationData':
            purchase.verificationData.serverVerificationData,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Verification service returned ${response.status}.');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
