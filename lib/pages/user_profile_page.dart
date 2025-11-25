import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../themes/colors.dart';
import '../services/ranking_service.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  late bool _isCurrentUser;

  @override
  void initState() {
    super.initState();
    _isCurrentUser = FirebaseAuth.instance.currentUser?.uid == null 
        ? false 
        : FirebaseAuth.instance.currentUser!.uid == widget.userId;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await RankingService.getUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        title: Text(
          _isCurrentUser ? 'My Profile' : 'User Profile',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _userProfile == null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 80,
                        color: textColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'User not found',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Profile Picture
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: _userProfile!['photoURL'] != null
                                    ? Image.network(
                                        _userProfile!['photoURL'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.white,
                                            child: const Icon(
                                              Icons.person,
                                              color: AppColors.primary,
                                              size: 40,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.white,
                                        child: const Icon(
                                          Icons.person,
                                          color: AppColors.primary,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userProfile!['displayName'] ?? 'User',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_userProfile!['email'] != null)
                                    Text(
                                      _userProfile!['email'],
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Stats Section
                      _buildStatsSection(
                        _userProfile!['stats'] ?? {},
                        textColor,
                        cardColor,
                        isDark,
                      ),
                    ],
                  ),
                ),
        ),
    );
  }

  Widget _buildStatsSection(
    Map<String, dynamic> stats,
    Color textColor,
    Color cardColor,
    bool isDark,
  ) {
    final totalQuizzes = stats['totalQuizzes'] ?? 0;
    final totalCorrect = stats['totalCorrectAnswers'] ?? 0;
    final totalQuestions = stats['totalQuestions'] ?? 0;
    final averageScore = stats['averageScore'] ?? 0.0;
    final categoryStats = stats['categoryStats'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quiz Statistics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        
        // Overall Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Quizzes',
                totalQuizzes.toString(),
                Icons.quiz,
                AppColors.primary,
                textColor,
                cardColor,
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Correct Answers',
                totalCorrect.toString(),
                Icons.check_circle,
                AppColors.success,
                textColor,
                cardColor,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Average Score',
                totalQuestions > 0 ? '${averageScore.toStringAsFixed(1)}%' : '-',
                Icons.trending_up,
                AppColors.accent,
                textColor,
                cardColor,
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Questions',
                totalQuestions.toString(),
                Icons.question_answer,
                AppColors.accent3,
                textColor,
                cardColor,
                isDark,
              ),
            ),
          ],
        ),
        
        // Category Stats
        if (categoryStats.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Performance by Subject',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          ...categoryStats.entries.map((entry) {
            final categoryData = entry.value as Map<String, dynamic>;
            final categoryName = categoryData['subjectName'] ?? 'Unknown';
            final catQuizCount = categoryData['quizCount'] ?? 0;
            final catAverage = categoryData['averageScore'] ?? 0.0;
            final catCorrect = categoryData['correctAnswers'] ?? 0;
            final catTotal = categoryData['totalQuestions'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: catAverage >= 70 ? AppColors.success.withOpacity(0.3) : Colors.transparent,
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$catQuizCount quizzes • $catCorrect/$catTotal correct',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: catAverage >= 70
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${catAverage.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: catAverage >= 70 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color textColor,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

