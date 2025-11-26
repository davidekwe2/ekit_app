class Highlight {
  final String id;
  final String text;
  final int startIndex;
  final int endIndex;
  final DateTime createdAt;
  final int version; // 1 = Version 1 (transcript), 2 = Version 2 (geminiTranscript)
  final String color; // 'yellow', 'pink', 'red'

  Highlight({
    required this.id,
    required this.text,
    required this.startIndex,
    required this.endIndex,
    DateTime? createdAt,
    this.version = 1, // Default to Version 1 for backward compatibility
    this.color = 'yellow', // Default to yellow for backward compatibility
  }) : createdAt = createdAt ?? DateTime.now();
}

class Note {
  final String id;
  final String title;
  final String? subject;
  final String? audioPath;
  final String transcript; // Writer 1: Google Cloud STT
  final String? geminiTranscript; // Writer 2: Gemini transcription
  final String? comments; // User remarks/comments
  final DateTime createdAt;
  final List<Highlight> highlights;
  final String? aiSummary;
  final String? aiSummaryTranslation;
  final String? aiTranslation;
  final List<String>? importantPoints;
  final List<String>? importantPointsTranslation;

  Note({
    required this.id,
    required this.title,
    required this.transcript,
    this.geminiTranscript,
    this.subject,
    this.audioPath,
    this.comments,
    DateTime? createdAt,
    List<Highlight>? highlights,
    this.aiSummary,
    this.aiSummaryTranslation,
    this.aiTranslation,
    this.importantPoints,
    this.importantPointsTranslation,
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
    String? geminiTranscript,
    String? comments,
    DateTime? createdAt,
    List<Highlight>? highlights,
    String? aiSummary,
    String? aiSummaryTranslation,
    String? aiTranslation,
    List<String>? importantPoints,
    List<String>? importantPointsTranslation,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      geminiTranscript: geminiTranscript ?? this.geminiTranscript,
      subject: subject ?? this.subject,
      audioPath: audioPath ?? this.audioPath,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      highlights: highlights ?? this.highlights,
      aiSummary: aiSummary ?? this.aiSummary,
      aiSummaryTranslation: aiSummaryTranslation ?? this.aiSummaryTranslation,
      aiTranslation: aiTranslation ?? this.aiTranslation,
      importantPoints: importantPoints ?? this.importantPoints,
      importantPointsTranslation: importantPointsTranslation ?? this.importantPointsTranslation,
    );
  }
}




