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
}
