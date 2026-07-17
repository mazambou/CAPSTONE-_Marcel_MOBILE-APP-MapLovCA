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
  static const _pendingPhoneKey = 'maplov_pending_phone';
  static const _pendingPhoneEmailKey = 'maplov_pending_phone_email';

  String? _pendingPhoneCache;
  String? _pendingPhoneEmailCache;

  SupabaseClient? get _client => SupabaseConfig.client;
  bool get isConfigured => SupabaseConfig.isConfigured;
  bool get hasActiveSession => _client?.auth.currentSession != null;
  String? get currentEmail => _client?.auth.currentUser?.email;
  bool get isEmailVerified =>
      !isConfigured || _client?.auth.currentUser?.emailConfirmedAt != null;
  bool get isPhoneVerified =>
      !isConfigured || _client?.auth.currentUser?.phoneConfirmedAt != null;
  bool get isPhoneVerificationDeferred =>
      _client?.auth.currentUser?.userMetadata?['phone_verification_deferred'] ==
      true;
  String? get pendingPhoneNumber {
    final user = _client?.auth.currentUser;
    final authPhone = user?.phone ?? user?.userMetadata?['phone_number'];
    if (authPhone is String && authPhone.isNotEmpty) return authPhone;
    final currentEmail = user?.email?.trim().toLowerCase();
    if (_pendingPhoneCache?.isNotEmpty == true &&
        (currentEmail == null || currentEmail == _pendingPhoneEmailCache)) {
      return _pendingPhoneCache;
    }
    return null;
  }

  bool get requiresPhoneVerification =>
      isConfigured &&
      pendingPhoneNumber?.isNotEmpty == true &&
      !isPhoneVerified &&
      !isPhoneVerificationDeferred;
  bool get requiresPreferencesCompletion =>
      isConfigured &&
      pendingPhoneNumber?.isNotEmpty == true &&
      _client?.auth.currentUser?.userMetadata?['preferences_completed'] != true;

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
    final preferences = await SharedPreferences.getInstance();
    _pendingPhoneCache = preferences.getString(_pendingPhoneKey);
    _pendingPhoneEmailCache = preferences.getString(_pendingPhoneEmailKey);
    final client = _client;
    if (client == null || client.auth.currentSession == null) return;
    if (preferences.getBool(_rememberSessionKey) == false) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
  }

  Future<String?> phoneNumberForVerification() async {
    final authPhone = pendingPhoneNumber;
    if (authPhone?.isNotEmpty == true) return authPhone;
    final preferences = await SharedPreferences.getInstance();
    _pendingPhoneCache = preferences.getString(_pendingPhoneKey);
    _pendingPhoneEmailCache = preferences.getString(_pendingPhoneEmailKey);
    return pendingPhoneNumber;
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

  Future<bool> isCurrentProfileComplete() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return true;
    final row = await client
        .from('profiles')
        .select(
          'first_name, date_of_birth, gender, city, country_name, spoken_languages',
        )
        .eq('id', user.id)
        .maybeSingle();
    return row?['first_name'] != null &&
        row?['date_of_birth'] != null &&
        row?['gender'] != null &&
        row?['city'] != null &&
        row?['country_name'] != null &&
        (row?['spoken_languages'] as List?)?.isNotEmpty == true;
  }

  Future<void> markPreferencesCompleted() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    await client.auth.updateUser(
      UserAttributes(
        data: {...?user.userMetadata, 'preferences_completed': true},
      ),
    );
  }

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String country,
    required String city,
    required DateTime dateOfBirth,
    required Map<String, String> acceptedDocuments,
    required DateTime legalAcceptedAt,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s().-]'), '');
    _pendingPhoneCache = normalizedPhone;
    _pendingPhoneEmailCache = normalizedEmail;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingPhoneKey, normalizedPhone);
    await preferences.setString(_pendingPhoneEmailKey, normalizedEmail);

    final client = _client;
    if (client == null) {
      return const SignUpResult(requiresEmailConfirmation: true);
    }

    final response = await client.auth.signUp(
      email: normalizedEmail,
      password: password,
      emailRedirectTo: authRedirectUrl,
      data: {
        'first_name': fullName.trim(),
        'phone_number': normalizedPhone,
        'country_code': _countryCode(country),
        'country_name': country.trim(),
        'city': city.trim(),
        'date_of_birth': _dateOnly(dateOfBirth),
        'accepted_legal_documents': acceptedDocuments,
        'legal_accepted_at': legalAcceptedAt.toUtc().toIso8601String(),
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

  Future<void> sendPhoneVerification() async {
    final client = _client;
    final phone = await phoneNumberForVerification();
    if (client == null) return;
    if (phone == null || phone.isEmpty) {
      throw const AuthException('No phone number is attached to this account.');
    }
    if (isPhoneVerified) return;
    await client.auth.updateUser(UserAttributes(phone: phone));
  }

  Future<void> resendPhoneVerification() async {
    final client = _client;
    final phone = await phoneNumberForVerification();
    if (client == null) return;
    if (phone == null || phone.isEmpty) {
      throw const AuthException('No phone number is attached to this account.');
    }
    await client.auth.resend(phone: phone, type: OtpType.phoneChange);
  }

  Future<void> verifyPhone(String code) async {
    final client = _client;
    final phone = await phoneNumberForVerification();
    if (client == null) return;
    if (phone == null || phone.isEmpty) {
      throw const AuthException('No phone number is attached to this account.');
    }
    await client.auth.verifyOTP(
      phone: phone,
      token: code.trim(),
      type: OtpType.phoneChange,
    );
    await client.auth.refreshSession();
  }

  Future<void> deferPhoneVerificationForTesting() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (isConfigured && (client == null || user == null)) {
      throw const AuthException(
        'Sign in to the account before deferring phone verification.',
      );
    }
    if (client != null && user != null) {
      await client.auth.updateUser(
        UserAttributes(
          data: {...?user.userMetadata, 'phone_verification_deferred': true},
        ),
      );
    }
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
    if (message.contains('token') || message.contains('otp')) {
      return 'The verification code is invalid or has expired.';
    }
    if (message.contains('sms') || message.contains('phone provider')) {
      return 'SMS verification is currently unavailable. Check the Supabase SMS provider configuration.';
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

  String? _countryCode(String country) => const {
    'Canada': 'CA',
    'United States': 'US',
    'Mexico': 'MX',
    'Brazil': 'BR',
    'United Kingdom': 'GB',
    'France': 'FR',
    'Germany': 'DE',
    'Spain': 'ES',
    'Italy': 'IT',
    'Belgium': 'BE',
    'Switzerland': 'CH',
    'Morocco': 'MA',
    'Algeria': 'DZ',
    'Tunisia': 'TN',
    'Senegal': 'SN',
    'Cameroon': 'CM',
    'Côte d’Ivoire': 'CI',
    'Democratic Republic of the Congo': 'CD',
    'Nigeria': 'NG',
    'South Africa': 'ZA',
    'India': 'IN',
    'China': 'CN',
    'Japan': 'JP',
    'Australia': 'AU',
    'New Zealand': 'NZ',
  }[country.trim()];
}
