import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../data/repositories/alarm_repository.dart';
import '../../data/repositories/log_repository.dart';
import '../../data/models/log_model.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'audio_service.dart';

class MonitorService {
  static final MonitorService _instance = MonitorService._internal();
  factory MonitorService() => _instance;
  MonitorService._internal();
  final Distance _distance = const Distance();
  final AlarmRepository _repo = AlarmRepository();
  final LogRepository _logRepo = LogRepository();
  Timer? _timer;
  final Set<int> _triggeredAlarms = {}; // Track already triggered alarms
  bool _isProcessingAlarms = false; // Prevent concurrent processing

  void startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Prevent concurrent processing
      if (_isProcessingAlarms) {
        print('MonitorService: Already processing alarms, skipping cycle');
        return;
      }

      _isProcessingAlarms = true;

      try {
        // Check location permission using the permission service
        LocationPermission permission = await PermissionService.instance
            .getCurrentPermission();

        if (!PermissionService.instance.hasLocationPermission(permission)) {
          print(
            'MonitorService: No location permission, skipping monitoring cycle',
          );
          return;
        }

        Position pos = await Geolocator.getCurrentPosition();
        print(
          'MonitorService: Current position: ${pos.latitude}, ${pos.longitude}',
        );

        final alarms = await _repo.getActiveAlarmsFromDB();
        print('MonitorService: Found ${alarms.length} active alarms');

        // Process alarms one by one to avoid conflicts
        for (var alarm in alarms) {
          // Skip if this alarm was already triggered
          if (_triggeredAlarms.contains(alarm.id)) {
            print(
              'MonitorService: Alarm ${alarm.id} already triggered, skipping',
            );
            continue;
          }

          final distanceInMeters = _distance.as(
            LengthUnit.Meter,
            LatLng(pos.latitude, pos.longitude),
            LatLng(alarm.destLat, alarm.destLng),
          );

          print(
            'MonitorService: Alarm ${alarm.id} - Current distance: ${distanceInMeters.toStringAsFixed(2)}m, Trigger radius: ${alarm.radiusM}m',
          );

          if (distanceInMeters <= alarm.radiusM) {
            print('MonitorService: TRIGGERING ALARM ${alarm.id}!');

            // Mark this alarm as triggered
            _triggeredAlarms.add(alarm.id!);

            // Create a log entry for this trigger
            final logEntry = LogModel(
              alarmId: alarm.id,
              triggeredAt: DateTime.now().millisecondsSinceEpoch,
              lat: pos.latitude,
              lng: pos.longitude,
            );
            await _logRepo.addLog(logEntry);
            print('MonitorService: Log entry created for alarm ${alarm.id}');

            // Trigger notification (only once per alarm)
            await NotificationService.instance.showNotification(
              title: 'SleepyTravels Alarm',
              body:
                  'You are within ${alarm.radiusM}m of your destination! Distance: ${distanceInMeters.toStringAsFixed(2)}m',
              id: alarm.id!, // Use alarm ID as notification ID
            );

            // Only play sound if no other alarm is currently playing
            if (alarm.soundPath != null && !AudioService.instance.isPlaying) {
              print('MonitorService: Playing sound: ${alarm.soundPath}');
              try {
                await AudioService.instance.playFromPath(alarm.soundPath!);
              } catch (e) {
                print('MonitorService: Error playing sound: $e');
              }
            } else if (AudioService.instance.isPlaying) {
              print(
                'MonitorService: Alarm audio already playing, skipping sound for alarm ${alarm.id}',
              );
            }

            // Deactivate alarm after triggering
            await _repo.deactivateAlarm(alarm.id!);
            print('MonitorService: Alarm ${alarm.id} deactivated');

            // Break after first triggered alarm to avoid multiple simultaneous alarms
            break;
          } else {
            print(
              'MonitorService: Alarm ${alarm.id} not triggered - distance too far',
            );
          }
        }
      } catch (e) {
        print('MonitorService: Location monitoring error: $e');
      } finally {
        _isProcessingAlarms = false;
      }
    });
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    // Clear triggered alarms so they can trigger again if reactivated
    _triggeredAlarms.clear();
    _isProcessingAlarms = false;
    print('MonitorService: Monitoring stopped and alarm tracking cleared');
  }
}
