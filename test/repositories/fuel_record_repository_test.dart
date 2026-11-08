// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/repositories/fuel_record_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('SqliteFuelRecordRepository CRUD and stream notifications', () async {
    const testDb = 'test_fuel_repo.db';
    if (await databaseFactory.databaseExists(testDb)) {
      await databaseFactory.deleteDatabase(testDb);
    }

    final db = await databaseFactory.openDatabase(
      testDb,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE fuel_types (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              unit TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE vehicles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              primaryFuelTypeId INTEGER NOT NULL,
              primaryFuelCapacity REAL,
              secondaryFuelTypeId INTEGER,
              secondaryFuelCapacity REAL,
              tripMeterMode TEXT NOT NULL DEFAULT 'none',
              volumeReminderEnabled INTEGER NOT NULL DEFAULT 0,
              volumeReminderValue REAL NOT NULL DEFAULT 3.0,
              distanceReminderEnabled INTEGER NOT NULL DEFAULT 0,
              distanceReminderValue REAL NOT NULL DEFAULT 50.0
            )
          ''');
          await db.execute('''
            CREATE TABLE fuel_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              odometer REAL NOT NULL,
              fuelTypeId INTEGER NOT NULL,
              vehicleId INTEGER NOT NULL,
              rate REAL NOT NULL,
              volume REAL NOT NULL,
              paidAmount REAL NOT NULL,
              isFullTank INTEGER NOT NULL DEFAULT 1,
              missedPrevious INTEGER NOT NULL DEFAULT 0,
              tripDistance REAL,
              secondaryTripDistance REAL,
              drivingCondition TEXT NOT NULL DEFAULT 'mixed',
              locationId INTEGER,
              latitude REAL,
              longitude REAL,
              receiptImagePath TEXT,
              odometerImagePath TEXT,
              currencyCode TEXT DEFAULT 'BDT',
              exchangeRateToBase REAL NOT NULL DEFAULT 1.0,
              energyKwh REAL,
              socStart REAL,
              socEnd REAL,
              chargingPowerKw REAL,
              chargeType TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE maintenance_tasks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              vehicleId INTEGER NOT NULL,
              taskKey TEXT,
              title TEXT NOT NULL,
              intervalKm REAL NOT NULL,
              intervalMonths INTEGER,
              lastServiceOdo REAL NOT NULL,
              lastServiceDate TEXT NOT NULL,
              reminderBufferKm REAL DEFAULT 100.0,
              isEnabled INTEGER DEFAULT 0
            )
          ''');
          await db.insert('fuel_types', {'name': 'Octane', 'category': 'gasoline', 'unit': 'litre'});
          await db.insert('vehicles', {
            'name': 'Corolla',
            'type': 'carOrSedan',
            'primaryFuelTypeId': 1,
            'primaryFuelCapacity': 50.0,
          });
        },
      ),
    );

    DatabaseHelper.setDatabaseForTesting(db);
    final repo = SqliteFuelRecordRepository(dbHelper: DatabaseHelper.instance);

    // Initial query
    var records = await repo.getFuelRecords(vehicleId: 1);
    expect(records, isEmpty);

    // Watch stream setup
    final streamEmissions = <List<FuelRecord>>[];
    final sub = repo.watchFuelRecords(1).listen(streamEmissions.add);

    // Wait for initial stream emission
    await Future.delayed(const Duration(milliseconds: 50));
    expect(streamEmissions.length, equals(1));
    expect(streamEmissions.first, isEmpty);

    // Insert record
    final rec1 = FuelRecord(
      date: DateTime.parse('2026-01-01T10:00:00'),
      odometer: 1000.0,
      fuelTypeId: 1,
      vehicleId: 1,
      rate: 130.0,
      volume: 30.0,
      paidAmount: 3900.0,
      isFullTank: true,
    );
    final id1 = await repo.insertFuelRecord(rec1);
    expect(id1, isPositive);

    await Future.delayed(const Duration(milliseconds: 50));
    expect(streamEmissions.length, equals(2));
    expect(streamEmissions.last.length, equals(1));
    expect(streamEmissions.last.first.odometer, equals(1000.0));

    // Update record
    final updated1 = rec1.copyWith(id: id1, odometer: 1050.0);
    await repo.updateFuelRecord(updated1);

    await Future.delayed(const Duration(milliseconds: 50));
    expect(streamEmissions.length, equals(3));
    expect(streamEmissions.last.first.odometer, equals(1050.0));

    // Batch insert
    final batchRecords = [
      FuelRecord(
        date: DateTime.parse('2026-01-05T10:00:00'),
        odometer: 1400.0,
        fuelTypeId: 1,
        vehicleId: 1,
        rate: 130.0,
        volume: 25.0,
        paidAmount: 3250.0,
      ),
      FuelRecord(
        date: DateTime.parse('2026-01-10T10:00:00'),
        odometer: 1800.0,
        fuelTypeId: 1,
        vehicleId: 1,
        rate: 130.0,
        volume: 28.0,
        paidAmount: 3640.0,
      ),
    ];
    final batchCount = await repo.batchInsertFuelRecords(batchRecords);
    expect(batchCount, equals(2));

    await Future.delayed(const Duration(milliseconds: 50));
    expect(streamEmissions.length, equals(4));
    expect(streamEmissions.last.length, equals(3));

    // Delete record
    await repo.deleteFuelRecord(id1, vehicleId: 1);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(streamEmissions.length, equals(5));
    expect(streamEmissions.last.length, equals(2));

    await sub.cancel();
    repo.dispose();
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
    await databaseFactory.deleteDatabase(testDb);
  });
}
