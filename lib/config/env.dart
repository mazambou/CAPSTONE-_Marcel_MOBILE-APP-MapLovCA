/// Compile-time environment values.
///
/// Never commit a `service_role` key to a Flutter application. The client uses
/// only the Supabase publishable/anon key; PostgreSQL RLS remains authoritative.
abstract final class Env {
  static const allowTestingBypass = bool.fromEnvironment(
    'ALLOW_TESTING_BYPASS',
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
