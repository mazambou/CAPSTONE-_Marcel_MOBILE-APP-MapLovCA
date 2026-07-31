import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, runApp;
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/locale_service.dart';
export 'app.dart' show MapLoveApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleService.instance.load();
  await SupabaseConfig.initialize();
  await AuthService.instance.initialize();
  await AuthService.instance.enforceSessionPreference();
  // Clean HTTPS paths allow maplov.ca/auth/callback to be both a web route
  // and the verified native-link target, without a hash fragment.
  usePathUrlStrategy();
  runApp(const MapLoveApp());
}
