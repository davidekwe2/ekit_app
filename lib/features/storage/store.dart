import 'dart:math';
import '../../models/category.dart';
import '../../models/note.dart';


class AppStore {
  static final List<Category> categories = [
    Category(id: 'c0', name: 'No category', coverIndex: 0),
  ];

  static final List<Note> notes = [];

  static void addCategory(String name) {
    final idx = 1 + Random().nextInt(8);
    categories.add(Category(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      coverIndex: idx,
    ));
  }

  static void removeCategory(String id) {
    categories.removeWhere((c) => c.id == id);
  }

  static void addNote(Note n) {
    notes.insert(0, n); // recent first
  }

  static void removeNote(String id) {
    notes.removeWhere((n) => n.id == id);
  }
}
