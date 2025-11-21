import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note.dart';
import '../themes/colors.dart';
import '../features/storage/store.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../l10n/app_localizations.dart';
import 'ai_chat_page.dart';
import 'dart:math';

class NoteDetailPage extends StatefulWidget {
  final Note note;

  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late Note _note;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _transcriptKey = GlobalKey();
  String _selectedText = '';
  int? _selectionStart;
  int? _selectionEnd;
  bool _isGeneratingSummary = false;
  bool _isTranslating = false;
  bool _isExtractingKeyPoints = false;
  bool _isTranslatingSummary = false;
  bool _isTranslatingKeyPoints = false;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _textController.text = _note.transcript;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _highlightText() {
    if (_selectionStart != null && _selectionEnd != null && _selectionStart! < _selectionEnd!) {
      final selectedText = _note.transcript.substring(_selectionStart!, _selectionEnd!);
      final highlight = Highlight(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: selectedText,
        startIndex: _selectionStart!,
        endIndex: _selectionEnd!,
      );

      setState(() {
        _note = _note.copyWith(
          highlights: [..._note.highlights, highlight],
        );
        // Update in store
        final index = AppStore.notes.indexWhere((n) => n.id == _note.id);
        if (index != -1) {
          AppStore.notes[index] = _note;
        }
        // Update in Firestore
        FirestoreService.updateNote(_note).catchError((e) {
          // Continue even if Firestore update fails
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text highlighted!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showAIOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final cardColor = theme.cardColor;
        final textColor = theme.colorScheme.onSurface;
        
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Actions',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            const SizedBox(height: 24),
            _AIOption(
              icon: Icons.summarize,
              title: AppLocalizations.of(context)?.summarize ?? 'Summarize',
              subtitle: AppLocalizations.of(context)?.getAConciseSummary ?? 'Get a concise summary',
              onTap: () {
                Navigator.pop(context);
                _generateSummary();
              },
            ),
            _AIOption(
              icon: Icons.translate,
              title: AppLocalizations.of(context)?.translate ?? 'Translate',
              subtitle: AppLocalizations.of(context)?.translateToAnotherLanguage ?? 'Translate to another language',
              onTap: () {
                Navigator.pop(context);
                _translate();
              },
            ),
            _AIOption(
              icon: Icons.lightbulb_outline,
              title: AppLocalizations.of(context)?.keyPoints ?? 'Key Points',
              subtitle: AppLocalizations.of(context)?.extractImportantPoints ?? 'Extract important points',
              onTap: () {
                Navigator.pop(context);
                _extractKeyPoints();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
      },
    );
  }

  Future<void> _generateSummary() async {
    if (_isGeneratingSummary) return;
    
    setState(() {
      _isGeneratingSummary = true;
    });

    try {
      final summary = await GeminiService.generateSummary(_note.transcript);
      
      if (mounted) {
        setState(() {
          _note = _note.copyWith(aiSummary: summary);
          _isGeneratingSummary = false;
        });
        
        // Update in store
        AppStore.updateNote(_note);
        
        // Update in Firestore
        await FirestoreService.updateNote(_note);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary generated successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingSummary = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating summary: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _translate() async {
    if (_isTranslating) return;
    
    // Show language selection dialog
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onSurface;
        final cardColor = theme.cardColor;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Target Language',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                'English', 'Spanish', 'French', 'German', 'Italian', 
                'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic',
                'Russian', 'Hindi', 'Dutch', 'Swedish', 'Norwegian'
              ].map((lang) {
                return ListTile(
                  title: Text(lang, style: GoogleFonts.poppins(color: textColor)),
                  onTap: () => Navigator.pop(context, lang),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedLanguage == null) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final translation = await GeminiService.translateNote(
        _note.transcript,
        targetLanguage: selectedLanguage,
      );
      
      if (mounted) {
        setState(() {
          _note = _note.copyWith(aiTranslation: translation);
          _isTranslating = false;
        });
        
        // Update in store
        AppStore.updateNote(_note);
        
        // Update in Firestore
        await FirestoreService.updateNote(_note);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translated to $selectedLanguage successfully!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error translating: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _extractKeyPoints() async {
    if (_isExtractingKeyPoints) return;
    
    setState(() {
      _isExtractingKeyPoints = true;
    });

    try {
      final points = await GeminiService.extractKeyPoints(_note.transcript);
      
      if (mounted) {
        setState(() {
          _note = _note.copyWith(importantPoints: points);
          _isExtractingKeyPoints = false;
        });
        
        // Update in store
        AppStore.updateNote(_note);
        
        // Update in Firestore
        await FirestoreService.updateNote(_note);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted ${points.length} key points!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtractingKeyPoints = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error extracting key points: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _note.title,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.highlight, color: AppColors.accent),
            onPressed: _highlightText,
            tooltip: 'Highlight selected text',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
            tooltip: 'AI Actions',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'highlight',
                child: Row(
                  children: [
                    Icon(Icons.highlight, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.highlights ?? 'Highlights', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'summarize',
                child: Row(
                  children: [
                    Icon(Icons.summarize, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.summarize ?? 'Summarize', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'translate',
                child: Row(
                  children: [
                    Icon(Icons.translate, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.translate ?? 'Translate', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'keypoints',
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.accent2, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.keyPoints ?? 'Key Points', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'continue_ai',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.continueWithAI ?? 'Continue with AI', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'more',
                child: Row(
                  children: [
                    Icon(Icons.more_horiz, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)?.moreOptions ?? 'More Options', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'highlight':
                  _viewHighlights();
                  break;
                case 'summarize':
                  _generateSummary();
                  break;
                case 'translate':
                  _translate();
                  break;
                case 'keypoints':
                  _extractKeyPoints();
                  break;
                case 'continue_ai':
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => AIChatPage(importedNote: _note),
                      transitionDuration: const Duration(milliseconds: 150),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                  break;
                case 'more':
                  _showAIOptions();
                  break;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject and date
            Row(
              children: [
                if (_note.subject != null)
                  Builder(
                    builder: (context) {
                      // Get subject name from ID
                      final subject = AppStore.subjects.firstWhere(
                        (s) => s.id == _note.subject,
                        orElse: () => AppStore.subjects.first,
                      );
                      // Only show if it's not "No Subject" or if it's a valid subject
                      if (subject.id != 's0' || _note.subject != null) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            subject.name,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                const Spacer(),
                Text(
                  _formatDate(_note.createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Comments section (expandable)
            if (_note.comments != null && _note.comments!.isNotEmpty) ...[
              _ExpandableCommentsSection(comments: _note.comments!),
              const SizedBox(height: 16),
            ],

            // Transcript with highlights
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SelectableText.rich(
                _buildTextWithHighlights(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  height: 1.6,
                  color: textColor,
                ),
                onSelectionChanged: (selection, cause) {
                  setState(() {
                    _selectionStart = selection.start;
                    _selectionEnd = selection.end;
                    if (_selectionStart != null && _selectionEnd != null) {
                      _selectedText = _note.transcript.substring(
                        _selectionStart!,
                        _selectionEnd!,
                      );
                    }
                  });
                },
              ),
            ),

            // AI Results
            if (_note.aiSummary != null || _note.aiTranslation != null || _note.importantPoints != null) ...[
              const SizedBox(height: 24),
              Text(
                'AI Insights',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_note.aiSummary != null) ...[
              _ExpandableAISection(
                icon: Icons.summarize,
                title: 'Summary',
                content: _note.aiSummary!,
                translation: _note.aiSummaryTranslation,
                color: AppColors.primary,
                onDelete: () => _deleteSummary(),
                onTranslate: () => _translateSummary(),
                isTranslating: _isTranslatingSummary,
                onRegenerate: () => _generateSummary(),
                isRegenerating: _isGeneratingSummary,
              ),
              const SizedBox(height: 12),
            ],

            if (_note.aiTranslation != null) ...[
              _ExpandableAISection(
                icon: Icons.translate,
                title: 'Translation',
                content: _note.aiTranslation!,
                color: AppColors.accent,
                onDelete: () => _deleteTranslation(),
                onRegenerate: () => _translate(),
                isRegenerating: _isTranslating,
              ),
              const SizedBox(height: 12),
            ],

            if (_note.importantPoints != null) ...[
              _ExpandableAISection(
                icon: Icons.lightbulb_outline,
                title: 'Key Points',
                content: _note.importantPoints!.map((p) => '• $p').join('\n'),
                translation: _note.importantPointsTranslation?.map((p) => '• $p').join('\n'),
                color: AppColors.accent2,
                onDelete: () => _deleteKeyPoints(),
                onTranslate: () => _translateKeyPoints(),
                isTranslating: _isTranslatingKeyPoints,
                onRegenerate: () => _extractKeyPoints(),
                isRegenerating: _isExtractingKeyPoints,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _buildTextWithHighlights() {
    if (_note.highlights.isEmpty) {
      return TextSpan(text: _note.transcript);
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    // Sort highlights by start index
    final sortedHighlights = List<Highlight>.from(_note.highlights)
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));

    for (final highlight in sortedHighlights) {
      // Add text before highlight
      if (highlight.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: _note.transcript.substring(lastIndex, highlight.startIndex),
        ));
      }

      // Add highlighted text
      spans.add(TextSpan(
        text: highlight.text,
        style: const TextStyle(
          backgroundColor: AppColors.accent2,
          fontWeight: FontWeight.w500,
        ),
      ));

      lastIndex = highlight.endIndex;
    }

    // Add remaining text
    if (lastIndex < _note.transcript.length) {
      spans.add(TextSpan(
        text: _note.transcript.substring(lastIndex),
      ));
    }

    return TextSpan(children: spans);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _scrollToHighlight(Highlight highlight) {
    // Calculate approximate scroll position based on character index
    // Average characters per line (rough estimate)
    const double avgCharsPerLine = 50.0;
    const double lineHeight = 25.6; // fontSize 16 * height 1.6
    
    // Estimate position: startIndex / avgCharsPerLine * lineHeight
    final double estimatedOffset = (highlight.startIndex / avgCharsPerLine) * lineHeight;
    
    // Add padding for container and page padding
    final double containerPadding = 20.0;
    final double pagePadding = 20.0;
    final double totalOffset = estimatedOffset + containerPadding + pagePadding;
    
    // Scroll to the estimated position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          totalOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
      
      // Highlight the text visually by temporarily selecting it
      setState(() {
        _selectionStart = highlight.startIndex;
        _selectionEnd = highlight.endIndex;
        _selectedText = highlight.text;
      });
      
      // Clear selection after a moment
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _selectionStart = null;
            _selectionEnd = null;
            _selectedText = '';
          });
        }
      });
    });
  }

  void _viewHighlights() {
    if (_note.highlights.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No highlights in this note'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    final backgroundColor = theme.scaffoldBackgroundColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.highlight, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Highlights (${_note.highlights.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Highlights list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _note.highlights.length,
                itemBuilder: (context, index) {
                  final highlight = _note.highlights[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent2.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context); // Close the highlights dialog
                        _scrollToHighlight(highlight);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent2.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Highlight ${index + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent2,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(highlight.createdAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: textColor.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            highlight.text,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: textColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: AppColors.accent2,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to jump to location',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.accent2,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSummary() async {
    setState(() {
      _note = _note.copyWith(aiSummary: null, aiSummaryTranslation: null);
    });
    AppStore.updateNote(_note);
    await FirestoreService.updateNote(_note);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary deleted'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteKeyPoints() async {
    setState(() {
      _note = _note.copyWith(importantPoints: null, importantPointsTranslation: null);
    });
    AppStore.updateNote(_note);
    await FirestoreService.updateNote(_note);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Key points deleted'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteTranslation() async {
    setState(() {
      _note = _note.copyWith(aiTranslation: null);
    });
    AppStore.updateNote(_note);
    await FirestoreService.updateNote(_note);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Translation deleted'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _translateSummary() async {
    if (_isTranslatingSummary || _note.aiSummary == null) return;
    
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onSurface;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Target Language',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                'English', 'Spanish', 'French', 'German', 'Italian', 
                'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic',
                'Russian', 'Hindi', 'Dutch', 'Swedish', 'Norwegian'
              ].map((lang) {
                return ListTile(
                  title: Text(lang, style: GoogleFonts.poppins(color: textColor)),
                  onTap: () => Navigator.pop(context, lang),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedLanguage == null) return;

    setState(() {
      _isTranslatingSummary = true;
    });

    try {
      final translation = await GeminiService.translateNote(
        _note.aiSummary!,
        targetLanguage: selectedLanguage,
      );
      
      if (mounted) {
        setState(() {
          _note = _note.copyWith(aiSummaryTranslation: translation);
          _isTranslatingSummary = false;
        });
        
        AppStore.updateNote(_note);
        await FirestoreService.updateNote(_note);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Summary translated to $selectedLanguage!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslatingSummary = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error translating summary: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _translateKeyPoints() async {
    if (_isTranslatingKeyPoints || _note.importantPoints == null) return;
    
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onSurface;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Select Target Language',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                'English', 'Spanish', 'French', 'German', 'Italian', 
                'Portuguese', 'Chinese', 'Japanese', 'Korean', 'Arabic',
                'Russian', 'Hindi', 'Dutch', 'Swedish', 'Norwegian'
              ].map((lang) {
                return ListTile(
                  title: Text(lang, style: GoogleFonts.poppins(color: textColor)),
                  onTap: () => Navigator.pop(context, lang),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selectedLanguage == null) return;

    setState(() {
      _isTranslatingKeyPoints = true;
    });

    try {
      final keyPointsText = _note.importantPoints!.join('\n');
      final translation = await GeminiService.translateNote(
        keyPointsText,
        targetLanguage: selectedLanguage,
      );
      
      // Parse translation back into list
      final translatedPoints = translation.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceFirst(RegExp(r'^[\d\.\)\-\•\*]\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      if (mounted) {
        setState(() {
          _note = _note.copyWith(importantPointsTranslation: translatedPoints);
          _isTranslatingKeyPoints = false;
        });
        
        AppStore.updateNote(_note);
        await FirestoreService.updateNote(_note);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Key points translated to $selectedLanguage!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslatingKeyPoints = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error translating key points: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _AIOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _AIOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableAISection extends StatefulWidget {
  final IconData icon;
  final String title;
  final String content;
  final String? translation;
  final Color color;
  final VoidCallback? onDelete;
  final VoidCallback? onTranslate;
  final bool isTranslating;
  final VoidCallback? onRegenerate;
  final bool isRegenerating;

  const _ExpandableAISection({
    required this.icon,
    required this.title,
    required this.content,
    this.translation,
    required this.color,
    this.onDelete,
    this.onTranslate,
    this.isTranslating = false,
    this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  State<_ExpandableAISection> createState() => _ExpandableAISectionState();
}

class _ExpandableAISectionState extends State<_ExpandableAISection> {
  bool _isExpanded = false;
  bool _showTranslation = false;
  static const int _maxCollapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final lines = widget.content.split('\n');
    final shouldShowExpand = lines.length > _maxCollapsedLines || 
                            widget.content.length > 150;

    return Container(
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          InkWell(
            onTap: shouldShowExpand
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Action buttons
                  if (widget.onTranslate != null)
                    IconButton(
                      icon: widget.isTranslating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : Icon(Icons.translate, color: widget.color, size: 18),
                      onPressed: widget.isTranslating ? null : widget.onTranslate,
                      tooltip: 'Translate',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (widget.onRegenerate != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: widget.isRegenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : Icon(Icons.refresh, color: widget.color, size: 18),
                      onPressed: widget.isRegenerating ? null : widget.onRegenerate,
                      tooltip: 'Regenerate',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  if (widget.onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  if (shouldShowExpand) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: widget.color,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, widget.translation != null ? 0 : 16),
            child: _isExpanded || !shouldShowExpand
                ? Text(
                    widget.content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor.withOpacity(0.9),
                      height: 1.5,
                    ),
                  )
                : Text(
                    widget.content,
                    maxLines: _maxCollapsedLines,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor.withOpacity(0.9),
                      height: 1.5,
                    ),
                  ),
          ),
          // Translation section
          if (widget.translation != null) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () {
                setState(() {
                  _showTranslation = !_showTranslation;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.translate, color: widget.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Translation',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.color,
                        ),
                      ),
                    ),
                    Icon(
                      _showTranslation ? Icons.expand_less : Icons.expand_more,
                      color: widget.color,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_showTranslation)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  widget.translation!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: textColor.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ExpandableCommentsSection extends StatefulWidget {
  final String comments;

  const _ExpandableCommentsSection({required this.comments});

  @override
  State<_ExpandableCommentsSection> createState() => _ExpandableCommentsSectionState();
}

class _ExpandableCommentsSectionState extends State<_ExpandableCommentsSection> {
  bool _isExpanded = false;
  static const int _maxCollapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final lines = widget.comments.split('\n');
    final shouldShowExpand = lines.length > _maxCollapsedLines || 
                            widget.comments.length > 150;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: shouldShowExpand
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.comment, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.comments ?? 'Comments',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (shouldShowExpand)
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.accent,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              shouldShowExpand ? 16 : 16,
            ),
            child: _isExpanded || !shouldShowExpand
                ? Text(
                    widget.comments,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  )
                : Text(
                    widget.comments,
                    maxLines: _maxCollapsedLines,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

