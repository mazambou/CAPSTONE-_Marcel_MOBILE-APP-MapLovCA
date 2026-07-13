/// Compile-time environment values.
///
/// Never commit a `service_role` key to a Flutter application. The client uses
/// only the Supabase publishable/anon key; PostgreSQL RLS remains authoritative.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
}
