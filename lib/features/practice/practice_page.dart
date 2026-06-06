import 'package:flutter/material.dart';

import '../../models/saved_word.dart';
import '../../services/tts_playback_service.dart';
import '../../services/vocabulary_service.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final VocabularyService _service = VocabularyService();
  final TtsPlaybackService _tts = TtsPlaybackService();

  bool _loading = true;
  String? _error;
  List<SavedWord> _words = const [];

  // id of the word currently being spoken, for the per-item loading spinner.
  String? _speakingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final words = await _service.fetchSavedVocabulary();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load your dictionary. Pull to retry.";
        _loading = false;
      });
    }
  }

  Future<void> _delete(SavedWord word) async {
    final previous = _words;
    setState(() => _words = _words.where((w) => w.id != word.id).toList());
    try {
      await _service.deleteVocabulary(word.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _words = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete the word.")),
      );
    }
  }

  Future<void> _speak(SavedWord word) async {
    if (_speakingId != null) return;
    setState(() => _speakingId = word.id);
    try {
      final example = word.exampleSentence?.trim();
      final text = (example == null || example.isEmpty)
          ? word.word
          : '${word.word}. $example';
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't play audio.")),
        );
      }
    } finally {
      if (mounted) setState(() => _speakingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Dictionary',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      );
    }

    if (_error != null) {
      return _CenteredMessage(text: _error!, onRetry: _load);
    }

    if (_words.isEmpty) {
      return const _CenteredMessage(
        text: 'Save words from your lessons to practice them here.',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF8B5CF6),
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _words.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final word = _words[index];
          return _DictionaryCard(
            word: word,
            speaking: _speakingId == word.id,
            onSpeak: () => _speak(word),
            onDelete: () => _delete(word),
          );
        },
      ),
    );
  }
}

class _DictionaryCard extends StatelessWidget {
  const _DictionaryCard({
    required this.word,
    required this.speaking,
    required this.onSpeak,
    required this.onDelete,
  });

  final SavedWord word;
  final bool speaking;
  final VoidCallback onSpeak;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  word.word,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: speaking ? null : onSpeak,
                icon: speaking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF8B5CF6),
                        ),
                      )
                    : const Icon(
                        Icons.volume_up_outlined,
                        color: Color(0xFF8B5CF6),
                      ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEC4899),
                ),
              ),
            ],
          ),
          if (word.pronunciation != null &&
              word.pronunciation!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                word.pronunciation!,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ),
          if (word.meaning != null && word.meaning!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              word.meaning!,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ],
          if (word.exampleSentence != null &&
              word.exampleSentence!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _LabeledLine(
              label: 'Example',
              text: word.exampleSentence!,
              color: const Color(0xFF8B5CF6),
            ),
          ],
          if (word.realLifeUsage != null &&
              word.realLifeUsage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _LabeledLine(
              label: 'Usage',
              text: word.realLifeUsage!,
              color: const Color(0xFFEC4899),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFF8B5CF6)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
