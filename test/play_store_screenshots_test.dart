import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';

void main() {
  SupabaseConfig.forceUiOnlyForTesting = true;

  Future<void> capture(
    WidgetTester tester,
    Widget screen,
    String fileName,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF4D6D)),
        ),
        home: RepaintBoundary(
          key: const Key('play_store_capture'),
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('play_store_capture')),
      matchesGoldenFile('../docs/play_store/screenshots/$fileName'),
    );
  }

  testWidgets('Play Store Discover screenshot', (tester) async {
    await capture(tester, const HomeScreen(), '01_discover.png');
  });

  testWidgets('Play Store Likes screenshot', (tester) async {
    await capture(tester, const LikesScreen(), '02_likes.png');
  });

  testWidgets('Play Store Matches screenshot', (tester) async {
    await capture(tester, const MatchScreen(), '03_matches.png');
  });

  testWidgets('Play Store Messages screenshot', (tester) async {
    await capture(tester, const MessagesScreen(), '04_messages.png');
  });

  testWidgets('Play Store Profile screenshot', (tester) async {
    await capture(tester, const ProfileScreen(), '05_profile.png');
  });
}
