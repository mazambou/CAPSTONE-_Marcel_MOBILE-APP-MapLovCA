/// Compile-time environment values.
///
/// Never commit a `service_role` key to a Flutter application. The client uses
/// only the Supabase publishable/anon key; PostgreSQL RLS remains authoritative.
abstract final class Env {
  static const allowTestingBypass = bool.fromEnvironment(
    'ALLOW_TESTING_BYPASS',
    defaultValue: false,
  );

  /// Exposes hosted Stripe, PayPal and Flutterwave checkout on Flutter Web.
  ///
  /// The matching server switch must also be enabled. Native mobile builds
  /// keep using App Store / Play Billing to comply with store policies.
  static const externalCheckoutEnabled = bool.fromEnvironment(
    'EXTERNAL_CHECKOUT_ENABLED',
    defaultValue: false,
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://heqkgexzlhdnmrkuikle.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_ugbKSZIhS74iLJ6bJvVQGw_YSmI6D5e',
    ),
  );
}
