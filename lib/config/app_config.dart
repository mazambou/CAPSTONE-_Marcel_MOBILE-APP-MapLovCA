import 'env.dart';

abstract final class AppConfig {
  static const appName = 'MapLov';

  static bool get hasSupabaseConfiguration =>
      Env.supabaseUrl.trim().isNotEmpty &&
      Env.supabasePublishableKey.trim().isNotEmpty;
}
