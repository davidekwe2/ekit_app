import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isSystem;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isSystem = false,
  });

  // Factory constructor for creating a ChatMessage from a map
  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      text: data['text'] as String,
      isUser: data['isUser'] as bool,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isSystem: data['isSystem'] as bool? ?? false,
    );
  }

  // Method to convert a ChatMessage to a map
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
      'isSystem': isSystem,
    };
  }
}

class ChatHistory {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final String? noteId;
  final String? noteTitle;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatHistory({
    required this.id,
    required this.title,
    required this.messages,
    this.noteId,
    this.noteTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Helper to generate a title if none is explicitly set
  String get autoTitle {
    if (messages.isEmpty) return 'Empty Chat';
    final firstUserMessage = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => messages.first, // Fallback to first message if no user message
    );
    return firstUserMessage.text.length > 50
        ? '${firstUserMessage.text.substring(0, 50)}...'
        : firstUserMessage.text;
  }

  ChatHistory copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    String? noteId,
    String? noteTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatHistory(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      noteId: noteId ?? this.noteId,
      noteTitle: noteTitle ?? this.noteTitle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}


