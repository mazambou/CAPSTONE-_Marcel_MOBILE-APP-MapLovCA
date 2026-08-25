import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/pages/onboarding/onboarding_page.dart';

Widget _testApp() {
  return MaterialApp(
    routes: {'/login': (_) => const Scaffold(body: Text('Login destination'))},
    home: const OnboardingScreen(),
  );
}

void main() {
  testWidgets('onboarding presents all four pages and reaches login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    expect(find.byKey(const Key('onboarding_screen')), findsOneWidget);
    expect(find.text('Find Love Near You'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Smart Matching'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Chat & Connect'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Safe & Verified Community'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next_button')));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip opens the last page and previous remains available', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const Key('onboarding_skip_button')));
    await tester.pumpAndSettle();
    expect(find.text('Safe & Verified Community'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_previous_button')));
    await tester.pumpAndSettle();
    expect(find.text('Chat & Connect'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding adapts to a desktop web viewport', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    expect(find.text('Find Love Near You'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_next_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
