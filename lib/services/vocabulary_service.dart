import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_word.dart';

/// Outcome of attempting to save a word to the dictionary.
enum SaveStatus { saved, alreadySaved, error }

class SaveResult {
  final SaveStatus status;

  /// User-facing message, set when [status] is [SaveStatus.error].
  final String? message;

  const SaveResult._(this.status, [this.message]);

  factory SaveResult.saved() => const SaveResult._(SaveStatus.saved);
  factory SaveResult.alreadySaved() =>
      const SaveResult._(SaveStatus.alreadySaved);
  factory SaveResult.error(String message) =>
      SaveResult._(SaveStatus.error, message);
}

/// Saves, fetches, and deletes the signed-in user's dictionary words.
/// Word enrichment is delegated to the `enrich-vocabulary` edge function so
/// the Azure keys stay server-side.
class VocabularyService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Lowercase, punctuation-stripped form used for duplicate detection and the
  /// `(user_id, normalized_word)` unique key.
  static String normalize(String word) {
    return word
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'''^[^\wäöüß]+|[^\wäöüß]+$''', unicode: true), '');
  }

  Future<SaveResult> saveVocabulary(String word, String sourceContext) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return SaveResult.error('Please sign in to save words.');
    }

    final normalized = normalize(word);
    if (normalized.isEmpty) {
      return SaveResult.error('Select a single word to save.');
    }
    if (RegExp(r'\s').hasMatch(normalized)) {
      return SaveResult.error('Please select just one word.');
    }

    try {
      final existing = await _client
          .from('saved_vocabulary')
          .select('id')
          .eq('user_id', userId)
          .eq('normalized_word', normalized)
          .maybeSingle();
      if (existing != null) {
        return SaveResult.alreadySaved();
      }

      final enriched = await _enrich(word.trim(), sourceContext);

      await _client.from('saved_vocabulary').insert({
        'user_id': userId,
        'word': (enriched['word'] as String?)?.trim().isNotEmpty == true
            ? (enriched['word'] as String).trim()
            : word.trim(),
        'normalized_word': normalized,
        'source_context': sourceContext.trim().isEmpty
            ? null
            : sourceContext.trim(),
        'meaning': enriched['meaning'] as String?,
        'pronunciation': enriched['pronunciation'] as String?,
        'example_sentence': enriched['exampleSentence'] as String?,
        'real_life_usage': enriched['realLifeUsage'] as String?,
      });

      return SaveResult.saved();
    } on PostgrestException catch (e) {
      // Unique-violation: the word was saved concurrently or already exists.
      if (e.code == '23505') {
        return SaveResult.alreadySaved();
      }
      return SaveResult.error("Couldn't save the word. Please try again.");
    } catch (_) {
      return SaveResult.error("Couldn't save the word. Please try again.");
    }
  }

  Future<Map<String, dynamic>> _enrich(
    String word,
    String sourceContext,
  ) async {
    final response = await _client.functions.invoke(
      'enrich-vocabulary',
      body: {'word': word, 'sourceContext': sourceContext},
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected enrichment response');
    }
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return data;
  }

  Future<List<SavedWord>> fetchSavedVocabulary() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('saved_vocabulary')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => SavedWord.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteVocabulary(String id) async {
    // RLS scopes the delete to the owner.
    await _client.from('saved_vocabulary').delete().eq('id', id);
  }
}
