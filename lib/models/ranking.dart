class UserRanking {
  final String userId;
  final String? displayName;
  final String? photoURL;
  final int totalQuizzes;
  final int totalCorrectAnswers;
  final double averageScore;
  final Map<String, CategoryStats> categoryStats; // subject -> stats
  final int rank; // Overall rank

  UserRanking({
    required this.userId,
    this.displayName,
    this.photoURL,
    required this.totalQuizzes,
    required this.totalCorrectAnswers,
    required this.averageScore,
    required this.categoryStats,
    required this.rank,
  });

  // Get top performing categories (sorted by average score)
  List<CategoryStats> get topCategories {
    final categories = categoryStats.values.toList();
    categories.sort((a, b) => b.averageScore.compareTo(a.averageScore));
    return categories;
  }

  // Get strong categories (categories with average score >= 70)
  List<CategoryStats> get strongCategories {
    return topCategories.where((cat) => cat.averageScore >= 70).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'photoURL': photoURL,
      'totalQuizzes': totalQuizzes,
      'totalCorrectAnswers': totalCorrectAnswers,
      'averageScore': averageScore,
      'categoryStats': categoryStats.map((key, value) => MapEntry(key, value.toJson())),
      'rank': rank,
    };
  }

  factory UserRanking.fromJson(Map<String, dynamic> json) {
    final categoryStatsMap = (json['categoryStats'] as Map<String, dynamic>?) ?? {};
    final categoryStats = categoryStatsMap.map((key, value) => 
      MapEntry(key, CategoryStats.fromJson(value as Map<String, dynamic>))
    );

    return UserRanking(
      userId: json['userId'] ?? '',
      displayName: json['displayName'],
      photoURL: json['photoURL'],
      totalQuizzes: json['totalQuizzes'] ?? 0,
      totalCorrectAnswers: json['totalCorrectAnswers'] ?? 0,
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
      categoryStats: categoryStats,
      rank: json['rank'] ?? 0,
    );
  }
}

class CategoryStats {
  final String subjectId;
  final String subjectName;
  final int quizCount;
  final int correctAnswers;
  final double averageScore;
  final int totalQuestions;

  CategoryStats({
    required this.subjectId,
    required this.subjectName,
    required this.quizCount,
    required this.correctAnswers,
    required this.averageScore,
    required this.totalQuestions,
  });

  Map<String, dynamic> toJson() {
    return {
      'subjectId': subjectId,
      'subjectName': subjectName,
      'quizCount': quizCount,
      'correctAnswers': correctAnswers,
      'averageScore': averageScore,
      'totalQuestions': totalQuestions,
    };
  }

  factory CategoryStats.fromJson(Map<String, dynamic> json) {
    return CategoryStats(
      subjectId: json['subjectId'] ?? '',
      subjectName: json['subjectName'] ?? '',
      quizCount: json['quizCount'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      averageScore: (json['averageScore'] ?? 0.0).toDouble(),
      totalQuestions: json['totalQuestions'] ?? 0,
    );
  }
}



