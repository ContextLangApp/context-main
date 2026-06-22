import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Single gateway for the app's cloud AI, all proxied through Supabase Edge
/// Functions backed by Azure (Azure Speech for STT/TTS, Azure AI Foundry for
/// the LLM). No AI-provider keys live in the client.
class AzureAiService {
  static const _functionsBase = '${AppConfig.supabaseUrl}/functions/v1';

  void _log(String message) {
    debugPrint('[AzureAiService] $message');
  }

  String _now() => DateTime.now().toIso8601String();

  int _ms(Stopwatch stopwatch) => stopwatch.elapsedMilliseconds;

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
    final token = session?.accessToken ?? AppConfig.supabaseAnonKey;
    return 'Bearer $token';
  }

  Future<String> transcribeAudio(Uint8List wavBytes) async {
    final totalWatch = Stopwatch()..start();
    _log(
      'STT start: ts=${_now()}, bytes=${wavBytes.length}, prefix=${_bytesPreview(wavBytes)}, auth=$_authMode',
    );
    final edgeWatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-stt'),
      headers: {'Authorization': _authHeader, 'Content-Type': 'audio/wav'},
      body: wavBytes,
    );
    edgeWatch.stop();
    _log(
      'STT edge response: edgeCallMs=${_ms(edgeWatch)}, totalMs=${_ms(totalWatch)}, status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      _log(
        'STT failure: totalMs=${_ms(totalWatch)}, body=${_bodyPreview(response.body)}',
      );
      throw Exception('STT failed (${response.statusCode}): ${response.body}');
    }

    final decodeWatch = Stopwatch()..start();
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    decodeWatch.stop();
    if (json.containsKey('error')) {
      _log(
        'STT JSON error: totalMs=${_ms(totalWatch)}, decodeMs=${_ms(decodeWatch)}, error=${json['error']}',
      );
      throw Exception('STT error: ${json['error']}');
    }
    final transcript = (json['transcript'] as String?) ?? '';
    _log(
      'STT success: totalMs=${_ms(totalWatch)}, edgeCallMs=${_ms(edgeWatch)}, decodeMs=${_ms(decodeWatch)}, transcriptLength=${transcript.length}',
    );
    return transcript;
  }

  Future<({String waiterResponse, String tip})> chat({
    required List<({String role, String text})> history,
    required String latestUserMessage,
  }) async {
    final totalWatch = Stopwatch()..start();
    _log(
      'Chat start: ts=${_now()}, historyCount=${history.length}, latestLength=${latestUserMessage.length}, auth=$_authMode',
    );
    final historyJson = history
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    final requestBody = jsonEncode({
      'conversationHistory': historyJson,
      'latestUserMessage': latestUserMessage,
    });

    final edgeWatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-chat'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );
    edgeWatch.stop();
    _log(
      'Chat edge response: edgeCallMs=${_ms(edgeWatch)}, totalMs=${_ms(totalWatch)}, requestBytes=${utf8.encode(requestBody).length}, status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      _log(
        'Chat failure: totalMs=${_ms(totalWatch)}, body=${_bodyPreview(response.body)}',
      );
      throw Exception('Chat failed (${response.statusCode}): ${response.body}');
    }

    final decodeWatch = Stopwatch()..start();
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    decodeWatch.stop();
    if (json.containsKey('error')) {
      _log(
        'Chat JSON error: totalMs=${_ms(totalWatch)}, decodeMs=${_ms(decodeWatch)}, error=${json['error']}',
      );
      throw Exception('Chat error: ${json['error']}');
    }

    _log(
      'Chat success: totalMs=${_ms(totalWatch)}, edgeCallMs=${_ms(edgeWatch)}, decodeMs=${_ms(decodeWatch)}, waiterLength=${(json['waiterResponse'] as String?)?.length ?? 0}, tipLength=${(json['tip'] as String?)?.length ?? 0}',
    );

    return (
      waiterResponse: (json['waiterResponse'] as String?) ?? '',
      tip: (json['tip'] as String?) ?? '',
    );
  }

  Future<Uint8List> synthesizeSpeech(String text) async {
    final totalWatch = Stopwatch()..start();
    _log('TTS start: ts=${_now()}, textLength=${text.length}, auth=$_authMode');
    final requestBody = jsonEncode({'text': text});
    final edgeWatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-tts'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );
    edgeWatch.stop();
    _log(
      'TTS edge response: edgeCallMs=${_ms(edgeWatch)}, totalMs=${_ms(totalWatch)}, requestBytes=${utf8.encode(requestBody).length}, status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}, prefix=${_bytesPreview(response.bodyBytes)}',
    );

    if (response.statusCode != 200) {
      _log(
        'TTS failure: totalMs=${_ms(totalWatch)}, body=${_bodyPreview(response.body)}',
      );
      throw Exception('TTS failed (${response.statusCode}): ${response.body}');
    }

    _log(
      'TTS success: totalMs=${_ms(totalWatch)}, edgeCallMs=${_ms(edgeWatch)}, audioBytes=${response.bodyBytes.length}',
    );
    return response.bodyBytes;
  }

  Future<String> getSpeakingFeedback(String transcript) async {
    final totalWatch = Stopwatch()..start();
    _log(
      'Feedback start: ts=${_now()}, transcriptLength=${transcript.length}, auth=$_authMode',
    );
    final requestBody = jsonEncode({'transcript': transcript});
    final edgeWatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse('$_functionsBase/speaking-feedback'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );
    edgeWatch.stop();
    _log(
      'Feedback edge response: edgeCallMs=${_ms(edgeWatch)}, totalMs=${_ms(totalWatch)}, requestBytes=${utf8.encode(requestBody).length}, status=${response.statusCode}, contentType=${response.headers['content-type']}, bodyBytes=${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      _log(
        'Feedback failure: totalMs=${_ms(totalWatch)}, body=${_bodyPreview(response.body)}',
      );
      throw Exception(
        'Feedback failed (${response.statusCode}): ${response.body}',
      );
    }

    final decodeWatch = Stopwatch()..start();
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    decodeWatch.stop();
    if (json.containsKey('error')) {
      _log(
        'Feedback JSON error: totalMs=${_ms(totalWatch)}, decodeMs=${_ms(decodeWatch)}, error=${json['error']}',
      );
      throw Exception('Feedback error: ${json['error']}');
    }

    final feedback = (json['feedback'] as String?) ?? '';
    _log(
      'Feedback success: totalMs=${_ms(totalWatch)}, edgeCallMs=${_ms(edgeWatch)}, decodeMs=${_ms(decodeWatch)}, feedbackLength=${feedback.length}',
    );
    return feedback;
  }

  Future<Map<String, dynamic>> enrichVocabulary({
    required String word,
    required String sourceContext,
  }) async {
    final totalWatch = Stopwatch()..start();
    _log(
      'Enrich start: ts=${_now()}, wordLength=${word.length}, contextLength=${sourceContext.length}, auth=$_authMode',
    );
    final requestBody = jsonEncode({
      'word': word,
      'sourceContext': sourceContext,
    });
    final edgeWatch = Stopwatch()..start();
    final response = await http.post(
      Uri.parse('$_functionsBase/enrich-vocabulary'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: requestBody,
    );
    edgeWatch.stop();
    _log(
      'Enrich edge response: edgeCallMs=${_ms(edgeWatch)}, totalMs=${_ms(totalWatch)}, requestBytes=${utf8.encode(requestBody).length}, status=${response.statusCode}, bodyBytes=${response.bodyBytes.length}',
    );

    if (response.statusCode != 200) {
      _log(
        'Enrich failure: totalMs=${_ms(totalWatch)}, body=${_bodyPreview(response.body)}',
      );
      throw Exception(
        'Enrich failed (${response.statusCode}): ${response.body}',
      );
    }

    final decodeWatch = Stopwatch()..start();
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    decodeWatch.stop();
    if (json.containsKey('error')) {
      _log(
        'Enrich JSON error: totalMs=${_ms(totalWatch)}, decodeMs=${_ms(decodeWatch)}, error=${json['error']}',
      );
      throw Exception('Enrich error: ${json['error']}');
    }
    _log(
      'Enrich success: totalMs=${_ms(totalWatch)}, edgeCallMs=${_ms(edgeWatch)}, decodeMs=${_ms(decodeWatch)}',
    );
    return json;
  }
}
