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
  /// [enableSpeakerDiarization] enables speaker identification (Speaker A, Speaker B, etc.)
  Future<String> transcribeAudio(
    Uint8List audioBytes, {
    String mimeType = 'audio/wav',
    bool enableSpeakerDiarization = true,
  }) async {
    try {
      debugPrint('Gemini audio length: ${audioBytes.length}');
      debugPrint('Gemini mimeType: $mimeType');
      debugPrint('Speaker diarization: $enableSpeakerDiarization');
      
      String promptText;
      if (enableSpeakerDiarization) {
        promptText = """Transcribe this audio with speaker identification in a simple script format.

Instructions:
1. Identify who is speaking - find the main speaker (speaks the most) and other speakers
2. Format as a script with speaker labels:
   Main Speaker: [exactly what they said]
   Second Speaker: [exactly what they said]
   Main Speaker: [exactly what they said continues]
   Third Speaker: [exactly what they said]

3. Label speakers as: "Main Speaker", "Second Speaker", "Third Speaker", "Fourth Speaker", etc.
4. Each speaker's dialogue should be on a new line with their label followed by a colon
5. Transcribe EXACTLY what is said - do not add, remove, or change any words
6. If there's only one speaker, just transcribe without labels
7. Be consistent - use the same label for the same speaker throughout

Keep it simple and clear like a script.""";
      } else {
        promptText = "Transcribe exactly what is said in this audio. "
            "Do not add or change any words.";
      }
      
      final prompt = TextPart(promptText);
      final audioPart = InlineDataPart(mimeType, audioBytes);
      
      final response = await _model.generateContent([
        Content.multi([prompt, audioPart]),
      ]);
      
      final transcript = response.text ?? '';
      debugPrint('Gemini transcript (first 200): ${transcript.length > 200 ? transcript.substring(0, 200) : transcript}');
      debugPrint('Gemini transcription completed: ${transcript.length} characters');
      
      return transcript;
    } catch (e) {
      debugPrint('Error in Gemini transcription: $e');
      rethrow;
    }
  }
}

