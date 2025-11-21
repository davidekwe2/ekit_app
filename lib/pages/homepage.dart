import 'dart:async';
import 'dart:math' as math;

import 'package:ekit_app/my%20components/myButtons.dart';
import 'package:ekit_app/my%20components/mytextfield.dart';
import 'package:ekit_app/themes/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../features/storage/store.dart';
import '../my%20components/mynotes_tile.dart';
import '../models/note.dart';
import '../models/category.dart';
import 'notecategory.dart';
import '../my components/note_tile.dart';
import 'recordpage.dart';
import 'ai_chat_page.dart';
import 'note_detail_page.dart';
import 'highlighted_texts_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import '../services/chat_session_service.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription? _authStateSubscription;
  bool _isLoadingNotes = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load notes from Firestore when page initializes
    _loadNotesFromFirestore();
    
    // Listen to user changes (including profile updates) to update user info in drawer
    _authStateSubscription = FirebaseAuth.instance.userChanges().listen((user) {
      if (mounted) {
        if (user != null) {
          // User logged in - load their data
          _loadNotesFromFirestore();
        } else {
          // User logged out - clear local store
          AppStore.notes.clear();
          AppStore.subjects.clear();
          AppStore.subjects.add(Subject(id: 's0', name: 'No Subject', coverIndex: 0));
          setState(() {});
        }
      }
    });
    // Refresh when returning to this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotesFromFirestore();
    });
  }

  Future<void> _loadNotesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No user logged in, clear store
      AppStore.notes.clear();
      AppStore.subjects.clear();
      AppStore.subjects.add(Subject(id: 's0', name: 'No Subject', coverIndex: 0));
      if (mounted) setState(() {});
      return;
    }

    if (_isLoadingNotes) return;
    
    setState(() {
      _isLoadingNotes = true;
    });

    try {
      // Load notes from Firestore
      final notes = await FirestoreService.getNotes();
      
      // Load subjects from Firestore
      final subjects = await FirestoreService.getSubjects();
      
      // Update AppStore with user-specific data
      AppStore.notes.clear();
      AppStore.notes.addAll(notes);
      
      AppStore.subjects.clear();
      AppStore.subjects.add(Subject(id: 's0', name: 'No Subject', coverIndex: 0));
      AppStore.subjects.addAll(subjects);
      
      if (mounted) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      // If loading fails, keep existing local data
      if (mounted) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allNotes = AppStore.notes;
    // Filter notes based on search query
    final notes = _searchQuery.isEmpty
        ? allNotes
        : allNotes.where((note) {
            final query = _searchQuery.toLowerCase();
            return note.title.toLowerCase().contains(query) ||
                note.transcript.toLowerCase().contains(query) ||
                (note.subject != null &&
                    AppStore.subjects
                        .where((s) => s.id == note.subject)
                        .isNotEmpty &&
                    AppStore.subjects
                        .firstWhere((s) => s.id == note.subject,
                            orElse: () => AppStore.subjects.first)
                        .name
                        .toLowerCase()
                        .contains(query));
          }).toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: textColor, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)?.appName ?? "EKit Notes",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.language, color: textColor, size: 24),
            onPressed: () {
              final languageService = Provider.of<LanguageService>(context, listen: false);
              _showLanguageDialog(context, languageService);
            },
            tooltip: 'Language',
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed section: Search bar and Start Recording card
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
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
                        hintText: "${AppLocalizations.of(context)?.searchThroughNotes ?? "Search through your notes"} 📚",
                        hintStyle: GoogleFonts.poppins(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Record card - Always visible
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/record');
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)?.speakAndCapture ?? "Speak & Capture",
                                        style: GoogleFonts.poppins(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        AppLocalizations.of(context)?.tapToRecord ?? "Tap to record",
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          color: Colors.white.withOpacity(0.8),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 2),
                                // Play/Record button indicator - closer to text
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Frog illustration
                          Image.asset(
                            "lib/assets/images/frog (1).png",
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Recent notes header - Fixed
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.recentNotes ?? "Recent Notes",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/categories');
                        },
                        child: Text(
                          AppLocalizations.of(context)?.viewAll ?? "View All",
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            
            // Scrollable section: Notes list only
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await _loadNotesFromFirestore();
                },
                child: notes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 80,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No notes yet",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Start recording to create your first note!",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return NoteTile(
                            note: note,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => NoteDetailPage(note: note),
                                  transitionDuration: const Duration(milliseconds: 150),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LanguageService languageService) {
    try {
      final theme = Theme.of(context);
      final textColor = theme.colorScheme.onSurface;
      final cardColor = theme.cardColor;
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: LanguageService.supportedLocales.map((locale) {
                final isSelected = languageService.locale == locale;
                return ListTile(
                  title: Text(
                    languageService.getLanguageName(locale),
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    languageService.setLanguage(locale);
                    Navigator.pop(dialogContext);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    } catch (e) {
      // Show error if dialog fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening language selector: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'No email';
    
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header (Clickable to go to Profile)
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                  // Refresh when returning from profile page
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                              ? Image.network(
                                  user.photoURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.white,
                                      child: const Icon(
                                        Icons.person,
                                        color: AppColors.primary,
                                        size: 30,
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.white,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.white,
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 30,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              email,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
              
              // Menu items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _DrawerItem(
                      icon: Icons.home,
                      title: AppLocalizations.of(context)?.home ?? "Home",
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.school,
                      title: AppLocalizations.of(context)?.subjects ?? "Subjects",
                      onTap: () async {
                        Navigator.pop(context);
                        // Reload notes before navigating to ensure note counts are up to date
                        await _loadNotesFromFirestore();
                        if (mounted) {
                          Navigator.pushNamed(context, '/categories');
                        }
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.mic,
                      title: AppLocalizations.of(context)?.recordings ?? "Recordings",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/record');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.chat_bubble_outline,
                      title: AppLocalizations.of(context)?.chatWithAI ?? "Chat with AI",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const AIChatPage(),
                            transitionDuration: const Duration(milliseconds: 150),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.highlight,
                      title: AppLocalizations.of(context)?.highlightedTexts ?? "Highlighted Texts",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const HighlightedTextsPage(),
                            transitionDuration: const Duration(milliseconds: 150),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(color: Colors.white24),
                    _DrawerItem(
                      icon: Icons.person_outline,
                      title: AppLocalizations.of(context)?.profile ?? "Profile",
                      onTap: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(),
                            transitionDuration: const Duration(milliseconds: 150),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                        // Refresh when returning from profile page
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings,
                      title: AppLocalizations.of(context)?.settings ?? "Settings",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
                            transitionDuration: const Duration(milliseconds: 150),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.logout,
                      title: AppLocalizations.of(context)?.logout ?? "Logout",
                      onTap: () async {
                        Navigator.pop(context);
                        // Handle logout with Firebase Auth
                        try {
                          final userId = FirebaseAuth.instance.currentUser?.uid;
                          if (userId != null) {
                            await ChatSessionService.clearCurrentChatForUser(userId);
                          }
                          // Clear local store before logout
                          AppStore.notes.clear();
                          AppStore.subjects.clear();
                          AppStore.subjects.add(Subject(id: 's0', name: 'No Subject', coverIndex: 0));
                          
                          // Sign out from Google Sign In if signed in with Google
                          await GoogleSignIn().signOut();
                          // Sign out from Firebase Auth
                          await FirebaseAuth.instance.signOut();
                          
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        } catch (e) {
                          // Even if there's an error, try to navigate to login
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

