// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/theme.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.loadSettings();
  MobileAds.instance.initialize();
  runApp(const MyApp());
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
          home: const DashboardPage(),
        );
      },
    );
  }
}
