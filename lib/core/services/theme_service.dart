import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themePrefKey = 'haidilao_app_theme_mode';

  /// Reactive notifier for global app ThemeMode (Default: Light per user request)
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Initializes saved theme mode preference from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedTheme = prefs.getString(_themePrefKey);
      if (savedTheme != null) {
        if (savedTheme == 'dark') {
          themeNotifier.value = ThemeMode.dark;
        } else {
          themeNotifier.value = ThemeMode.light;
        }
      } else {
        themeNotifier.value = ThemeMode.light;
      }
    } catch (e) {
      debugPrint('Error loading saved theme preference: $e');
    }
  }

  /// Returns true if current theme is Dark Mode
  static bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  /// Toggles theme mode between Light and Dark globally
  static Future<void> toggleTheme() async {
    final ThemeMode nextMode = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(nextMode);
  }

  /// Sets a specific ThemeMode (Light or Dark)
  static Future<void> setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
