import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/storage/store.dart';
import '../themes/colors.dart';
import '../models/category.dart';
import '../models/note.dart';
import '../my components/note_tile.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'note_detail_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final TextEditingController _ctl = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubjectsFromFirestore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadNotesIfNeeded();
  }

  Future<void> _reloadNotesIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final notes = await FirestoreService.getNotes();
      AppStore.notes.clear();
      AppStore.notes.addAll(notes);

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjectsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final subjects = await FirestoreService.getSubjects();
      AppStore.subjects.clear();
      AppStore.subjects.add(
        Subject(id: 's0', name: 'No Subject', coverIndex: 0),
      );
      AppStore.subjects.addAll(subjects);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddSubjectDialog() {
    _ctl.clear();
    IconData? selectedIcon;

    final availableIcons = [
      Icons.school,
      Icons.calculate,
      Icons.science,
      Icons.language,
      Icons.history_edu,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Create New Subject',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _ctl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Subject name (e.g., Math, Science)',
                      prefixIcon: Icon(
                        selectedIcon ?? Icons.school,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a subject name';
                      }
                      if (AppStore.subjects.any(
                            (s) =>
                        s.name.toLowerCase() ==
                            value.trim().toLowerCase(),
                      )) {
                        return 'Subject already exists';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Icon (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // No icon option
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = null;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: selectedIcon == null
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedIcon == null
                                    ? AppColors.primary
                                    : AppColors.textLight,
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.block, size: 24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Icon options
                        ...availableIcons.map(
                              (icon) {
                            final isSelected = selectedIcon == icon;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedIcon = icon;
                                  });
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.2)
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textLight,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final subjectId =
                      's${DateTime.now().microsecondsSinceEpoch}';
                  final coverIndex =
                      1 + (DateTime.now().millisecondsSinceEpoch % 8);

                  final subject = Subject(
                    id: subjectId,
                    name: _ctl.text.trim(),
                    coverIndex: coverIndex,
                    icon: selectedIcon,
                  );

                  AppStore.subjects.add(subject);

                  try {
                    await FirestoreService.saveSubject(subject);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Subject saved locally. Will sync when online.',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Create',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Subjects',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: _showAddSubjectDialog,
            tooltip: 'Add Subject',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : AppStore.subjects.isEmpty
          ? _buildEmptyState()
          : _buildSubjectList(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubjectDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Subject',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.7);
    final lightTextColor = theme.colorScheme.onSurface.withOpacity(0.5);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: lightTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No subjects yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first subject to organize your notes!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSubjectDialog,
            icon: const Icon(Icons.add),
            label: Text('Create Subject', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    
    return Column(
      children: [
        // Header card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organize Your Notes',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppStore.subjects.length} ${AppStore.subjects.length == 1 ? 'subject' : 'subjects'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_special,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.poppins(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search subjects...',
                hintStyle: GoogleFonts.poppins(
                  color: textColor.withOpacity(0.5),
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.primary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: textColor.withOpacity(0.5),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Subjects list
        Expanded(
          child: Builder(
            builder: (context) {
              final filteredSubjects = _searchQuery.isEmpty
                  ? AppStore.subjects
                  : AppStore.subjects.where((subject) {
                return subject.name
                    .toLowerCase()
                    .contains(_searchQuery);
              }).toList();

              if (filteredSubjects.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: textColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No subjects found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try a different search term',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: filteredSubjects.length,
                itemBuilder: (context, i) {
                  final subject = filteredSubjects[i];
                  final originalIndex = AppStore.subjects.indexOf(subject);
                  final noteCount = AppStore.getSubjectNoteCount(
                    subject.id == 's0' ? null : subject.id,
                  );
                  final canDelete = originalIndex != 0; // keep "No Subject"

                  return Dismissible(
                    key: ValueKey(subject.id),
                    direction: canDelete
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    confirmDismiss: (_) async {
                      if (!canDelete) return false;
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Delete Subject?',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            'Are you sure you want to delete "${subject.name}"? Notes in this subject will be moved to "No Subject".',
                            style: GoogleFonts.poppins(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              child: Text(
                                'Delete',
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ],
                        ),
                      );
                      return result ?? false;
                    },
                    onDismissed: (_) async {
                      if (!canDelete) return;

                      // Move notes to "No Subject"
                      for (var note in AppStore.notes) {
                        if (note.subject == subject.id) {
                          final updatedNote = note.copyWith(subject: null);
                          AppStore.updateNote(updatedNote);
                          try {
                            await FirestoreService.updateNote(updatedNote);
                          } catch (_) {}
                        }
                      }

                      AppStore.removeSubject(subject.id);
                      try {
                        await FirestoreService.deleteSubject(subject.id);
                      } catch (_) {}

                      if (mounted) {
                        setState(() {});
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                     child: Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: cardColor,
                         borderRadius: BorderRadius.circular(16),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                             blurRadius: 10,
                             offset: const Offset(0, 5),
                           ),
                         ],
                       ),
                       child: InkWell(
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (context) => _SubjectNotesPage(
                                 subject: subject,
                                 subjectId:
                                 subject.id == 's0' ? null : subject.id,
                               ),
                             ),
                           );
                         },
                         borderRadius: BorderRadius.circular(16),
                         child: Row(
                           children: [
                             // Subject icon/avatar
                             Container(
                               width: 56,
                               height: 56,
                               decoration: BoxDecoration(
                                 gradient: LinearGradient(
                                   colors: [
                                     AppColors.primary.withOpacity(0.2),
                                     AppColors.primaryLight
                                         .withOpacity(0.2),
                                   ],
                                 ),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: Icon(
                                 subject.icon ?? Icons.school,
                                 color: AppColors.primary,
                                 size: 28,
                               ),
                             ),
                             const SizedBox(width: 16),
                             // Subject info
                             Expanded(
                               child: Column(
                                 crossAxisAlignment:
                                 CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     subject.name,
                                     style: GoogleFonts.poppins(
                                       fontSize: 18,
                                       fontWeight: FontWeight.bold,
                                       color: textColor,
                                     ),
                                   ),
                                   const SizedBox(height: 4),
                                   Text(
                                     '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
                                     style: GoogleFonts.poppins(
                                       fontSize: 14,
                                       color: textColor.withOpacity(0.7),
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                             // Arrow icon
                             Icon(
                               Icons.chevron_right,
                               color: textColor.withOpacity(0.5),
                             ),
                           ],
                         ),
                       ),
                     ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SubjectNotesPage extends StatelessWidget {
  final Subject subject;
  final String? subjectId;

  const _SubjectNotesPage({
    required this.subject,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    
    final notes = AppStore.notes.where((note) {
      if (subjectId == null) {
        return note.subject == null;
      }
      return note.subject == subjectId;
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          subject.name,
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: notes.isEmpty
          ? Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(
               Icons.note_add_outlined,
               size: 80,
               color: textColor.withOpacity(0.5),
             ),
             const SizedBox(height: 16),
             Text(
               'No notes in this subject',
               style: GoogleFonts.poppins(
                 fontSize: 20,
                 color: textColor,
                 fontWeight: FontWeight.w500,
               ),
             ),
             const SizedBox(height: 8),
             Text(
               'Start recording to add notes!',
               style: GoogleFonts.poppins(
                 fontSize: 14,
                 color: textColor.withOpacity(0.7),
               ),
             ),
           ],
         ),
       )
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return NoteTile(
            note: note,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation,
                      secondaryAnimation) =>
                      NoteDetailPage(note: note),
                  transitionDuration:
                  const Duration(milliseconds: 150),
                  transitionsBuilder: (context, animation,
                      secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
