import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, runApp;

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
export 'app.dart' show MapLoveApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await AuthService.instance.enforceSessionPreference();
  runApp(const MapLoveApp());
}
