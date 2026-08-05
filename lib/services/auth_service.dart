import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_link_config.dart';
import '../config/supabase_config.dart';

enum MapLovAuthEvent {
  signedIn,
  signedOut,
  passwordRecovery,
  userUpdated,
  other,
}

/// The request that must be completed when Supabase returns to MapLov.
///
/// Supabase emits the authoritative auth event. Persisting this small,
/// non-secret intent also covers Flutter web, where Supabase can process and
/// clear the callback URL before the first widget subscribes to auth events.
enum MapLovAuthIntent {
  emailConfirmation,
  passwordRecovery,
  magicLink,
  oauth,
  emailChange,
}

class SignUpResult {
  const SignUpResult({required this.requiresEmailConfirmation});

  final bool requiresEmailConfirmation;
}

class AuthService {
  AuthService._();

  static final instance = AuthService._();
  static const authRedirectUrl = AuthLinkConfig.callbackUrl;
  static const fallbackAuthRedirectUrl = AuthLinkConfig.customSchemeCallbackUrl;
  static const _rememberSessionKey = 'maplov_remember_session';
  static const _pendingAuthIntentKey = 'maplov_pending_auth_intent';
  static const _pendingPhoneKey = 'maplov_pending_phone';
  static const _pendingPhoneEmailKey = 'maplov_pending_phone_email';
  static const _pendingPhoneCountryKey = 'maplov_pending_phone_country';
  static const _pendingPhoneCallingCodeKey = 'maplov_pending_calling_code';

  String? _pendingPhoneCache;
  String? _pendingPhoneEmailCache;
  MapLovAuthIntent? _pendingAuthIntent;

  SupabaseClient? get _client => SupabaseConfig.client;
  bool get isConfigured => SupabaseConfig.isConfigured;
  bool get hasActiveSession => _client?.auth.currentSession != null;
  MapLovAuthIntent? get pendingAuthIntent => _pendingAuthIntent;
  String? get currentEmail => _client?.auth.currentUser?.email;
  String? get emailForVerification {
    final activeEmail = currentEmail?.trim().toLowerCase();
    if (activeEmail?.isNotEmpty == true) return activeEmail;
    final pendingEmail = _pendingPhoneEmailCache?.trim().toLowerCase();
    return pendingEmail?.isNotEmpty == true ? pendingEmail : null;
  }

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
      _client?.auth.currentUser != null &&
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

  /// Hydrates local auth state before the first widget is built.
  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _pendingPhoneCache = preferences.getString(_pendingPhoneKey);
    _pendingPhoneEmailCache = preferences.getString(_pendingPhoneEmailKey);
    final storedIntent = preferences.getString(_pendingAuthIntentKey);
    _pendingAuthIntent = MapLovAuthIntent.values
        .where((intent) => intent.name == storedIntent)
        .firstOrNull;
  }

  Future<void> enforceSessionPreference() async {
    final preferences = await SharedPreferences.getInstance();
    _pendingPhoneCache = preferences.getString(_pendingPhoneKey);
    _pendingPhoneEmailCache = preferences.getString(_pendingPhoneEmailKey);
    final client = _client;
    if (client == null || client.auth.currentSession == null) return;
    // A recovery/confirmation callback creates a short-lived session needed
    // to finish the requested operation, even when "Remember me" was off.
    if (_pendingAuthIntent == null &&
        preferences.getBool(_rememberSessionKey) == false) {
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

    await clearPendingAuthIntent();
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
          'first_name, date_of_birth, gender, city, country_name, residence_region, origin_country_name, origin_region, origin_city, spoken_languages',
        )
        .eq('id', user.id)
        .maybeSingle();
    return row?['first_name'] != null &&
        row?['date_of_birth'] != null &&
        row?['gender'] != null &&
        row?['city'] != null &&
        row?['country_name'] != null &&
        row?['residence_region'] != null &&
        row?['origin_country_name'] != null &&
        row?['origin_region'] != null &&
        row?['origin_city'] != null &&
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
    required String phoneCountry,
    required String callingCode,
    required String password,
    required String country,
    required String countryCode,
    required String region,
    required String originCountry,
    required String originRegion,
    required String originCity,
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
    await preferences.setString(_pendingPhoneCountryKey, phoneCountry.trim());
    await preferences.setString(_pendingPhoneCallingCodeKey, callingCode);

    final client = _client;
    if (client == null) {
      return const SignUpResult(requiresEmailConfirmation: true);
    }

    await _rememberAuthIntent(MapLovAuthIntent.emailConfirmation);
    try {
      final response = await client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'first_name': fullName.trim(),
          'phone_number': normalizedPhone,
          'phone_country_name': phoneCountry.trim(),
          'phone_calling_code': callingCode,
          'country_code': countryCode.trim().toUpperCase(),
          'country_name': country.trim(),
          'residence_region': region.trim(),
          'origin_country_name': originCountry.trim(),
          'origin_region': originRegion.trim(),
          'origin_city': originCity.trim(),
          'city': city.trim(),
          'date_of_birth': _dateOnly(dateOfBirth),
          'accepted_legal_documents': acceptedDocuments,
          'legal_accepted_at': legalAcceptedAt.toUtc().toIso8601String(),
        },
      );
      return SignUpResult(requiresEmailConfirmation: response.session == null);
    } catch (_) {
      await clearPendingAuthIntent();
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  Future<bool> signInWithApple() => _signInWithOAuth(OAuthProvider.apple);

  Future<bool> _signInWithOAuth(OAuthProvider provider) async {
    final client = _client;
    if (client == null) return false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberSessionKey, true);
    await _rememberAuthIntent(MapLovAuthIntent.oauth);
    try {
      final launched = await client.auth.signInWithOAuth(
        provider,
        redirectTo: authRedirectUrl,
      );
      if (!launched) await clearPendingAuthIntent();
      return launched;
    } catch (_) {
      await clearPendingAuthIntent();
      rethrow;
    }
  }

  Future<void> sendMagicLink(String email) async {
    final client = _client;
    if (client == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberSessionKey, true);
    await _rememberAuthIntent(MapLovAuthIntent.magicLink);
    try {
      await client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        emailRedirectTo: authRedirectUrl,
        shouldCreateUser: false,
      );
    } catch (_) {
      await clearPendingAuthIntent();
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final client = _client;
    if (client == null) return;
    await _rememberAuthIntent(MapLovAuthIntent.passwordRecovery);
    try {
      await client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: authRedirectUrl,
      );
    } catch (_) {
      await clearPendingAuthIntent();
      rethrow;
    }
  }

  Future<void> updatePassword(String password) async {
    final client = _client;
    if (client == null) return;
    await client.auth.updateUser(UserAttributes(password: password));
    await clearPendingAuthIntent();
  }

  Future<void> requestEmailChange(String email) async {
    final client = _client;
    if (client == null) return;
    await _rememberAuthIntent(MapLovAuthIntent.emailChange);
    try {
      await client.auth.updateUser(
        UserAttributes(email: email.trim().toLowerCase()),
        emailRedirectTo: authRedirectUrl,
      );
    } catch (_) {
      await clearPendingAuthIntent();
      rethrow;
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    final client = _client;
    if (client == null) return;
    await _rememberAuthIntent(MapLovAuthIntent.emailConfirmation);
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final client = _client;
    if (client == null) return;
    final response = await client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code.trim(),
      type: OtpType.signup,
    );
    if (response.session == null || response.user?.emailConfirmedAt == null) {
      throw const AuthException(
        'Email verification did not create an authenticated session.',
      );
    }
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

  Future<void> deferPhoneVerification() async {
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
    await clearPendingAuthIntent();
    final client = _client;
    if (client != null) {
      try {
        await client.rpc('set_my_presence', params: {'online': false});
      } on PostgrestException {
        // Presence support is additive; sign-out must remain available.
      }
      await client.auth.signOut(
        scope: allDevices ? SignOutScope.global : SignOutScope.local,
      );
    }
  }

  Future<void> discardRejectedRegistration() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingPhoneKey);
    await preferences.remove(_pendingPhoneEmailKey);
    await preferences.remove(_pendingPhoneCountryKey);
    await preferences.remove(_pendingPhoneCallingCodeKey);
    _pendingPhoneCache = null;
    _pendingPhoneEmailCache = null;
    await clearPendingAuthIntent();

    final client = _client;
    if (client != null) {
      await client.auth.signOut(scope: SignOutScope.local);
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

  Future<void> _rememberAuthIntent(MapLovAuthIntent intent) async {
    _pendingAuthIntent = intent;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingAuthIntentKey, intent.name);
  }

  Future<void> clearPendingAuthIntent() async {
    _pendingAuthIntent = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingAuthIntentKey);
  }

  String messageFor(Object error) {
    final raw = error is AuthException ? error.message : error.toString();
    final message = raw.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email, phone number, or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please verify your email with the code before signing in.';
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
}
