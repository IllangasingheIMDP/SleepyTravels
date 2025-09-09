import 'package:flutter/material.dart';
import '../core/services/permission_service.dart';

class PermissionDialog {
  static Future<void> showActivityRecognitionPermissionDialog(
    BuildContext context,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Activity Recognition Permission'),
          content: const Text(
            'SleepyTravels needs Activity Recognition permission to detect when you\'re moving and optimize battery usage for location monitoring.\n\n'
            'This permission helps the app work more efficiently in the background.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Grant Permission'),
              onPressed: () async {
                Navigator.of(context).pop();
                await PermissionService.instance.requestActivityRecognition();
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required String permissionType,
    required String explanation,
    bool isPermanentlyDenied = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionType Permission Denied'),
          content: Text(
            isPermanentlyDenied
                ? '$explanation\n\nPlease go to Settings > Apps > SleepyTravels > Permissions to enable this permission manually.'
                : explanation,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (isPermanentlyDenied)
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await PermissionService.instance.openAppSettings();
                },
              )
            else
              TextButton(
                child: const Text('Try Again'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  static Future<void> showLocationPermissionDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'SleepyTravels needs location permission to monitor your travel progress and wake you up when you approach your destination.\n\n'
            'For the best experience, please select "Allow all the time" when prompted.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Grant Permission'),
              onPressed: () async {
                Navigator.of(context).pop();
                await PermissionService.instance.requestLocationPermission(
                  requestAlways: true,
                );
              },
            ),
          ],
        );
      },
    );
  }
}
