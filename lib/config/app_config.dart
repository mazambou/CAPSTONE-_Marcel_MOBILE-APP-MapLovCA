import 'package:flutter/foundation.dart';

import 'env.dart';

abstract final class AppConfig {
  static const appName = 'MapLov';

  static bool get hasSupabaseConfiguration =>
      Env.supabaseUrl.trim().isNotEmpty &&
      Env.supabasePublishableKey.trim().isNotEmpty;

  /// Test-only shortcuts are never exposed by a release build.
  static bool get allowTestingBypass =>
      !kReleaseMode && (Env.allowTestingBypass || kDebugMode);

  /// Demo data is useful for widget tests and local UI reviews only.
  static bool get allowDemoData => !kReleaseMode;

  /// External providers are available from Flutter Web only. Apple and Google
  /// purchases continue through their native store billing systems.
  ///
  /// The server keeps its own checkout feature switch. The Flutter client must
  /// use [kIsWeb] as its platform source of truth so a browser reporting an
  /// Android or iOS target platform still follows the hosted checkout flow.
  static bool get externalCheckoutEnabled => kIsWeb;
}
