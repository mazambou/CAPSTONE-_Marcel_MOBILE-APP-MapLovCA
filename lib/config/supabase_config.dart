import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'env.dart';

abstract final class SupabaseConfig {
  static bool get isConfigured => AppConfig.hasSupabaseConfiguration;

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
