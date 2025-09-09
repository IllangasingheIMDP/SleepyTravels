import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static PermissionService get instance => _instance;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location permission status
  Future<LocationPermission> getCurrentPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission with comprehensive handling
  /// For background monitoring, tries to get "always" permission
  Future<LocationPermission> requestLocationPermission({
    bool requestAlways = false,
  }) async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('PermissionService: Location services not enabled');
        return LocationPermission.denied;
      }

      // Check current permission
      LocationPermission permission = await getCurrentPermission();
      print('PermissionService: Current permission: $permission');

      // Request permission if needed
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('PermissionService: Requested permission result: $permission');
      }

      // If we need always permission and currently have whileInUse, request always
      if (requestAlways && permission == LocationPermission.whileInUse) {
        print(
          'PermissionService: Requesting always location permission for background monitoring',
        );

        // Note: On Android 10+ and iOS, this requires explicit user action
        // The app should show a dialog explaining why "always" permission is needed
        permission = await Geolocator.requestPermission();

        if (permission != LocationPermission.always) {
          print(
            'PermissionService: Always permission denied, using whileInUse',
          );
        }
      }

      // Log final status
      switch (permission) {
        case LocationPermission.always:
          print('PermissionService: Location permission granted (always)');
          break;
        case LocationPermission.whileInUse:
          print(
            'PermissionService: Location permission granted (while in use)',
          );
          break;
        case LocationPermission.denied:
          print('PermissionService: Location permission denied');
          break;
        case LocationPermission.deniedForever:
          print('PermissionService: Location permission permanently denied');
          break;
        case LocationPermission.unableToDetermine:
          print('PermissionService: Unable to determine location permission');
          break;
      }

      return permission;
    } catch (e) {
      print('PermissionService: Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Check if we have sufficient location permission
  bool hasLocationPermission(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Open app settings for manual permission grant
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      print('PermissionService: Error opening app settings: $e');
      return false;
    }
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      print('PermissionService: Error opening location settings: $e');
      return false;
    }
  }

  /// Check activity recognition permission status
  Future<PermissionStatus> getActivityRecognitionStatus() async {
    try {
      return await Permission.activityRecognition.status;
    } catch (e) {
      print(
        'PermissionService: Error checking activity recognition status: $e',
      );
      return PermissionStatus.denied;
    }
  }

  /// Request activity recognition permission
  Future<PermissionStatus> requestActivityRecognition() async {
    try {
      final status = await Permission.activityRecognition.request();
      print(
        'PermissionService: Activity recognition permission status: $status',
      );
      return status;
    } catch (e) {
      print(
        'PermissionService: Error requesting activity recognition permission: $e',
      );
      return PermissionStatus.denied;
    }
  }

  /// Check if activity recognition permission is granted
  bool hasActivityRecognitionPermission(PermissionStatus status) {
    return status == PermissionStatus.granted;
  }

  /// Handle permanently denied activity recognition permission
  Future<void> handleActivityRecognitionPermanentlyDenied() async {
    print(
      'PermissionService: Activity recognition permission permanently denied',
    );
    // Show dialog to user explaining they need to go to settings
    await openAppSettings();
  }

  /// Request all necessary permissions for geofencing
  Future<Map<String, bool>> requestGeofencingPermissions() async {
    final results = <String, bool>{};

    // Request location permission
    final locationPermission = await requestLocationPermission(
      requestAlways: true,
    );
    results['location'] = hasLocationPermission(locationPermission);

    // Request activity recognition permission
    final activityStatus = await requestActivityRecognition();
    results['activityRecognition'] = hasActivityRecognitionPermission(
      activityStatus,
    );

    // Handle permanently denied activity recognition
    if (activityStatus == PermissionStatus.permanentlyDenied) {
      await handleActivityRecognitionPermanentlyDenied();
    }

    return results;
  }
}
