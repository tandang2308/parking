/// Supabase connection settings from `--dart-define` (never hard-coded,
/// never committed). Only the public `anon` key may be used in the client
/// (CLAUDE.md, SPEC-001 NFR-7).
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  /// Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
  factory SupabaseConfig.fromEnvironment() => const SupabaseConfig(
        url: String.fromEnvironment('SUPABASE_URL'),
        anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  final String url;
  final String anonKey;

  /// Both values present and the URL is absolute http(s).
  bool get isConfigured {
    if (url.trim().isEmpty || anonKey.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
  }

  /// URL without a trailing slash (the client appends `/rest/v1`).
  String get normalizedUrl {
    final u = url.trim();
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }
}
