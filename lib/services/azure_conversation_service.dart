import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

const _supabaseUrl = 'https://gfdsibvelqceexcgerah.supabase.co';
const _supabaseAnonKey =
    'sb_publishable_vFZdq8NT56-4deP4eH3xOQ_SQQ4GBW2';

class AzureConversationService {
  static const _functionsBase = '$_supabaseUrl/functions/v1';

  String get _authHeader {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? _supabaseAnonKey;
    return 'Bearer $token';
  }

  Future<String> transcribeAudio(Uint8List wavBytes) async {
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-stt'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'audio/wav',
      },
      body: wavBytes,
    );

    if (response.statusCode != 200) {
      throw Exception('STT failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      throw Exception('STT error: ${json['error']}');
    }
    return (json['transcript'] as String?) ?? '';
  }

  Future<({String waiterResponse, String tip})> chat({
    required List<({String role, String text})> history,
    required String latestUserMessage,
  }) async {
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

    if (response.statusCode != 200) {
      throw Exception('Chat failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      throw Exception('Chat error: ${json['error']}');
    }

    return (
      waiterResponse: (json['waiterResponse'] as String?) ?? '',
      tip: (json['tip'] as String?) ?? '',
    );
  }

  Future<Uint8List> synthesizeSpeech(String text) async {
    final response = await http.post(
      Uri.parse('$_functionsBase/azure-tts'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode != 200) {
      throw Exception('TTS failed (${response.statusCode}): ${response.body}');
    }

    return response.bodyBytes;
  }
}
