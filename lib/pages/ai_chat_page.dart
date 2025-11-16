import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/colors.dart';
import '../models/note.dart';
import '../features/storage/store.dart';
import '../services/gemini_service.dart';

class AIChatPage extends StatefulWidget {
  final Note? importedNote;
  
  const AIChatPage({super.key, this.importedNote});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  Note? _currentNote;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.importedNote;
    
    // Initialize messages with greeting or note context
    _messages = [
      ChatMessage(
        text: _currentNote != null
            ? "I've imported your note: '${_currentNote!.title}'. I can help you understand it better, answer questions about it, summarize it, or extract key points. What would you like to know?"
            : "Hi! I'm your educational AI assistant. I can help you with:\n• Understanding concepts and explaining topics\n• Answering homework and study questions\n• Summarizing and analyzing your notes\n• Extracting key points from educational content\n• Study tips and learning strategies\n• Translations for educational purposes\n\nYou can also import a note to discuss it with me. How can I help you learn today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
    
    // If note is imported, add note content as context
    if (_currentNote != null) {
      _messages.add(
        ChatMessage(
          text: "Note content:\n${_currentNote!.transcript}",
          isUser: false,
          timestamp: DateTime.now(),
          isSystem: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(
        ChatMessage(
          text: userMessage,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Build conversation history (excluding system messages)
      List<Map<String, String>> conversationHistory = [];
      for (var message in _messages) {
        if (!message.isSystem) {
          conversationHistory.add({
            'role': message.isUser ? 'user' : 'model',
            'text': message.text,
          });
        }
      }

      // Get note context if available
      String? noteContext;
      if (_currentNote != null) {
        noteContext = _currentNote!.transcript;
      }

      // Call Gemini API
      final response = await GeminiService.chatWithGemini(
        userMessage: userMessage,
        conversationHistory: conversationHistory.length > 1 
            ? conversationHistory.sublist(0, conversationHistory.length - 1) 
            : null,
        noteContext: noteContext,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Sorry, I encountered an error: ${e.toString()}. Please check your API key and internet connection.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
        
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showImportNoteDialog() {
    if (AppStore.notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No notes available to import'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Import Note',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppStore.notes.length,
            itemBuilder: (context, index) {
              final note = AppStore.notes[index];
              return ListTile(
                leading: Icon(
                  Icons.note,
                  color: AppColors.primary,
                ),
                title: Text(
                  note.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  note.transcript.length > 50
                      ? '${note.transcript.substring(0, 50)}...'
                      : note.transcript,
                  style: GoogleFonts.poppins(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentNote = note;
                    _messages = [
                      ChatMessage(
                        text: "I've imported your note: '${note.title}'. I can help you understand it better, answer questions about it, summarize it, or extract key points. What would you like to know?",
                        isUser: false,
                        timestamp: DateTime.now(),
                      ),
                      ChatMessage(
                        text: "Note content:\n${note.transcript}",
                        isUser: false,
                        timestamp: DateTime.now(),
                        isSystem: true,
                      ),
                    ];
                  });
                  _scrollToBottom();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _currentNote != null ? _currentNote!.title : "AI Assistant",
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add, color: AppColors.primary),
            tooltip: 'Import Note',
            onPressed: _showImportNoteDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: GoogleFonts.poppins(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Type your message...",
                          hintStyle: GoogleFonts.poppins(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.note_add, color: AppColors.primary),
                    tooltip: 'Import Note',
                    onPressed: _showImportNoteDialog,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isLoading ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primary
              : message.isSystem
                  ? AppColors.primary.withOpacity(0.1)
                  : (Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).colorScheme.surface 
                      : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          border: message.isSystem
              ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: GoogleFonts.poppins(
                color: message.isUser 
                    ? Colors.white 
                    : message.isSystem
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                fontSize: message.isSystem ? 12 : 14,
                height: 1.5,
                fontStyle: message.isSystem ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: GoogleFonts.poppins(
                color: message.isUser
                    ? Colors.white.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

