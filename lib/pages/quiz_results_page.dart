import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../themes/colors.dart';
import '../models/quiz.dart';
import '../services/quiz_export_service.dart';
import '../services/firestore_service.dart';
import '../services/ranking_service.dart';

class QuizResultsPage extends StatefulWidget {
  final QuizResult result;

  const QuizResultsPage({super.key, required this.result});

  @override
  State<QuizResultsPage> createState() => _QuizResultsPageState();
}

class _QuizResultsPageState extends State<QuizResultsPage> {
  bool _isExporting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _saveQuizResult();
  }

  Future<void> _saveQuizResult() async {
    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('Saving quiz result...');
      await FirestoreService.saveQuizResult(widget.result);
      debugPrint('Quiz result saved successfully');

      // Update ranking statistics
      debugPrint('Updating ranking statistics...');
      await RankingService.updateUserRanking(widget.result);
      debugPrint('Ranking statistics updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Quiz result saved and ranking updated!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving quiz result: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving quiz result: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        title: Text(
          'Quiz Results',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: textColor),
            onPressed: _isExporting ? null : _showExportDialog,
            tooltip: 'Download Results',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Results Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient:
                  _getGradientForPercentage(widget.result.percentage),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Score',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.result.percentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.result.level,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.result.correctAnswers} / ${widget.result.totalQuestions} Correct',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Warning about not saving
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Your quiz results will not be saved. We recommend downloading your results.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recommendations Section
              _buildSectionTitle(
                'Recommendations',
                Icons.lightbulb_outline,
                textColor,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                  widget.result.recommendations.asMap().entries.map((e) {
                    final index = e.key;
                    final recommendation = e.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index <
                            widget.result.recommendations.length - 1
                            ? 12
                            : 0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              recommendation,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: textColor,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Questions Review Section
              _buildSectionTitle('Question Review', Icons.quiz, textColor),
              const SizedBox(height: 16),
              ...widget.result.questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return _buildQuestionReviewCard(
                  question,
                  index + 1,
                  cardColor,
                  textColor,
                );
              }).toList(),

              const SizedBox(height: 32),

              // Download Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _showExportDialog,
                  icon: _isExporting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.download),
                  label: Text(
                    _isExporting ? 'Exporting...' : 'Download Results',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionReviewCard(
      QuizQuestion question,
      int questionNumber,
      Color cardColor,
      Color textColor,
      ) {
    final isCorrect = question.isCorrect ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCorrect ? 'Correct' : 'Incorrect',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                        isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Q$questionNumber',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.question,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (question.type == 'mcq' && question.options != null) ...[
            ...question.options!.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final optionLabel = String.fromCharCode(65 + index);
              final isUserAnswer = question.userAnswer == option;
              final isCorrectAnswer = question.correctAnswer == option;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrectAnswer
                      ? AppColors.success.withOpacity(0.15)
                      : isUserAnswer && !isCorrect
                      ? AppColors.error.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrectAnswer
                        ? AppColors.success
                        : isUserAnswer && !isCorrect
                        ? AppColors.error
                        : textColor.withOpacity(0.2),
                    width: isCorrectAnswer || (isUserAnswer && !isCorrect)
                        ? 2
                        : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$optionLabel. ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (isCorrectAnswer)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                    if (isUserAnswer && !isCorrect && !isCorrectAnswer)
                      const Icon(
                        Icons.cancel,
                        color: AppColors.error,
                        size: 20,
                      ),
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Answer:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    question.userAnswer ?? 'No answer provided',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  if (question.correctAnswer != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Correct Answer:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question.correctAnswer!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (question.feedback != null &&
                      question.type == 'theory') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Sample Answer/Key Points:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question.feedback!,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: textColor.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  LinearGradient _getGradientForPercentage(double percentage) {
    if (percentage >= 90) {
      return const LinearGradient(
        colors: [AppColors.success, Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (percentage >= 75) {
      return AppColors.primaryGradient;
    } else if (percentage >= 60) {
      return const LinearGradient(
        colors: [AppColors.warning, Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [AppColors.error, Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Export Results',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.error),
              title: Text(
                'Export as PDF',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.description, color: AppColors.primary),
              title: Text(
                'Export as Word (Coming Soon)',
                style: GoogleFonts.poppins(),
              ),
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAsPDF() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final pdf = await QuizExportService.generatePDF(widget.result);

      if (!mounted) return;

      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/quiz_results_${widget.result.quizId}.pdf',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quiz Results: ${widget.result.quizTitle}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Results exported successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}
