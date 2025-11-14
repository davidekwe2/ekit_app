import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note.dart';
import '../themes/colors.dart';
import '../features/storage/store.dart';
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
  String _selectedText = '';
  int? _selectionStart;
  int? _selectionEnd;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _textController.text = _note.transcript;
  }

  @override
  void dispose() {
    _textController.dispose();
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _AIOption(
              icon: Icons.summarize,
              title: 'Summarize',
              subtitle: 'Get a concise summary',
              onTap: () {
                Navigator.pop(context);
                _generateSummary();
              },
            ),
            _AIOption(
              icon: Icons.translate,
              title: 'Translate',
              subtitle: 'Translate to another language',
              onTap: () {
                Navigator.pop(context);
                _translate();
              },
            ),
            _AIOption(
              icon: Icons.lightbulb_outline,
              title: 'Key Points',
              subtitle: 'Extract important points',
              onTap: () {
                Navigator.pop(context);
                _extractKeyPoints();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _generateSummary() {
    // Simulate AI summary (replace with actual AI call)
    final summary = 'This is a summary of the note: ${_note.transcript.substring(0, min(100, _note.transcript.length))}...';
    setState(() {
      _note = _note.copyWith(aiSummary: summary);
      // Update in store
      AppStore.updateNote(_note);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary generated!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _translate() {
    // Simulate AI translation (replace with actual AI call)
    final translation = 'Translation: ${_note.transcript}';
    setState(() {
      _note = _note.copyWith(aiTranslation: translation);
      // Update in store
      AppStore.updateNote(_note);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Translation generated!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _extractKeyPoints() {
    // Simulate AI key points (replace with actual AI call)
    final points = [
      'Key point 1 from the note',
      'Key point 2 from the note',
      'Key point 3 from the note',
    ];
    setState(() {
      _note = _note.copyWith(importantPoints: points);
      // Update in store
      AppStore.updateNote(_note);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Key points extracted!'),
        backgroundColor: AppColors.success,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _note.title,
          style: GoogleFonts.poppins(
            color: AppColors.textPrimary,
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
                value: 'summarize',
                child: Row(
                  children: [
                    Icon(Icons.summarize, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Summarize', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'translate',
                child: Row(
                  children: [
                    Icon(Icons.translate, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Text('Translate', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'keypoints',
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.accent2, size: 20),
                    const SizedBox(width: 12),
                    Text('Key Points', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'continue_ai',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text('Continue with AI', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'more',
                child: Row(
                  children: [
                    Icon(Icons.more_horiz, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Text('More Options', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
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
                    MaterialPageRoute(
                      builder: (context) => AIChatPage(importedNote: _note),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                  color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_note.aiSummary != null)
              _AIResultCard(
                icon: Icons.summarize,
                title: 'Summary',
                content: _note.aiSummary!,
                color: AppColors.primary,
              ),

            if (_note.aiTranslation != null) ...[
              const SizedBox(height: 12),
              _AIResultCard(
                icon: Icons.translate,
                title: 'Translation',
                content: _note.aiTranslation!,
                color: AppColors.accent,
              ),
            ],

            if (_note.importantPoints != null) ...[
              const SizedBox(height: 12),
              _AIResultCard(
                icon: Icons.lightbulb_outline,
                title: 'Key Points',
                content: _note.importantPoints!.map((p) => '• $p').join('\n'),
                color: AppColors.accent2,
              ),
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
}

class _AIOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AIOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _AIResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _AIResultCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
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
                      'Comments',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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

