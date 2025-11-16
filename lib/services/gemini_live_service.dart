import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Gemini Live API streaming service for real-time audio transcription
class GeminiLiveService {
  static const String _keyAssetPath = 'lib/assets/keys/gemini_api_key.json';
  static String? _apiKey;
  WebSocketChannel? _channel;
  StreamController<String>? _transcriptController;
  bool _isConnected = false;
  String _sessionId = '';
  Timer? _keepAliveTimer;

  /// Load API key from assets
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

  /// Get transcript stream
  Stream<String> get transcriptStream {
    _transcriptController ??= StreamController<String>.broadcast();
    return _transcriptController!.stream;
  }

  /// Connect to Gemini Live API
  Future<void> connect({String model = 'gemini-2.0-flash-live-001'}) async {
    await _loadApiKey();
    
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Gemini API key not found');
    }

    if (_isConnected) {
      return; // Already connected
    }

    try {
      // Gemini Live API WebSocket endpoint
      // Using the latest Gemini Live API endpoint format
      // Note: You may need to verify the exact endpoint from Google's latest documentation
      final wsUrl = Uri.parse(
        'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=$_apiKey'
      );

      _channel = WebSocketChannel.connect(wsUrl);
      
      // Wait a moment for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isConnected = true;

      // Send initial setup message
      await _sendSetupMessage(model);

      // Listen for responses
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _transcriptController?.addError(error);
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
          _transcriptController?.close();
        },
        cancelOnError: false,
      );

      // Start keep-alive timer
      _startKeepAlive();
    } catch (e) {
      _isConnected = false;
      throw Exception('Failed to connect to Gemini Live API: $e');
    }
  }

  /// Send setup message to initialize the session
  Future<void> _sendSetupMessage(String model) async {
    final setupMessage = {
      'setup': {
        'model': model,
        'generation_config': {
          'response_modality': 'TEXT',
        },
        'system_instruction': {
          'parts': [
            {
              'text': 'You are a real-time transcription assistant. Transcribe the audio input accurately with proper punctuation and formatting. Only respond with the transcribed text, no additional commentary.'
            }
          ]
        }
      }
    };

    _channel?.sink.add(jsonEncode(setupMessage));
  }

  /// Send audio chunk to Gemini Live API
  Future<void> sendAudioChunk(Uint8List audioData) async {
    if (!_isConnected || _channel == null) {
      return;
    }

    try {
      // Convert audio to base64
      final base64Audio = base64Encode(audioData);
      
      final message = {
        'content': {
          'parts': [
            {
              'inline_data': {
                'mime_type': 'audio/pcm',
                'data': base64Audio,
              }
            }
          ]
        }
      };

      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      print('Error sending audio chunk: $e');
    }
  }

  /// Handle incoming messages from Gemini Live API
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      
      // Handle different message types
      if (data.containsKey('serverContent')) {
        final serverContent = data['serverContent'] as Map<String, dynamic>?;
        if (serverContent != null && serverContent.containsKey('modelTurn')) {
          final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
          if (modelTurn != null && modelTurn.containsKey('parts')) {
            final parts = modelTurn['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              for (final part in parts) {
                if (part is Map<String, dynamic> && part.containsKey('text')) {
                  final text = part['text'] as String?;
                  if (text != null && text.isNotEmpty) {
                    _transcriptController?.add(text);
                  }
                }
              }
            }
          }
        }
      } else if (data.containsKey('content')) {
        final content = data['content'] as Map<String, dynamic>?;
        if (content != null && content.containsKey('parts')) {
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            for (final part in parts) {
              if (part is Map<String, dynamic> && part.containsKey('text')) {
                final text = part['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  _transcriptController?.add(text);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  /// Start keep-alive timer to maintain connection
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        try {
          // Send keep-alive ping
          _channel!.sink.add(jsonEncode({'ping': {}}));
        } catch (e) {
          print('Keep-alive error: $e');
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Disconnect from Gemini Live API
  Future<void> disconnect() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    
    _isConnected = false;
    await _transcriptController?.close();
    _transcriptController = null;
  }

  bool get isConnected => _isConnected;
}

