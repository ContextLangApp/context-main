import 'dart:convert';
import 'package:http/http.dart' as http;

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _model = 'gemini-2.5-flash';

class ScenarioConversationReply {
  final String waiterResponse;
  final String tip;

  const ScenarioConversationReply({
    required this.waiterResponse,
    required this.tip,
  });
}

class GeminiService {
  Future<String> getGermanSpeakingFeedback(String transcript) async {
    final prompt =
        'You are a friendly German tutor. The learner said: "$transcript". '
        'Reply briefly. Correct major mistakes, explain in simple English, '
        'and give one improved German version.';

    return _generateText(prompt);
  }

  Future<ScenarioConversationReply> getScenarioConversationReply({
    required String conversationHistory,
    required String userMessage,
  }) async {
    final responseText = await _generateText(
      'You are acting as a waiter in a German restaurant conversation practice. '
      'The learner is practicing German. Continue the conversation naturally '
      'in simple A2/B1 German. Also provide one short English correction or '
      'learning tip.\n\n'
      'Return the answer in this exact JSON format:\n'
      '{\n'
      '  "waiterResponse": "...",\n'
      '  "tip": "..."\n'
      '}\n\n'
      'Conversation so far:\n'
      '$conversationHistory\n\n'
      "Learner's latest message:\n"
      '$userMessage',
    );

    final jsonText = _stripJsonCodeFence(responseText);
    final data = jsonDecode(jsonText) as Map<String, dynamic>;

    return ScenarioConversationReply(
      waiterResponse: data['waiterResponse'] as String? ?? '',
      tip: data['tip'] as String? ?? '',
    );
  }

  Future<String> _generateText(String prompt) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception(
        'Missing Gemini API key. Run the app with '
        '--dart-define=GEMINI_API_KEY=your_key.',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_geminiApiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else if (response.statusCode == 403) {
      throw Exception(
        'Gemini permission denied. Replace the Gemini API key and run with '
        '--dart-define=GEMINI_API_KEY=your_key.',
      );
    } else {
      throw Exception('Gemini ${response.statusCode}: ${response.body}');
    }
  }

  String _stripJsonCodeFence(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) return trimmed;

    return trimmed
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
}
