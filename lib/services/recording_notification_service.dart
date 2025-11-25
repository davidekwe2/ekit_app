import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform, File, Directory;
import 'package:path_provider/path_provider.dart';

class RecordingNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static const int _notificationId = 1001;
  static const String _channelId = 'recording_channel';
  static const String _channelName = 'Recording';
  static const String _channelDescription = 'Shows when recording is active';
  
  // Action IDs
  static const String _pauseActionId = 'pause_action';
  static const String _resumeActionId = 'resume_action';
  static const String _stopActionId = 'stop_action';
  
  // Callbacks for notification actions
  static VoidCallback? _onPause;
  static VoidCallback? _onResume;
  static VoidCallback? _onStop;

  static Future<void> initialize({
    VoidCallback? onPause,
    VoidCallback? onResume,
    VoidCallback? onStop,
  }) async {
    if (_isInitialized) {
      // Update callbacks even if already initialized
      _onPause = onPause;
      _onResume = onResume;
      _onStop = onStop;
      return;
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Set up notification action handlers
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    
    _onPause = onPause;
    _onResume = onResume;
    _onStop = onStop;
    _isInitialized = true;

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }
  
  static void _handleNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == _pauseActionId) {
      _onPause?.call();
    } else if (actionId == _resumeActionId) {
      _onResume?.call();
    } else if (actionId == _stopActionId) {
      _onStop?.call();
    }
  }

  static Future<void> showRecordingNotification(
    Duration duration, {
    bool isPaused = false,
  }) async {
    await initialize();

    // Load the frog image
    final String? imagePath = await _getFrogImagePath();
    
    // Determine actions based on pause state
    final List<AndroidNotificationAction> actions = isPaused
        ? [
            AndroidNotificationAction(
              _resumeActionId,
              'Resume',
              titleColor: Colors.green,
            ),
            AndroidNotificationAction(
              _stopActionId,
              'Stop',
              titleColor: Colors.red,
            ),
          ]
        : [
            AndroidNotificationAction(
              _pauseActionId,
              'Pause',
              titleColor: Colors.orange,
            ),
            AndroidNotificationAction(
              _stopActionId,
              'Stop',
              titleColor: Colors.red,
            ),
          ];

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.service,
      actions: actions,
      styleInformation: const MediaStyleInformation(),
      icon: '@mipmap/ic_launcher',
      largeIcon: imagePath != null
          ? FilePathAndroidBitmap(imagePath)
          : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      'EkitNotes Recording',
      isPaused 
          ? 'Paused: ${_formatDuration(duration)}'
          : 'Recording... ${_formatDuration(duration)}',
      details,
    );
  }

  static Future<void> updateRecordingNotification(
    Duration duration, {
    bool isPaused = false,
  }) async {
    if (!_isInitialized) return;

    // Load the frog image
    final String? imagePath = await _getFrogImagePath();
    
    // Determine actions based on pause state
    final List<AndroidNotificationAction> actions = isPaused
        ? [
            AndroidNotificationAction(
              _resumeActionId,
              'Resume',
              titleColor: Colors.green,
            ),
            AndroidNotificationAction(
              _stopActionId,
              'Stop',
              titleColor: Colors.red,
            ),
          ]
        : [
            AndroidNotificationAction(
              _pauseActionId,
              'Pause',
              titleColor: Colors.orange,
            ),
            AndroidNotificationAction(
              _stopActionId,
              'Stop',
              titleColor: Colors.red,
            ),
          ];

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      category: AndroidNotificationCategory.service,
      actions: actions,
      styleInformation: const MediaStyleInformation(),
      icon: '@mipmap/ic_launcher',
      largeIcon: imagePath != null
          ? FilePathAndroidBitmap(imagePath)
          : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      'EkitNotes Recording',
      isPaused 
          ? 'Paused: ${_formatDuration(duration)}'
          : 'Recording... ${_formatDuration(duration)}',
      details,
    );
  }

  static Future<void> cancelRecordingNotification() async {
    if (!_isInitialized) return;
    await _notifications.cancel(_notificationId);
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static Future<String?> _getFrogImagePath() async {
    try {
      // Load the frog image from assets
      final ByteData byteData = await rootBundle.load('lib/assets/images/frog (4).png');
      final List<int> bytes = byteData.buffer.asUint8List();
      final Directory tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/frog_notification_icon.png');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Error loading frog image for notification: $e');
      return null;
    }
  }
  
  /// Update callbacks for notification actions
  static void updateCallbacks({
    VoidCallback? onPause,
    VoidCallback? onResume,
    VoidCallback? onStop,
  }) {
    if (onPause != null) _onPause = onPause;
    if (onResume != null) _onResume = onResume;
    if (onStop != null) _onStop = onStop;
  }
}

