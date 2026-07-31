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
  });
}
