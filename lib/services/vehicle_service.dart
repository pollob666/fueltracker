// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleService {
  final DatabaseHelper _dbHelper;
  static const String _defaultVehicleKey = 'default_vehicle';

  VehicleService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

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

  Future<void> clearDefaultVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_defaultVehicleKey);
  }

  Future<int> getRecordCountForVehicle(int vehicleId) async {
    return await _dbHelper.getFuelRecordCountForVehicle(vehicleId);
  }

  Future<void> deleteVehicle(int vehicleId, {required bool cascade}) async {
    if (cascade) {
      await _dbHelper.deleteVehicleCascade(vehicleId);
    } else {
      await _dbHelper.deleteVehicle(vehicleId);
    }

    final currentDefaultId = await getDefaultVehicle();
    final remainingVehicles = await getVehicles();

    final isCurrentDefaultDeleted = currentDefaultId == vehicleId;
    final isCurrentDefaultInvalid = currentDefaultId != null &&
        !remainingVehicles.any((v) => v.id == currentDefaultId);

    if (isCurrentDefaultDeleted || isCurrentDefaultInvalid) {
      if (remainingVehicles.isNotEmpty) {
        await setDefaultVehicle(remainingVehicles.first.id!);
      } else {
        await clearDefaultVehicle();
      }
    }
  }

  Future<void> deleteVehicleCascade(int vehicleId) =>
      deleteVehicle(vehicleId, cascade: true);
}
