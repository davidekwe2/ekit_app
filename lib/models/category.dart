import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String name;
  final int coverIndex;
  final int noteCount; // Number of notes in this subject
  final IconData? icon; // Optional icon for the subject

  Subject({
    required this.id,
    required this.name,
    required this.coverIndex,
    this.noteCount = 0,
    this.icon,
  });
}
