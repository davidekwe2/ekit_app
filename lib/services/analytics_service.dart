import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service for Firebase Analytics and Crashlytics
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Log a custom event to Analytics
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      // Silently fail - don't break the app if analytics fails
      debugPrint('Analytics error: $e');
    }
  }

  /// Log screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Set user ID for Analytics
  static Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log a non-fatal error to Crashlytics
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }

  /// Log a custom message to Crashlytics
  static Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }

  /// Set custom key-value pairs for Crashlytics
  static Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }

  /// Set user identifier for Crashlytics
  static Future<void> setUserIdentifier(String identifier) async {
    try {
      await _crashlytics.setUserIdentifier(identifier);
    } catch (e) {
      debugPrint('Crashlytics error: $e');
    }
  }
}

