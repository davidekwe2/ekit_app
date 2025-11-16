import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

import 'package:ekit_app/services/theme_service.dart';
import 'package:ekit_app/pages/introPage.dart';
import 'package:ekit_app/pages/homepage.dart';
import 'package:ekit_app/pages/notecategory.dart';
import 'package:ekit_app/pages/recordpage.dart';
import 'package:ekit_app/pages/auth/login_page.dart';
import 'package:ekit_app/pages/auth/signup_page.dart';
import 'package:ekit_app/pages/profile_page.dart';
import 'package:ekit_app/pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Setup Crashlytics
  FlutterError.onError = (FlutterErrorDetails errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Crashlytics (disable in debug if you prefer)
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  // Single Analytics instance used in navigatorObservers
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'EKit Notes',

            // Firebase Analytics navigation tracking
            navigatorObservers: [
              FirebaseAnalyticsObserver(analytics: _analytics),
            ],

            theme: themeService.lightTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(
                themeService.lightTheme.textTheme,
              ),
            ),
            darkTheme: themeService.darkTheme.copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(
                themeService.darkTheme.textTheme,
              ),
            ),
            themeMode:
            themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            home: const IntroPage(),

            routes: {
              '/intro': (context) => const IntroPage(),
              '/login': (context) => const LoginPage(),
              '/signup': (context) => const SignUpPage(),
              '/home': (context) => const HomePage(),
              '/record': (context) => const RecordPage(),
              '/categories': (context) => const SubjectPage(),
              '/profile': (context) => const ProfilePage(),
              '/settings': (context) => const SettingsPage(),
            },

            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/home':
                  return PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                    const HomePage(),
                    transitionsBuilder: (context, animation,
                        secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  );
                case '/record':
                  return PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                    const RecordPage(),
                    transitionsBuilder: (context, animation,
                        secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 1.0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: child,
                      );
                    },
                  );
                default:
                  return null;
              }
            },
          );
        },
      ),
    );
  }
}
