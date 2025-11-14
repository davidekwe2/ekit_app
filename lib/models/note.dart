class Highlight {
  final String id;
  final String text;
  final int startIndex;
  final int endIndex;
  final DateTime createdAt;

  Highlight({
    required this.id,
    required this.text,
    required this.startIndex,
    required this.endIndex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class Note {
  final String id;
  final String title;
  final String? subject;
  final String? audioPath;
  final String transcript;
  final String? comments; // User remarks/comments
  final DateTime createdAt;
  final List<Highlight> highlights;
  final String? aiSummary;
  final String? aiTranslation;
  final List<String>? importantPoints;

  Note({
    required this.id,
    required this.title,
    required this.transcript,
    this.subject,
    this.audioPath,
    this.comments,
    DateTime? createdAt,
    List<Highlight>? highlights,
    this.aiSummary,
    this.aiTranslation,
    this.importantPoints,
  }) : createdAt = createdAt ?? DateTime.now(),
       highlights = highlights ?? [];

  String get _id => id;
  String get _title => title;
  String? get _subject => subject;
  String? get _audioPath => audioPath;
  String get _transcript => transcript;
  DateTime get _createdAt => createdAt;
  
  Note copyWith({
    String? id,
    String? title,
    String? subject,
    String? audioPath,
    String? transcript,
    String? comments,
    DateTime? createdAt,
    List<Highlight>? highlights,
    String? aiSummary,
    String? aiTranslation,
    List<String>? importantPoints,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      subject: subject ?? this.subject,
      audioPath: audioPath ?? this.audioPath,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      highlights: highlights ?? this.highlights,
      aiSummary: aiSummary ?? this.aiSummary,
      aiTranslation: aiTranslation ?? this.aiTranslation,
      importantPoints: importantPoints ?? this.importantPoints,
    );
  }
}




