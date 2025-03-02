import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/l10n/l10n_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.loadSettings();
  runApp(const MyApp()); // Add const here
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  void setLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuel Consumption Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      localizationsDelegates: const [
        AppLocalizations.delegate, // Use the generated delegate
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.all, // Use the supported locales from L10n
      locale: _locale, // Set the locale here
      localeResolutionCallback: (locale, supportedLocales) {
        return supportedLocales.firstWhere(
              (supportedLocale) => supportedLocale.languageCode == locale?.languageCode,
          orElse: () => supportedLocales.first,
        );
      },
      home: const DashboardPage(), // Add const here
    );
  }
}