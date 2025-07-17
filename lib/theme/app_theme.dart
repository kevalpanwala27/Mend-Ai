import 'package:flutter/material.dart';

class AppTheme {
  static const Color partnerAColor = Color(0xFFE3F2FD); // Light blue
  static const Color partnerBColor = Color(0xFFFCE4EC); // Light pink
  static const Color partnerADark = Color(0xFF1976D2); // Darker blue
  static const Color partnerBDark = Color(0xFFC2185B); // Darker pink
  static const Color interruptionColor = Color(0xFFFF5252); // Red
  static const Color primaryTeal = Color(0xFF4DB6AC);
  static const Color accentBlushPink = Color(0xFFF8BBD9);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF757575);
  static const Color successGreen = Color(0xFF66BB6A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        brightness: Brightness.light,
        primary: primaryTeal,
        secondary: accentBlushPink,
        surface: backgroundLight,
        error: interruptionColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
      ),
    );
  }

  static Color getPartnerColor(String partnerId, {bool isDark = false}) {
    if (partnerId == 'A') {
      return isDark ? partnerADark : partnerAColor;
    } else {
      return isDark ? partnerBDark : partnerBColor;
    }
  }

  static Color getSpeakingIndicatorColor(String partnerId) {
    return partnerId == 'A' ? partnerADark : partnerBDark;
  }
}
