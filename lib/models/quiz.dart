class QuizQuestion {
  final String id;
  final String type; // 'mcq', 'fill_gap', 'theory'
  final String question;
  final List<String>? options; // For MCQ
  final String? correctAnswer; // For MCQ and Fill Gap
  final String? userAnswer;
  final bool? isCorrect;
  final String? feedback; // For theory questions

  QuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options,
    this.correctAnswer,
    this.userAnswer,
    this.isCorrect,
    this.feedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'userAnswer': userAnswer,
      'isCorrect': isCorrect,
      'feedback': feedback,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      question: json['question'] ?? '',
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      correctAnswer: json['correctAnswer'],
      userAnswer: json['userAnswer'],
      isCorrect: json['isCorrect'],
      feedback: json['feedback'],
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final List<QuizQuestion> questions;
  final DateTime createdAt;
  final String? subject;

  Quiz({
    required this.id,
    required this.title,
    required this.questions,
    DateTime? createdAt,
    this.subject,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'questions': questions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'subject': subject,
    };
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      subject: json['subject'],
    );
  }
}

class QuizResult {
  final String quizId;
  final String quizTitle;
  final int totalQuestions;
  final int correctAnswers;
  final double percentage;
  final String level; // 'Beginner', 'Intermediate', 'Advanced', 'Expert'
  final List<String> recommendations;
  final List<QuizQuestion> questions;
  final String? subject;
  final DateTime completedAt;

  QuizResult({
    required this.quizId,
    required this.quizTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.percentage,
    required this.level,
    required this.recommendations,
    required this.questions,
    this.subject,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'quizTitle': quizTitle,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'percentage': percentage,
      'level': level,
      'recommendations': recommendations,
      'questions': questions.map((q) => q.toJson()).toList(),
      'subject': subject,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      quizId: json['quizId'] ?? '',
      quizTitle: json['quizTitle'] ?? '',
      totalQuestions: json['totalQuestions'] ?? 0,
      correctAnswers: json['correctAnswers'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
      level: json['level'] ?? 'Beginner',
      recommendations: List<String>.from(json['recommendations'] ?? []),
      questions: (json['questions'] as List<dynamic>?)
          ?.map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList() ?? [],
      subject: json['subject'],
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : DateTime.now(),
    );
  }
}

class UploadedNote {
  final String? id; // For notes from app (Note.id), null for external files
  final String name;
  final String? content; // Extracted text content
  final String? filePath; // For external files
  final bool isFromApp; // true if from app notes, false if external file

  UploadedNote({
    this.id,
    required this.name,
    this.content,
    this.filePath,
    required this.isFromApp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'content': content,
      'filePath': filePath,
      'isFromApp': isFromApp,
    };
  }

  factory UploadedNote.fromJson(Map<String, dynamic> json) {
    return UploadedNote(
      id: json['id'],
      name: json['name'] ?? '',
      content: json['content'],
      filePath: json['filePath'],
      isFromApp: json['isFromApp'] ?? false,
    );
  }
}



