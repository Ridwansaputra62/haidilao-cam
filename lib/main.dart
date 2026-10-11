import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:haidilao_cam/core/services/app_settings_service.dart';
import 'package:haidilao_cam/core/services/theme_service.dart';
import 'package:haidilao_cam/core/theme/app_theme.dart';
import 'package:haidilao_cam/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for all supported locales
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('zh_CN', null);
  await initializeDateFormatting('id', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('zh', null);
  await EasyLocalization.ensureInitialized();

  // Initialize Theme Service & App Settings
  await ThemeService.init();
  await AppSettingsService.init();

  // Allow all orientations for camera rotation UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('id'), Locale('en'), Locale('zh')],
      path: 'assets/translations',
      fallbackLocale: const Locale('id'),
      child: const HaidilaoCameraApp(),
    ),
  );
}

class HaidilaoCameraApp extends StatelessWidget {
  const HaidilaoCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          title: 'HI CAM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SplashScreen(),
        );
      },
    );
  }
}
