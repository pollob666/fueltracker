// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getVehicles();
  Future<Vehicle?> getVehicleById(int id);
  Future<int> insertVehicle(Vehicle vehicle);
  Future<int> updateVehicle(Vehicle vehicle);
  Future<void> deleteVehicle(int id, {bool cascade = true});
  Future<int?> getDefaultVehicleId();
  Future<void> setDefaultVehicleId(int id);
  Future<int> getRecordCountForVehicle(int id);
}

class SqliteVehicleRepository implements VehicleRepository {
  final DatabaseHelper _dbHelper;
  final VehicleService _vehicleService;

  SqliteVehicleRepository({
    DatabaseHelper? dbHelper,
    VehicleService? vehicleService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _vehicleService = vehicleService ??
            VehicleService(dbHelper: dbHelper ?? DatabaseHelper.instance);

  @override
  Future<List<Vehicle>> getVehicles() => _vehicleService.getVehicles();

  @override
  Future<Vehicle?> getVehicleById(int id) async {
    final list = await getVehicles();
    try {
      return list.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> insertVehicle(Vehicle vehicle) => _dbHelper.insertVehicle(vehicle);

  @override
  Future<int> updateVehicle(Vehicle vehicle) => _dbHelper.updateVehicle(vehicle);

  @override
  Future<void> deleteVehicle(int id, {bool cascade = true}) =>
      _vehicleService.deleteVehicle(id, cascade: cascade);

  @override
  Future<int?> getDefaultVehicleId() => _vehicleService.getDefaultVehicle();

  @override
  Future<void> setDefaultVehicleId(int id) =>
      _vehicleService.setDefaultVehicle(id);

  @override
  Future<int> getRecordCountForVehicle(int id) =>
      _vehicleService.getRecordCountForVehicle(id);
}
