import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'https://gfdsibvelqceexcgerah.supabase.co';
const _supabaseAnonKey = 'sb_publishable_vFZdq8NT56-4deP4eH3xOQ_SQQ4GBW2';

class AzureConversationService {
  static const _functionsBase = '$_supabaseUrl/functions/v1';

  void _log(String message) {
    debugPrint('[AzureConversationService] $message');
  }

  String _bodyPreview(String body) {
    const maxLength = 700;
    if (body.length <= maxLength) return body;
    return '${body.substring(0, maxLength)}...';
  }

  String _bytesPreview(Uint8List bytes) {
    return bytes
        .take(12)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
  }

  String get _authMode {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null ? 'anon-key fallback' : 'signed-in session';
  }

  String get _authHeader {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? _supabaseAnonKey;
    return 'Bearer $token';
  }

  Future<String> transcribeAudio(Uint8List wavBytes) async {
    _log(
      'STT start: bytes=${wavBytes.length}, prefix=${_bytesPreview(wavBytes)}, auth=$_authMode',
    );
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-stt'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'audio/wav'},
      body: wavBytes,
    );
    _log(
      'STT response: status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      _log('STT failure body: ${_bodyPreview(response.body)}');
      throw Exception('STT failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      _log('STT JSON error: ${json['error']}');
      throw Exception('STT error: ${json['error']}');
    }
    final transcript = (json['transcript'] as String?) ?? '';
    _log('STT success: transcriptLength=${transcript.length}');
    return transcript;
  }

  Future<({String waiterResponse, String tip})> chat({
    required List<({String role, String text})> history,
    required String latestUserMessage,
  }) async {
    _log(
      'Chat start: historyCount=${history.length}, latestLength=${latestUserMessage.length}, auth=$_authMode',
    );
    final historyJson = history
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();

    final response = await http.post(
      Uri.parse('$_functionsBase/azure-chat'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'conversationHistory': historyJson,
        'latestUserMessage': latestUserMessage,
      }),
    );
    _log(
      'Chat response: status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      _log('Chat failure body: ${_bodyPreview(response.body)}');
      throw Exception('Chat failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      _log('Chat JSON error: ${json['error']}');
      throw Exception('Chat error: ${json['error']}');
    }

    _log(
      'Chat success: waiterLength=${(json['waiterResponse'] as String?)?.length ?? 0}, tipLength=${(json['tip'] as String?)?.length ?? 0}',
    );

    return (
      waiterResponse: (json['waiterResponse'] as String?) ?? '',
      tip: (json['tip'] as String?) ?? '',
    );
  }

  Future<Uint8List> synthesizeSpeech(String text) async {
    _log('TTS start: textLength=${text.length}, auth=$_authMode');
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-tts'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );
    _log(
      'TTS response: status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}, prefix=${_bytesPreview(response.bodyBytes)}',
    );

    if (response.statusCode != 200) {
      _log('TTS failure body: ${_bodyPreview(response.body)}');
      throw Exception('TTS failed (${response.statusCode}): ${response.body}');
    }

    _log('TTS success: audioBytes=${response.bodyBytes.length}');
    return response.bodyBytes;
  }
}
