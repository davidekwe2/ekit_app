class Note {
  final String id;
  final String title;
  final String? category;
  final String? audioPath;
  final String transcript;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.transcript,
    this.category,
    this.audioPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
