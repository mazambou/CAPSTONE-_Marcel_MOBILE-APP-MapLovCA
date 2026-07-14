import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

enum MapLovAuthEvent {
  signedIn,
  signedOut,
  passwordRecovery,
  userUpdated,
  other,
}

class SignUpResult {
  const SignUpResult({required this.requiresEmailConfirmation});

  final bool requiresEmailConfirmation;
}

class AuthService {
  AuthService._();

  static final instance = AuthService._();
  static const authRedirectUrl = 'io.maplov.app://auth-callback';
  static const _rememberSessionKey = 'maplov_remember_session';

  SupabaseClient? get _client => SupabaseConfig.client;
  bool get isConfigured => SupabaseConfig.isConfigured;
  bool get hasActiveSession => _client?.auth.currentSession != null;
  String? get currentEmail => _client?.auth.currentUser?.email;
  bool get isEmailVerified =>
      !isConfigured || _client?.auth.currentUser?.emailConfirmedAt != null;

  Stream<MapLovAuthEvent> get events {
    final client = _client;
    if (client == null) return const Stream<MapLovAuthEvent>.empty();
    return client.auth.onAuthStateChange.map((state) {
      return switch (state.event) {
        AuthChangeEvent.signedIn => MapLovAuthEvent.signedIn,
        AuthChangeEvent.signedOut => MapLovAuthEvent.signedOut,
        AuthChangeEvent.passwordRecovery => MapLovAuthEvent.passwordRecovery,
        AuthChangeEvent.userUpdated => MapLovAuthEvent.userUpdated,
        _ => MapLovAuthEvent.other,
      };
    });
  }

  Future<void> enforceSessionPreference() async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_rememberSessionKey) == false) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
    required bool rememberSession,
  }) async {
    final client = _client;
    if (client == null) return;

    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.contains('@')) {
      await client.auth.signInWithPassword(
        email: normalizedIdentifier.toLowerCase(),
        password: password,
      );
    } else {
      await client.auth.signInWithPassword(
        phone: normalizedIdentifier,
        password: password,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberSessionKey, rememberSession);
    await validateCurrentAccount();
  }

  Future<void> validateCurrentAccount() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    final row = await client
        .from('profiles')
        .select('status')
        .eq('id', user.id)
        .maybeSingle();
    final status = row?['status'] as String? ?? 'active';
    if (status != 'active') {
      await client.auth.signOut(scope: SignOutScope.local);
      throw AuthException(
        status == 'suspended'
            ? 'This account is temporarily suspended.'
            : status == 'banned'
            ? 'This account has been banned.'
            : 'This account is unavailable.',
      );
    }
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
    required String country,
    required String city,
    required DateTime dateOfBirth,
  }) async {
    final client = _client;
    if (client == null) {
      return const SignUpResult(requiresEmailConfirmation: true);
    }

    final response = await client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      emailRedirectTo: authRedirectUrl,
      data: {
        'first_name': fullName.trim(),
        'country_name': country.trim(),
        'city': city.trim(),
        'date_of_birth': _dateOnly(dateOfBirth),
      },
    );
    return SignUpResult(requiresEmailConfirmation: response.session == null);
  }

  Future<bool> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  Future<bool> signInWithApple() => _signInWithOAuth(OAuthProvider.apple);

  Future<bool> _signInWithOAuth(OAuthProvider provider) async {
    final client = _client;
    if (client == null) return false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberSessionKey, true);
    return client.auth.signInWithOAuth(provider, redirectTo: authRedirectUrl);
  }

  Future<void> sendPasswordReset(String email) async {
    final client = _client;
    if (client == null) return;
    await client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: authRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    final client = _client;
    if (client == null) return;
    await client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> resendVerificationEmail(String email) async {
    final client = _client;
    if (client == null) return;
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
      emailRedirectTo: authRedirectUrl,
    );
  }

  Future<bool> refreshAndCheckEmailVerification() async {
    final client = _client;
    if (client == null) return true;
    if (client.auth.currentSession != null) {
      await client.auth.refreshSession();
    }
    return client.auth.currentUser?.emailConfirmedAt != null;
  }

  Future<void> signOut({bool allDevices = false}) async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut(
        scope: allDevices ? SignOutScope.global : SignOutScope.local,
      );
    }
  }

  Future<void> signOutOtherDevices() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut(scope: SignOutScope.others);
    }
  }

  Future<void> requestAccountDeletion() async {
    final client = _client;
    if (client != null) {
      await client.rpc('request_account_deletion');
      await client.auth.signOut(scope: SignOutScope.global);
    }
  }

  String messageFor(Object error) {
    final raw = error is AuthException ? error.message : error.toString();
    final message = raw.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email, phone number, or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (message.contains('suspended') || message.contains('banned')) {
      return raw;
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'An account already exists for this email.';
    }
    if (message.contains('password') && message.contains('least')) {
      return 'Use at least 8 characters, including a number and a symbol.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('network') || message.contains('socket')) {
      return 'Unable to connect. Check your internet connection.';
    }
    return 'Authentication failed. Please try again.';
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
