# SleepyTravels MonitorService Refactor - Implementation Guide

## Overview

The MonitorService has been completely refactored to use **geofencing** instead of timer-based polling, with automatic fallback to improved polling when geofencing is unavailable. This provides **better battery efficiency**, **background execution**, and **in-memory caching**.

## Key Features Implemented

### ✅ 1. Geofencing with Fallback
- **Primary**: Uses `geofence_service` package for efficient location monitoring
- **Fallback**: Enhanced polling system (10-second intervals) when geofencing fails
- **Automatic detection**: Seamlessly switches between modes
- **Platform limits**: Respects Android (~100) and iOS (~20) geofence limits

### ✅ 2. In-Memory Caching
- **Cache management**: `List<AlarmModel>` cached in MonitorService
- **Auto-sync**: AlarmRepository automatically updates cache on CRUD operations
- **Performance**: Eliminates repeated database queries
- **Memory safe**: Cache cleared on monitoring stop

### ✅ 3. Background Execution
- **Flutter Background Service**: Persistent foreground service with notification
- **Platform support**: Android foreground service + iOS background modes
- **Always permission**: Requests "always" location for optimal background operation
- **Service lifecycle**: Proper start/stop with heartbeat monitoring

### ✅ 4. Enhanced Features
- **Shared preferences**: Persists geofence IDs across app restarts
- **Error handling**: Comprehensive error logging and recovery
- **Permission management**: Enhanced permission requests with "always" option
- **Battery optimization**: Efficient geofencing vs polling based on availability

## API Changes and Usage

### MonitorService Methods

```dart
// Initialize and start monitoring
await MonitorService().initialize();
await MonitorService().startMonitoring();

// Stop monitoring
await MonitorService().stopMonitoring();

// Check status
bool isMonitoring = MonitorService().isMonitoring;
bool usingGeofencing = MonitorService().isUsingGeofencing;
List<AlarmModel> cachedAlarms = MonitorService().cachedAlarms;

// Cache management (automatically called by AlarmRepository)
await MonitorService().addAlarmToCache(alarm);
await MonitorService().removeAlarmFromCache(alarmId);
await MonitorService().updateAlarmInCache(updatedAlarm);
```

### AlarmRepository Integration

The AlarmRepository now automatically manages the MonitorService cache:

```dart
// Adding an alarm - automatically updates cache
await alarmRepo.addAlarm(newAlarm);

// Updating alarm - automatically updates cache and geofences
await alarmRepo.updateAlarm(id, newRadius, newSoundPath);

// Deactivating alarm - automatically removes from cache
await alarmRepo.deactivateAlarm(id);

// Removing alarm - automatically cleans up cache
await alarmRepo.removeAlarm(id);
```

### Permission Enhancements

```dart
// Request optimal permissions for background monitoring
final permission = await PermissionService.instance.requestLocationPermission(requestAlways: true);
```

## Background Service Configuration

The service uses these configurations:

### Android
- **Foreground service**: Persistent notification "Monitoring your travel alarms"
- **Notification channel**: `sleepy_travels_bg`
- **Service ID**: 888
- **Auto-start**: Disabled (manual control)

### iOS
- **Background modes**: Location and background processing
- **Foreground/Background**: Dual mode support

## Monitoring Modes

### Geofencing Mode (Preferred)
- **Efficiency**: System-level location monitoring
- **Battery**: Minimal battery usage
- **Accuracy**: Platform-optimized
- **Triggers**: Immediate geofence entry detection

### Polling Mode (Fallback)
- **Frequency**: 10-second intervals (improved from 5 seconds)
- **Accuracy**: High accuracy GPS requests
- **Battery**: Moderate usage (better than original)
- **Logic**: Distance calculation with LatLng

## Error Handling and Logging

### Comprehensive Logging
- **Initialization**: Service setup and mode detection
- **Permissions**: Permission requests and results
- **Geofencing**: Registration, events, and errors
- **Alarm triggers**: Detailed trigger information
- **Background service**: Heartbeat and lifecycle events

### Fallback Scenarios
1. **Geofencing unavailable**: Automatic fallback to polling
2. **Permission issues**: Graceful degradation
3. **Service errors**: Recovery mechanisms
4. **Platform limits**: Warning logs when limits exceeded

## Deployment Steps

### 1. Android Permissions (android/app/src/main/AndroidManifest.xml)
```xml
<!-- Add these permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Add to application section -->
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:exported="false" />
```

### 2. iOS Permissions (ios/Runner/Info.plist)
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to trigger alarms when you reach your destination.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to trigger alarms when you reach your destination.</string>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
</array>
```

### 3. Test the Implementation

```dart
// Example usage in your app
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeMonitoring();
  }

  Future<void> _initializeMonitoring() async {
    try {
      await MonitorService().initialize();
      // Start monitoring only when user has active alarms
      if (shouldStartMonitoring) {
        await MonitorService().startMonitoring();
      }
    } catch (e) {
      print('Failed to initialize monitoring: $e');
    }
  }

  @override
  void dispose() {
    MonitorService().stopMonitoring();
    super.dispose();
  }
}
```

## Performance Benefits

### Battery Optimization
- **Geofencing**: System-level efficiency
- **Reduced polling**: 10s intervals vs 5s
- **Smart fallback**: Only when necessary
- **Permission optimization**: "Always" permission for background efficiency

### Memory Management
- **Cached alarms**: No repeated DB queries
- **Proper cleanup**: Cache cleared on stop
- **Geofence persistence**: SharedPreferences for restoration

### Background Reliability
- **Foreground service**: Prevents system termination
- **Service monitoring**: Heartbeat every 30 seconds
- **Cross-platform**: Android and iOS support

## Testing Checklist

- [ ] Monitor starts/stops without errors
- [ ] Geofencing mode detection works
- [ ] Fallback to polling when geofencing unavailable
- [ ] Alarm triggers work in both modes
- [ ] Background service persists
- [ ] Permissions requested correctly
- [ ] Cache updates on alarm CRUD operations
- [ ] App restart preserves geofences
- [ ] Platform limits respected
- [ ] Battery usage optimized

## Troubleshooting

### Common Issues

1. **Geofencing not working**: Check if falling back to polling mode in logs
2. **Background not working**: Verify "always" location permission granted
3. **Cache not updating**: Check AlarmRepository integration
4. **Service stops**: Check battery optimization settings on device
5. **Permissions denied**: Guide user to settings for manual permission grant

### Debug Information

Monitor logs for these patterns:
- `MonitorService: Initialization complete (Mode: Geofencing/Polling)`
- `MonitorService: Always location permission granted`
- `MonitorService: Background service heartbeat`
- `MonitorService: TRIGGERING ALARM X!`

## Future Enhancements

### Potential Improvements
1. **Battery optimization dialog**: Prompt user to disable battery optimization
2. **Geofencing API migration**: Switch to newer `geofencing_api` package
3. **Smart polling**: Adaptive intervals based on distance to destinations
4. **Analytics**: Track monitoring efficiency and battery usage
5. **User preferences**: Allow users to choose monitoring mode

This refactored implementation provides a robust, efficient, and scalable foundation for location-based alarm monitoring in SleepyTravels.
