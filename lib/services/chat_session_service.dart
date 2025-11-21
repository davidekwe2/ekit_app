import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_history.dart';
import 'firestore_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Persists chat across navigation, only clears on logout or app close
class ChatSessionService {
  static const String _currentChatIdKey = 'currentChatId_';
  static const String _currentNoteIdKey = 'currentNoteId_';

  static Future<SharedPreferences> _instance() async {
    return await SharedPreferences.getInstance();
  }

  static String _getUserIdKey(String baseKey) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('Warning: No user ID found for session key. Using generic key.');
      return baseKey; // Fallback, though ideally should not happen for user-specific data
    }
    return '$baseKey$userId';
  }

  /// Set the ID of the currently active chat session
  static Future<void> setCurrentChatId(String? chatId) async {
    final prefs = await _instance();
    final key = _getUserIdKey(_currentChatIdKey);
    if (chatId != null) {
      await prefs.setString(key, chatId);
      debugPrint('ChatSessionService: Set currentChatId: $chatId for key: $key');
    } else {
      await prefs.remove(key);
      debugPrint('ChatSessionService: Cleared currentChatId for key: $key');
    }
  }

  /// Get the ID of the currently active chat session
  static Future<String?> getCurrentChatId() async {
    final prefs = await _instance();
    final key = _getUserIdKey(_currentChatIdKey);
    final chatId = prefs.getString(key);
    debugPrint('ChatSessionService: Get currentChatId: $chatId for key: $key');
    return chatId;
  }

  /// Set the ID of the note currently linked to the active chat session
  static Future<void> setCurrentNoteId(String? noteId) async {
    final prefs = await _instance();
    final key = _getUserIdKey(_currentNoteIdKey);
    if (noteId != null) {
      await prefs.setString(key, noteId);
      debugPrint('ChatSessionService: Set currentNoteId: $noteId for key: $key');
    } else {
      await prefs.remove(key);
      debugPrint('ChatSessionService: Cleared currentNoteId for key: $key');
    }
  }

  /// Get the ID of the note currently linked to the active chat session
  static Future<String?> getCurrentNoteId() async {
    final prefs = await _instance();
    final key = _getUserIdKey(_currentNoteIdKey);
    final noteId = prefs.getString(key);
    debugPrint('ChatSessionService: Get currentNoteId: $noteId for key: $key');
    return noteId;
  }

  /// Load the full ChatHistory object for the current session
  static Future<ChatHistory?> loadCurrentChat() async {
    final chatId = await getCurrentChatId();
    if (chatId != null) {
      try {
        final chatHistory = await FirestoreService.getChatHistory(chatId);
        debugPrint('ChatSessionService: Loaded chat history for ID: $chatId');
        return chatHistory;
      } catch (e) {
        debugPrint('ChatSessionService: Error loading chat history $chatId: $e');
        // If there's an error loading, clear the session to prevent future errors
        await clearCurrentChat();
        return null;
      }
    }
    debugPrint('ChatSessionService: No current chat ID found.');
    return null;
  }

  /// Clear the current chat session (called on logout or app close)
  static Future<void> clearCurrentChat() async {
    await setCurrentChatId(null);
    await setCurrentNoteId(null);
    debugPrint('ChatSessionService: Current chat session cleared.');
  }

  /// Clear chat session for a specific user (on logout)
  static Future<void> clearCurrentChatForUser(String userId) async {
    final prefs = await _instance();
    await prefs.remove('${_currentChatIdKey}$userId');
    await prefs.remove('${_currentNoteIdKey}$userId');
    debugPrint('ChatSessionService: Chat session cleared for user: $userId');
  }
}


