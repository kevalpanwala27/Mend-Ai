import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF4FC3F7); // Soft blue
  static const Color secondary = Color(0xFFF8BBD0); // Soft pink
  static const Color accent = Color(0xFF80CBC4); // Teal
  static const Color background = Color(0xFFF5F7FA); // Light background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFF0D47A1);
  static const Color onSecondary = Color(0xFFAD1457);
  static const Color successGreen = Color(0xFF43A047);
  static const Color interruptionColor = Color(0xFFFF5252);

  // Partner color coding
  static Color getPartnerColor(String partnerId, {bool isDark = false}) {
    if (partnerId == 'A') {
      return isDark ? const Color(0xFF1976D2) : primary;
    } else if (partnerId == 'B') {
      return isDark ? const Color(0xFFD81B60) : secondary;
    } else {
      // Fallback for same-gender or unknown
      return isDark ? accent : accent.withOpacity(0.7);
    }
  }

  static Color getSpeakingIndicatorColor(String partnerId) {
    if (partnerId == 'A') {
      return primary;
    } else if (partnerId == 'B') {
      return secondary;
    } else {
      return accent;
    }
  }

  static ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: interruptionColor,
      onError: Colors.white,
      background: background,
      onBackground: Colors.black,
      surface: surface,
      onSurface: Colors.black,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      elevation: 0,
      iconTheme: IconThemeData(color: primary),
      titleTextStyle: TextStyle(
        color: onPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
