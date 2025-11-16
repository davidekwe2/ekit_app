import 'package:ekit_app/pages/homepage.dart';
import 'package:ekit_app/pages/introPage.dart';
import 'package:ekit_app/pages/notecategory.dart';
import 'package:ekit_app/pages/recordpage.dart';
import 'package:ekit_app/pages/auth/login_page.dart';
import 'package:ekit_app/pages/auth/signup_page.dart';
import 'package:ekit_app/themes/colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Note: firebase_options.dart is NOT committed to git for security
// Each developer should run: flutterfire configure --project=ekitnote
// to generate their own firebase_options.dart file locally
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase - will use google-services.json for Android
  // If firebase_options.dart exists locally, it will be used automatically
  // Otherwise, Firebase will use platform-specific config files
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EKit Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const IntroPage(),
      routes: {
        '/intro': (context) => const IntroPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/record': (context) => const RecordPage(),
        '/categories': (context) => const SubjectPage(),
      },
      onGenerateRoute: (settings) {
        // Add custom transitions for routes
        switch (settings.name) {
          case '/home':
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          case '/record':
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const RecordPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                  child: child,
                );
              },
            );
          default:
            return null;
        }
      },
    );
  }
}
