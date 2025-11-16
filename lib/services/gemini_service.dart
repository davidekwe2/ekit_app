import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _keyAssetPath = 'lib/assets/keys/gemini_api_key.json';
  static const String _modelId = 'gemini-2.0-flash'; // same as your test
  static String? _apiKey;

  // Load API key once from assets
  static Future<void> _loadApiKey() async {
    if (_apiKey != null) return;

    try {
      final jsonString = await rootBundle.loadString(_keyAssetPath);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _apiKey = json['api_key'] as String?;
    } catch (e) {
      _apiKey = null;
      throw Exception('Failed to load Gemini API key: $e');
    }
  }

  // Build the Gemini REST URL (v1beta)
  static Uri _geminiUrl() {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelId:generateContent?key=$_apiKey',
    );
  }

  // ---- internal helper ----
  static Future<String> _callGemini(List<Map<String, dynamic>> contents) async {
    await _loadApiKey();
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Gemini API key not found');
    }

    final url = _geminiUrl();

    final body = {
      'contents': contents,
      // no systemInstruction, no generationConfig -> keep it simple
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'];
          if (text is String && text.isNotEmpty) {
            return text;
          }
        }
      }
      return 'Sorry, I could not generate a response.';
    } else {
      throw Exception(
        'Gemini API error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // ---------- PUBLIC METHODS ----------

  /// Clean up speech-to-text output
  static Future<String> transcribeWithGemini(String text) async {
    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'text':
            'Please correct and improve the following speech-to-text output, fixing errors and punctuation:\n\n$text'
          }
        ]
      }
    ];

    return _callGemini(contents);
  }

  /// Improve a small text chunk (fallback-safe)
  static Future<String> processTextChunk(String chunk) async {
    await _loadApiKey();
    if (_apiKey == null || _apiKey!.isEmpty) return chunk;

    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'text':
            'Improve and correct this text chunk while keeping the same meaning:\n\n$chunk'
          }
        ]
      }
    ];

    try {
      return await _callGemini(contents);
    } catch (_) {
      return chunk;
    }
  }

  /// Main educational chat method
  static Future<String> chatWithGemini({
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
    String? noteContext,
  }) async {
    final List<Map<String, dynamic>> contents = [];

    // 1) Educational “system prompt” as a normal message
    contents.add({
      'role': 'user',
      'parts': [
        {
          'text': '''
You are an educational AI tutor.
Explain concepts clearly and step-by-step.
Help with homework, notes, and study questions.
If you are unsure about something, say so instead of guessing.
Now help the student based on the following conversation.
'''
        }
      ]
    });

    // 2) Optional note context
    if (noteContext != null && noteContext.isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text':
            'Here is some note content that gives context for my questions:\n\n$noteContext'
          }
        ]
      });
    }

    // 3) Conversation history (your saved messages)
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      for (final msg in conversationHistory) {
        contents.add({
          'role': msg['role'] ?? 'user', // "user" or "model"
          'parts': [
            {'text': msg['text'] ?? ''}
          ],
        });
      }
    }

    // 4) Current user message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    return _callGemini(contents);
  }
}
