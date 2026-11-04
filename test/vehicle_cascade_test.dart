// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database testDb;
  late DatabaseHelper dbHelper;
  late VehicleService vehicleService;

  Future<void> createSchema(Database db) async {
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
        FOREIGN KEY (fuelTypeId) REFERENCES fuel_types (id),
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id)
      )
    ''');
  }

  Future<int> insertFuelType({
    int? id,
    String name = 'Octane',
    FuelCategory category = FuelCategory.gasoline,
    FuelUnit unit = FuelUnit.litre,
  }) async {
    return await testDb.insert('fuel_types', {
      if (id != null) 'id': id,
      'name': name,
      'category': category.toString(),
      'unit': unit.toString(),
    });
  }

  Future<int> insertVehicle({
    int? id,
    String name = 'Test Vehicle',
    VehicleType type = VehicleType.carOrSedan,
    int primaryFuelTypeId = 1,
    double? primaryFuelCapacity = 50.0,
    int? secondaryFuelTypeId,
    double? secondaryFuelCapacity,
  }) async {
    return await testDb.insert('vehicles', {
      if (id != null) 'id': id,
      'name': name,
      'type': type.toString(),
      'primaryFuelTypeId': primaryFuelTypeId,
      'primaryFuelCapacity': primaryFuelCapacity,
      if (secondaryFuelTypeId != null) 'secondaryFuelTypeId': secondaryFuelTypeId,
      if (secondaryFuelCapacity != null)
        'secondaryFuelCapacity': secondaryFuelCapacity,
    });
  }

  Future<int> insertFuelRecord({
    int? id,
    DateTime? date,
    double odometer = 1000.0,
    int fuelTypeId = 1,
    required int vehicleId,
    double rate = 120.0,
    double volume = 40.0,
    double paidAmount = 4800.0,
    int isFullTank = 1,
    int missedPrevious = 0,
    double? tripDistance = 400.0,
  }) async {
    return await testDb.insert('fuel_records', {
      if (id != null) 'id': id,
      'date': (date ?? DateTime.now()).toIso8601String(),
      'odometer': odometer,
      'fuelTypeId': fuelTypeId,
      'vehicleId': vehicleId,
      'rate': rate,
      'volume': volume,
      'paidAmount': paidAmount,
      'isFullTank': isFullTank,
      'missedPrevious': missedPrevious,
      if (tripDistance != null) 'tripDistance': tripDistance,
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    testDb = await openDatabase(
      inMemoryDatabasePath,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await createSchema(db);
      },
    );

    DatabaseHelper.setDatabaseForTesting(testDb);
    dbHelper = DatabaseHelper.instance;
    vehicleService = VehicleService(dbHelper: dbHelper);
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await testDb.close();
  });

  group('SQLite In-Memory Database & Foreign Key Constraint Enforcement', () {
    test('PRAGMA foreign_keys is actively enabled in SQLite FFI', () async {
      final pragmaCheck = await testDb.rawQuery('PRAGMA foreign_keys;');
      expect(pragmaCheck.first.values.first, equals(1));
    });

    test('Inserting child fuel record with non-existent vehicleId violates foreign key constraint', () async {
      final ftId = await insertFuelType(id: 1);
      expect(
        () async => await insertFuelRecord(vehicleId: 9999, fuelTypeId: ftId),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Direct vehicle deletion without cascading child records throws foreign key constraint failure', () async {
      final ftId = await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 10, name: 'Sedan', primaryFuelTypeId: ftId);
      await insertFuelRecord(vehicleId: vId, fuelTypeId: ftId);

      // Attempt raw deletion of parent row without removing children
      expect(
        () async => await testDb.delete('vehicles', where: 'id = ?', whereArgs: [vId]),
        throwsA(isA<DatabaseException>()),
      );

      // dbHelper.deleteVehicle without cascade must also fail under active FK constraints
      expect(
        () => dbHelper.deleteVehicle(vId),
        throwsA(isA<DatabaseException>()),
      );

      // Neither record nor vehicle was deleted
      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(1));
      final vehicles = await dbHelper.getVehicles();
      expect(vehicles.any((v) => v.id == vId), isTrue);
    });
  });

  group('DatabaseHelper - Record Counting', () {
    test('returns 0 when vehicle has no fuel records', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 1);

      final count = await dbHelper.getFuelRecordCountForVehicle(vId);
      expect(count, equals(0));
    });

    test('returns 1 when vehicle has exactly 1 fuel record', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 1);
      await insertFuelRecord(vehicleId: vId);

      final count = await dbHelper.getFuelRecordCountForVehicle(vId);
      expect(count, equals(1));
    });

    test('returns N (e.g. 5) when vehicle has 5 fuel records', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 1);
      for (int i = 0; i < 5; i++) {
        await insertFuelRecord(
          vehicleId: vId,
          odometer: 1000.0 + (i * 100),
        );
      }

      final count = await dbHelper.getFuelRecordCountForVehicle(vId);
      expect(count, equals(5));
    });

    test('accurately counts without cross-contamination across multiple vehicles', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Vehicle 1');
      final v2 = await insertVehicle(id: 2, name: 'Vehicle 2');
      final v3 = await insertVehicle(id: 3, name: 'Vehicle 3');

      // Seed 3 records for v1, 2 for v2, 0 for v3
      for (int i = 0; i < 3; i++) {
        await insertFuelRecord(vehicleId: v1, odometer: 1000.0 + i * 50);
      }
      for (int i = 0; i < 2; i++) {
        await insertFuelRecord(vehicleId: v2, odometer: 2000.0 + i * 50);
      }

      expect(await dbHelper.getFuelRecordCountForVehicle(v1), equals(3));
      expect(await dbHelper.getFuelRecordCountForVehicle(v2), equals(2));
      expect(await dbHelper.getFuelRecordCountForVehicle(v3), equals(0));
    });

    test('returns 0 for non-existent vehicle ID', () async {
      final count = await dbHelper.getFuelRecordCountForVehicle(9999);
      expect(count, equals(0));
    });
  });

  group('DatabaseHelper - Cascade Deletion & Foreign Keys', () {
    test('deletes vehicle and all child fuel records atomically when multiple records exist', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 1);
      for (int i = 0; i < 4; i++) {
        await insertFuelRecord(vehicleId: vId, odometer: 1000.0 + i * 100);
      }

      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(4));

      await dbHelper.deleteVehicleCascade(vId);

      // Child records deleted
      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(0));
      // Vehicle row deleted
      final vehicles = await dbHelper.getVehicles();
      expect(vehicles.any((v) => v.id == vId), isFalse);
    });

    test('deletes vehicle cleanly when it has 0 fuel records', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 1);

      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(0));

      await dbHelper.deleteVehicleCascade(vId);

      final vehicles = await dbHelper.getVehicles();
      expect(vehicles.any((v) => v.id == vId), isFalse);
    });

    test('completes cleanly when attempting to cascade delete non-existent vehicle ID', () async {
      await dbHelper.deleteVehicleCascade(9999);
      expect(await dbHelper.getFuelRecordCountForVehicle(9999), equals(0));
    });
  });

  group('DatabaseHelper - Transaction Atomicity & Rollback', () {
    test('rolls back child record deletions if an error occurs during vehicle deletion', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(
        id: 99,
        name: 'RollbackVehicle',
        primaryFuelTypeId: 1,
      );
      await insertFuelRecord(id: 101, vehicleId: vId, odometer: 1000);
      await insertFuelRecord(id: 102, vehicleId: vId, odometer: 1500);

      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(2));

      // Trigger aborting deletion for vehicle id 99
      await testDb.execute('''
        CREATE TRIGGER abort_rollback_vehicle_delete
        BEFORE DELETE ON vehicles
        WHEN OLD.id = 99
        BEGIN
          SELECT RAISE(ABORT, 'Simulated failure during vehicle deletion');
        END;
      ''');

      // Attempt cascade delete - should fail when deleting vehicles row
      expect(
        () => dbHelper.deleteVehicleCascade(vId),
        throwsA(isA<DatabaseException>()),
      );

      // Transaction atomicity: fuel records must NOT be deleted
      final recordCountAfter = await dbHelper.getFuelRecordCountForVehicle(vId);
      expect(recordCountAfter, equals(2));

      // Vehicle still exists
      final vehicles = await dbHelper.getVehicles();
      expect(vehicles.any((v) => v.id == vId), isTrue);

      // Clean up trigger
      await testDb.execute('DROP TRIGGER IF EXISTS abort_rollback_vehicle_delete;');

      // Now cascade delete succeeds
      await dbHelper.deleteVehicleCascade(vId);
      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(0));
      final vehiclesFinal = await dbHelper.getVehicles();
      expect(vehiclesFinal.any((v) => v.id == vId), isFalse);
    });
  });

  group('VehicleService - Record Counting', () {
    test('delegates getRecordCountForVehicle to DatabaseHelper correctly', () async {
      await insertFuelType(id: 1);
      final vId = await insertVehicle(id: 1);
      await insertFuelRecord(vehicleId: vId);
      await insertFuelRecord(vehicleId: vId);
      await insertFuelRecord(vehicleId: vId);

      final count = await vehicleService.getRecordCountForVehicle(vId);
      expect(count, equals(3));
    });
  });

  group('VehicleService - Deletion & Default Vehicle Reassignment', () {
    test('reassigns default vehicle to first remaining vehicle when default vehicle is deleted', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Vehicle 1');
      final v2 = await insertVehicle(id: 2, name: 'Vehicle 2');
      await insertFuelRecord(vehicleId: v1);

      await vehicleService.setDefaultVehicle(v1);
      expect(await vehicleService.getDefaultVehicle(), equals(v1));

      await vehicleService.deleteVehicle(v1, cascade: true);

      // Default must have been reassigned to v2
      expect(await vehicleService.getDefaultVehicle(), equals(v2));
      final remaining = await vehicleService.getVehicles();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(v2));
    });

    test('clears default vehicle when the only remaining vehicle is deleted', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Only Vehicle');
      await insertFuelRecord(vehicleId: v1);

      await vehicleService.setDefaultVehicle(v1);
      expect(await vehicleService.getDefaultVehicle(), equals(v1));

      await vehicleService.deleteVehicle(v1, cascade: true);

      // Default must be cleared (null)
      expect(await vehicleService.getDefaultVehicle(), isNull);
      final remaining = await vehicleService.getVehicles();
      expect(remaining, isEmpty);
    });

    test('leaves default vehicle unchanged when a non-default vehicle is deleted', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Default Vehicle');
      final v2 = await insertVehicle(id: 2, name: 'Other Vehicle');
      await insertFuelRecord(vehicleId: v2);

      await vehicleService.setDefaultVehicle(v1);
      expect(await vehicleService.getDefaultVehicle(), equals(v1));

      await vehicleService.deleteVehicle(v2, cascade: true);

      // Default must remain v1
      expect(await vehicleService.getDefaultVehicle(), equals(v1));
      final remaining = await vehicleService.getVehicles();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(v1));
    });

    test('recovers and reassigns default if current default vehicle was already invalid/stale', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Vehicle 1');
      final v2 = await insertVehicle(id: 2, name: 'Vehicle 2');

      // Set default to invalid ID
      await vehicleService.setDefaultVehicle(999);
      expect(await vehicleService.getDefaultVehicle(), equals(999));

      // Deleting v2 should detect invalid default and reassign to v1
      await vehicleService.deleteVehicle(v2, cascade: true);

      expect(await vehicleService.getDefaultVehicle(), equals(v1));
    });

    test('deleteVehicleCascade convenience method delegates to deleteVehicle with cascade: true', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Vehicle 1');
      final v2 = await insertVehicle(id: 2, name: 'Vehicle 2');
      await insertFuelRecord(vehicleId: v1);

      await vehicleService.setDefaultVehicle(v1);

      await vehicleService.deleteVehicleCascade(v1);

      expect(await vehicleService.getDefaultVehicle(), equals(v2));
      expect(await dbHelper.getFuelRecordCountForVehicle(v1), equals(0));
    });
  });

  group('Vehicle Cascade Deletion - Isolation & Multi-Vehicle Integrity', () {
    test('deleting vehicle A does not affect vehicle B or vehicle B fuel records', () async {
      await insertFuelType(id: 1);
      final vA = await insertVehicle(id: 1, name: 'Vehicle A');
      final vB = await insertVehicle(id: 2, name: 'Vehicle B');

      for (int i = 0; i < 3; i++) {
        await insertFuelRecord(vehicleId: vA, odometer: 1000.0 + i * 100);
      }
      for (int i = 0; i < 4; i++) {
        await insertFuelRecord(vehicleId: vB, odometer: 2000.0 + i * 100);
      }

      expect(await dbHelper.getFuelRecordCountForVehicle(vA), equals(3));
      expect(await dbHelper.getFuelRecordCountForVehicle(vB), equals(4));

      // Cascade delete vehicle A
      await dbHelper.deleteVehicleCascade(vA);

      // Verify A is deleted and has 0 records
      expect(await dbHelper.getFuelRecordCountForVehicle(vA), equals(0));
      final vehiclesAfter = await dbHelper.getVehicles();
      expect(vehiclesAfter.any((v) => v.id == vA), isFalse);

      // Verify B and B records are completely intact
      expect(await dbHelper.getFuelRecordCountForVehicle(vB), equals(4));
      expect(vehiclesAfter.any((v) => v.id == vB), isTrue);

      final allRecords = await dbHelper.getFuelRecords();
      expect(allRecords.length, equals(4));
      expect(allRecords.every((r) => r.vehicleId == vB), isTrue);
    });

    test('complex scenario: 3 vehicles, default reassignment, mixed record counts, and isolation', () async {
      await insertFuelType(id: 1);
      final v1 = await insertVehicle(id: 1, name: 'Vehicle 1');
      final v2 = await insertVehicle(id: 2, name: 'Vehicle 2');
      final v3 = await insertVehicle(id: 3, name: 'Vehicle 3');

      // v1 has 2 records, v2 has 4 records, v3 has 1 record
      for (int i = 0; i < 2; i++) {
        await insertFuelRecord(vehicleId: v1, odometer: 1000.0 + i * 10);
      }
      for (int i = 0; i < 4; i++) {
        await insertFuelRecord(vehicleId: v2, odometer: 2000.0 + i * 10);
      }
      await insertFuelRecord(vehicleId: v3, odometer: 3000.0);

      final initialRecords = await dbHelper.getFuelRecords();
      expect(initialRecords.length, equals(7));

      await vehicleService.setDefaultVehicle(v1);
      expect(await vehicleService.getDefaultVehicle(), equals(v1));

      // 1. Delete default vehicle v1
      await vehicleService.deleteVehicle(v1, cascade: true);

      // Default reassigns to v2
      expect(await vehicleService.getDefaultVehicle(), equals(v2));
      expect(await dbHelper.getFuelRecordCountForVehicle(v1), equals(0));
      expect(await dbHelper.getFuelRecordCountForVehicle(v2), equals(4));
      expect(await dbHelper.getFuelRecordCountForVehicle(v3), equals(1));
      expect((await dbHelper.getFuelRecords()).length, equals(5));

      // 2. Delete non-default vehicle v3
      await vehicleService.deleteVehicleCascade(v3);

      // Default remains v2
      expect(await vehicleService.getDefaultVehicle(), equals(v2));
      expect(await dbHelper.getFuelRecordCountForVehicle(v3), equals(0));
      expect(await dbHelper.getFuelRecordCountForVehicle(v2), equals(4));
      expect((await dbHelper.getFuelRecords()).length, equals(4));

      // 3. Delete only remaining vehicle v2
      await vehicleService.deleteVehicle(v2, cascade: true);

      // Default cleared, database empty
      expect(await vehicleService.getDefaultVehicle(), isNull);
      expect(await vehicleService.getVehicles(), isEmpty);
      expect(await dbHelper.getFuelRecords(), isEmpty);
    });
  });
}
