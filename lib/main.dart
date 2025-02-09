import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'fuel_tracker_app.dart';
import 'fuel_tracker_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => FuelTrackerModel(),
      child: const FuelTrackerApp(),
    ),
  );
}