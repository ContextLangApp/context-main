import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../services/azure_ai_service.dart';
import '../../widgets/vocabulary_selectable_text.dart';

class SpeakPracticePage extends StatefulWidget {
  const SpeakPracticePage({super.key});

  @override
  State<SpeakPracticePage> createState() => _SpeakPracticePageState();
}

class _SpeakPracticePageState extends State<SpeakPracticePage> {
  final SpeechToText _speech = SpeechToText();
  final AzureAiService _ai = AzureAiService();

  Stopwatch? _speechListenWatch;
  int _speechResultCount = 0;

  bool _speechAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _localeId = 'de_DE';

  bool _loadingFeedback = false;
  String? _feedbackText;
  String? _feedbackError;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _log(String message) {
    debugPrint('[SpeakPracticePage] $message');
  }

  int _ms(Stopwatch stopwatch) => stopwatch.elapsedMilliseconds;

  Future<void> _initSpeech() async {
    final initWatch = Stopwatch()..start();
    _log('STT init start: ts=${DateTime.now().toIso8601String()}');
    final available = await _speech.initialize(
      onStatus: _onStatus,
      onError: (error) {
        _log(
          'STT error: elapsedMs=${_speechListenWatch?.elapsedMilliseconds}, error=$error',
        );
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!mounted) return;
    if (available) {
      final localesWatch = Stopwatch()..start();
      final locales = await _speech.locales();
      localesWatch.stop();
      final german = locales.firstWhere(
        (l) => l.localeId.startsWith('de'),
        orElse: () => locales.first,
      );
      _log(
        'STT init success: initMs=${_ms(initWatch)}, localesMs=${_ms(localesWatch)}, localeCount=${locales.length}, selectedLocale=${german.localeId}',
      );
      setState(() {
        _speechAvailable = true;
        _localeId = german.localeId;
      });
    } else {
      _log('STT init unavailable: initMs=${_ms(initWatch)}');
      setState(() => _speechAvailable = false);
    }
  }

  void _onStatus(String status) {
    _log(
      'STT status: status=$status, listenElapsedMs=${_speechListenWatch?.elapsedMilliseconds}, resultEvents=$_speechResultCount, transcriptLength=${_recognizedText.length}',
    );
    if (status == 'done' || status == 'notListening') {
      setState(() => _isListening = false);
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      _log(
        'STT stop requested: elapsedMs=${_speechListenWatch?.elapsedMilliseconds}',
      );
      final stopWatch = Stopwatch()..start();
      await _speech.stop();
      stopWatch.stop();
      _log('STT stop completed: stopMs=${_ms(stopWatch)}');
      setState(() => _isListening = false);
    } else {
      _speechListenWatch = Stopwatch()..start();
      _speechResultCount = 0;
      _log(
        'STT listen start: ts=${DateTime.now().toIso8601String()}, locale=$_localeId',
      );
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) => setState(() {
          _speechResultCount++;
          _recognizedText = result.recognizedWords;
          _log(
            'STT result: event=$_speechResultCount, elapsedMs=${_speechListenWatch?.elapsedMilliseconds}, final=${result.finalResult}, transcriptLength=${_recognizedText.length}',
          );
        }),
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      _log(
        'STT listen requested: setupMs=${_speechListenWatch?.elapsedMilliseconds}',
      );
    }
  }

  Future<void> _getFeedback() async {
    final feedbackWatch = Stopwatch()..start();
    _log(
      'Feedback pipeline start: ts=${DateTime.now().toIso8601String()}, transcriptLength=${_recognizedText.length}',
    );
    setState(() {
      _loadingFeedback = true;
      _feedbackText = null;
      _feedbackError = null;
    });
    final buffer = StringBuffer();
    try {
      try {
        // Stream the feedback so it appears word-by-word.
        await for (final chunk in _ai.streamSpeakingFeedback(_recognizedText)) {
          if (!mounted) return;
          buffer.write(chunk);
          setState(() {
            _feedbackText = buffer.toString();
            _loadingFeedback = false;
          });
        }
        _log(
          'Feedback pipeline success (streamed): totalMs=${_ms(feedbackWatch)}, feedbackLength=${buffer.length}',
        );
      } catch (streamErr) {
        // Streaming unsupported/failed — fall back to a single-shot reply.
        _log('Feedback stream failed, falling back: $streamErr');
        final feedback = await _ai.getSpeakingFeedback(_recognizedText);
        if (!mounted) return;
        _log(
          'Feedback pipeline success (fallback): totalMs=${_ms(feedbackWatch)}, feedbackLength=${feedback.length}',
        );
        setState(() {
          _feedbackText = feedback;
          _loadingFeedback = false;
        });
      }

      if (mounted &&
          (_feedbackText == null || _feedbackText!.trim().isEmpty)) {
        setState(() {
          _feedbackError =
              "Couldn't get feedback right now. Please try again.";
          _feedbackText = null;
          _loadingFeedback = false;
        });
      }
    } catch (e) {
      _log('Feedback pipeline error: totalMs=${_ms(feedbackWatch)}, error=$e');
      if (mounted) {
        setState(() {
          _feedbackError = "Couldn't get feedback right now. Please try again.";
          _loadingFeedback = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (!_speechAvailable)
                      _ErrorCard(
                        text:
                            'Speech recognition is not available on this device.',
                      )
                    else ...[
                      _InstructionCard(),
                      const SizedBox(height: 16),
                      _RecognizedTextBox(text: _recognizedText),
                      const SizedBox(height: 16),
                      _FeedbackButton(
                        enabled:
                            _recognizedText.isNotEmpty && !_loadingFeedback,
                        loading: _loadingFeedback,
                        onPressed: _getFeedback,
                      ),
                      if (_feedbackText != null) ...[
                        const SizedBox(height: 16),
                        _FeedbackCard(text: _feedbackText!),
                      ],
                      if (_feedbackError != null) ...[
                        const SizedBox(height: 12),
                        _ErrorCard(text: _feedbackError!),
                      ],
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (_speechAvailable)
              _BottomControls(
                isListening: _isListening,
                hasText: _recognizedText.isNotEmpty,
                onToggle: _toggleListening,
                onClear: () => setState(() {
                  _recognizedText = '';
                  _feedbackText = null;
                  _feedbackError = null;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Speaking Practice',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Speak in German and see your words appear below.',
        style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
      ),
    );
  }
}

class _RecognizedTextBox extends StatelessWidget {
  final String text;

  const _RecognizedTextBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: text.isEmpty
          ? const Text(
              'Your spoken words will appear here…',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black38,
                fontStyle: FontStyle.italic,
              ),
            )
          : VocabularySelectableText(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.6,
              ),
            ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _FeedbackButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? const Color(0xFF8B5CF6)
              : const Color(0xFFB8C4E0),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Get AI Feedback',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String text;

  const _FeedbackCard({required this.text});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'AI Feedback',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;

  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.redAccent,
          height: 1.5,
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final bool isListening;
  final bool hasText;
  final VoidCallback onToggle;
  final VoidCallback onClear;

  const _BottomControls({
    required this.isListening,
    required this.hasText,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 8),
      child: Column(
        children: [
          Text(
            isListening ? 'Listening…' : 'Tap to speak',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isListening
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isListening ? null : const Color(0xFFDDE3EA),
              ),
              child: Icon(
                isListening ? Icons.stop : Icons.mic,
                color: isListening ? Colors.white : Colors.black54,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hasText)
            TextButton(
              onPressed: onClear,
              child: const Text(
                'Clear',
                style: TextStyle(color: Color(0xFF8B5CF6)),
              ),
            ),
        ],
      ),
    );
  }
}
