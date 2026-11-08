// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/tire.dart';
import 'package:fuel_tracker/models/tire_log.dart';

abstract class TireRepository {
  Future<List<Tire>> getTiresForVehicle(int vehicleId, {bool includeArchived = false});
  Future<Tire?> getTireById(int id);
  Future<int> insertTire(Tire tire);
  Future<int> updateTire(Tire tire);
  Future<int> deleteTire(int id);

  Future<int> insertTireLog(TireLog log);
  Future<List<TireLog>> getTireLogsForTire(int tireId);
  Future<List<TireLog>> getLatestTireLogsForVehicle(int vehicleId);
  Future<int> deleteTireLog(int id);
}

class SqliteTireRepository implements TireRepository {
  final DatabaseHelper _dbHelper;

  SqliteTireRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Tire>> getTiresForVehicle(int vehicleId, {bool includeArchived = false}) =>
      _dbHelper.getTiresForVehicle(vehicleId, includeArchived: includeArchived);

  @override
  Future<Tire?> getTireById(int id) => _dbHelper.getTireById(id);

  @override
  Future<int> insertTire(Tire tire) => _dbHelper.insertTire(tire);

  @override
  Future<int> updateTire(Tire tire) => _dbHelper.updateTire(tire);

  @override
  Future<int> deleteTire(int id) => _dbHelper.deleteTire(id);

  @override
  Future<int> insertTireLog(TireLog log) => _dbHelper.insertTireLog(log);

  @override
  Future<List<TireLog>> getTireLogsForTire(int tireId) =>
      _dbHelper.getTireLogsForTire(tireId);

  @override
  Future<List<TireLog>> getLatestTireLogsForVehicle(int vehicleId) =>
      _dbHelper.getLatestTireLogsForVehicle(vehicleId);

  @override
  Future<int> deleteTireLog(int id) => _dbHelper.deleteTireLog(id);
}
