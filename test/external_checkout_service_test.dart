import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/config/app_config.dart';
import 'package:maplove/services/external_checkout_service.dart';
import 'package:maplove/services/purchase_service.dart';

void main() {
  group('external checkout safety', () {
    test('external checkout follows the Flutter Web compile target', () {
      expect(AppConfig.externalCheckoutEnabled, kIsWeb);
      expect(ExternalCheckoutService.instance.available, kIsWeb);
    });

    test('Android and iOS reports do not decide web checkout', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(AppConfig.externalCheckoutEnabled, kIsWeb);
        expect(ExternalCheckoutService.instance.available, kIsWeb);
      }
    });

    test('store product identifiers map to server-controlled tiers', () {
      expect(
        ExternalCheckoutService.tierForProduct(PremiumProductIds.plusMonthly),
        'plus',
      );
      expect(
        ExternalCheckoutService.tierForProduct(PremiumProductIds.eliteMonthly),
        'vip',
      );
      expect(
        ExternalCheckoutService.tierForProduct(PremiumProductIds.vipMonthly),
        'vip',
      );
      expect(
        ExternalCheckoutService.tierForProduct('maplov_plus_yearly'),
        'plus',
      );
      expect(
        ExternalCheckoutService.tierForProduct('maplov_vip_yearly'),
        'vip',
      );
      expect(ExternalCheckoutService.tierForProduct('unknown_product'), isNull);
    });

    test('Stripe owns annual and one-time products', () {
      expect(
        ExternalPaymentProduct.plusYearly.supports(
          ExternalPaymentProvider.stripe,
        ),
        isTrue,
      );
      expect(
        ExternalPaymentProduct.plusYearly.supports(
          ExternalPaymentProvider.paypal,
        ),
        isFalse,
      );
      expect(
        ExternalPaymentProduct.countryPass24h.supports(
          ExternalPaymentProvider.stripe,
        ),
        isTrue,
      );
      expect(
        ExternalPaymentProduct.countryPass24h.supports(
          ExternalPaymentProvider.flutterwave,
        ),
        isFalse,
      );
      expect(ExternalPaymentProduct.values, hasLength(14));
    });

    test('only HTTPS provider domains are accepted', () {
      expect(
        ExternalCheckoutService.isTrustedCheckoutUrl(
          Uri.parse('https://checkout.stripe.com/c/pay/cs_test'),
          ExternalPaymentProvider.stripe,
        ),
        isTrue,
      );
      expect(
        ExternalCheckoutService.isTrustedCheckoutUrl(
          Uri.parse('https://www.sandbox.paypal.com/checkoutnow'),
          ExternalPaymentProvider.paypal,
        ),
        isTrue,
      );
      expect(
        ExternalCheckoutService.isTrustedCheckoutUrl(
          Uri.parse('https://checkout.flutterwave.com/v3/hosted/pay/test'),
          ExternalPaymentProvider.flutterwave,
        ),
        isTrue,
      );
      expect(
        ExternalCheckoutService.isTrustedCheckoutUrl(
          Uri.parse('https://paypal.com.example.test/checkout'),
          ExternalPaymentProvider.paypal,
        ),
        isFalse,
      );
      expect(
        ExternalCheckoutService.isTrustedCheckoutUrl(
          Uri.parse('http://checkout.stripe.com/insecure'),
          ExternalPaymentProvider.stripe,
        ),
        isFalse,
      );
    });
  });
}
