import 'package:flutter/material.dart';
import 'features/map_screen.dart';
import 'core/services/monitor_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/db_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBService.instance.init();
  await NotificationService.instance.init();
  await AudioService.instance.init();

  // Request location permissions with comprehensive handling
  await PermissionService.instance.requestLocationPermission();

  MonitorService().startMonitoring();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepyTravels',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}
