/// Runtime configuration. Nothing here is hardcoded — values are passed in
/// via --dart-define at build/run time, so this file is safe to commit even
/// once real values exist elsewhere.
///
/// Example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// The Supabase anon key is meant to be public (Supabase's security model
/// relies on Row-Level Security, not on this key being secret) — but
/// keeping it out of source still avoids needing to edit code to swap
/// environments (local Supabase project vs. a teammate's, etc).
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Inference backend base URL. Defaults to the live Railway deployment.
  /// Override with --dart-define=BACKEND_URL=http://127.0.0.1:8000 when using
  /// `adb reverse tcp:8000 tcp:8000` for local backend development.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://basirahai-api-production.up.railway.app',
  );

  static bool get isSupabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
