import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    print('NotificationService: Initializing...');

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('NotificationService: Notification tapped: ${response.payload}');
      },
    );

    // Request notification permissions for Android 13+
    await _requestNotificationPermissions();

    // Create notification channel
    await _createNotificationChannel();

    print('NotificationService: Initialization complete');
  }

  Future<void> _requestNotificationPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation
            .requestNotificationsPermission();
        print('NotificationService: Permission granted: $granted');
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('NotificationService: iOS Permission granted: $granted');
      }
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'sleepytravels_alarm_channel',
      'SleepyTravels Alarm Alerts',
      description:
          'High priority alarm notifications when you reach your destination',
      importance: Importance.defaultImportance,
      playSound: false, // We handle custom sound via AudioService
      enableVibration: true,
      showBadge: true,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidChannel);
      print('NotificationService: Notification channel created');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    try {
      print('NotificationService: Attempting to show notification: $title');

      const androidDetails = AndroidNotificationDetails(
        'sleepytravels_alarm_channel',
        'SleepyTravels Alarm Alerts',
        channelDescription:
            'High priority alarm notifications when you reach your destination',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false, // We handle custom sound via AudioService
        enableVibration: true,
        autoCancel: true, // Don't auto-dismiss
        ongoing: false, // Make it persistent until user dismisses
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false, // We handle custom sound via AudioService
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use provided ID or generate one based on timestamp
      final notificationId =
          id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

      await _plugin.show(notificationId, title, body, details);

      print('NotificationService: Notification shown with ID: $notificationId');
    } catch (e) {
      print('NotificationService: Error showing notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    print('NotificationService: All notifications cancelled');
  }
}
