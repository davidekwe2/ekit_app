import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note.dart';
import '../themes/colors.dart';
import '../features/storage/store.dart';
import 'dart:math' as math;

class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
  });

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _getPreview(String text) {
    if (text.isEmpty) return 'No transcript';
    final words = text.split(' ');
    if (words.length <= 10) return text;
    return '${words.take(10).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _getPreview(note.transcript);
    final timeAgo = _getTimeAgo(note.createdAt);
    final hasHighlights = note.highlights.isNotEmpty;
    final hasAI = note.aiSummary != null || 
                  note.aiTranslation != null || 
                  note.importantPoints != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note icon/thumbnail - use subject icon if available
            Builder(
              builder: (context) {
                IconData noteIcon = Icons.note;
                if (note.subject != null) {
                  try {
                    final subject = AppStore.subjects.firstWhere(
                      (s) => s.id == note.subject,
                      orElse: () => AppStore.subjects.first,
                    );
                    if (subject.icon != null) {
                      noteIcon = subject.icon!;
                    }
                  } catch (e) {
                    // Use default icon if subject not found
                  }
                }
                return Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.2),
                        AppColors.primaryLight.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        noteIcon,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      if (hasHighlights || hasAI) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasHighlights)
                              Icon(
                                Icons.highlight,
                                size: 12,
                                color: AppColors.accent2,
                              ),
                            if (hasHighlights && hasAI) const SizedBox(width: 4),
                            if (hasAI)
                              Icon(
                                Icons.auto_awesome,
                                size: 12,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            // Note content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and subject
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.subject != null)
                        Builder(
                          builder: (context) {
                            try {
                              final subject = AppStore.subjects.firstWhere(
                                (s) => s.id == note.subject,
                                orElse: () => AppStore.subjects.first,
                              );
                              if (subject.id != 's0') {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    subject.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              // Subject not found
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Preview text
                  Text(
                    preview,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: textColor.withOpacity(0.7),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Footer with time and stats
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: textColor.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: textColor.withOpacity(0.5),
                        ),
                      ),
                      const Spacer(),
                      if (hasHighlights)
                        Row(
                          children: [
                            Icon(
                              Icons.highlight,
                              size: 14,
                              color: AppColors.accent2,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${note.highlights.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: textColor.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

