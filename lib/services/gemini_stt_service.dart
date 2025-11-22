import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Gemini STT Service using Firebase AI Logic
/// Follows the Firebase AI Logic structure for audio transcription
class GeminiSttService {
  final GenerativeModel _model = FirebaseAI
      .googleAI()
      .generativeModel(model: 'gemini-2.5-flash'); // or 2.5-flash-lite

  /// Transcribe audio from bytes (Uint8List)
  /// Audio should be in a supported format (WAV, MP3, etc.)
  Future<String> transcribeAudio(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
  }) async {
    try {
      debugPrint('Gemini audio length: ${audioBytes.length}');
      debugPrint('Gemini mimeType: $mimeType');
      
      final prompt = TextPart(
        "Transcribe exactly what is said in this audio. "
        "Do not add or change any words.",
      );
      
      final audioPart = InlineDataPart(mimeType, audioBytes);
      
      final response = await _model.generateContent([
        Content.multi([prompt, audioPart]),
      ]);
      
      final transcript = response.text ?? '';
      debugPrint('Gemini transcript (first 80): ${transcript.length > 80 ? transcript.substring(0, 80) : transcript}');
      debugPrint('Gemini transcription completed: ${transcript.length} characters');
      
      return transcript;
    } catch (e) {
      debugPrint('Error in Gemini transcription: $e');
      rethrow;
    }
  }
}

