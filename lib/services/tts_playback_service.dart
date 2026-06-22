import 'dart:collection';
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

  // Process-wide LRU cache of synthesized audio, keyed by the exact text.
  // Repeated phrases (the constant initial waiter line, "Repeat Waiter", a
  // re-spoken Dictionary word) skip the network entirely. Clips are ~20 KB, so
  // 32 entries stays well under 1 MB. Static so it survives screen instances.
  static const int _maxCacheEntries = 32;
  static final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();

  void _log(String message) {
    debugPrint('[TtsPlaybackService] $message');
  }

  int _ms(Stopwatch stopwatch) => stopwatch.elapsedMilliseconds;

  /// Synthesizes [text] (or reuses a cached clip), plays it, and returns the
  /// audio bytes so callers can cache them for repeat playback.
  Future<Uint8List> speak(String text) async {
    final totalWatch = Stopwatch()..start();
    final cached = _cacheGet(text);
    if (cached != null) {
      _log(
        'speak cacheHit=true textLength=${text.length}, bytes=${cached.length}',
      );
      await playBytes(cached);
      _log('speak complete (cached): totalMs=${_ms(totalWatch)}');
      return cached;
    }
    _log('speak start: cacheHit=false textLength=${text.length}');
    final synthWatch = Stopwatch()..start();
    final bytes = await _azure.synthesizeSpeech(text);
    synthWatch.stop();
    _log(
      'speak synthesized: synthMs=${_ms(synthWatch)}, bytes=${bytes.length}',
    );
    _cachePut(text, bytes);
    final playbackWatch = Stopwatch()..start();
    await playBytes(bytes);
    playbackWatch.stop();
    _log(
      'speak complete: totalMs=${_ms(totalWatch)}, synthMs=${_ms(synthWatch)}, playbackStartMs=${_ms(playbackWatch)}',
    );
    return bytes;
  }

  Uint8List? _cacheGet(String text) {
    final bytes = _cache.remove(text);
    if (bytes != null) {
      _cache[text] = bytes; // re-insert as most-recently-used
    }
    return bytes;
  }

  void _cachePut(String text, Uint8List bytes) {
    _cache[text] = bytes;
    if (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first); // evict least-recently-used
    }
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
