import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../themes/colors.dart';
import '../models/note.dart';
import '../models/chat_history.dart';
import '../features/storage/store.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';
import '../services/chat_session_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'homepage.dart';

class AIChatPage extends StatefulWidget {
  final Note? importedNote;
  final ChatHistory? chatHistory;

  const AIChatPage({super.key, this.importedNote, this.chatHistory});

  factory AIChatPage.fromHistory(ChatHistory history) {
    return AIChatPage(chatHistory: history, importedNote: null);
  }

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<ChatMessage> _messages;
  Note? _currentNote;
  bool _isLoading = false;
  String? _currentChatId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.importedNote;
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _messages = [];

    if (widget.chatHistory != null) {
      debugPrint(
          'Loading chat history: ${widget.chatHistory!.id} with ${widget.chatHistory!.messages.length} messages');
      _currentChatId = widget.chatHistory!.id;
      _messages = List.from(widget.chatHistory!.messages);

      if (widget.chatHistory!.noteId != null) {
        try {
          final noteInStore = AppStore.notes.firstWhere(
                (n) => n.id == widget.chatHistory!.noteId,
            orElse: () => Note(
              id: widget.chatHistory!.noteId!,
              title: widget.chatHistory!.noteTitle ?? '',
              transcript: '',
            ),
          );

          if (noteInStore.transcript.isNotEmpty) {
            _currentNote = noteInStore;
          } else {
            final noteFromFirestore =
            await FirestoreService.getNote(widget.chatHistory!.noteId!);
            if (noteFromFirestore != null) {
              _currentNote = noteFromFirestore;
            } else {
              _currentNote = noteInStore;
            }
          }
        } catch (e) {
          debugPrint('Error loading note: $e');
          _currentNote = Note(
            id: widget.chatHistory!.noteId!,
            title: widget.chatHistory!.noteTitle ?? '',
            transcript: '',
          );
        }
      }

      await ChatSessionService.setCurrentChatId(_currentChatId);
      await ChatSessionService.setCurrentNoteId(widget.chatHistory!.noteId);
      debugPrint('Chat initialized with ${_messages.length} messages');
    } else {
      final currentChat = await ChatSessionService.loadCurrentChat();
      if (currentChat != null && currentChat.messages.isNotEmpty) {
        _currentChatId = currentChat.id;
        _messages = List.from(currentChat.messages);
        if (currentChat.noteId != null) {
          _currentNote = AppStore.notes.firstWhere(
                (n) => n.id == currentChat.noteId,
            orElse: () => Note(
              id: currentChat.noteId!,
              title: currentChat.noteTitle ?? '',
              transcript: '',
            ),
          );
        }
      } else {
        _currentChatId = null;
        // Generate welcome message in user's language
        final welcomeMessage = await _generateWelcomeMessage(_currentNote);
        _messages = [
          ChatMessage(
            text: welcomeMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ];

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
    }

    if (mounted) {
      setState(() => _isInitializing = false);
      _scrollToBottom();
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

    await _saveChatHistory();

    try {
      final conversationHistory = <Map<String, String>>[];
      for (var message in _messages) {
        if (!message.isSystem) {
          conversationHistory.add({
            'role': message.isUser ? 'user' : 'model',
            'text': message.text,
          });
        }
      }

      String? noteContext;
      if (_currentNote != null) {
        noteContext = _currentNote!.transcript;
      }

      // Get current language
      final languageService = Provider.of<LanguageService>(context, listen: false);
      final currentLocale = languageService.locale;
      final languageName = _getLanguageName(currentLocale);

      final response = await GeminiService.chatWithGemini(
        userMessage: userMessage,
        conversationHistory: conversationHistory.length > 1
            ? conversationHistory.sublist(0, conversationHistory.length - 1)
            : null,
        noteContext: noteContext,
        responseLanguage: languageName,
      );

      if (!mounted) return;

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
      _saveChatHistory();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text:
            'Sorry, I encountered an error: ${e.toString()}. Please check your API key and internet connection.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
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

  String _getLanguageName(Locale locale) {
    final languageNames = {
      'en_US': 'English',
      'es_ES': 'Spanish',
      'fr_FR': 'French',
      'de_DE': 'German',
      'it_IT': 'Italian',
      'pt_BR': 'Portuguese',
      'ru_RU': 'Russian',
      'ar_SA': 'Arabic',
      'zh_CN': 'Chinese',
      'ja_JP': 'Japanese',
      'ko_KR': 'Korean',
      'hi_IN': 'Hindi',
      'nl_NL': 'Dutch',
      'sv_SE': 'Swedish',
      'pl_PL': 'Polish',
    };
    final key = '${locale.languageCode}_${locale.countryCode ?? 'US'}';
    return languageNames[key] ?? 'English';
  }

  Future<String> _generateWelcomeMessage(Note? note) async {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final currentLocale = languageService.locale;
    final languageName = _getLanguageName(currentLocale);
    
    if (languageName == 'English') {
      return note != null
          ? "Ribbit! 🐸 I've imported your note: '${note.title}'. I'm Froggy, your quirky educational AI tutor! I can help you understand it better, answer questions, summarize it, or extract key points. What would you like to know?"
          : "Ribbit! 🐸 Hi there! I'm Froggy, your quirky and friendly educational AI tutor! I love helping with:\n\n• Understanding concepts and explaining topics\n• Answering homework and study questions\n• Summarizing and analyzing your notes\n• Extracting key points from educational content\n• Study tips and learning strategies\n• Translations for educational purposes\n\nYou can also import a note to discuss it with me. Ready to hop into some learning? What can I help you with today? 🌟";
    }
    
    // Generate localized welcome message via AI
    try {
      final welcomePrompt = note != null
          ? "Generate a friendly welcome message in $languageName as Froggy, a quirky educational AI tutor. Say that you've imported the note '${note.title}' and can help understand it, answer questions, summarize, or extract key points. Keep it short, friendly, and include the 🐸 emoji. Start with 'Ribbit!'"
          : "Generate a friendly welcome message in $languageName as Froggy, a quirky and friendly educational AI tutor. Mention that you help with: understanding concepts, homework questions, summarizing notes, extracting key points, study tips, and translations. Keep it warm and engaging, include the 🐸 emoji, and start with 'Ribbit!'";
      
      return await GeminiService.chatWithGemini(
        userMessage: welcomePrompt,
        conversationHistory: null,
        noteContext: null,
        responseLanguage: languageName,
      );
    } catch (e) {
      // Fallback to English if AI generation fails
      return note != null
          ? "Ribbit! 🐸 I've imported your note: '${note.title}'. I'm Froggy, your quirky educational AI tutor! I can help you understand it better, answer questions, summarize it, or extract key points. What would you like to know?"
          : "Ribbit! 🐸 Hi there! I'm Froggy, your quirky and friendly educational AI tutor! I love helping with:\n\n• Understanding concepts and explaining topics\n• Answering homework and study questions\n• Summarizing and analyzing your notes\n• Extracting key points from educational content\n• Study tips and learning strategies\n• Translations for educational purposes\n\nYou can also import a note to discuss it with me. Ready to hop into some learning? What can I help you with today? 🌟";
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Cannot save chat history: User not authenticated');
        return;
      }

      final nonSystemMessages = _messages.where((m) => !m.isSystem).toList();
      if (nonSystemMessages.isEmpty) {
        debugPrint('Skipping save: No messages to save');
        return;
      }

      _currentChatId ??= DateTime.now().millisecondsSinceEpoch.toString();

      final firstUserMessage = _messages.firstWhere(
            (m) => m.isUser,
        orElse: () => _messages.first,
      );

      final title = firstUserMessage.text.length > 50
          ? '${firstUserMessage.text.substring(0, 50)}...'
          : firstUserMessage.text;

      final chatHistory = ChatHistory(
        id: _currentChatId!,
        title: title,
        messages: nonSystemMessages,
        noteId: _currentNote?.id,
        noteTitle: _currentNote?.title,
        updatedAt: DateTime.now(),
      );

      await FirestoreService.saveChatHistory(chatHistory);
      debugPrint(
          'Chat history saved to Firestore: ${chatHistory.id} with ${chatHistory.messages.length} messages');

      await ChatSessionService.setCurrentChatId(_currentChatId);
      await ChatSessionService.setCurrentNoteId(_currentNote?.id);
    } catch (e) {
      debugPrint('Error saving chat history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Warning: Chat may not be saved. ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showChatHistory() async {
    if (!mounted) return;

    final pageContext = context;

    try {
      // loading dialog
      showDialog(
        context: pageContext,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final chatHistories = await FirestoreService.getChatHistories();

      if (!mounted) return;
      Navigator.of(pageContext, rootNavigator: true).pop();

      showDialog(
        context: pageContext,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              AppLocalizations.of(context)?.chatHistory ?? 'Chat History',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(pageContext).size.height * 0.7,
              child: chatHistories.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '${AppLocalizations.of(context)?.noChatHistory ?? 'No chat history yet'}. Start chatting with ${AppLocalizations.of(context)?.froggy ?? 'Froggy'} to see your conversations here! 🐸',
                  style: GoogleFonts.poppins(),
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: chatHistories.length,
                itemBuilder: (context, index) {
                  final chat = chatHistories[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chat,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      chat.title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chat.noteTitle != null)
                          Padding(
                            padding:
                            const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.note,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    chat.noteTitle!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          _formatDate(chat.updatedAt),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: AppColors.error,
                        size: 20,
                      ),
                      onPressed: () async {
                        final confirm =
                        await showDialog<bool>(
                          context: dialogContext,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            title: Text(
                              'Delete Chat?',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              AppLocalizations.of(context)?.areYouSureDeleteChat ?? 'Ribbit! Are you sure you want to delete this chat? 🐸',
                              style: GoogleFonts.poppins(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(
                                        context, false),
                                child: Text(
                                  'Cancel',
                                  style:
                                  GoogleFonts.poppins(),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(
                                        context, true),
                                style:
                                TextButton.styleFrom(
                                  foregroundColor:
                                  AppColors.error,
                                ),
                                child: Text(
                                  'Delete',
                                  style:
                                  GoogleFonts.poppins(),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && mounted) {
                          try {
                            await FirestoreService
                                .deleteChatHistory(chat.id);
                            Navigator.of(dialogContext).pop();
                            _showChatHistory();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(
                                  pageContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error deleting chat: $e'),
                                  backgroundColor:
                                  AppColors.error,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                    onTap: () async {
                      Navigator.of(dialogContext).pop();

                      BuildContext? loadingDialogContext;

                      try {
                        showDialog(
                          context: pageContext,
                          barrierDismissible: false,
                          builder: (loadingContext) {
                            loadingDialogContext =
                                loadingContext;
                            return const Center(
                              child:
                              CircularProgressIndicator(),
                            );
                          },
                        );

                        final loadedChat =
                        await FirestoreService
                            .getChatHistory(chat.id);

                        if (mounted &&
                            loadingDialogContext != null) {
                          Navigator.of(loadingDialogContext!,
                              rootNavigator: true)
                              .pop();
                        }

                        if (!mounted) return;

                        if (loadedChat != null &&
                            loadedChat
                                .messages.isNotEmpty) {
                          await ChatSessionService
                              .setCurrentChatId(
                              loadedChat.id);
                          await ChatSessionService
                              .setCurrentNoteId(
                              loadedChat.noteId);

                          await Navigator.of(pageContext)
                              .pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (context,
                                  animation,
                                  secondaryAnimation) =>
                                  AIChatPage.fromHistory(
                                      loadedChat),
                              transitionDuration:
                              const Duration(
                                  milliseconds: 200),
                              transitionsBuilder:
                                  (context,
                                  animation,
                                  secondaryAnimation,
                                  child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(pageContext)
                                .showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Chat history is empty or could not be loaded.'),
                                backgroundColor:
                                AppColors.error,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted &&
                            loadingDialogContext != null) {
                          try {
                            Navigator.of(
                                loadingDialogContext!,
                                rootNavigator: true)
                                .maybePop();
                          } catch (_) {}
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(pageContext)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Error loading chat: ${e.toString()}'),
                              backgroundColor:
                              AppColors.error,
                              duration: const Duration(
                                  seconds: 3),
                            ),
                          );
                        }
                        debugPrint(
                            'Error loading chat history: $e');
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(),
                child: Text(AppLocalizations.of(context)?.close ?? 'Close',
                    style: GoogleFonts.poppins()),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.of(pageContext, rootNavigator: true).maybePop();

      String errorMessage = 'Error loading chat history';
      if (e.toString().contains('Unable to connect')) {
        errorMessage =
        'Unable to connect to database. Please check your internet connection and try again.';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Please log in to view chat history.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _startNewChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context)?.startNewChat ?? 'Start New Chat?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppLocalizations.of(context)?.startNewChatMessage ?? 'Ribbit! This will start a fresh conversation. Your current chat is saved and you can access it from Chat History. Ready to hop into a new topic? 🐸',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            child: Text(
              AppLocalizations.of(context)?.newChat ?? 'New Chat',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ChatSessionService.clearCurrentChat();

      final welcomeMessage = await _generateWelcomeMessage(null);
      setState(() {
        _currentChatId = null;
        _currentNote = null;
        _messages = [
          ChatMessage(
            text: welcomeMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ];
      });

      _scrollToBottom();
    }
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
          AppLocalizations.of(context)?.importNote ?? 'Import Note',
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
                leading: const Icon(
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
                onTap: () async {
                  Navigator.pop(context);
                  final welcomeMessage = await _generateWelcomeMessage(note);
                  if (mounted) {
                    setState(() {
                      _currentNote = note;
                      _messages = [
                        ChatMessage(
                          text: welcomeMessage,
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
                  }
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
        toolbarHeight: kToolbarHeight,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                const HomePage(),
                transitionDuration: const Duration(milliseconds: 150),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
                  (route) => route.isFirst || route.settings.name == '/home',
            );
          },
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'lib/assets/images/cat1.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.froggy ?? 'Froggy',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primary),
            tooltip: AppLocalizations.of(context)?.chatHistory ?? 'Chat History',
            onPressed: _showChatHistory,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            tooltip: 'More Options',
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.note_add,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.importNote ?? 'Import Note', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'new_chat',
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.newChat ?? 'New Chat', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    const Icon(Icons.history,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.chatHistory ?? 'Chat History', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _showImportNoteDialog();
                  break;
                case 'new_chat':
                  _startNewChat();
                  break;
                case 'history':
                  _showChatHistory();
                  break;
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _isInitializing
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'lib/assets/images/cat1.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _ChatBubble(message: message);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(isDark ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)?.typeAMessage ?? 'Type your message...',
                            hintStyle: GoogleFonts.poppins(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                            const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization:
                          TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _sendMessage,
                          borderRadius: BorderRadius.circular(26),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                                : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment:
      message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primary
              : message.isSystem
              ? AppColors.primary.withOpacity(0.1)
              : (theme.brightness == Brightness.dark
              ? theme.colorScheme.surface
              : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 20),
          ),
          border: message.isSystem
              ? Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: message.isUser
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(
                      theme.brightness == Brightness.dark ? 0.2 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
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
                    : theme.colorScheme.onSurface,
                fontSize: message.isSystem ? 12 : 14,
                height: 1.5,
                fontStyle: message.isSystem
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: GoogleFonts.poppins(
                color: message.isUser
                    ? Colors.white.withOpacity(0.7)
                    : theme.colorScheme.onSurface.withOpacity(0.6),
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
