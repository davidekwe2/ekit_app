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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription? _authStateSubscription;
  bool _isLoadingNotes = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = AppStore.notes;
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
          "EKit Notes",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadNotesFromFirestore();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
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
                          style: GoogleFonts.poppins(color: textColor),
                          decoration: InputDecoration(
                            hintText: "Search through your notes 📚",
                            hintStyle: GoogleFonts.poppins(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.primary,
                            ),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Record card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Start Recording",
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Turn your speech into notes instantly",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/record');
                                    },
                                    icon: const Icon(Icons.mic, color: Colors.white),
                                    label: Text(
                                      "Start Recording",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
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
                            ),
                            const SizedBox(width: 16),
                            Image.asset(
                              "lib/assets/images/frog (1).png",
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Recent notes header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Recent Notes",
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
                              "View All",
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
              ),
              
              // Notes list
              if (notes.isEmpty)
                SliverFillRemaining(
                  child: Center(
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
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                      childCount: notes.length,
                    ),
                  ),
                ),
              
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
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
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 30,
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
                      title: "Home",
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.school,
                      title: "Subjects",
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
                      title: "Recordings",
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/record');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.chat_bubble_outline,
                      title: "Chat with AI",
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
                      title: "Highlighted Texts",
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
                      title: "Profile",
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
                      title: "Settings",
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
                      title: "Logout",
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

