// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const String _defaultVehicleKey = 'default_vehicle';

  Future<List<Vehicle>> getVehicles() async {
    return await _dbHelper.getVehicles();
  }

  Future<int?> getDefaultVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_defaultVehicleKey);
  }

  Future<void> setDefaultVehicle(int vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultVehicleKey, vehicleId);
  }
}
