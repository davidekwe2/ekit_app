import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_history.dart';
import '../models/note.dart';
import '../models/category.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Helper to get authenticated user ID
  static String _getUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please log in first.');
    }
    return user.uid;
  }

  // ==================== USER PROFILE ====================
  static DocumentReference _userProfileDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  /// Save user profile
  static Future<void> saveUserProfile({
    required String displayName,
    String? photoURL,
    int? notesWritten,
  }) async {
    try {
      final userId = _getUserId();
      final profileRef = _userProfileDoc(userId);
      
      final data = <String, dynamic>{
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (photoURL != null) {
        data['photoURL'] = photoURL;
      }
      
      if (notesWritten != null) {
        data['notesWritten'] = notesWritten;
      }
      
      await profileRef.set(data, SetOptions(merge: true));
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _getUserId();
      final profileDoc = await _userProfileDoc(userId).get();
      
      if (!profileDoc.exists) return null;
      
      return profileDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  // ==================== NOTES ====================
  static CollectionReference _userNotesCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('notes');
  }

  /// Save a note to Firestore
  static Future<void> saveNote(Note note) async {
    try {
      final userId = _getUserId();
      final noteRef = _userNotesCollection(userId).doc(note.id);
      
      await noteRef.set({
        'title': note.title,
        'transcript': note.transcript,
        'subject': note.subject,
        'audioPath': note.audioPath,
        'comments': note.comments,
        'highlights': note.highlights.map((h) => _highlightToMap(h)).toList(),
        'aiSummary': note.aiSummary,
        'aiTranslation': note.aiTranslation,
        'importantPoints': note.importantPoints,
        'createdAt': Timestamp.fromDate(note.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Your note will be saved when connection is restored.');
      }
      rethrow;
    }
  }

  /// Update an existing note
  static Future<void> updateNote(Note note) async {
    try {
      final userId = _getUserId();
      final noteRef = _userNotesCollection(userId).doc(note.id);
      
      await noteRef.update({
        'title': note.title,
        'transcript': note.transcript,
        'subject': note.subject,
        'audioPath': note.audioPath,
        'comments': note.comments,
        'highlights': note.highlights.map((h) => _highlightToMap(h)).toList(),
        'aiSummary': note.aiSummary,
        'aiTranslation': note.aiTranslation,
        'importantPoints': note.importantPoints,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Your changes will be saved when connection is restored.');
      }
      rethrow;
    }
  }

  /// Delete a note
  static Future<void> deleteNote(String noteId) async {
    try {
      final userId = _getUserId();
      await _userNotesCollection(userId).doc(noteId).delete();
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get a single note by ID
  static Future<Note?> getNote(String noteId) async {
    try {
      final userId = _getUserId();
      final noteDoc = await _userNotesCollection(userId).doc(noteId).get();
      
      if (!noteDoc.exists) return null;
      
      final data = noteDoc.data();
      if (data == null) return null;
      
      return _noteFromMap(data as Map<String, dynamic>, noteId);
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get all notes for the current user
  static Future<List<Note>> getNotes() async {
    try {
      final userId = _getUserId();
      final snapshot = await _userNotesCollection(userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _noteFromMap(data, doc.id);
      }).toList();
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Stream notes for real-time updates
  static Stream<List<Note>> streamNotes() {
    try {
      final userId = _getUserId();
      return _userNotesCollection(userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _noteFromMap(data, doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  // ==================== SUBJECTS ====================
  static CollectionReference _userSubjectsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('subjects');
  }

  /// Save a subject
  static Future<void> saveSubject(Subject subject) async {
    try {
      final userId = _getUserId();
      final subjectRef = _userSubjectsCollection(userId).doc(subject.id);
      
      await subjectRef.set({
        'name': subject.name,
        'coverIndex': subject.coverIndex,
        'noteCount': subject.noteCount,
        'iconCode': subject.icon?.codePoint, // Store icon as code point
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Your subject will be saved when connection is restored.');
      }
      rethrow;
    }
  }

  /// Delete a subject
  static Future<void> deleteSubject(String subjectId) async {
    try {
      final userId = _getUserId();
      await _userSubjectsCollection(userId).doc(subjectId).delete();
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get all subjects for the current user
  static Future<List<Subject>> getSubjects() async {
    try {
      final userId = _getUserId();
      final snapshot = await _userSubjectsCollection(userId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _subjectFromMap(data, doc.id);
      }).toList();
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Stream subjects for real-time updates
  static Stream<List<Subject>> streamSubjects() {
    try {
      final userId = _getUserId();
      return _userSubjectsCollection(userId)
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _subjectFromMap(data, doc.id);
        }).toList();
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  /// Get note count for a subject
  static Future<int> getNoteCountForSubject(String? subjectId) async {
    try {
      final userId = _getUserId();
      final query = _userNotesCollection(userId);
      
      QuerySnapshot snapshot;
      if (subjectId == null) {
        snapshot = await query.where('subject', isNull: true).get();
      } else {
        snapshot = await query.where('subject', isEqualTo: subjectId).get();
      }
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // ==================== CHAT HISTORY ====================
  static CollectionReference _userChatHistoryCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('chat_history');
  }

  /// Save a chat history to Firestore
  static Future<void> saveChatHistory(ChatHistory chatHistory) async {
    try {
      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please log in first.');
      }
      
      final userId = user.uid;

      final chatRef = _userChatHistoryCollection(userId).doc(chatHistory.id);
      
      // Use set with merge: true to create or update without overwriting
      await chatRef.set({
        'title': chatHistory.title,
        'messages': chatHistory.messages.map((m) => m.toMap()).toList(),
        'noteId': chatHistory.noteId,
        'noteTitle': chatHistory.noteTitle,
        'createdAt': Timestamp.fromDate(chatHistory.createdAt),
        'updatedAt': Timestamp.fromDate(chatHistory.updatedAt),
      }, SetOptions(merge: true));
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Your chat will be saved when connection is restored.');
      }
      rethrow;
    }
  }

  /// Update an existing chat history
  static Future<void> updateChatHistory(ChatHistory chatHistory) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final chatRef = _userChatHistoryCollection(userId).doc(chatHistory.id);
    
    await chatRef.update({
      'title': chatHistory.title,
      'messages': chatHistory.messages.map((m) => m.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get a single chat history by ID
  static Future<ChatHistory?> getChatHistory(String chatId) async {
    try {
      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please log in first.');
      }
      
      final userId = user.uid;

      final chatDoc = await _userChatHistoryCollection(userId).doc(chatId).get();
      
      if (!chatDoc.exists) return null;
      
      final data = chatDoc.data();
      if (data == null) return null;
      
      return _chatHistoryFromMap(data as Map<String, dynamic>, chatId);
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection and try again.');
      }
      rethrow;
    }
  }

  /// Get all chat histories for the current user
  static Future<List<ChatHistory>> getChatHistories() async {
    try {
      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please log in first.');
      }
      
      final userId = user.uid;

      final snapshot = await _userChatHistoryCollection(userId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _chatHistoryFromMap(data, doc.id);
      }).toList();
    } catch (e) {
      // Re-throw with more context
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection and try again.');
      }
      rethrow;
    }
  }

  /// Stream chat histories for real-time updates
  static Stream<List<ChatHistory>> streamChatHistories() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _userChatHistoryCollection(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _chatHistoryFromMap(data, doc.id);
      }).toList();
    });
  }

  /// Delete a chat history
  static Future<void> deleteChatHistory(String chatId) async {
    try {
      // Ensure user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please log in first.');
      }
      
      final userId = user.uid;

      await _userChatHistoryCollection(userId).doc(chatId).delete();
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Please check your internet connection and try again.');
      }
      rethrow;
    }
  }

  // ==================== HELPER METHODS FOR DATA CONVERSION ====================

  // Note conversion
  static Note _noteFromMap(Map<String, dynamic> data, String id) {
    return Note(
      id: id,
      title: data['title'] as String? ?? '',
      transcript: data['transcript'] as String? ?? '',
      subject: data['subject'] as String?,
      audioPath: data['audioPath'] as String?,
      comments: data['comments'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      highlights: (data['highlights'] as List<dynamic>?)
              ?.map((h) => _highlightFromMap(h as Map<String, dynamic>))
              .toList() ??
          [],
      aiSummary: data['aiSummary'] as String?,
      aiTranslation: data['aiTranslation'] as String?,
      importantPoints: (data['importantPoints'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList(),
    );
  }

  static Map<String, dynamic> _highlightToMap(Highlight highlight) {
    return {
      'id': highlight.id,
      'text': highlight.text,
      'startIndex': highlight.startIndex,
      'endIndex': highlight.endIndex,
      'createdAt': Timestamp.fromDate(highlight.createdAt),
    };
  }

  static Highlight _highlightFromMap(Map<String, dynamic> data) {
    return Highlight(
      id: data['id'] as String? ?? '',
      text: data['text'] as String? ?? '',
      startIndex: data['startIndex'] as int? ?? 0,
      endIndex: data['endIndex'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Subject conversion
  static Subject _subjectFromMap(Map<String, dynamic> data, String id) {
    IconData? icon;
    if (data['iconCode'] != null) {
      icon = IconData(
        data['iconCode'] as int,
        fontFamily: 'MaterialIcons',
      );
    }

    return Subject(
      id: id,
      name: data['name'] as String? ?? '',
      coverIndex: data['coverIndex'] as int? ?? 0,
      noteCount: data['noteCount'] as int? ?? 0,
      icon: icon,
    );
  }

  static Map<String, dynamic> _subjectToMap(Subject subject) {
    return {
      'name': subject.name,
      'coverIndex': subject.coverIndex,
      'noteCount': subject.noteCount,
      'iconCode': subject.icon?.codePoint,
    };
  }

  // Chat History conversion
  static ChatHistory _chatHistoryFromMap(Map<String, dynamic> data, String id) {
    return ChatHistory(
      id: id,
      title: data['title'] as String? ?? '',
      messages: (data['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      noteId: data['noteId'] as String?,
      noteTitle: data['noteTitle'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ==================== UTILITY METHODS ====================

  /// Batch update multiple notes (useful for subject changes)
  static Future<void> batchUpdateNotes(List<Note> notes) async {
    try {
      final userId = _getUserId();
      final batch = _firestore.batch();
      
      for (final note in notes) {
        final noteRef = _userNotesCollection(userId).doc(note.id);
        batch.update(noteRef, {
          'title': note.title,
          'transcript': note.transcript,
          'subject': note.subject,
          'highlights': note.highlights.map((h) => _highlightToMap(h)).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception('Unable to connect to database. Your changes will be saved when connection is restored.');
      }
      rethrow;
    }
  }

  /// Delete all user data (for account deletion)
  static Future<void> deleteUserData(String userId) async {
    try {
      // Delete all collections
      final batch = _firestore.batch();
      
      // Delete notes
      final notesSnapshot = await _userNotesCollection(userId).get();
      for (var doc in notesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete subjects
      final subjectsSnapshot = await _userSubjectsCollection(userId).get();
      for (var doc in subjectsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete chat history
      final chatSnapshot = await _userChatHistoryCollection(userId).get();
      for (var doc in chatSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user profile
      batch.delete(_userProfileDoc(userId));
      
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}

