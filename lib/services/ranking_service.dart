import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/ranking.dart';
import '../models/quiz.dart';
import '../features/storage/store.dart';

class RankingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user ranking statistics after completing a quiz
  static Future<void> updateUserRanking(QuizResult result) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Cannot update ranking: User not authenticated');
        return;
      }

      final userId = user.uid;
      final now = DateTime.now();
      
      debugPrint('Updating ranking for user: $userId');
      debugPrint('Quiz result: ${result.correctAnswers}/${result.totalQuestions} correct');
      
      // Update daily stats
      final dateKey = _getDateKey(now);
      debugPrint('Updating daily stats for: $dateKey');
      final currentDailyStats = await _getUserStats(userId, 'daily_$dateKey');
      final updatedDailyStats = _calculateUpdatedStats(currentDailyStats, result);
      await _saveUserStats(userId, updatedDailyStats, 'daily_$dateKey');
      debugPrint('Saved daily stats to Firestore');
      
      // Update weekly stats (updates on Saturday mornings)
      final weekKey = _getWeekKey(now);
      debugPrint('Updating weekly stats for: $weekKey');
      final currentWeeklyStats = await _getUserStats(userId, 'weekly_$weekKey');
      final updatedWeeklyStats = _calculateUpdatedStats(currentWeeklyStats, result);
      await _saveUserStats(userId, updatedWeeklyStats, 'weekly_$weekKey');
      debugPrint('Saved weekly stats to Firestore');
      
      // Update overall stats (never resets, accumulates all quiz data)
      debugPrint('Updating overall stats');
      final currentOverallStats = await _getUserStats(userId, 'overall');
      final updatedOverallStats = _calculateUpdatedStats(currentOverallStats, result);
      await _saveUserStats(userId, updatedOverallStats, 'overall');
      debugPrint('Saved overall stats to Firestore');
      
      debugPrint('Ranking update completed successfully');
    } catch (e, stackTrace) {
      // Log error but don't fail - ranking is not critical
      debugPrint('Error updating ranking: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  static String _getDateKey(DateTime date) {
    // Format: YYYY-MM-DD
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _getWeekKey(DateTime date) {
    // Get Saturday of the week (week starts on Saturday morning)
    // In Dart: Monday=1, Tuesday=2, ..., Saturday=6, Sunday=7
    // We want to find the most recent Saturday
    int daysToSubtract;
    if (date.weekday == 6) {
      // It's Saturday, use today
      daysToSubtract = 0;
    } else if (date.weekday == 7) {
      // It's Sunday, go back 1 day to Saturday
      daysToSubtract = 1;
    } else {
      // Monday (1) through Friday (5), go back to previous Saturday
      daysToSubtract = date.weekday + 1;
    }
    final saturday = date.subtract(Duration(days: daysToSubtract));
    final saturdayAtMidnight = DateTime(saturday.year, saturday.month, saturday.day);
    return '${saturdayAtMidnight.year}-${saturdayAtMidnight.month.toString().padLeft(2, '0')}-${saturdayAtMidnight.day.toString().padLeft(2, '0')}';
  }

  /// Get user's current ranking (overall, daily, or weekly)
  static Future<UserRanking?> getUserRanking({String? period}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userId = user.uid;
      // period should always be provided, but default to overall if not
      period ??= 'overall';
      
      // Get user stats
      final stats = await _getUserStats(userId, period);
      
      // Get ranking based on period
      final allUsers = await _getAllUserStats(period: period);
      final sortedUsers = _sortUsersForRanking(allUsers);
      var rank = sortedUsers.indexWhere((u) => u['userId'] == userId) + 1;
      if (rank == 0 && sortedUsers.isNotEmpty) rank = sortedUsers.length + 1; // If not found
      if (sortedUsers.isEmpty) rank = 0; // No rankings yet
      
      // Build category stats
      final categoryStats = _buildCategoryStats(stats);
      
      // Get user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = userDoc.data();
      
      return UserRanking(
        userId: userId,
        displayName: userProfile?['displayName'] ?? user.displayName,
        photoURL: userProfile?['photoURL'] ?? user.photoURL,
        totalQuizzes: stats['totalQuizzes'] ?? 0,
        totalCorrectAnswers: stats['totalCorrectAnswers'] ?? 0,
        averageScore: (stats['averageScore'] ?? 0.0).toDouble(),
        categoryStats: categoryStats,
        rank: rank,
      );
    } catch (e) {
      debugPrint('Error getting user ranking: $e');
      return null;
    }
  }

  /// Get daily ranking
  static Future<UserRanking?> getDailyRanking() async {
    final now = DateTime.now();
    final dateKey = _getDateKey(now);
    return getUserRanking(period: 'daily_$dateKey');
  }

  /// Get weekly ranking
  static Future<UserRanking?> getWeeklyRanking() async {
    final now = DateTime.now();
    final weekKey = _getWeekKey(now);
    return getUserRanking(period: 'weekly_$weekKey');
  }

  /// Get overall ranking (never resets, shows all-time stats)
  static Future<UserRanking?> getOverallRanking() async {
    return getUserRanking(period: 'overall');
  }

  /// Get top ranked users (overall, daily, or weekly)
  static Future<List<UserRanking>> getTopRankedUsers({int limit = 10, String? period}) async {
    try {
      // period should always be provided, but default to overall if not
      period ??= 'overall';
      final allUsers = await _getAllUserStats(period: period);
      final sortedUsers = _sortUsersForRanking(allUsers);
      
      final topUsers = <UserRanking>[];
      for (int i = 0; i < sortedUsers.length && i < limit; i++) {
        final userData = sortedUsers[i];
        final stats = await _getUserStats(userData['userId'] as String, period);
        final categoryStats = _buildCategoryStats(stats);
        
        // Get user profile
        final userDoc = await _firestore.collection('users').doc(userData['userId'] as String).get();
        final userProfile = userDoc.data();
        
        topUsers.add(UserRanking(
          userId: userData['userId'] as String,
          displayName: userProfile?['displayName'] ?? userData['displayName'] as String?,
          photoURL: userProfile?['photoURL'] as String?,
          totalQuizzes: stats['totalQuizzes'] ?? 0,
          totalCorrectAnswers: stats['totalCorrectAnswers'] ?? 0,
          averageScore: (stats['averageScore'] ?? 0.0).toDouble(),
          categoryStats: categoryStats,
          rank: i + 1,
        ));
      }
      
      return topUsers;
    } catch (e) {
      debugPrint('Error getting top ranked users: $e');
      return [];
    }
  }

  /// Get top daily ranked users
  static Future<List<UserRanking>> getTopDailyRankedUsers({int limit = 10}) async {
    final now = DateTime.now();
    final dateKey = _getDateKey(now);
    return getTopRankedUsers(limit: limit, period: 'daily_$dateKey');
  }

  /// Get top weekly ranked users
  static Future<List<UserRanking>> getTopWeeklyRankedUsers({int limit = 10}) async {
    final now = DateTime.now();
    final weekKey = _getWeekKey(now);
    return getTopRankedUsers(limit: limit, period: 'weekly_$weekKey');
  }

  /// Get top overall ranked users (never resets, shows all-time stats)
  static Future<List<UserRanking>> getTopOverallRankedUsers({int limit = 10}) async {
    return getTopRankedUsers(limit: limit, period: 'overall');
  }

  /// Get user profile with stats
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      final userData = userDoc.data();
      final overallStats = await _getUserStats(userId, 'overall');
      
      return {
        ...?userData,
        'stats': overallStats,
      };
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Get user's rank category (e.g., "Top 10%", "Novice", etc.)
  static String getRankCategory(UserRanking ranking, int totalUsers) {
    if (totalUsers == 0) return 'Unranked';
    
    final percentile = (ranking.rank / totalUsers) * 100;
    
    if (percentile <= 5) return '🏆 Elite';
    if (percentile <= 10) return '⭐ Master';
    if (percentile <= 25) return '🎯 Expert';
    if (percentile <= 50) return '📚 Advanced';
    if (percentile <= 75) return '📖 Intermediate';
    return '🌱 Beginner';
  }

  // ==================== PRIVATE HELPER METHODS ====================

  static Future<Map<String, dynamic>> _getUserStats(String userId, String docId) async {
    try {
      final statsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quiz_stats')
          .doc(docId)
          .get();

      if (!statsDoc.exists) {
        debugPrint('_getUserStats: No stats doc found for user $userId, period $docId');
        return {
          'totalQuizzes': 0,
          'totalCorrectAnswers': 0,
          'totalQuestions': 0,
          'averageScore': 0.0,
          'categoryStats': <String, dynamic>{},
        };
      }

      final data = statsDoc.data() ?? {};
      debugPrint('_getUserStats: Found stats for user $userId, period $docId: $data');
      return data;
    } catch (e) {
      debugPrint('_getUserStats: Error fetching stats for user $userId, period $docId: $e');
      return {
        'totalQuizzes': 0,
        'totalCorrectAnswers': 0,
        'totalQuestions': 0,
        'averageScore': 0.0,
        'categoryStats': <String, dynamic>{},
      };
    }
  }

  static Map<String, dynamic> _calculateUpdatedStats(
    Map<String, dynamic> current,
    QuizResult result,
  ) {
    final totalQuizzes = (current['totalQuizzes'] ?? 0) + 1;
    final totalCorrect = (current['totalCorrectAnswers'] ?? 0) + result.correctAnswers;
    final totalQuestions = (current['totalQuestions'] ?? 0) + result.totalQuestions;
    final averageScore = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0.0;

    // Update category stats
    final categoryStats = Map<String, dynamic>.from(current['categoryStats'] ?? {});
    if (result.subject != null) {
      final subjectId = result.subject!;
      final subjectName = AppStore.subjects
          .firstWhere((s) => s.id == subjectId, orElse: () => AppStore.subjects.first)
          .name;
      
      final currentCategory = categoryStats[subjectId] ?? {
        'quizCount': 0,
        'correctAnswers': 0,
        'totalQuestions': 0,
        'averageScore': 0.0,
      };
      
      final catQuizCount = (currentCategory['quizCount'] ?? 0) + 1;
      final catCorrect = (currentCategory['correctAnswers'] ?? 0) + result.correctAnswers;
      final catTotalQuestions = (currentCategory['totalQuestions'] ?? 0) + result.totalQuestions;
      final catAverage = catTotalQuestions > 0 ? (catCorrect / catTotalQuestions) * 100 : 0.0;

      categoryStats[subjectId] = {
        'subjectId': subjectId,
        'subjectName': subjectName,
        'quizCount': catQuizCount,
        'correctAnswers': catCorrect,
        'totalQuestions': catTotalQuestions,
        'averageScore': catAverage,
      };
    }

    return {
      'totalQuizzes': totalQuizzes,
      'totalCorrectAnswers': totalCorrect,
      'totalQuestions': totalQuestions,
      'averageScore': averageScore,
      'categoryStats': categoryStats,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  /// Ensures the parent user document exists before saving stats
  static Future<void> _ensureUserDocument(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('_ensureUserDocument: Creating user document for $userId');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(userId).set({
            'userId': userId,
            'displayName': user.displayName,
            'photoURL': user.photoURL,
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('_ensureUserDocument: User document created successfully');
        } else {
          debugPrint('_ensureUserDocument: WARNING - No authenticated user, creating minimal document');
          await _firestore.collection('users').doc(userId).set({
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        debugPrint('_ensureUserDocument: User document already exists for $userId');
      }
    } catch (e) {
      debugPrint('_ensureUserDocument: Error ensuring user document: $e');
      // Don't rethrow - this is not critical if it fails
    }
  }

  static Future<void> _saveUserStats(String userId, Map<String, dynamic> stats, String docId) async {
    try {
      debugPrint('_saveUserStats: Saving stats for user $userId, doc $docId');
      debugPrint('_saveUserStats: Stats data: $stats');
      
      // 1) Ensure parent /users/{userId} exists
      await _ensureUserDocument(userId);
      
      // 2) Save stats in subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('quiz_stats')
          .doc(docId)
          .set(stats, SetOptions(merge: true));
      
      // Optional verify
      final verifyDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quiz_stats')
          .doc(docId)
          .get();
      
      if (verifyDoc.exists) {
        debugPrint('_saveUserStats: Successfully saved and verified stats for user $userId, doc $docId');
        debugPrint('_saveUserStats: Verified data: ${verifyDoc.data()}');
      } else {
        debugPrint('_saveUserStats: WARNING - Stats were not saved (verify failed)');
      }
    } catch (e, stackTrace) {
      debugPrint('_saveUserStats: Error saving stats to Firestore: $e');
      debugPrint('_saveUserStats: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> _getAllUserStats({String? period}) async {
    // period should always be provided, but default to overall if not
    period ??= 'overall';
    debugPrint('_getAllUserStats: Fetching stats for period: $period');
    
    final usersSnapshot = await _firestore.collection('users').get();
    debugPrint('_getAllUserStats: Found ${usersSnapshot.docs.length} users in collection');
    
    final allStats = <Map<String, dynamic>>[];

    for (final userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final stats = await _getUserStats(userId, period);
      
      final totalQuizzes = stats['totalQuizzes'] ?? 0;
      final totalQuestions = stats['totalQuestions'] ?? 0;
      
      debugPrint('_getAllUserStats: User $userId - totalQuizzes: $totalQuizzes, totalQuestions: $totalQuestions');
      
      if (totalQuizzes > 0 || totalQuestions > 0) {
        allStats.add({
          'userId': userId,
          'displayName': userDoc.data()['displayName'],
          'totalQuizzes': totalQuizzes,
          'totalQuestions': totalQuestions,
          'totalCorrectAnswers': stats['totalCorrectAnswers'] ?? 0,
          'averageScore': stats['averageScore'] ?? 0.0,
        });
        debugPrint('_getAllUserStats: Added user $userId to rankings');
      }
    }

    debugPrint('_getAllUserStats: Returning ${allStats.length} users with stats');
    return allStats;
  }

  static List<Map<String, dynamic>> _sortUsersForRanking(List<Map<String, dynamic>> users) {
    users.sort((a, b) {
      // Primary: total correct answers (Grind - most correct answers ranks higher)
      final correctDiff = (b['totalCorrectAnswers'] ?? 0) - (a['totalCorrectAnswers'] ?? 0);
      if (correctDiff != 0) return correctDiff;
      
      // Secondary: average score (Performance - higher average score ranks higher)
      final avgDiff = (b['averageScore'] ?? 0.0).compareTo(a['averageScore'] ?? 0.0);
      if (avgDiff != 0) return avgDiff;
      
      // Tertiary: total quizzes (more quizzes ranks higher) - tiebreaker
      return (b['totalQuizzes'] ?? 0) - (a['totalQuizzes'] ?? 0);
    });
    
    debugPrint('Sorted ${users.length} users by: 1) Total correct answers, 2) Average score, 3) Total quizzes');
    return users;
  }

  static Map<String, CategoryStats> _buildCategoryStats(Map<String, dynamic> stats) {
    final categoryStats = <String, CategoryStats>{};
    final catData = stats['categoryStats'] as Map<String, dynamic>? ?? {};
    
    for (final entry in catData.entries) {
      final subjectId = entry.key;
      final data = entry.value as Map<String, dynamic>;
      
      try {
        final subjectName = AppStore.subjects
            .firstWhere((s) => s.id == subjectId, orElse: () => AppStore.subjects.first)
            .name;
        
        categoryStats[subjectId] = CategoryStats(
          subjectId: subjectId,
          subjectName: data['subjectName']?.toString() ?? subjectName,
          quizCount: data['quizCount'] ?? 0,
          correctAnswers: data['correctAnswers'] ?? 0,
          averageScore: (data['averageScore'] ?? 0.0).toDouble(),
          totalQuestions: data['totalQuestions'] ?? 0,
        );
      } catch (e) {
        // Skip invalid category - continue to next iteration
      }
    }
    
    return categoryStats;
  }

}

