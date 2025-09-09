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
      theme: _buildPremiumDarkTheme(),
      home: const MapScreen(),
    );
  }

  ThemeData _buildPremiumDarkTheme() {
    const Color primaryGold = Color(0xFFFFD700);
    const Color secondaryGold = Color(0xFFFFA500);
    const Color navyBlue = Color(0xFF1A237E);
    const Color darkNavy = Color(0xFF0D1B3C);
    const Color lightNavy = Color(0xFF3949AB);
    const Color darkBackground = Color(0xFF0A0A0A);
    const Color cardBackground = Color(0xFF1A1A1A);
    const Color surfaceColor = Color(0xFF2A2A2A);

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
        background: darkBackground,
        onPrimary: darkNavy,
        onSecondary: darkNavy,
        onSurface: Colors.white,
        onBackground: Colors.white,
        tertiary: navyBlue,
        outline: lightNavy,
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
        shadowColor: primaryGold.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryGold.withOpacity(0.2), width: 1),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: darkNavy,
          elevation: 6,
          shadowColor: primaryGold.withOpacity(0.5),
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
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryGold;
          }
          return Colors.grey[600];
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
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
          borderSide: BorderSide(color: primaryGold.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 2),
        ),
        labelStyle: const TextStyle(color: primaryGold),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
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
          side: BorderSide(color: primaryGold.withOpacity(0.3), width: 1),
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
