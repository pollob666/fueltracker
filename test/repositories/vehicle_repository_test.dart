// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/repositories/vehicle_repository.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SqliteVehicleRepository delegates CRUD and default vehicle tracking', () async {
    const testDb = 'test_vehicle_repo.db';
    if (await databaseFactory.databaseExists(testDb)) {
      await databaseFactory.deleteDatabase(testDb);
    }

    final db = await databaseFactory.openDatabase(
      testDb,
      options: OpenDatabaseOptions(
        version: 9,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
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
              distanceReminderValue REAL NOT NULL DEFAULT 50.0,
              distanceUnit TEXT NOT NULL DEFAULT 'km',
              fuelVolumeUnit TEXT NOT NULL DEFAULT 'litre',
              consumptionUnit TEXT NOT NULL DEFAULT 'kmPerLitre',
              baseCurrency TEXT NOT NULL DEFAULT 'BDT',
              powertrainType TEXT NOT NULL DEFAULT 'ice',
              batteryCapacityKwh REAL,
              FOREIGN KEY (primaryFuelTypeId) REFERENCES fuel_types (id),
              FOREIGN KEY (secondaryFuelTypeId) REFERENCES fuel_types (id)
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
              FOREIGN KEY (fuelTypeId) REFERENCES fuel_types (id),
              FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
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
              isEnabled INTEGER DEFAULT 0,
              FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
            )
          ''');
          await db.insert('fuel_types', {'name': 'Octane', 'category': 'gasoline', 'unit': 'litre'});
        },
      ),
    );

    DatabaseHelper.setDatabaseForTesting(db);
    final service = VehicleService(dbHelper: DatabaseHelper.instance);
    final repo = SqliteVehicleRepository(dbHelper: DatabaseHelper.instance, vehicleService: service);

    // Initial empty
    var list = await repo.getVehicles();
    expect(list, isEmpty);

    // Insert vehicle
    final v1 = Vehicle(
      name: 'Corolla',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
      primaryFuelCapacity: 50.0,
    );
    final id1 = await repo.insertVehicle(v1);
    expect(id1, isPositive);

    list = await repo.getVehicles();
    expect(list.length, equals(1));
    expect(list.first.name, equals('Corolla'));

    // Default vehicle
    await repo.setDefaultVehicleId(id1);
    final defId = await repo.getDefaultVehicleId();
    expect(defId, equals(id1));

    // Get by id
    final fetched = await repo.getVehicleById(id1);
    expect(fetched, isNotNull);
    expect(fetched!.name, equals('Corolla'));

    // Update
    final updated = fetched.copyWith(name: 'Corolla Altis');
    await repo.updateVehicle(updated);
    final fetchedUpdated = await repo.getVehicleById(id1);
    expect(fetchedUpdated!.name, equals('Corolla Altis'));

    // Insert second vehicle
    final v2 = Vehicle(
      name: 'Vespa',
      type: VehicleType.scooterOrMoped,
      primaryFuelTypeId: 1,
    );
    final id2 = await repo.insertVehicle(v2);

    // Cascade delete first vehicle
    await repo.deleteVehicle(id1, cascade: true);
    list = await repo.getVehicles();
    expect(list.length, equals(1));
    expect(list.first.id, equals(id2));

    // Default automatically re-assigned to remaining vehicle
    final newDefId = await repo.getDefaultVehicleId();
    expect(newDefId, equals(id2));

    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
    await databaseFactory.deleteDatabase(testDb);
  });
}
