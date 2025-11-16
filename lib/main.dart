import 'dart:async';
import 'package:ekit_app/pages/homepage.dart';
import 'package:ekit_app/pages/introPage.dart';
import 'package:ekit_app/pages/notecategory.dart';
import 'package:ekit_app/pages/recordpage.dart';
import 'package:ekit_app/pages/auth/login_page.dart';
import 'package:ekit_app/pages/auth/signup_page.dart';
import 'package:ekit_app/themes/colors.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';

// Note: firebase_options.dart is NOT committed to git for security
// Each developer should run: flutterfire configure --project=ekitnote
// to generate their own firebase_options.dart file locally
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with options from firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase Analytics
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  
  // Initialize Firebase Crashlytics
  FlutterError.onError = (errorDetails) {
    // Pass Flutter errors to Crashlytics
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Pass non-Flutter errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  // Enable Crashlytics collection
  // In debug mode, you might want to disable it, but for now we'll enable it
  // Set to !kDebugMode if you want to disable in debug builds
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  
  runApp(MyApp(analytics: analytics));
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics;
  
  const MyApp({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EKit Notes',
      // Enable Firebase Analytics for navigation tracking
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
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
