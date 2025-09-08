import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../data/repositories/alarm_repository.dart';
import 'notification_service.dart';
import 'package:just_audio/just_audio.dart';

class MonitorService {
  static final MonitorService _instance = MonitorService._internal();
  factory MonitorService() => _instance;
  MonitorService._internal();
  final Distance _distance = const Distance();
  final AlarmRepository _repo = AlarmRepository();
  final player = AudioPlayer();
  Timer? _timer;
  void startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      Position pos = await Geolocator.getCurrentPosition();
      final alarms = _repo.getActiveAlarms();
      for (var alarm in alarms) {
        final dist = _distance(
          LatLng(pos.latitude, pos.longitude),
          LatLng(alarm.destLat, alarm.destLng),
        );
        if (dist <= alarm.radiusM) {
          // Trigger alarm
          await NotificationService.instance.showNotification(
            title: 'SleepyTravels Alarm',
            body: 'You are within ${alarm.radiusM}m of your destination!',
          );
          if (alarm.soundPath != null) {
            try {
              await player.setFilePath(alarm.soundPath!);
              player.play();
            } catch (_) {}
          }
          // Deactivate alarm after triggering
          alarm.active = false;
          await _repo.deactivateAlarm(alarm.id!);
        }
      }
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
  }
}
