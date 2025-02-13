import 'package:flutter/material.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.loadSettings();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuel Consumption Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DashboardPage(),
    );
  }
}
