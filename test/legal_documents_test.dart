import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/app.dart';

void main() {
  testWidgets('legal hub exposes the MapLov-specific production documents', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Cookie & Similar Technologies Policy'), findsOneWidget);
    expect(find.text('Face Verification Notice'), findsOneWidget);

    await tester.tap(find.text('Terms of Use'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Effective date: July 30, 2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('These Terms govern access to the MapLov'),
      findsOneWidget,
    );
  });

  test('legal drafts do not include Tinder branding', () {
    final source = File(
      'lib/pages/settings/legal_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Tinder')));
    expect(source, contains("'Terms of Use'"));
    expect(source, contains("'Privacy Policy'"));
    expect(source, contains("'Face Verification Notice'"));
    expect(source, contains('do not impose mandatory private arbitration'));
  });
}
