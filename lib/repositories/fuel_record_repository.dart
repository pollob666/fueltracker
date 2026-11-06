// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:sqflite/sqflite.dart';

abstract class FuelRecordRepository {
  Future<List<FuelRecord>> getFuelRecords({int? vehicleId});
  Stream<List<FuelRecord>> watchFuelRecords(int vehicleId);
  Future<int> insertFuelRecord(FuelRecord record);
  Future<int> updateFuelRecord(FuelRecord record);
  Future<int> deleteFuelRecord(int id, {int? vehicleId});
  Future<int> batchInsertFuelRecords(List<FuelRecord> records, {bool overwrite = false});
  void notifyChanged([int? vehicleId]);
}

class SqliteFuelRecordRepository implements FuelRecordRepository {
  final DatabaseHelper _dbHelper;
  final _changeStreamController = StreamController<int?>.broadcast();

  SqliteFuelRecordRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<FuelRecord>> getFuelRecords({int? vehicleId}) async {
    final all = await _dbHelper.getFuelRecords();
    if (vehicleId == null) return all;
    return all.where((r) => r.vehicleId == vehicleId).toList();
  }

  @override
  Stream<List<FuelRecord>> watchFuelRecords(int vehicleId) {
    late StreamController<List<FuelRecord>> controller;
    StreamSubscription<int?>? sub;

    controller = StreamController<List<FuelRecord>>.broadcast(
      onListen: () async {
        controller.add(await getFuelRecords(vehicleId: vehicleId));
        sub = _changeStreamController.stream.listen((changedVehicleId) async {
          if (changedVehicleId == null || changedVehicleId == vehicleId) {
            if (!controller.isClosed) {
              controller.add(await getFuelRecords(vehicleId: vehicleId));
            }
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<int> insertFuelRecord(FuelRecord record) async {
    final id = await _dbHelper.insertFuelRecord(record);
    notifyChanged(record.vehicleId);
    return id;
  }

  @override
  Future<int> updateFuelRecord(FuelRecord record) async {
    final count = await _dbHelper.updateFuelRecord(record);
    notifyChanged(record.vehicleId);
    return count;
  }

  @override
  Future<int> deleteFuelRecord(int id, {int? vehicleId}) async {
    final count = await _dbHelper.deleteFuelRecord(id);
    notifyChanged(vehicleId);
    return count;
  }

  @override
  Future<int> batchInsertFuelRecords(List<FuelRecord> records, {bool overwrite = false}) async {
    final db = await _dbHelper.database;
    int count = 0;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final r in records) {
        if (overwrite && r.id != null) {
          batch.insert('fuel_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final map = r.toMap()..remove('id');
          batch.insert('fuel_records', map);
        }
        count++;
      }
      await batch.commit(noResult: true);
    });
    notifyChanged();
    return count;
  }

  @override
  void notifyChanged([int? vehicleId]) {
    if (!_changeStreamController.isClosed) {
      _changeStreamController.add(vehicleId);
    }
  }

  void dispose() {
    _changeStreamController.close();
  }
}
