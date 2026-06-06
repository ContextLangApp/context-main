/// Central app configuration.
///
/// The Supabase URL and publishable (anon) key are safe to ship in the client.
/// Real service keys (Azure, etc.) never live here — they stay server-side in
/// Supabase Edge Functions.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://gfdsibvelqceexcgerah.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_vFZdq8NT56-4deP4eH3xOQ_SQQ4GBW2';
}
