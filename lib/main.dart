import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, runApp;

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/locale_service.dart';
export 'app.dart' show MapLoveApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleService.instance.load();
  await SupabaseConfig.initialize();
  await AuthService.instance.enforceSessionPreference();
  runApp(const MapLoveApp());
}
