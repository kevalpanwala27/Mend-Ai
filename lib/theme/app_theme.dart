import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 🌙 Dark Mode Foundation - Deep, calming backgrounds
  static const Color backgroundPrimary = Color(0xFF0E0E0E); // Ultra deep black
  static const Color backgroundSecondary = Color(0xFF121212); // Card surfaces
  static const Color backgroundTertiary = Color(
    0xFF1A1A1A,
  ); // Elevated surfaces
  static const Color backgroundQuaternary = Color(
    0xFF242424,
  ); // Interactive surfaces

  // ✨ Neon Accent Colors - Soft, glowing, therapeutic
  static const Color neonTeal = Color(0xFF64FFDA); // Primary AI accent
  static const Color neonPink = Color(0xFFFF6B9D); // Partner B accent
  static const Color neonBlue = Color(0xFF4FC3F7); // Partner A accent
  static const Color neonViolet = Color(0xFFB39DDB); // Secondary accent
  static const Color neonCoral = Color(0xFFFF8A65); // Warning/Alert

  // 🎨 Partner Color System - Distinct but harmonious
  static const Color partnerAGlow = neonBlue; // Blue glow for Partner A
  static const Color partnerBGlow = neonPink; // Pink glow for Partner B

  // 📝 Typography Colors - High contrast, accessible
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFFE0E0E0); // Soft white
  static const Color textTertiary = Color(0xFFB0B0B0); // Muted white
  static const Color textQuaternary = Color(0xFF808080); // Subtle white

  // 🌫️ Glassmorphism Effects - Translucent, ethereal
  static const Color glassOverlay = Color(0x0DFFFFFF); // Ultra-subtle white
  static const Color glassBorder = Color(0x1AFFFFFF); // Soft white border
  static const Color glassHighlight = Color(0x33FFFFFF); // Brighter highlights

  // 🔥 AI Presence Colors - Dynamic, alive
  static const Color aiIdle = Color(0xFF404040); // Dormant state
  static const Color aiActive = neonTeal; // Active/listening
  static const Color aiSpeaking = neonViolet; // AI responding
  static const Color aiAlert = neonCoral; // Interruption warning

  // Legacy compatibility
  static const Color primary = neonTeal;
  static const Color secondary = neonPink;
  static const Color accent = neonViolet;
  static const Color background = backgroundPrimary;
  static const Color surface = backgroundSecondary;
  static const Color onPrimary = backgroundPrimary;
  static const Color onSecondary = backgroundPrimary;
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color interruptionColor = neonCoral;
  static const Color borderColor = glassBorder;
  static const Color partnerAColor = partnerAGlow;
  static const Color partnerBColor = partnerBGlow;
  static const Color gradientStart = neonTeal;
  static const Color gradientEnd = neonViolet;
  static const Color cardBackground = backgroundTertiary;

  // 📏 Spacing System - Consistent, rhythmic
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // 🔄 Border Radius - Fluid, organic
  static const double radiusXS = 6.0;
  static const double radiusS = 12.0;
  static const double radiusM = 18.0;
  static const double radiusL = 24.0;
  static const double radiusXL = 32.0;
  static const double radiusXXL = 48.0;

  // 🎯 Partner Color Methods
  static Color getPartnerColor(String partnerId, {bool isDark = true}) {
    switch (partnerId.toUpperCase()) {
      case 'A':
        return partnerAGlow;
      case 'B':
        return partnerBGlow;
      default:
        return neonViolet;
    }
  }

  static Color getSpeakingIndicatorColor(String partnerId) {
    return getPartnerColor(partnerId);
  }

  // 🌊 Waveform Colors - Dynamic visualization
  static List<Color> getWaveformColors(String? activeSpeaker) {
    final baseColor = activeSpeaker != null
        ? getPartnerColor(activeSpeaker)
        : neonTeal;

    return [
      baseColor.withValues(alpha: 1.0),
      baseColor.withValues(alpha: 0.7),
      baseColor.withValues(alpha: 0.4),
      baseColor.withValues(alpha: 0.2),
    ];
  }

  // 🎨 Main Theme Data
  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      error: interruptionColor,
      onError: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: backgroundTertiary,
      onSurfaceVariant: textSecondary,
      outline: glassBorder,
    ),
    scaffoldBackgroundColor: backgroundPrimary,
    fontFamily: GoogleFonts.manrope().fontFamily, // Soft, rounded typography
    // 📝 Text Theme - Modern, accessible hierarchy
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w300,
        color: textPrimary,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        letterSpacing: -1.0,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.6,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.4,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 0.2,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: 0.2,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        letterSpacing: 0.3,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textTertiary,
        letterSpacing: 0.4,
        height: 1.6,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textTertiary,
        letterSpacing: 0.6,
      ),
    ),

    // 📱 App Bar Theme - Clean, minimal
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: textPrimary, size: 24),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.4,
      ),
    ),

    // 🟦 Button Themes - Glowing, interactive
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM + 4,
        ),
      ),
    ),

    // 🎴 Card Theme - Glassmorphic, floating
    cardTheme: CardThemeData(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
      margin: EdgeInsets.all(spacingS),
    ),

    // 📝 Input Theme - Minimal, glowing focus
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundTertiary,
      contentPadding: EdgeInsets.symmetric(
        horizontal: spacingL,
        vertical: spacingM + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusL),
        borderSide: BorderSide(color: glassBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusL),
        borderSide: BorderSide(color: glassBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusL),
        borderSide: BorderSide(color: neonTeal, width: 2),
      ),
      labelStyle: TextStyle(color: textTertiary, fontSize: 16),
      hintStyle: TextStyle(color: textQuaternary, fontSize: 16),
    ),

    // 🌊 Dialog Theme - Floating, ethereal
    dialogTheme: DialogThemeData(
      backgroundColor: backgroundSecondary,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
    ),

    // 📄 Bottom Sheet Theme - Smooth, rounded
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
      ),
    ),
  );

  // ✨ Custom Decoration Methods

  /// Glassmorphic container with enhanced blur and glow effects
  static BoxDecoration glassmorphicDecoration({
    double borderRadius = 24,
    bool hasGlow = false,
    Color? glowColor,
    double opacity = 1.0,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          glassOverlay.withValues(alpha: opacity * 0.2),
          glassOverlay.withValues(alpha: opacity * 0.1),
          glassOverlay.withValues(alpha: opacity * 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glassBorder.withValues(alpha: opacity * 0.4),
        width: 1.5,
      ),
      boxShadow: [
        // Enhanced depth shadow
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
        // Inner light reflection
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, -2),
          spreadRadius: -8,
        ),
        // Glow effect
        if (hasGlow && glowColor != null) ...[
          BoxShadow(
            color: glowColor.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.1),
            blurRadius: 64,
            offset: const Offset(0, 0),
            spreadRadius: 8,
          ),
        ],
      ],
    );
  }

  /// Enhanced AI Orb decoration with better visual effects
  static BoxDecoration aiOrbDecoration({
    required Color color,
    bool isActive = false,
    double size = 120,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: 1.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.5),
          color.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
      ),
      boxShadow: [
        // Core glow
        BoxShadow(
          color: color.withValues(alpha: 0.8),
          blurRadius: size * 0.15,
          offset: const Offset(0, 0),
          spreadRadius: -size * 0.05,
        ),
        // Ambient glow
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: size * 0.3,
          offset: const Offset(0, 0),
          spreadRadius: 0,
        ),
        // Active state glow
        if (isActive) ...[
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: size * 0.5,
            offset: const Offset(0, 0),
            spreadRadius: size * 0.1,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: size * 0.8,
            offset: const Offset(0, 0),
            spreadRadius: size * 0.2,
          ),
        ],
      ],
    );
  }

  /// Neon gradient for buttons and interactive elements
  static LinearGradient neonGradient({
    required Color primaryColor,
    Color? secondaryColor,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        primaryColor,
        secondaryColor ?? primaryColor.withValues(alpha: 0.8),
        primaryColor.withValues(alpha: 0.6),
      ],
      stops: [0.0, 0.6, 1.0],
    );
  }

  /// Background gradient for screens
  static LinearGradient backgroundGradient({
    Color? topColor,
    Color? bottomColor,
  }) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        topColor ?? backgroundPrimary,
        bottomColor ?? backgroundSecondary,
      ],
    );
  }

  /// Primary gradient (legacy compatibility)
  static LinearGradient primaryGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    double opacity = 1.0,
  }) {
    return neonGradient(
      primaryColor: primary.withValues(alpha: opacity),
      begin: begin,
      end: end,
    );
  }

  /// Partner-specific gradients
  static LinearGradient partnerGradient(
    String partnerId, {
    double opacity = 1.0,
  }) {
    final color = getPartnerColor(partnerId);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: opacity * 0.6),
        color.withValues(alpha: opacity * 0.3),
        color.withValues(alpha: opacity * 0.1),
      ],
    );
  }

  /// Card decoration (legacy compatibility)
  static BoxDecoration cardDecoration({
    Color? color,
    double borderRadius = 24,
    bool hasGlow = false,
    Color? glowColor,
  }) {
    return glassmorphicDecoration(
      borderRadius: borderRadius,
      hasGlow: hasGlow,
      glowColor: glowColor,
    );
  }

  /// Waveform visualization decoration
  static BoxDecoration waveformDecoration(Color color, double intensity) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: intensity),
          color.withValues(alpha: intensity * 0.6),
          color.withValues(alpha: intensity * 0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(radiusXS),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: intensity * 0.5),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }
}
