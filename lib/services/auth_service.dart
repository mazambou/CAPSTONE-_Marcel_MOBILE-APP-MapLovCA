import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class TestAccountOption {
  const TestAccountOption({
    required this.id,
    required this.authEmail,
    required this.contactEmail,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String authEmail;
  final String contactEmail;
  final String name;
  final DateTime? createdAt;
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class RegistrationSmsException implements Exception {
  const RegistrationSmsException(this.message);

  final String message;

  @override
  String toString() => message;
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
  static const _pendingRegistrationSecretKey =
      'maplov_pending_registration_secret';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const _africanCountryCodes = <String>{
    'DZ',
    'AO',
    'BJ',
    'BW',
    'BF',
    'BI',
    'CV',
    'CM',
    'CF',
    'TD',
    'KM',
    'CG',
    'CD',
    'CI',
    'DJ',
    'EG',
    'GQ',
    'ER',
    'SZ',
    'ET',
    'GA',
    'GM',
    'GH',
    'GN',
    'GW',
    'KE',
    'LS',
    'LR',
    'LY',
    'MG',
    'MW',
    'ML',
    'MR',
    'MU',
    'MA',
    'MZ',
    'NA',
    'NE',
    'NG',
    'RW',
    'ST',
    'SN',
    'SC',
    'SL',
    'SO',
    'ZA',
    'SS',
    'SD',
    'TZ',
    'TG',
    'TN',
    'UG',
    'ZM',
    'ZW',
    'EH',
  };

  static bool isAfricanResidenceCountry(String? countryCode) =>
      countryCode != null &&
      _africanCountryCodes.contains(countryCode.trim().toUpperCase());

  static bool phoneRequirementIsSatisfied({
    required String? phone,
    required bool phoneVerified,
    required bool verificationExempt,
  }) =>
      phone?.trim().isNotEmpty == true && (phoneVerified || verificationExempt);

  String? _pendingPhoneCache;
  String? _pendingPhoneEmailCache;
  String? _pendingRegistrationPassword;
  bool _skipNextEmailReminder = false;
  String? _residenceCountryCodeCache;
  String? _residenceCountryUserIdCache;
  MapLovAuthIntent? _pendingAuthIntent;

  SupabaseClient? get _client => SupabaseConfig.client;
  bool get isConfigured => SupabaseConfig.isConfigured;
  bool get hasActiveSession => _client?.auth.currentSession != null;
  bool get isTestDuplicateAccount =>
      _client?.auth.currentUser?.appMetadata['maplov_test_duplicate'] == true;
  MapLovAuthIntent? get pendingAuthIntent => _pendingAuthIntent;
  String? get currentEmail {
    final user = _client?.auth.currentUser;
    final contactEmail = user?.appMetadata['maplov_contact_email'];
    return contactEmail is String && contactEmail.isNotEmpty
        ? contactEmail
        : user?.email;
  }

  String? get emailForVerification {
    final activeEmail = currentEmail?.trim().toLowerCase();
    if (activeEmail?.isNotEmpty == true) return activeEmail;
    final pendingEmail = _pendingPhoneEmailCache?.trim().toLowerCase();
    return pendingEmail?.isNotEmpty == true ? pendingEmail : null;
  }

  bool get isEmailVerified {
    if (!isConfigured) return true;
    final user = _client?.auth.currentUser;
    if (user == null) return false;
    final contactEmail = user.appMetadata['maplov_contact_email'];
    if (contactEmail is String && contactEmail.isNotEmpty) {
      return user.appMetadata['maplov_contact_email_verified'] == true;
    }
    return user.emailConfirmedAt != null;
  }

  bool get isSharedPhoneEmailPending {
    final metadata = _client?.auth.currentUser?.appMetadata;
    return metadata?['maplov_shared_test_phone_verified'] == true &&
        metadata?['maplov_contact_email_verified'] != true;
  }

  bool get needsEmailVerificationReminder =>
      hasActiveSession &&
      !isEmailVerified &&
      _client?.auth.currentUser?.appMetadata['maplov_sms_fallback_verified'] ==
          true;
  bool consumeEmailReminderSkip() {
    final skip = _skipNextEmailReminder;
    _skipNextEmailReminder = false;
    return skip;
  }

  bool get isPhoneVerified {
    if (!isConfigured) return true;
    final user = _client?.auth.currentUser;
    final metadata = user?.appMetadata;
    return user?.phoneConfirmedAt != null ||
        (metadata?['maplov_test_duplicate'] == true &&
            metadata?['maplov_test_phone_verified'] == true &&
            metadata?['maplov_contact_phone'] ==
                user?.userMetadata?['phone_number']) ||
        (metadata?['maplov_shared_test_phone_verified'] == true &&
            metadata?['maplov_shared_test_phone'] ==
                user?.userMetadata?['phone_number']);
  }

  String? get residenceCountryCode {
    final currentUserId = _client?.auth.currentUser?.id;
    if (_residenceCountryUserIdCache == currentUserId &&
        _residenceCountryCodeCache?.isNotEmpty == true) {
      return _residenceCountryCodeCache;
    }
    final metadataCode =
        _client?.auth.currentUser?.userMetadata?['country_code'];
    if (metadataCode is String && metadataCode.trim().isNotEmpty) {
      return metadataCode.trim().toUpperCase();
    }
    return _residenceCountryCodeCache;
  }

  bool get isPhoneVerificationExempt =>
      isAfricanResidenceCountry(residenceCountryCode);
  String? get pendingPhoneNumber {
    final user = _client?.auth.currentUser;
    if (user?.appMetadata['maplov_test_duplicate'] == true) {
      final contactPhone = user?.appMetadata['maplov_contact_phone'];
      if (contactPhone is String && contactPhone.isNotEmpty) {
        return contactPhone;
      }
    }
    final authPhone = user?.phone;
    if (authPhone?.isNotEmpty == true) return authPhone;
    final metadataPhone = user?.userMetadata?['phone_number'];
    if (metadataPhone is String && metadataPhone.isNotEmpty) {
      return metadataPhone;
    }
    final currentEmail = user?.email?.trim().toLowerCase();
    if (_pendingPhoneCache?.isNotEmpty == true &&
        (currentEmail == null || currentEmail == _pendingPhoneEmailCache)) {
      return _pendingPhoneCache;
    }
    return null;
  }

  bool get isPhoneRequirementSatisfied => phoneRequirementIsSatisfied(
    phone: pendingPhoneNumber,
    phoneVerified: isPhoneVerified,
    verificationExempt: isPhoneVerificationExempt,
  );

  bool get requiresPhoneVerification =>
      isConfigured &&
      _client?.auth.currentUser != null &&
      !isPhoneRequirementSatisfied;
  bool get requiresPreferencesCompletion =>
      isConfigured &&
      _client?.auth.currentUser != null &&
      _client?.auth.currentUser?.userMetadata?['preferences_completed'] != true;

  bool get isSocialAccount {
    final metadata = _client?.auth.currentUser?.appMetadata ?? const {};
    final provider = metadata['provider'];
    final providers = metadata['providers'];
    return provider == 'google' ||
        provider == 'apple' ||
        providers is List &&
            (providers.contains('google') || providers.contains('apple'));
  }

  Future<bool> requiresSocialRegistrationGate() async {
    final client = _client;
    if (client == null || !isSocialAccount) return false;
    final completed = await client.rpc('has_completed_my_registration_gate');
    return completed != true;
  }

  Future<void> completeSocialRegistrationGate({
    required DateTime dateOfBirth,
    required Map<String, String> acceptedDocuments,
    required DateTime acceptedAt,
  }) async {
    final client = _client;
    if (client == null || !isSocialAccount) return;
    await client.rpc(
      'complete_my_social_registration_gate',
      params: {
        'date_of_birth_value': _dateOnly(dateOfBirth),
        'accepted_documents_value': acceptedDocuments,
        'accepted_at_value': acceptedAt.toUtc().toIso8601String(),
      },
    );
  }

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
      final email = normalizedIdentifier.toLowerCase();
      try {
        await client.auth.signInWithPassword(email: email, password: password);
      } on AuthException catch (error) {
        final message = error.message.toLowerCase();
        if (!message.contains('invalid login credentials') &&
            !message.contains('email not confirmed')) {
          rethrow;
        }
        final alias = await _resolveSharedPhoneLoginAlias(email, password);
        if (alias == null) rethrow;
        await client.auth.signInWithPassword(email: alias, password: password);
      }
    } else {
      await client.auth.signInWithPassword(
        phone: normalizedIdentifier,
        password: password,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberSessionKey, rememberSession);
    await validateCurrentAccount();
    await _clearPendingRegistrationSecret();
  }

  Future<String?> _resolveSharedPhoneLoginAlias(
    String email,
    String password,
  ) async {
    final client = _client;
    if (client == null) return null;
    try {
      final response = await client.functions.invoke(
        'shared-phone-alias-login',
        body: {'email': email, 'password': password},
      );
      final data = response.data;
      if (data is Map &&
          data['code'] == 'alias_ready' &&
          data['auth_email'] is String) {
        return data['auth_email'] as String;
      }
    } catch (_) {
      // Keep the original login error when no matching test account exists.
    }
    return null;
  }

  Future<void> validateCurrentAccount() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    final row = await client
        .from('profiles')
        .select('status, country_code')
        .eq('id', user.id)
        .maybeSingle();
    final countryCode = row?['country_code'];
    if (countryCode is String && countryCode.trim().isNotEmpty) {
      _residenceCountryCodeCache = countryCode.trim().toUpperCase();
      _residenceCountryUserIdCache = user.id;
    }
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
    await _clearPendingRegistrationSecret();
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
      if (response.session == null) {
        _pendingRegistrationPassword = password;
        try {
          await _secureStorage.write(
            key: _pendingRegistrationSecretKey,
            value: jsonEncode({
              'email': normalizedEmail,
              'phone': normalizedPhone,
              'password': password,
              'stored_at': DateTime.now().toUtc().toIso8601String(),
            }),
          );
        } catch (_) {
          // The active registration can still continue with the memory copy.
        }
      }
      return SignUpResult(requiresEmailConfirmation: response.session == null);
    } catch (_) {
      await clearPendingAuthIntent();
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  Future<bool> get testDuplicateWindowActive async {
    final client = _client;
    if (client == null) return false;
    try {
      final response = await client.functions.invoke(
        'test-duplicate-accounts',
        body: {'action': 'status'},
      );
      return response.data is Map && response.data['active'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _callTestAccounts(
    Map<String, dynamic> body,
  ) async {
    final client = _client;
    if (client == null) {
      throw const RegistrationSmsException('MapLov is not connected.');
    }
    try {
      final response = await client.functions.invoke(
        'test-duplicate-accounts',
        body: body,
      );
      if (response.data case final Map data) {
        return Map<String, dynamic>.from(data);
      }
      throw const RegistrationSmsException(
        'The server returned an invalid response.',
      );
    } on FunctionException catch (error) {
      Object? code;
      final details = error.details;
      if (details is Map) {
        code = details['code'];
      } else if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) code = decoded['code'];
        } on FormatException {
          // Keep the stable message below for a plain-text gateway response.
        }
      }
      throw RegistrationSmsException(_registrationSmsMessage(code));
    }
  }

  Future<void> sendTestDuplicateRegistrationCode({
    required String email,
    required String phone,
  }) async {
    final result = await _callTestAccounts({
      'action': 'send_registration',
      'email': email.trim().toLowerCase(),
      'phone': phone,
    });
    if (result['code'] != 'code_sent') {
      throw RegistrationSmsException(_registrationSmsMessage(result['code']));
    }
  }

  Future<void> completeTestDuplicateRegistration({
    required String email,
    required String phone,
    required String code,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    final result = await _callTestAccounts({
      'action': 'complete_registration',
      'email': email.trim().toLowerCase(),
      'phone': phone,
      'code': code.trim(),
      'password': password,
      'metadata': metadata,
    });
    final alias = result['auth_email'];
    if (result['code'] != 'account_created' || alias is! String) {
      throw RegistrationSmsException(_registrationSmsMessage(result['code']));
    }
    await signIn(identifier: alias, password: password, rememberSession: true);
  }

  Future<void> sendAccountSelectionCode(String phone) async {
    final result = await _callTestAccounts({
      'action': 'send_login',
      'phone': phone.trim(),
    });
    if (result['code'] != 'code_sent') {
      throw RegistrationSmsException(_registrationSmsMessage(result['code']));
    }
  }

  Future<List<TestAccountOption>> checkAccountSelectionCode({
    required String phone,
    required String code,
  }) async {
    final result = await _callTestAccounts({
      'action': 'check_login',
      'phone': phone.trim(),
      'code': code.trim(),
    });
    final rows = result['accounts'];
    if (result['code'] != 'accounts_ready' || rows is! List) {
      throw RegistrationSmsException(_registrationSmsMessage(result['code']));
    }
    return rows
        .whereType<Map>()
        .map((row) {
          final created = row['created_at'];
          return TestAccountOption(
            id: row['id']?.toString() ?? '',
            authEmail: row['auth_email']?.toString() ?? '',
            contactEmail: row['contact_email']?.toString() ?? '',
            name: row['name']?.toString() ?? 'MapLov',
            createdAt: created is String ? DateTime.tryParse(created) : null,
          );
        })
        .where(
          (account) => account.id.isNotEmpty && account.authEmail.isNotEmpty,
        )
        .toList(growable: false);
  }

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

  Future<void> verifyPasswordRecoveryCode({
    required String email,
    required String code,
  }) async {
    final client = _client;
    if (client == null) return;
    final response = await client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code.trim(),
      type: OtpType.recovery,
    );
    if (response.session == null) {
      throw const AuthException(
        'Password recovery did not create an authenticated session.',
      );
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
    if (isSharedPhoneEmailPending) {
      throw const AuthException(
        'Verify your current email before changing it.',
      );
    }
    if (isTestDuplicateAccount) {
      throw const AuthException(
        'Contact email changes are unavailable for test accounts. Contact support.',
      );
    }
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
    if (isSharedPhoneEmailPending) {
      await _sharedPhoneContactEmail(action: 'send');
      return;
    }
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
    if (isSharedPhoneEmailPending) {
      await _sharedPhoneContactEmail(action: 'check', code: code);
      await client.auth.refreshSession();
      if (!isEmailVerified) {
        throw const RegistrationSmsException(
          'Email verification could not be completed. Try again.',
        );
      }
      return;
    }
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
    await _clearPendingRegistrationSecret();
  }

  Future<void> _sharedPhoneContactEmail({
    required String action,
    String? code,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final response = await client.functions.invoke(
        'shared-phone-contact-email',
        body: {'action': action, if (code != null) 'code': code.trim()},
      );
      final data = response.data;
      final expected = action == 'send' ? 'code_sent' : 'email_verified';
      if (data is! Map || data['code'] != expected) {
        throw RegistrationSmsException(
          _sharedPhoneEmailMessage(data is Map ? data['code'] : null),
        );
      }
    } on FunctionException catch (error) {
      final details = error.details;
      Object? resultCode;
      if (details is Map) {
        resultCode = details['code'];
      } else if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) resultCode = decoded['code'];
        } on FormatException {
          // Keep a stable message when an intermediary returns plain text.
        }
      }
      throw RegistrationSmsException(_sharedPhoneEmailMessage(resultCode));
    }
  }

  String _sharedPhoneEmailMessage(Object? code) => switch (code) {
    'email_rate_limited' =>
      'Too many email requests. Wait before requesting another code.',
    'email_provider_unavailable' =>
      'The email service is temporarily unavailable. Try again later.',
    'invalid_code' => 'The email code is invalid or has expired.',
    'email_already_in_use' =>
      'This email address is already used by another account. Contact support.',
    'email_verification_unavailable' =>
      'Email verification is unavailable for this account.',
    _ => 'Email verification could not be completed. Try again.',
  };

  Future<void> sendRegistrationSmsFallback({
    required String email,
    required String phone,
  }) async {
    await _registrationSmsFallback(action: 'send', email: email, phone: phone);
  }

  Future<void> verifyRegistrationSmsFallback({
    required String email,
    required String phone,
    required String code,
  }) async {
    final result = await _registrationSmsFallback(
      action: 'check',
      email: email,
      phone: phone,
      code: code,
    );
    _skipNextEmailReminder = true;
    try {
      final tokenHash = result['token_hash'];
      if (tokenHash is String && tokenHash.isNotEmpty) {
        final client = _client;
        if (client == null) {
          throw const RegistrationSmsException(
            'SMS verification is unavailable.',
          );
        }
        final response = await client.auth.verifyOTP(
          tokenHash: tokenHash,
          type: OtpType.email,
        );
        if (response.session == null) {
          throw const RegistrationSmsException(
            'SMS session could not be opened.',
          );
        }
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool(_rememberSessionKey, true);
        await validateCurrentAccount();
        await _clearPendingRegistrationSecret();
      } else {
        final password = await _registrationPasswordFor(email, phone);
        await signIn(
          identifier: result['auth_email'] as String? ?? phone,
          password: password,
          rememberSession: true,
        );
      }
    } catch (_) {
      _skipNextEmailReminder = false;
      rethrow;
    }
    if (!hasActiveSession) {
      throw const RegistrationSmsException(
        'Phone verified. Sign in with your phone number and password to continue.',
      );
    }
  }

  Future<Map> _registrationSmsFallback({
    required String action,
    required String email,
    required String phone,
    String? code,
  }) async {
    String? password;
    try {
      password = await _registrationPasswordFor(email, phone);
    } on RegistrationSmsException {
      // The allowlisted test phone can use its SMS code as the first proof.
    }
    final client = _client;
    if (client == null) {
      throw const RegistrationSmsException('SMS verification is unavailable.');
    }
    try {
      final body = <String, String>{
        'action': action,
        'email': email.trim().toLowerCase(),
        'phone': phone,
        if (code != null) 'code': code.trim(),
      };
      if (password != null) body['password'] = password;
      final response = await client.functions.invoke(
        'registration-sms-fallback',
        body: body,
      );
      final data = response.data;
      final resultCode = data is Map ? data['code'] : null;
      final expected = action == 'send'
          ? 'code_sent'
          : 'phone_verified_email_pending';
      if (resultCode != expected) {
        throw RegistrationSmsException(_registrationSmsMessage(resultCode));
      }
      return data is Map ? data : const {};
    } on FunctionException catch (error) {
      final details = error.details;
      Object? resultCode;
      if (details is Map) {
        resultCode = details['code'];
      } else if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) resultCode = decoded['code'];
        } on FormatException {
          // Keep a stable message when an intermediary returns plain text.
        }
      }
      throw RegistrationSmsException(_registrationSmsMessage(resultCode));
    }
  }

  Future<String> _registrationPasswordFor(String email, String phone) async {
    String? password = _pendingRegistrationPassword;
    if (password == null) {
      try {
        final stored = await _secureStorage.read(
          key: _pendingRegistrationSecretKey,
        );
        if (stored != null) {
          final values = jsonDecode(stored);
          if (values is Map) {
            final storedAt = DateTime.tryParse(
              values['stored_at']?.toString() ?? '',
            );
            final age = storedAt == null
                ? null
                : DateTime.now().toUtc().difference(storedAt);
            if (values['email'] == email.trim().toLowerCase() &&
                values['phone'] == phone &&
                age != null &&
                !age.isNegative &&
                age < const Duration(hours: 24)) {
              password = values['password'] as String?;
              _pendingRegistrationPassword = password;
            }
          }
        }
      } catch (_) {
        // Corrupt or inaccessible secure storage cannot prove registration.
      }
    }
    if (password == null ||
        _pendingPhoneEmailCache != email.trim().toLowerCase() ||
        _pendingPhoneCache != phone) {
      throw const RegistrationSmsException(
        'Registration proof is unavailable or has expired. Start registration again.',
      );
    }
    return password;
  }

  Future<void> _clearPendingRegistrationSecret() async {
    _pendingRegistrationPassword = null;
    try {
      await _secureStorage.delete(key: _pendingRegistrationSecretKey);
    } catch (_) {
      // Sign-out and successful verification must still finish.
    }
  }

  String _registrationSmsMessage(Object? code) => switch (code) {
    'invalid_request' => 'Check your email, phone number and password.',
    'registration_unavailable' =>
      'This registration could not be verified by SMS. If you already have an account with this phone number, sign in to that account.',
    'phone_already_linked' =>
      'This phone number is already linked to another MapLov account. Sign in to that account.',
    'email_confirmation_required' =>
      'Confirm this account’s email first. You can then verify this phone number by SMS.',
    'sms_rate_limited' => 'Too many SMS requests. Try again later.',
    'sms_provider_unavailable' =>
      'The SMS provider is temporarily unavailable. Try again later.',
    'invalid_code' => 'The SMS code is invalid or has expired.',
    'test_window_closed' => 'The temporary test account period has ended.',
    'source_account_unavailable' =>
      'A verified account with this email and phone number is required.',
    'account_unavailable' => 'No account is available for this phone number.',
    'account_creation_failed' =>
      'The test account could not be created. Request a new SMS code.',
    'age_ineligible' => 'You must be at least 18 years old to use MapLov.',
    _ => 'SMS verification is temporarily unavailable. Try again later.',
  };

  Future<void> sendPhoneVerification() async {
    final client = _client;
    final phone = await phoneNumberForVerification();
    if (client == null) return;
    if (isPhoneVerificationExempt) {
      throw const AuthException(
        'Phone verification is not required in your country.',
      );
    }
    if (phone == null || phone.isEmpty) {
      throw const AuthException('No phone number is attached to this account.');
    }
    if (isPhoneVerified) return;
    await client.functions.invoke('bright-processor', body: {'phone': phone});
  }

  Future<void> resendPhoneVerification() async {
    final client = _client;
    final phone = await phoneNumberForVerification();
    if (client == null) return;
    if (isPhoneVerificationExempt) {
      throw const AuthException(
        'Phone verification is not required in your country.',
      );
    }
    if (phone == null || phone.isEmpty) {
      throw const AuthException('No phone number is attached to this account.');
    }
    await client.functions.invoke('bright-processor', body: {'phone': phone});
  }

  Future<void> verifyPhone(String code) async {
    final client = _client;
    final phone = await phoneNumberForVerification();
    if (client == null) return;
    if (isPhoneVerificationExempt) {
      throw const AuthException(
        'Phone verification is not required in your country.',
      );
    }
    if (phone == null || phone.isEmpty) {
      throw const AuthException('No phone number is attached to this account.');
    }
    try {
      await client.functions.invoke(
        'quick-action',
        body: {'phone': phone, 'code': code.trim()},
      );
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map &&
          details['error'] ==
              'This phone number is already linked to another account') {
        throw const RegistrationSmsException(
          'This phone number is already linked to another MapLov account. Sign in to that account.',
        );
      }
      rethrow;
    }
    await client.auth.refreshSession();
  }

  Future<void> setPhoneNumberForVerification(String phone) async {
    final client = _client;
    final user = client?.auth.currentUser;
    final normalized = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
      throw const AuthException(
        'Enter the phone number in international format, for example +14165551234.',
      );
    }
    if (client == null || user == null) return;
    await client.auth.updateUser(
      UserAttributes(data: {...?user.userMetadata, 'phone_number': normalized}),
    );
    _pendingPhoneCache = normalized;
    _pendingPhoneEmailCache = user.email?.trim().toLowerCase();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingPhoneKey, normalized);
    if (_pendingPhoneEmailCache != null) {
      await preferences.setString(
        _pendingPhoneEmailKey,
        _pendingPhoneEmailCache!,
      );
    }
  }

  Future<bool> requiresPhoneVerificationForCurrentUser() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || isPhoneVerified) return false;
    if (_residenceCountryUserIdCache != user.id) {
      final row = await client
          .from('profiles')
          .select('country_code')
          .eq('id', user.id)
          .maybeSingle();
      final countryCode = row?['country_code'];
      _residenceCountryCodeCache = countryCode is String
          ? countryCode.trim().toUpperCase()
          : null;
      _residenceCountryUserIdCache = user.id;
    }
    return requiresPhoneVerification;
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
    await _clearPendingRegistrationSecret();
    _skipNextEmailReminder = false;
    _residenceCountryCodeCache = null;
    _residenceCountryUserIdCache = null;
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
    await _clearPendingRegistrationSecret();
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

  Future<void> deleteCurrentAccountImmediately() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.functions.invoke(
        'admin-delete-account',
        body: const {'action': 'delete_self', 'confirmation': 'DELETE'},
      );
      await client.auth.signOut(scope: SignOutScope.local);
    } on FunctionException catch (error) {
      final details = error.details;
      Map<String, dynamic> body = const {};
      if (details is Map) {
        body = Map<String, dynamic>.from(details);
      } else if (details is String && details.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) body = Map<String, dynamic>.from(decoded);
        } on FormatException {
          // Keep the stable client message when an intermediary returns text.
        }
      }
      final code = body['code'] as String? ?? 'account_deletion_failed';
      final message = switch (code) {
        'authentication_required' || 'invalid_session' =>
          'Your session has expired. Sign in again before deleting your account.',
        'privileged_account' =>
          'This privileged account must be deleted by another administrator.',
        _ =>
          body['message'] as String? ??
              (error.status == 0
                  ? 'Unable to connect. Check your internet connection.'
                  : 'Permanent account deletion could not be completed. Try again.'),
      };
      throw AccountDeletionException(code, message);
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
    if (error is AccountDeletionException) return error.message;
    if (error is RegistrationSmsException) return error.message;
    final raw = error is AuthException ? error.message : error.toString();
    final message = raw.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email, phone number, or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Verify your email code, or sign in with your verified phone number and password.';
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
