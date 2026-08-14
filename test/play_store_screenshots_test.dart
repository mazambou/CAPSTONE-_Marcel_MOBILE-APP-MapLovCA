import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';

class _CrossPlatformGoldenComparator extends LocalFileComparator {
  _CrossPlatformGoldenComparator(super.testFile);

  static const double _renderingTolerance = 0.02;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _renderingTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void main() {
  SupabaseConfig.forceUiOnlyForTesting = true;
  goldenFileComparator = _CrossPlatformGoldenComparator(
    Uri.file('${Directory.current.path}/test/play_store_screenshots_test.dart'),
  );

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
