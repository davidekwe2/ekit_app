import 'package:flutter/material.dart';
import '../features/storage/store.dart';
import '../models/note.dart';

class MyNotesTile extends StatelessWidget {
  final Note note;
  final VoidCallback onPlay;
  const MyNotesTile({super.key, required this.note, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => AppStore.removeNote(note.id),
      child: ListTile(
        leading: const Icon(Icons.delete, color: Colors.red), // delete logo left
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(note.category ?? 'No category'),
        trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: onPlay),
      ),
    );
  }
}
