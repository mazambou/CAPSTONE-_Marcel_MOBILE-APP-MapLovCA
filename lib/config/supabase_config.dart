import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'env.dart';

abstract final class SupabaseConfig {
  /// Keeps widget tests deterministic while development and release builds
  /// connect to the configured MapLov project by default.
  static bool forceUiOnlyForTesting = false;

  static bool get isConfigured =>
      !forceUiOnlyForTesting && AppConfig.hasSupabaseConfiguration;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  /// Returns null in local UI-only mode when no dart-defines were supplied.
  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;
}
