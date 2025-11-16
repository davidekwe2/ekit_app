import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _keyAssetPath = 'lib/assets/keys/gemini_api_key.json';
  static String? _apiKey;

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

  /// Transcribe audio using Gemini API
  /// Note: Gemini API doesn't directly support audio transcription
  /// This would need to be used with speech-to-text first, then Gemini for enhancement
  static Future<String> transcribeWithGemini(String text) async {
    await _loadApiKey();
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Gemini API key not found');
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey'
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'Please transcribe and improve the following speech-to-text output, fixing any errors and adding proper punctuation: $text'
                }
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? text;
          }
        }
        return text;
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to call Gemini API: $e');
    }
  }

  /// Process text in real-time chunks (for streaming transcription)
  static Future<String> processTextChunk(String chunk) async {
    await _loadApiKey();
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      return chunk; // Return original if API key not available
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey'
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'Improve and correct this text chunk, maintaining the same meaning: $chunk'
                }
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? chunk;
          }
        }
        return chunk;
      } else {
        // If API call fails, return original chunk
        return chunk;
      }
    } catch (e) {
      // If error occurs, return original chunk
      return chunk;
    }
  }
}

