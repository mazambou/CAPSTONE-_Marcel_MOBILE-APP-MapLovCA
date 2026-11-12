import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/config/auth_link_config.dart';

void main() {
  group('AuthLinkConfig', () {
    test('uses the exact production callback', () {
      expect(AuthLinkConfig.siteUrl, 'https://maplov.ca');
      expect(AuthLinkConfig.callbackUrl, 'https://maplov.ca/auth/callback');
    });

    test('accepts only the production callback and compatibility scheme', () {
      expect(
        AuthLinkConfig.isCallback(
          Uri.parse('https://maplov.ca/auth/callback?code=pkce-code'),
        ),
        isTrue,
      );
      expect(
        AuthLinkConfig.isCallback(
          Uri.parse('io.maplov.app://auth-callback?code=pkce-code'),
        ),
        isTrue,
      );
      expect(
        AuthLinkConfig.isCallback(
          Uri.parse('https://maplov.ca/unrelated?code=pkce-code'),
        ),
        isFalse,
      );
      expect(
        AuthLinkConfig.isCallback(
          Uri.parse('https://attacker.example/auth/callback?code=pkce-code'),
        ),
        isFalse,
      );
    });
  });

  test('requires email confirmation for every Supabase email signup', () {
    final config = File('supabase/config.toml').readAsStringSync();
    final emailSectionStart = config.indexOf('[auth.email]');
    expect(emailSectionStart, isNonNegative);

    final nextSectionStart = config.indexOf('\n[', emailSectionStart + 1);
    final emailSection = config.substring(
      emailSectionStart,
      nextSectionStart == -1 ? config.length : nextSectionStart,
    );

    expect(emailSection, contains('enable_signup = true'));
    expect(emailSection, contains('enable_confirmations = true'));
    expect(emailSection, isNot(contains('enable_confirmations = false')));
    expect(emailSection, contains('otp_length = 8'));
  });

  test('signup confirmation email contains a code instead of a link', () {
    final template = File(
      'supabase/templates/confirmation.html',
    ).readAsStringSync();

    expect(template, contains('{{ .Token }}'));
    expect(template, isNot(contains('{{ .ConfirmationURL }}')));
  });

  test(
    'Cloudflare Pages keeps static documents ahead of the auth callback',
    () {
      final redirects = File('web/_redirects')
          .readAsLinesSync()
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList(growable: false);
      final callbackIndex = redirects.indexWhere(
        (line) => line.startsWith('/auth/callback '),
      );

      expect(callbackIndex, isNonNegative);
      for (final route in const [
        '/privacy',
        '/privacy/',
        '/account-deletion',
        '/account-deletion/',
        '/child-safety',
        '/child-safety/',
        '/terms',
        '/terms/',
      ]) {
        final routeIndex = redirects.indexWhere(
          (line) => line.startsWith('$route '),
        );
        expect(
          routeIndex,
          isNonNegative,
          reason: 'Missing static route $route',
        );
        expect(
          routeIndex,
          lessThan(callbackIndex),
          reason: '$route must be resolved before the auth callback rewrite',
        );
      }
      expect(
        redirects.any((line) => line.startsWith('/* ')),
        isFalse,
        reason: 'A catch-all rewrite would intercept /.well-known/ assets',
      );
      expect(
        File('web/404.html').existsSync(),
        isFalse,
        reason:
            'Cloudflare Pages needs its default SPA fallback for other routes',
      );
    },
  );

  test('public compliance documents are standalone static pages', () {
    for (final path in const [
      'web/privacy/index.html',
      'web/account-deletion/index.html',
      'web/child-safety/index.html',
      'web/terms/index.html',
    ]) {
      final document = File(path).readAsStringSync();
      expect(document, contains('<!doctype html>'), reason: path);
      expect(document, contains('MapLov'), reason: path);
      expect(document, isNot(contains('flutter_bootstrap.js')), reason: path);
    }
  });
}
