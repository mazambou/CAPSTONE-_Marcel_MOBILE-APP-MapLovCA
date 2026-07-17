import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.forceUiOnlyForTesting = true;

  testWidgets('MVP account to discovery smoke flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/home': (_) => const HomeScreen()},
        home: const LoginScreen(),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'qa@maplov.ca');
    await tester.enterText(find.byType(TextField).at(1), 'StrongPass!42');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Likes'), findsWidgets);
    expect(find.text('Matches'), findsWidgets);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });
}
