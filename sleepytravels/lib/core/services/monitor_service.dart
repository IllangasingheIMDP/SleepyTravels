import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geofence_service/geofence_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/alarm_repository.dart';
import '../../data/repositories/log_repository.dart';
import '../../data/models/log_model.dart';
import '../../data/models/alarm_model.dart';
import 'notification_service.dart';
import 'permission_service.dart';
import 'audio_service.dart';
import 'dart:developer' as developer;
@pragma('vm:entry-point')
class MonitorService {
  static final MonitorService _instance = MonitorService._internal();
  factory MonitorService() => _instance;
  MonitorService._internal();

  // Constants
  static const int _maxGeofencesAndroid = 100;
  static const int _maxGeofencesIOS = 20;
  static const String _geofenceIdsKey = 'geofence_ids';
  static const int _fallbackIntervalSeconds = 10; // Fallback polling interval

  // Services
  final AlarmRepository _alarmRepo = AlarmRepository();
  final LogRepository _logRepo = LogRepository();
  final Distance _distance = const Distance();

  // In-memory cache
  final List<AlarmModel> _cachedAlarms = [];
  final Set<String> _activeGeofenceIds = {};
  final Set<int> _triggeredAlarms = {};

  // State
  bool _isMonitoring = false;
  bool _isInitialized = false;
  bool _useGeofencing = true;
  bool _debugMode = true; // Enable debug logging
  Timer? _fallbackTimer;

  // Geofencing components (nullable for fallback mode)
  StreamSubscription<GeofenceStatus>? _geofenceSubscription;

  // Getters
  bool get isMonitoring => _isMonitoring;
  List<AlarmModel> get cachedAlarms => List.unmodifiable(_cachedAlarms);
  bool get isUsingGeofencing => _useGeofencing;

  /// Initialize the MonitorService
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      developer.log('MonitorService: Initializing...');

      // Try to initialize geofencing
      try {
        await _initializeGeofencing();
        _useGeofencing = true;
        developer.log('MonitorService: Geofencing initialized successfully');
      } catch (e) {
        developer.log('MonitorService: Geofencing initialization failed: $e');
        developer.log('MonitorService: Falling back to location polling mode');
        _useGeofencing = false;
      }

      // Initialize background service
      await _initializeBackgroundService();

      // Load cached alarms
      await _refreshAlarmCache();

      // Restore geofences from shared preferences if using geofencing
      if (_useGeofencing) {
        await _restoreGeofences();
      }

      _isInitialized = true;
      developer.log(
        'MonitorService: Initialization complete (Mode: ${_useGeofencing ? 'Geofencing' : 'Polling'})',
      );
    } catch (e) {
      developer.log('MonitorService: Initialization error: $e');
      rethrow;
    }
  }

  /// Initialize geofencing (with fallback handling)
  Future<void> _initializeGeofencing() async {
    try {
      // Create GeofenceService with basic setup
      GeofenceService.instance.setup(
        interval: 5000,
        accuracy: 100,
        loiteringDelayMs: 60000,
        statusChangeDelayMs: 10000,
        useActivityRecognition: true,
        allowMockLocations: false,
        geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
      );

      developer.log('MonitorService: GeofenceService setup completed');
    } catch (e) {
      developer.log('MonitorService: GeofenceService setup failed: $e');
      _useGeofencing = false;
      rethrow;
    }
  }

  /// Start monitoring with geofences or fallback to polling
  Future<void> startMonitoring() async {
    try {
      developer.log('MonitorService: Starting monitoring...');

      // Initialize if not done
      if (!_isInitialized) {
        await initialize();
      }

      // Check permissions
      final hasPermission = await _checkAndRequestPermissions();
      if (!hasPermission) {
        developer.log('MonitorService: Insufficient permissions for monitoring');
        return;
      }

      // Refresh alarm cache
      await _refreshAlarmCache();

      // Start background service
      final serviceRunning = await FlutterBackgroundService().isRunning();
      if (!serviceRunning) {
        FlutterBackgroundService().startService();
      }

      if (_useGeofencing) {
        // Use geofencing approach
        await _startGeofenceMonitoring();
      } else {
        // Use fallback polling approach
        await _startPollingMonitoring();
      }

      _isMonitoring = true;
      developer.log(
        'MonitorService: Monitoring started successfully (Mode: ${_useGeofencing ? 'Geofencing' : 'Polling'})',
      );
    } catch (e) {
      developer.log('MonitorService: Error starting monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    try {
      developer.log('MonitorService: Stopping monitoring...');

      _isMonitoring = false;

      if (_useGeofencing) {
        // Stop geofencing
        await _geofenceSubscription?.cancel();
        _geofenceSubscription = null;

        try {
          GeofenceService.instance.stop();
        } catch (e) {
          developer.log('MonitorService: Error stopping geofence service: $e');
        }

        await _clearAllGeofences();
      } else {
        // Stop polling
        _fallbackTimer?.cancel();
        _fallbackTimer = null;
      }

      // Stop background service
      FlutterBackgroundService().invoke('stop');

      // Clear cache and state
      _cachedAlarms.clear();
      _activeGeofenceIds.clear();
      _triggeredAlarms.clear();

      developer.log('MonitorService: Monitoring stopped successfully');
    } catch (e) {
      developer.log('MonitorService: Error stopping monitoring: $e');
    }
  }

  /// Start geofence-based monitoring
  Future<void> _startGeofenceMonitoring() async {
    try {
      developer.log('MonitorService: Starting geofence monitoring...');

      // Register geofences for active alarms
      await _registerGeofencesForActiveAlarms();

      // For now, use hybrid approach: start geofencing and also use polling as backup
      // This ensures we catch the alarm even if geofence events are not working perfectly
      try {
        await GeofenceService.instance.start();
        developer.log('MonitorService: GeofenceService started successfully');

        // Start a slower polling backup (every 30 seconds instead of 10)
        _fallbackTimer?.cancel();
        _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (
          timer,
        ) async {
          await _processAlarmsPolling();
        });
        developer.log(
          'MonitorService: Backup polling started (30s interval) with geofencing',
        );
      } catch (e) {
        developer.log('MonitorService: Failed to start GeofenceService: $e');
        throw e;
      }

      developer.log(
        'MonitorService: Hybrid geofence + polling monitoring setup completed',
      );
    } catch (e) {
      developer.log('MonitorService: Error starting geofence monitoring: $e');
      // Fall back to polling if geofencing fails
      developer.log(
        'MonitorService: Falling back to polling mode due to geofencing error',
      );
      _useGeofencing = false;
      await _startPollingMonitoring();
    }
  }

  /// Handle geofence events (placeholder for future implementation)
  Future<void> _handleGeofenceEvent(dynamic geofenceStatus) async {
    try {
      developer.log('MonitorService: Geofence event received: $geofenceStatus');
      // For now, just trigger alarm checking
      await _processAlarmsPolling();
    } catch (e) {
      developer.log('MonitorService: Error handling geofence event: $e');
    }
  }

  /// Start polling-based monitoring (fallback)
  Future<void> _startPollingMonitoring() async {
    try {
      developer.log('MonitorService: Starting polling monitoring...');

      _fallbackTimer?.cancel();
      _fallbackTimer = Timer.periodic(
        Duration(seconds: _fallbackIntervalSeconds),
        (timer) async {
          await _processAlarmsPolling();
        },
      );

      developer.log(
        'MonitorService: Polling monitoring started (interval: ${_fallbackIntervalSeconds}s)',
      );
    } catch (e) {
      developer.log('MonitorService: Error starting polling monitoring: $e');
      rethrow;
    }
  }

  /// Process alarms using polling method (improved from original)
  Future<void> _processAlarmsPolling() async {
    try {
      // Get current position
      final position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      developer.log(
        'MonitorService: Current position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)',
      );

      // Process each cached alarm
      for (final alarm in List.from(_cachedAlarms)) {
        if (alarm.id == null) continue;

        // Skip if already triggered
        if (_triggeredAlarms.contains(alarm.id)) {
          if (_debugMode)
            developer.log(
              'MonitorService: Alarm ${alarm.id} already triggered, skipping',
            );
          continue;
        }

        final distanceInMeters = _distance.as(
          LengthUnit.Meter,
          LatLng(position.latitude, position.longitude),
          LatLng(alarm.destLat, alarm.destLng),
        );

        developer.log(
          'MonitorService: Alarm ${alarm.id} - Distance: ${distanceInMeters.toStringAsFixed(2)}m, Radius: ${alarm.radiusM}m, Within: ${distanceInMeters <= alarm.radiusM}',
        );

        if (distanceInMeters <= alarm.radiusM) {
          developer.log(
            'MonitorService: 🚨 TRIGGERING ALARM ${alarm.id} 🚨 - User is within ${alarm.radiusM}m radius (distance: ${distanceInMeters.toStringAsFixed(1)}m)!',
          );
          await _triggerAlarm(alarm, position.latitude, position.longitude);
          break; // Process one alarm at a time
        }
      }
    } catch (e) {
      developer.log('MonitorService: Error in polling cycle: $e');
    }
  }

  /// Trigger an alarm (common logic for both geofencing and polling)
  Future<void> _triggerAlarm(AlarmModel alarm, double lat, double lng) async {
    try {
      if (alarm.id == null) return;

      developer.log('MonitorService: TRIGGERING ALARM ${alarm.id}!');

      // Mark as triggered
      _triggeredAlarms.add(alarm.id!);

      // Create log entry
      final logEntry = LogModel(
        alarmId: alarm.id,
        triggeredAt: DateTime.now().millisecondsSinceEpoch,
        lat: lat,
        lng: lng,
      );
      await _logRepo.addLog(logEntry);
      developer.log('MonitorService: Log entry created for alarm ${alarm.id}');

      // Show notification
      await NotificationService.instance.showNotification(
        title: 'SleepyTravels Alarm',
        body: 'You have arrived at your destination!',
        id: alarm.id!,
      );

      // Play sound if available and no other alarm is playing
      if (alarm.soundPath != null && !AudioService.instance.isPlaying) {
        developer.log('MonitorService: Playing sound: ${alarm.soundPath}');
        try {
          await AudioService.instance.playFromPath(alarm.soundPath!);
        } catch (e) {
          developer.log('MonitorService: Error playing sound: $e');
        }
      }

      // Deactivate alarm
      await _alarmRepo.deactivateAlarm(alarm.id!);

      // Remove from cache
      _cachedAlarms.removeWhere((a) => a.id == alarm.id);

      // Remove geofence if using geofencing
      if (_useGeofencing) {
        final geofenceId = 'alarm_${alarm.id}';
        await _removeGeofence(geofenceId);
      }

      developer.log('MonitorService: Alarm ${alarm.id} processed and deactivated');
    } catch (e) {
      developer.log('MonitorService: Error triggering alarm: $e');
    }
  }

  /// Refresh the in-memory alarm cache
  Future<void> _refreshAlarmCache() async {
    try {
      final alarms = await _alarmRepo.getActiveAlarmsFromDB();
      _cachedAlarms.clear();
      _cachedAlarms.addAll(alarms);
      developer.log(
        'MonitorService: Cache refreshed with ${_cachedAlarms.length} active alarms',
      );
    } catch (e) {
      developer.log('MonitorService: Error refreshing alarm cache: $e');
    }
  }

  /// Check and request necessary permissions
  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Check location permission
      final permission = await PermissionService.instance
          .getCurrentPermission();
      if (!PermissionService.instance.hasLocationPermission(permission)) {
        // Request "always" permission for background monitoring
        final requestedPermission = await PermissionService.instance
            .requestLocationPermission(requestAlways: true);
        if (!PermissionService.instance.hasLocationPermission(
          requestedPermission,
        )) {
          developer.log('MonitorService: Location permission denied');
          return false;
        }

        // Log permission type for monitoring efficiency
        if (requestedPermission == geolocator.LocationPermission.always) {
          developer.log(
            'MonitorService: Always location permission granted - optimal for background monitoring',
          );
        } else {
          developer.log(
            'MonitorService: WhileInUse permission granted - background monitoring may be limited',
          );
        }
      }

      // Check if location services are enabled
      final serviceEnabled = await PermissionService.instance
          .isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('MonitorService: Location services disabled');
        return false;
      }

      // Check activity recognition permission for geofencing
      if (_useGeofencing) {
        final activityStatus = await PermissionService.instance
            .getActivityRecognitionStatus();

        if (!PermissionService.instance.hasActivityRecognitionPermission(
          activityStatus,
        )) {
          developer.log(
            'MonitorService: Requesting activity recognition permission for geofencing',
          );
          final requestedActivity = await PermissionService.instance
              .requestActivityRecognition();

          if (!PermissionService.instance.hasActivityRecognitionPermission(
            requestedActivity,
          )) {
            developer.log(
              'MonitorService: Activity recognition permission denied - falling back to polling mode',
            );
            _useGeofencing = false;
            return true; // Continue with polling mode
          } else {
            developer.log('MonitorService: Activity recognition permission granted');
          }
        } else {
          developer.log(
            'MonitorService: Activity recognition permission already granted',
          );
        }
      }

      return true;
    } catch (e) {
      developer.log('MonitorService: Error checking permissions: $e');
      return false;
    }
  }

  /// Register geofences for all active alarms (geofencing mode)
  Future<void> _registerGeofencesForActiveAlarms() async {
    if (!_useGeofencing) return;

    try {
      developer.log(
        'MonitorService: Registering geofences for ${_cachedAlarms.length} alarms',
      );

      // Check platform limits
      final platformLimit = Platform.isIOS
          ? _maxGeofencesIOS
          : _maxGeofencesAndroid;

      if (_cachedAlarms.length > platformLimit) {
        developer.log(
          'MonitorService: Warning - ${_cachedAlarms.length} alarms exceed platform limit of $platformLimit geofences',
        );
      }

      int registeredCount = 0;

      for (final alarm in _cachedAlarms) {
        if (registeredCount >= platformLimit) {
          developer.log(
            'MonitorService: Skipping alarm ${alarm.id} - platform limit reached',
          );
          break;
        }

        if (alarm.id == null) continue;

        final geofenceId = 'alarm_${alarm.id}';

        // Skip if already registered
        if (_activeGeofenceIds.contains(geofenceId)) {
          developer.log('MonitorService: Geofence $geofenceId already registered');
          continue;
        }

        // Create geofence with correct API structure
        try {
          final geofence = Geofence(
            id: geofenceId,
            latitude: alarm.destLat,
            longitude: alarm.destLng,
            radius: [
              GeofenceRadius(
                id: 'radius_${alarm.id}',
                length: alarm.radiusM.toDouble(),
              ),
            ],
          );

          GeofenceService.instance.addGeofence(geofence);
          _activeGeofenceIds.add(geofenceId);
          registeredCount++;

          developer.log(
            'MonitorService: Registered geofence for alarm ${alarm.id} at (${alarm.destLat}, ${alarm.destLng}) with radius ${alarm.radiusM}m',
          );
        } catch (e) {
          developer.log(
            'MonitorService: Error creating geofence for alarm ${alarm.id}: $e',
          );
        }
      }

      await _saveGeofenceIds();
      developer.log(
        'MonitorService: Geofence registration completed - ${registeredCount} geofences registered',
      );
    } catch (e) {
      developer.log('MonitorService: Error registering geofences: $e');
    }
  }

  /// Remove a specific geofence
  Future<void> _removeGeofence(String geofenceId) async {
    if (!_useGeofencing) return;

    try {
      GeofenceService.instance.removeGeofenceById(geofenceId);
      _activeGeofenceIds.remove(geofenceId);
      await _saveGeofenceIds();
      developer.log('MonitorService: Removed geofence: $geofenceId');
    } catch (e) {
      developer.log('MonitorService: Error removing geofence $geofenceId: $e');
    }
  }

  /// Clear all geofences
  Future<void> _clearAllGeofences() async {
    if (!_useGeofencing) return;

    try {
      for (final geofenceId in List.from(_activeGeofenceIds)) {
        GeofenceService.instance.removeGeofenceById(geofenceId);
      }
      _activeGeofenceIds.clear();
      await _saveGeofenceIds();
      developer.log('MonitorService: All geofences cleared');
    } catch (e) {
      developer.log('MonitorService: Error clearing geofences: $e');
    }
  }

  /// Save geofence IDs to shared preferences
  Future<void> _saveGeofenceIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geofenceList = _activeGeofenceIds.toList();
      await prefs.setString(_geofenceIdsKey, jsonEncode(geofenceList));
    } catch (e) {
      developer.log('MonitorService: Error saving geofence IDs: $e');
    }
  }

  /// Restore geofences from shared preferences
  Future<void> _restoreGeofences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geofenceJson = prefs.getString(_geofenceIdsKey);

      if (geofenceJson != null) {
        final geofenceList = List<String>.from(jsonDecode(geofenceJson));
        _activeGeofenceIds.addAll(geofenceList);
        developer.log(
          'MonitorService: Restored ${geofenceList.length} geofence IDs from preferences',
        );
      }
    } catch (e) {
      developer.log('MonitorService: Error restoring geofence IDs: $e');
    }
  }

  /// Initialize background service
  Future<void> _initializeBackgroundService() async {
    try {
      // Ensure notification channels are created first
      await NotificationService.instance.init();

      // Configure background service
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'sleepy_travels_bg',
          initialNotificationTitle: 'SleepyTravels',
          initialNotificationContent: 'Monitoring your travel alarms',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      developer.log('MonitorService: Background service configured');
    } catch (e) {
      developer.log('MonitorService: Error configuring background service: $e');
    }
  }

  /// Background service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    service.on('stop').listen((event) {
      service.stopSelf();
    });

    // Background monitoring timer
    Timer.periodic(const Duration(seconds: 20), (timer) async {
      try {
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            service.setForegroundNotificationInfo(
              title: "SleepyTravels",
              content: "Monitoring your travel alarms",
            );
          }
        }

        // Run alarm checking in background
        final monitorService = MonitorService();
        if (monitorService._isMonitoring &&
            monitorService._cachedAlarms.isNotEmpty) {
          developer.log('MonitorService: Background service checking alarms...');
          await monitorService._processAlarmsPolling();
        }

        developer.log('MonitorService: Background service heartbeat');
      } catch (e) {
        developer.log('MonitorService: Background service error: $e');
      }
    });
  }

  /// iOS background handler
  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    developer.log('MonitorService: iOS background mode');
    return true;
  }

  /// Public methods for cache management

  /// Add alarm to cache and register geofence
  Future<void> addAlarmToCache(AlarmModel alarm) async {
    if (!_isMonitoring) return;

    try {
      _cachedAlarms.add(alarm);

      if (_useGeofencing && alarm.id != null) {
        final geofenceId = 'alarm_${alarm.id}';
        final geofence = Geofence(
          id: geofenceId,
          latitude: alarm.destLat,
          longitude: alarm.destLng,
          radius: [
            GeofenceRadius(
              id: 'radius_${alarm.id}',
              length: alarm.radiusM.toDouble(),
            ),
          ],
        );

        GeofenceService.instance.addGeofence(geofence);
        _activeGeofenceIds.add(geofenceId);
        await _saveGeofenceIds();

        developer.log(
          'MonitorService: Added alarm ${alarm.id} to cache and registered geofence',
        );
      } else {
        developer.log(
          'MonitorService: Added alarm ${alarm.id} to cache (polling mode)',
        );
      }
    } catch (e) {
      developer.log('MonitorService: Error adding alarm to cache: $e');
    }
  }

  /// Remove alarm from cache and unregister geofence
  Future<void> removeAlarmFromCache(int alarmId) async {
    try {
      _cachedAlarms.removeWhere((a) => a.id == alarmId);
      _triggeredAlarms.remove(alarmId);

      if (_useGeofencing) {
        final geofenceId = 'alarm_$alarmId';
        await _removeGeofence(geofenceId);
      }

      developer.log('MonitorService: Removed alarm $alarmId from cache');
    } catch (e) {
      developer.log('MonitorService: Error removing alarm from cache: $e');
    }
  }

  /// Update alarm in cache and geofence
  Future<void> updateAlarmInCache(AlarmModel updatedAlarm) async {
    if (!_isMonitoring || updatedAlarm.id == null) return;

    try {
      final index = _cachedAlarms.indexWhere((a) => a.id == updatedAlarm.id);
      if (index != -1) {
        _cachedAlarms[index] = updatedAlarm;

        if (_useGeofencing) {
          // Remove old geofence and add new one
          final geofenceId = 'alarm_${updatedAlarm.id}';
          await _removeGeofence(geofenceId);

          final geofence = Geofence(
            id: geofenceId,
            latitude: updatedAlarm.destLat,
            longitude: updatedAlarm.destLng,
            radius: [
              GeofenceRadius(
                id: 'radius_${updatedAlarm.id}',
                length: updatedAlarm.radiusM.toDouble(),
              ),
            ],
          );

          GeofenceService.instance.addGeofence(geofence);
          _activeGeofenceIds.add(geofenceId);
          await _saveGeofenceIds();
        }

        developer.log('MonitorService: Updated alarm ${updatedAlarm.id} in cache');
      }
    } catch (e) {
      developer.log('MonitorService: Error updating alarm in cache: $e');
    }
  }
}
