import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Haidilao Signature Color Palette
  static const Color primaryRed = Color(0xFFC62828);
  static const Color accentRed = Color(0xFFE53935);
  static const Color haidilaoGold = Color(0xFFFFD700);
  static const Color haidilaoGoldDark = Color(0xFFB8860B);

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);
  static const Color borderDark = Color(0xFF383838);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFEDEFF2);
  static const Color borderLight = Color(0xFFE0E3E8);

  /// Helper to check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Helper to get background color based on active theme
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  /// Helper to get surface color based on active theme
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? surfaceDark : surfaceLight;
  }

  /// Helper to get card color based on active theme
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? cardDark : cardLight;
  }

  /// Helper to get border color based on active theme
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;
  }

  /// Helper to get text primary color based on active theme
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1F2328);
  }

  /// Helper to get text secondary color based on active theme
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF57606A);
  }

  /// Helper to get gold accent color adapted for high contrast legibility
  static Color getGoldColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? haidilaoGold
        : const Color(0xFFC67D00); // Rich high-contrast dark amber gold for light backgrounds
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryRed,
      colorScheme: const ColorScheme.dark(
        primary: primaryRed,
        secondary: haidilaoGold,
        surface: surfaceDark,
        background: darkBackground,
        error: Colors.redAccent,
        onSurface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: Colors.white70),
        bodyMedium: GoogleFonts.inter(color: Colors.white60),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardDark,
        selectedColor: primaryRed,
        secondarySelectedColor: primaryRed,
        labelStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        secondaryLabelStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primaryRed,
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: haidilaoGoldDark,
        surface: surfaceLight,
        background: lightBackground,
        error: Colors.redAccent,
        onSurface: Color(0xFF1F2328),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1F2328)),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1F2328),
          letterSpacing: 0.5,
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: GoogleFonts.outfit(color: const Color(0xFF1F2328), fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: const Color(0xFF1F2328), fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF424A53)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF6E7781)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardLight,
        selectedColor: primaryRed,
        secondarySelectedColor: primaryRed,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF1F2328), fontSize: 13),
        secondaryLabelStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
