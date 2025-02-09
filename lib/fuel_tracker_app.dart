import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'all_data_screen.dart';
// import 'fuel_tracker_model.dart';

class FuelTrackerApp extends StatelessWidget {
  const FuelTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuel Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DashboardScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/all_data': (context) => const AllDataScreen(),
      },
    );
  }
}