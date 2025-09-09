import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'features/map_screen.dart';
import 'core/services/monitor_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/db_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/logger_service.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize services
      await DBService.instance.init();
      await NotificationService.instance.init();
      await AudioService.instance.init();

      // Set up error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        LoggerService.error(
          'Flutter error occurred',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // Request location permissions
      await PermissionService.instance.requestLocationPermission();

      // Start background monitoring
      MonitorService().startMonitoring();

      LoggerService.info("Application started successfully.");

      runApp(const MyApp());
    },
    (error, stack) {
      LoggerService.error(
        'Unhandled error in main',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SleepyTravels',
      theme: _buildPremiumDarkTheme(),
      home: const MapScreen(),
      // Disable debug banner for production
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildPremiumDarkTheme() {
    const Color primaryGold = Color(0xFFF0CB46);
    const Color secondaryGold = Color(0xFFCCA000);
    const Color navyBlue = Color(0xFF003566);
    const Color darkNavy = Color(0xFF001D3D);
    const Color darkBackground = Color(0xFF000814);
    const Color cardBackground = Color(0xFF001D3D);
    const Color surfaceColor = Color(0xFF003566);

    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.amber,
      primaryColor: primaryGold,
      scaffoldBackgroundColor: darkBackground,

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryGold,
        secondary: secondaryGold,
        surface: cardBackground,
        onPrimary: darkNavy,
        onSecondary: darkNavy,
        onSurface: Colors.white,
        tertiary: navyBlue,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkNavy,
        foregroundColor: primaryGold,
        elevation: 8,
        shadowColor: primaryGold,
        titleTextStyle: TextStyle(
          color: primaryGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: IconThemeData(color: primaryGold),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 8,
        shadowColor: primaryGold.withAlpha(77),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryGold.withAlpha(51), width: 1),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: darkNavy,
          elevation: 6,
          shadowColor: primaryGold.withAlpha(128),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGold,
        foregroundColor: darkNavy,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGold;
          }
          return Colors.grey[600];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return navyBlue;
          }
          return Colors.grey[800];
        }),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: primaryGold),

      // Text theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: primaryGold,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
        headlineMedium: TextStyle(
          color: primaryGold,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        bodyLarge: TextStyle(color: Colors.white, letterSpacing: 0.5),
        bodyMedium: TextStyle(color: Colors.white70, letterSpacing: 0.3),
        labelLarge: TextStyle(
          color: primaryGold,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGold.withAlpha(77)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGold.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        labelStyle: const TextStyle(color: primaryGold),
        hintStyle: TextStyle(color: Colors.white.withAlpha(153)),
        prefixIconColor: primaryGold,
        suffixIconColor: primaryGold,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navyBlue,
        contentTextStyle: const TextStyle(color: primaryGold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primaryGold.withAlpha(77), width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: primaryGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}
