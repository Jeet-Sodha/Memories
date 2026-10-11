/// Put your real values here LOCALLY. Never use the secret / service-role key.
/// Supabase dashboard -> Project Settings -> API.
class SupabaseConfig {
  static const String url = 'https://zacylrnrslgervecraul.supabase.co';
  static const String publishableKey = 'sb_publishable_vj8Kh6mFOn8AplcNexgJFw_EEPb_46i';

  static const String mediaBucket = 'memory-media';
  static const String avatarBucket = 'avatars';

  static bool get isConfigured =>
      !url.contains('<YOUR_') && !publishableKey.contains('<YOUR_');
}
