import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class NotificationService {
NotificationService._();
static final NotificationService instance = NotificationService._();


final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();


Future<void> init() async {
const android = AndroidInitializationSettings('@mipmap/ic_launcher');
const iOS = DarwinInitializationSettings();
await _plugin.initialize(const InitializationSettings(android: android, iOS: iOS));
}


Future<void> showNotification({required String title, required String body}) async {
const androidDetails = AndroidNotificationDetails(
'sleepytravels_channel',
'SleepyTravels Alerts',
channelDescription: 'Alarm alerts when you reach destination radius',
importance: Importance.max,
priority: Priority.high,
playSound: false, // we will play custom sound via audio player
);
const details = NotificationDetails(android: androidDetails);
await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
}
}