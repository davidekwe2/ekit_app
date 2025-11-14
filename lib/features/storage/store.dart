import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/note.dart';


class AppStore {
  static final List<Subject> subjects = [
    Subject(id: 's0', name: 'No Subject', coverIndex: 0),
  ];

  static final List<Note> notes = [];

  static void addSubject(String name, {IconData? icon}) {
    final idx = 1 + Random().nextInt(8);
    subjects.add(Subject(
      id: 's${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      coverIndex: idx,
      icon: icon,
    ));
  }

  static void removeSubject(String id) {
    subjects.removeWhere((s) => s.id == id);
  }

  static void addNote(Note n) {
    notes.insert(0, n); // recent first
    // Update subject note count
    if (n.subject != null) {
      final subject = subjects.firstWhere(
        (s) => s.id == n.subject,
        orElse: () => subjects.first,
      );
      // Note: Since Subject is immutable, we'd need to rebuild the list
      // For now, we'll handle this in the UI
    }
  }

  static void removeNote(String id) {
    notes.removeWhere((n) => n.id == id);
  }

  static void updateNote(Note updatedNote) {
    final index = notes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      notes[index] = updatedNote;
    }
  }

  static int getSubjectNoteCount(String? subjectId) {
    if (subjectId == null) {
      return notes.where((n) => n.subject == null).length;
    }
    return notes.where((n) => n.subject == subjectId).length;
  }
}
