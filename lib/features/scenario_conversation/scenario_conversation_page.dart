import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../services/azure_conversation_service.dart';

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
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final AzureConversationService _azure = AzureConversationService();
  final ScrollController _scrollController = ScrollController();

  final List<_ScenarioMessage> _messages = [];

  bool _isRecording = false;
  bool _loadingResponse = false;
  String? _tip;
  String? _errorText;
  Uint8List? _lastTtsBytes;

  @override
  void initState() {
    super.initState();
    _resetScenario(speak: true);
  }

  Future<void> _toggleRecording() async {
    if (_loadingResponse) return;

    if (_isRecording) {
      setState(() => _isRecording = false);
      final path = await _recorder.stop();
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      if (bytes.isNotEmpty) await _submitAudio(bytes);
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _errorText = 'Microphone permission denied.');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _errorText = null;
      _tip = null;
    });

    final tempPath = '${Directory.systemTemp.path}/scenario_recording.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: tempPath,
    );
  }

  Future<void> _submitAudio(Uint8List bytes) async {
    setState(() => _loadingResponse = true);

    try {
      final transcript = await _azure.transcribeAudio(bytes);
      if (!mounted) return;

      if (transcript.trim().isEmpty) {
        setState(() {
          _loadingResponse = false;
          _errorText = "Couldn't understand — please try again.";
        });
        return;
      }

      setState(() {
        _messages.add(
          _ScenarioMessage(role: _ScenarioRole.user, text: transcript),
        );
        _tip = null;
        _errorText = null;
      });
      _scrollToBottom();

      final historyForService = _messages
          .sublist(0, _messages.length - 1)
          .map(
            (m) => (
              role: m.role == _ScenarioRole.waiter ? 'waiter' : 'user',
              text: m.text,
            ),
          )
          .toList();

      final reply = await _azure.chat(
        history: historyForService,
        latestUserMessage: transcript,
      );
      if (!mounted) return;

      final waiterResponse = reply.waiterResponse.trim().isEmpty
          ? 'Entschuldigung, könnten Sie das bitte wiederholen?'
          : reply.waiterResponse.trim();

      setState(() {
        _messages.add(
          _ScenarioMessage(role: _ScenarioRole.waiter, text: waiterResponse),
        );
        _tip = reply.tip.trim().isEmpty ? null : reply.tip.trim();
      });
      _scrollToBottom();

      final audioBytes = await _azure.synthesizeSpeech(waiterResponse);
      if (!mounted) return;

      _lastTtsBytes = audioBytes;
      setState(() => _loadingResponse = false);
      await _playAudioBytes(audioBytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Error: $e';
        _loadingResponse = false;
      });
    }
  }

  Future<void> _playAudioBytes(Uint8List bytes) async {
    final tempFile = File('${Directory.systemTemp.path}/tts_output.mp3');
    await tempFile.writeAsBytes(bytes);
    await _player.stop();
    await _player.play(DeviceFileSource(tempFile.path));
  }

  Future<void> _speakLatestWaiterMessage() async {
    if (_lastTtsBytes != null) {
      await _playAudioBytes(_lastTtsBytes!);
      return;
    }
    final text = _latestWaiterMessage;
    if (text == null) return;
    try {
      final bytes = await _azure.synthesizeSpeech(text);
      if (!mounted) return;
      _lastTtsBytes = bytes;
      await _playAudioBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not play audio: $e');
    }
  }

  Future<void> _speakInitialMessage() async {
    try {
      final bytes = await _azure.synthesizeSpeech(_initialWaiterMessage);
      if (!mounted) return;
      _lastTtsBytes = bytes;
      await _playAudioBytes(bytes);
    } catch (_) {
      // non-fatal: user can tap Repeat Waiter to retry
    }
  }

  String? get _latestWaiterMessage {
    for (final message in _messages.reversed) {
      if (message.role == _ScenarioRole.waiter) return message.text;
    }
    return null;
  }

  Future<void> _resetScenario({bool speak = false}) async {
    if (_isRecording) await _recorder.stop();
    await _player.stop();

    setState(() {
      _messages
        ..clear()
        ..add(
          const _ScenarioMessage(
            role: _ScenarioRole.waiter,
            text: _initialWaiterMessage,
          ),
        );
      _isRecording = false;
      _loadingResponse = false;
      _tip = null;
      _errorText = null;
      _lastTtsBytes = null;
    });
    _scrollToBottom();

    if (speak) _speakInitialMessage();
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
    _recorder.dispose();
    _player.dispose();
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
                      isRecording: _isRecording,
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
              isRecording: _isRecording,
              loadingResponse: _loadingResponse,
              onMicPressed: _toggleRecording,
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
  final bool isRecording;

  const _ChatCard({
    required this.messages,
    required this.loadingResponse,
    required this.isRecording,
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
          if (isRecording) ...[
            const _RecordingBubble(),
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

class _RecordingBubble extends StatelessWidget {
  const _RecordingBubble();

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
        child: const Text(
          '● Recording...',
          style: TextStyle(
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
  final bool isRecording;
  final bool loadingResponse;
  final VoidCallback onMicPressed;
  final VoidCallback onRepeatPressed;
  final VoidCallback onClearPressed;

  const _BottomControls({
    required this.isRecording,
    required this.loadingResponse,
    required this.onMicPressed,
    required this.onRepeatPressed,
    required this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    final micEnabled = !loadingResponse;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      color: const Color(0xFFEFF3F7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isRecording
                ? 'Recording...'
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
                gradient: isRecording
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isRecording ? null : const Color(0xFFDDE3EA),
              ),
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: isRecording ? Colors.white : Colors.black54,
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
