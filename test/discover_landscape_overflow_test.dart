import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';

void main() {
  SupabaseConfig.forceUiOnlyForTesting = true;
  testWidgets('Discover remains scrollable in landscape with popular photos', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 440);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.byKey(const Key('popular_photos_strip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
