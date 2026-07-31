/// Production URLs shared by every Supabase Auth flow.
///
/// A single HTTPS callback keeps the Supabase allow-list, Android App Links,
/// iOS Universal Links, and the future web application in sync. Supabase's
/// auth event identifies whether the callback is a confirmation, recovery,
/// Magic Link, email change, or OAuth response.
abstract final class AuthLinkConfig {
  static const siteUrl = 'https://maplov.ca';
  static const callbackPath = '/auth/callback';
  static const callbackUrl = '$siteUrl$callbackPath';

  /// Kept as an allow-listed fallback for installed builds that predate the
  /// verified HTTPS associations. New authentication requests use callbackUrl.
  static const customSchemeCallbackUrl = 'io.maplov.app://auth-callback';

  static bool isCallback(Uri uri) =>
      (uri.scheme == 'https' &&
          uri.host == 'maplov.ca' &&
          uri.path == callbackPath) ||
      (uri.scheme == 'io.maplov.app' && uri.host == 'auth-callback');
}
