import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'azure_ai_service.dart';

/// Fetches Azure TTS audio and plays it back. Shared by any screen that needs
/// to speak German text, so playback logic lives in one place.
class TtsPlaybackService {
  TtsPlaybackService({AzureAiService? azure})
    : _azure = azure ?? AzureAiService();

  final AzureAiService _azure;
  final AudioPlayer _player = AudioPlayer();

  // Unique-ish per instance so concurrent screens don't overwrite each other.
  final String _tempFileName =
      'tts_${DateTime.now().microsecondsSinceEpoch}.mp3';

  /// Synthesizes [text], plays it, and returns the audio bytes so callers can
  /// cache them for repeat playback without another network call.
  Future<Uint8List> speak(String text) async {
    final bytes = await _azure.synthesizeSpeech(text);
    await playBytes(bytes);
    return bytes;
  }

  /// Plays already-fetched audio bytes (e.g. cached TTS output).
  Future<void> playBytes(Uint8List bytes) async {
    final tempFile = File('${Directory.systemTemp.path}/$_tempFileName');
    await tempFile.writeAsBytes(bytes);
    await _player.stop();
    await _player.play(DeviceFileSource(tempFile.path));
  }

  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}
