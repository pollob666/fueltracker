// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';
import 'package:fuel_tracker/services/in_app_purchase_service.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:fuel_tracker/services/workmanager_backup_service.dart';
import 'package:fuel_tracker/theme.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await AppSettings.loadSettings();
    await NotificationService.instance.initialize();
    await WorkManagerBackupService.initialize();
    unawaited(InAppPurchaseService.instance.initialize(null));
    if (AppSettings.autoBackupEnabled) {
      await WorkManagerBackupService.schedulePeriodicBackup(
        frequencyDays: AppSettings.autoBackupFrequencyDays,
        wifiOnly: AppSettings.autoBackupWifiOnly,
      );
    }

    // Support portrait and landscape orientations for foldables and tablets
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Enable edge-to-edge mode
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    // Initialize Google Mobile Ads SDK
    if (AppSettings.adsEnabled) {
      // Use test ads during development to avoid policy violations
      RequestConfiguration configuration =
          RequestConfiguration(testDeviceIds: ["YOUR_TEST_DEVICE_ID"]);
      MobileAds.instance.updateRequestConfiguration(configuration);
      await MobileAds.instance.initialize();
    }

    runApp(const ProviderScope(child: MyApp()));
  } catch (error, stackTrace) {
    // In a real-world app, you would use a robust error logging framework
    // like Sentry or Firebase Crashlytics to report errors.
    // For now, we just print the error to the console.
    debugPrint('Caught error: $error');
    debugPrint('Stack trace: $stackTrace');

    // Optionally, you could run a fallback app to display the error.
    // runApp(ErrorApp(error: error, stackTrace: stackTrace));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  static void setThemeMode(BuildContext context, String themeMode) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setThemeMode(themeMode);
  }

  static void setDarkTheme(BuildContext context, String darkTheme) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setDarkTheme(darkTheme);
  }
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  String _themeMode = AppSettings.themeMode;
  String _darkTheme = AppSettings.darkTheme;

  @override
  void initState() {
    super.initState();
    _locale = Locale(AppSettings.language);
    _themeMode = AppSettings.themeMode;
    _darkTheme = AppSettings.darkTheme;
  }

  void setLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
      AppSettings.language = newLocale.languageCode;
      AppSettings.saveSettings();
    });
  }

  void setThemeMode(String themeMode) {
    setState(() {
      _themeMode = themeMode;
      AppSettings.themeMode = themeMode;
      AppSettings.saveSettings();
    });
  }

  void setDarkTheme(String darkTheme) {
    setState(() {
      _darkTheme = darkTheme;
      AppSettings.darkTheme = darkTheme;
      AppSettings.saveSettings();
    });
  }

  ThemeMode get _currentThemeMode {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final darkTheme = _darkTheme == 'monet'
            ? AppTheme.getMonetDarkTheme(darkDynamic)
            : AppTheme.getBlackDarkTheme(darkDynamic);

        return MaterialApp(
          title: 'Fuel Consumption Tracker',
          theme: AppTheme.getLightTheme(lightDynamic),
          darkTheme: darkTheme,
          themeMode: _currentThemeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: _locale,
          localeResolutionCallback: (locale, supportedLocales) {
            return supportedLocales.firstWhere(
              (supportedLocale) =>
                  supportedLocale.languageCode == locale?.languageCode,
              orElse: () => supportedLocales.first,
            );
          },
          builder: (context, child) {
            return MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.35,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const DashboardPage(),
        );
      },
    );
  }
}
