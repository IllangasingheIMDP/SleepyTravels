import 'package:geolocator/geolocator.dart';

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
  Future<LocationPermission> requestLocationPermission() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        
        return LocationPermission.denied;
      }

      // Check current permission
      LocationPermission permission = await getCurrentPermission();
      

      // Request permission if needed
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
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
}
