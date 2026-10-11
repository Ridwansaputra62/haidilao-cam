import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized, high-performance settings persistence service.
/// All reads are synchronous from in-memory cache (0ms latency, zero UI stutter),
/// and all writes update in-memory state instantly while persisting asynchronously in the background.
class AppSettingsService {
  AppSettingsService._();

  static const String _keyWatermarkLogo = 'haidilao_watermark_logo';
  static const String _keyWatermarkVisible = 'haidilao_watermark_visible';
  static const String _keyCollageLogo = 'haidilao_collage_logo';
  static const String _keyTemplateLogo = 'haidilao_template_logo';

  // Default application settings requested:
  // Watermark logo: Logo Standar
  // Collage logo: Panda 1
  // Template logo: Panda 2
  static const String defaultWatermarkLogo = 'assets/images/haidilao_logo.png';
  static const String defaultCollageLogo = 'assets/images/haidilao_panda.png';
  static const String defaultTemplateLogo = 'assets/images/haidilao_panda2.png';

  static SharedPreferences? _prefs;
  static bool _initialized = false;

  static String _watermarkLogo = defaultWatermarkLogo;
  static bool _watermarkVisible = true;
  static String _collageLogo = defaultCollageLogo;
  static String _templateLogo = defaultTemplateLogo;

  /// Initializes SharedPreferences and loads saved settings into fast in-memory variables.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _watermarkLogo = _prefs?.getString(_keyWatermarkLogo) ?? defaultWatermarkLogo;
      _watermarkVisible = _prefs?.getBool(_keyWatermarkVisible) ?? true;
      _collageLogo = _prefs?.getString(_keyCollageLogo) ?? defaultCollageLogo;
      _templateLogo = _prefs?.getString(_keyTemplateLogo) ?? defaultTemplateLogo;
      _initialized = true;
    } catch (e) {
      debugPrint('AppSettingsService init error: $e');
    }
  }

  // ─── Watermark Logo ────────────────────────────────────────────────────────
  static String get watermarkLogo => _watermarkLogo;

  static Future<void> setWatermarkLogo(String path) async {
    if (_watermarkLogo == path) return;
    _watermarkLogo = path;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyWatermarkLogo, path);
    } catch (e) {
      debugPrint('Error saving watermark logo: $e');
    }
  }

  // ─── Watermark Visibility ──────────────────────────────────────────────────
  static bool get watermarkVisible => _watermarkVisible;

  static Future<void> setWatermarkVisible(bool visible) async {
    if (_watermarkVisible == visible) return;
    _watermarkVisible = visible;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_keyWatermarkVisible, visible);
    } catch (e) {
      debugPrint('Error saving watermark visibility: $e');
    }
  }

  // ─── Collage Logo (Default: Panda 1) ───────────────────────────────────────
  static String get collageLogo => _collageLogo;

  static Future<void> setCollageLogo(String path) async {
    if (_collageLogo == path) return;
    _collageLogo = path;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyCollageLogo, path);
    } catch (e) {
      debugPrint('Error saving collage logo: $e');
    }
  }

  // ─── Template Logo (Default: Panda 2) ──────────────────────────────────────
  static String get templateLogo => _templateLogo;

  static Future<void> setTemplateLogo(String path) async {
    if (_templateLogo == path) return;
    _templateLogo = path;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyTemplateLogo, path);
    } catch (e) {
      debugPrint('Error saving template logo: $e');
    }
  }
}
