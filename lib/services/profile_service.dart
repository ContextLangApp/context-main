import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the signed-in user's `profiles` row. Centralizes the profile queries
/// that were previously duplicated across the app.
class ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Whether the current user has a profile row (i.e. completed onboarding).
  Future<bool> profileExists() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return row != null;
  }

  /// The current user's favorite topics, or empty if unset / not signed in.
  Future<List<String>> favoriteTopics() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final row = await _client
        .from('profiles')
        .select('favorite_topics')
        .eq('id', userId)
        .maybeSingle();
    final topics = row?['favorite_topics'];
    if (topics is List) return topics.cast<String>();
    return [];
  }
}
