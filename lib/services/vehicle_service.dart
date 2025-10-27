// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';

class VehicleService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FuelTypeService _fuelTypeService = FuelTypeService();

  Future<List<Vehicle>> getVehicles() async {
    final vehicles = await _dbHelper.getVehicles();
    if (vehicles.isEmpty) {
      await _addDefaultVehicle();
      return _dbHelper.getVehicles();
    }
    return vehicles;
  }

  Future<void> _addDefaultVehicle() async {
    final fuelTypes = await _fuelTypeService.getFuelTypes();
    if (fuelTypes.isNotEmpty) {
      final defaultVehicle = Vehicle(
        name: 'Default Vehicle',
        type: VehicleType.car,
        primaryFuelTypeId: fuelTypes.first.id!,
      );
      await _dbHelper.insertVehicle(defaultVehicle);
    }
  }

  Future<Vehicle?> getVehicleById(int id) async {
    final allVehicles = await getVehicles();
    return allVehicles.firstWhere((vehicle) => vehicle.id == id);
  }
}
