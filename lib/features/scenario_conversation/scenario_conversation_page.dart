import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../services/gemini_service.dart';

const String _initialWaiterMessage =
    'Guten Tag! Willkommen in unserem Restaurant. Möchten Sie schon etwas bestellen?';

enum _ScenarioRole { waiter, user }

class _ScenarioMessage {
  final _ScenarioRole role;
  final String text;

  const _ScenarioMessage({required this.role, required this.text});
}

class ScenarioConversationPage extends StatefulWidget {
  const ScenarioConversationPage({super.key});

  @override
  State<ScenarioConversationPage> createState() =>
      _ScenarioConversationPageState();
}

class _ScenarioConversationPageState extends State<ScenarioConversationPage> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final GeminiService _geminiService = GeminiService();
  final ScrollController _scrollController = ScrollController();

  final List<_ScenarioMessage> _messages = [];

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _loadingResponse = false;
  bool _hasSubmittedCurrentTranscript = false;
  String _localeId = 'de_DE';
  String _currentTranscript = '';
  String? _tip;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _resetScenario(speak: true);
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!mounted) return;

    if (!available) {
      setState(() {
        _speechAvailable = false;
        _errorText = 'Speech recognition is not available on this device.';
      });
      return;
    }

    final locales = await _speech.locales();
    LocaleName? selectedLocale;
    for (final locale in locales) {
      if (locale.localeId == 'de_DE') {
        selectedLocale = locale;
        break;
      }
    }
    selectedLocale ??= locales
        .where((locale) => locale.localeId.startsWith('de'))
        .cast<LocaleName?>()
        .firstWhere((locale) => locale != null, orElse: () => null);
    selectedLocale ??= locales.isNotEmpty ? locales.first : null;

    if (!mounted) return;
    setState(() {
      _speechAvailable = true;
      _localeId = selectedLocale?.localeId ?? 'de_DE';
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('de-DE');
    await _tts.setSpeechRate(0.45);
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (!mounted) return;
      setState(() => _isListening = false);
      final transcript = _currentTranscript.trim();
      if (transcript.isNotEmpty && !_hasSubmittedCurrentTranscript) {
        _hasSubmittedCurrentTranscript = true;
        _submitTranscript(transcript);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable || _loadingResponse) return;

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    setState(() {
      _currentTranscript = '';
      _hasSubmittedCurrentTranscript = false;
      _errorText = null;
      _isListening = true;
    });

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _currentTranscript = result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitTranscript(String transcript) async {
    setState(() {
      _messages.add(
        _ScenarioMessage(role: _ScenarioRole.user, text: transcript),
      );
      _loadingResponse = true;
      _tip = null;
      _errorText = null;
      _currentTranscript = '';
      _hasSubmittedCurrentTranscript = true;
    });
    _scrollToBottom();

    try {
      final reply = await _geminiService.getScenarioConversationReply(
        conversationHistory: _conversationHistory,
        userMessage: transcript,
      );
      if (!mounted) return;

      final waiterResponse = reply.waiterResponse.trim();
      setState(() {
        _messages.add(
          _ScenarioMessage(
            role: _ScenarioRole.waiter,
            text: waiterResponse.isEmpty
                ? 'Entschuldigung, könnten Sie das bitte wiederholen?'
                : waiterResponse,
          ),
        );
        _tip = reply.tip.trim().isEmpty ? null : reply.tip.trim();
        _loadingResponse = false;
      });
      _scrollToBottom();
      await _speakLatestWaiterMessage();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Error: $e';
        _loadingResponse = false;
      });
    }
  }

  String get _conversationHistory {
    return _messages
        .map((message) {
          final speaker = message.role == _ScenarioRole.waiter
              ? 'Waiter'
              : 'Learner';
          return '$speaker: ${message.text}';
        })
        .join('\n');
  }

  String? get _latestWaiterMessage {
    for (final message in _messages.reversed) {
      if (message.role == _ScenarioRole.waiter) return message.text;
    }
    return null;
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _speakLatestWaiterMessage() async {
    final text = _latestWaiterMessage;
    if (text != null && text.isNotEmpty) {
      await _speak(text);
    }
  }

  Future<void> _resetScenario({bool speak = false}) async {
    if (_isListening) await _speech.stop();
    setState(() {
      _messages
        ..clear()
        ..add(
          const _ScenarioMessage(
            role: _ScenarioRole.waiter,
            text: _initialWaiterMessage,
          ),
        );
      _currentTranscript = '';
      _hasSubmittedCurrentTranscript = false;
      _tip = null;
      _errorText = null;
      _isListening = false;
      _loadingResponse = false;
    });
    _scrollToBottom();
    if (speak) await _speak(_initialWaiterMessage);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
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
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScenarioHeader(),
                    const SizedBox(height: 16),
                    _ChatCard(
                      messages: _messages,
                      loadingResponse: _loadingResponse,
                      transcript: _currentTranscript,
                    ),
                    if (_tip != null) ...[
                      const SizedBox(height: 16),
                      _TipCard(text: _tip!),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      _ErrorCard(text: _errorText!),
                    ],
                  ],
                ),
              ),
            ),
            _BottomControls(
              speechAvailable: _speechAvailable,
              isListening: _isListening,
              loadingResponse: _loadingResponse,
              onMicPressed: _toggleListening,
              onRepeatPressed: _speakLatestWaiterMessage,
              onClearPressed: () => _resetScenario(speak: true),
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
          const Expanded(
            child: Text(
              'Conversation Scenario',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioHeader extends StatelessWidget {
  const _ScenarioHeader();

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
          const Text(
            'Ordering at a Restaurant',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You are in a German restaurant. Practice ordering food and drinks.',
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _RoleChip(label: 'Waiter', icon: Icons.room_service_outlined),
              SizedBox(width: 8),
              _RoleChip(label: 'You', icon: Icons.person_outline),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _RoleChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B5CF6),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final List<_ScenarioMessage> messages;
  final bool loadingResponse;
  final String transcript;

  const _ChatCard({
    required this.messages,
    required this.loadingResponse,
    required this.transcript,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final message in messages) ...[
            _MessageBubble(message: message),
            const SizedBox(height: 12),
          ],
          if (transcript.isNotEmpty) ...[
            _LiveTranscriptBubble(text: transcript),
            const SizedBox(height: 12),
          ],
          if (loadingResponse)
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6),
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ScenarioMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _ScenarioRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF8B5CF6) : const Color(0xFFEFF3F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _LiveTranscriptBubble extends StatelessWidget {
  final String text;

  const _LiveTranscriptBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFB8C4E0),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String text;

  const _TipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Tip',
              style: TextStyle(
                color: Color(0xFFEC4899),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
  final bool speechAvailable;
  final bool isListening;
  final bool loadingResponse;
  final VoidCallback onMicPressed;
  final VoidCallback onRepeatPressed;
  final VoidCallback onClearPressed;

  const _BottomControls({
    required this.speechAvailable,
    required this.isListening,
    required this.loadingResponse,
    required this.onMicPressed,
    required this.onRepeatPressed,
    required this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    final micEnabled = speechAvailable && !loadingResponse;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      color: const Color(0xFFEFF3F7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isListening
                ? 'Listening...'
                : loadingResponse
                ? 'Waiter is replying...'
                : 'Tap to speak',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: micEnabled ? onMicPressed : null,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRepeatPressed,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Repeat Waiter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: onClearPressed,
                  child: const Text(
                    'Clear Scenario',
                    style: TextStyle(color: Color(0xFF8B5CF6)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
