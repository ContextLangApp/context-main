import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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

  void _log(String message) {
    debugPrint('[TtsPlaybackService] $message');
  }

  int _ms(Stopwatch stopwatch) => stopwatch.elapsedMilliseconds;

  /// Synthesizes [text], plays it, and returns the audio bytes so callers can
  /// cache them for repeat playback without another network call.
  Future<Uint8List> speak(String text) async {
    final totalWatch = Stopwatch()..start();
    _log('speak start: textLength=${text.length}');
    final synthWatch = Stopwatch()..start();
    final bytes = await _azure.synthesizeSpeech(text);
    synthWatch.stop();
    _log(
      'speak synthesized: synthMs=${_ms(synthWatch)}, bytes=${bytes.length}',
    );
    final playbackWatch = Stopwatch()..start();
    await playBytes(bytes);
    playbackWatch.stop();
    _log(
      'speak complete: totalMs=${_ms(totalWatch)}, synthMs=${_ms(synthWatch)}, playbackStartMs=${_ms(playbackWatch)}',
    );
    return bytes;
  }

  /// Plays already-fetched audio bytes (e.g. cached TTS output).
  Future<void> playBytes(Uint8List bytes) async {
    final totalWatch = Stopwatch()..start();
    final tempFile = File('${Directory.systemTemp.path}/$_tempFileName');
    final writeWatch = Stopwatch()..start();
    await tempFile.writeAsBytes(bytes);
    writeWatch.stop();
    final stopWatch = Stopwatch()..start();
    await _player.stop();
    stopWatch.stop();
    final playWatch = Stopwatch()..start();
    await _player.play(DeviceFileSource(tempFile.path));
    playWatch.stop();
    _log(
      'playBytes complete: totalMs=${_ms(totalWatch)}, writeMs=${_ms(writeWatch)}, stopMs=${_ms(stopWatch)}, playStartMs=${_ms(playWatch)}, bytes=${bytes.length}, path=${tempFile.path}',
    );
  }

  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}
