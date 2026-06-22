import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_word.dart';
import 'azure_ai_service.dart';

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
  final AzureAiService _ai = AzureAiService();

  SupabaseClient get _client => Supabase.instance.client;

  void _log(String message) {
    debugPrint('[VocabularyService] $message');
  }

  int _ms(Stopwatch stopwatch) => stopwatch.elapsedMilliseconds;

  /// Lowercase, punctuation-stripped form used for duplicate detection and the
  /// `(user_id, normalized_word)` unique key.
  static String normalize(String word) {
    return word.trim().toLowerCase().replaceAll(
      RegExp(r'''^[^\wäöüß]+|[^\wäöüß]+$''', unicode: true),
      '',
    );
  }

  Future<SaveResult> saveVocabulary(String word, String sourceContext) async {
    final totalWatch = Stopwatch()..start();
    _log(
      'saveVocabulary start: ts=${DateTime.now().toIso8601String()}, wordLength=${word.length}, contextLength=${sourceContext.length}',
    );
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _log('saveVocabulary aborted: no user, totalMs=${_ms(totalWatch)}');
      return SaveResult.error('Please sign in to save words.');
    }

    final normalizeWatch = Stopwatch()..start();
    final normalized = normalize(word);
    normalizeWatch.stop();
    _log(
      'normalize done: normalizeMs=${_ms(normalizeWatch)}, normalizedLength=${normalized.length}, totalMs=${_ms(totalWatch)}',
    );
    if (normalized.isEmpty) {
      _log(
        'saveVocabulary aborted: empty normalized word, totalMs=${_ms(totalWatch)}',
      );
      return SaveResult.error('Select a single word to save.');
    }
    if (RegExp(r'\s').hasMatch(normalized)) {
      _log(
        'saveVocabulary aborted: multi-word selection, totalMs=${_ms(totalWatch)}',
      );
      return SaveResult.error('Please select just one word.');
    }

    try {
      final duplicateWatch = Stopwatch()..start();
      final existing = await _client
          .from('saved_vocabulary')
          .select('id')
          .eq('user_id', userId)
          .eq('normalized_word', normalized)
          .maybeSingle();
      duplicateWatch.stop();
      _log(
        'duplicate check done: duplicateCheckMs=${_ms(duplicateWatch)}, totalMs=${_ms(totalWatch)}, found=${existing != null}',
      );
      if (existing != null) {
        _log(
          'saveVocabulary complete: status=alreadySaved, totalMs=${_ms(totalWatch)}',
        );
        return SaveResult.alreadySaved();
      }

      final enrichWatch = Stopwatch()..start();
      final enriched = await _ai.enrichVocabulary(
        word: word.trim(),
        sourceContext: sourceContext,
      );
      enrichWatch.stop();
      _log(
        'enrichment done: enrichMs=${_ms(enrichWatch)}, totalMs=${_ms(totalWatch)}',
      );

      final insertWatch = Stopwatch()..start();
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
      insertWatch.stop();
      _log(
        'insert done: insertMs=${_ms(insertWatch)}, totalMs=${_ms(totalWatch)}',
      );

      _log('saveVocabulary complete: status=saved, totalMs=${_ms(totalWatch)}');
      return SaveResult.saved();
    } on PostgrestException catch (e) {
      _log(
        'saveVocabulary PostgrestException: totalMs=${_ms(totalWatch)}, code=${e.code}, message=${e.message}',
      );
      // Unique-violation: the word was saved concurrently or already exists.
      if (e.code == '23505') {
        _log(
          'saveVocabulary complete: status=alreadySaved, totalMs=${_ms(totalWatch)}',
        );
        return SaveResult.alreadySaved();
      }
      return SaveResult.error("Couldn't save the word. Please try again.");
    } catch (e) {
      _log('saveVocabulary error: totalMs=${_ms(totalWatch)}, error=$e');
      return SaveResult.error("Couldn't save the word. Please try again.");
    }
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
