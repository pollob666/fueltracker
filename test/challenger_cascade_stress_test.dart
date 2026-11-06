// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
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
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await testDb.close();
  });

  group('Adversarial Stress Testing: Foreign Keys & Rollback Atomicity', () {
    test('PRAGMA foreign_key_check returns zero violations on clean schema', () async {
      final fkCheck = await testDb.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);
    });

    test('Rollback when child record deletion fails midway (trigger on fuel_records)', () async {
      // Seed 2 fuel types and a bi-fuel vehicle
      final ft1 = await testDb.insert('fuel_types', {
        'name': 'Octane',
        'category': FuelCategory.gasoline.toString(),
        'unit': FuelUnit.litre.toString(),
      });
      final ft2 = await testDb.insert('fuel_types', {
        'name': 'CNG',
        'category': FuelCategory.gas.toString(),
        'unit': FuelUnit.cubicMeter.toString(),
      });

      final vId = await testDb.insert('vehicles', {
        'id': 50,
        'name': 'BiFuel Car',
        'type': VehicleType.carOrSedan.toString(),
        'primaryFuelTypeId': ft1,
        'secondaryFuelTypeId': ft2,
      });

      // Insert 10 records: 5 for ft1, 5 for ft2
      for (int i = 0; i < 10; i++) {
        await testDb.insert('fuel_records', {
          'id': 500 + i,
          'date': DateTime.now().toIso8601String(),
          'odometer': 1000.0 + (i * 100),
          'fuelTypeId': i.isEven ? ft1 : ft2,
          'vehicleId': vId,
          'rate': 100.0,
          'volume': 10.0,
          'paidAmount': 1000.0,
        });
      }

      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(10));

      // Create a trigger that prevents deletion of fuel_record id 505 (the 6th record)
      await testDb.execute('''
        CREATE TRIGGER abort_midway_child_delete
        BEFORE DELETE ON fuel_records
        WHEN OLD.id = 505
        BEGIN
          SELECT RAISE(ABORT, 'Simulated mid-stream failure deleting fuel record');
        END;
      ''');

      // Attempt cascade deletion - must fail due to trigger inside transaction
      expect(
        () => dbHelper.deleteVehicleCascade(vId),
        throwsA(isA<DatabaseException>()),
      );

      // Verify transaction rollback: ALL 10 records must still exist, none deleted!
      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(10));
      final allRecords = await dbHelper.getFuelRecords();
      expect(allRecords.length, equals(10));

      // Parent vehicle must still exist
      final vehicles = await dbHelper.getVehicles();
      expect(vehicles.any((v) => v.id == vId), isTrue);

      // Drop trigger and delete should now succeed completely
      await testDb.execute('DROP TRIGGER abort_midway_child_delete;');
      await dbHelper.deleteVehicleCascade(vId);

      expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(0));
      expect(await dbHelper.getFuelRecords(), isEmpty);
      expect((await dbHelper.getVehicles()).any((v) => v.id == vId), isFalse);

      // Verify PRAGMA foreign_key_check passes cleanly
      final fkCheck = await testDb.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);
    });

    test('High-volume interleaved multi-vehicle isolation test (100 records, 10 vehicles)', () async {
      final ftId = await testDb.insert('fuel_types', {
        'name': 'Petrol',
        'category': FuelCategory.gasoline.toString(),
        'unit': FuelUnit.litre.toString(),
      });

      // Insert 10 vehicles
      final vehicleIds = <int>[];
      for (int i = 1; i <= 10; i++) {
        final id = await testDb.insert('vehicles', {
          'name': 'Fleet Vehicle $i',
          'type': VehicleType.carOrSedan.toString(),
          'primaryFuelTypeId': ftId,
        });
        vehicleIds.add(id);
      }

      // Insert 100 records interleaved (10 per vehicle)
      for (int rec = 0; rec < 100; rec++) {
        final targetVId = vehicleIds[rec % 10];
        await testDb.insert('fuel_records', {
          'date': DateTime.now().toIso8601String(),
          'odometer': 1000.0 + (rec * 25),
          'fuelTypeId': ftId,
          'vehicleId': targetVId,
          'rate': 120.0,
          'volume': 20.0,
          'paidAmount': 2400.0,
        });
      }

      // Verify each vehicle has exactly 10 records
      for (final vId in vehicleIds) {
        expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(10));
      }
      expect((await dbHelper.getFuelRecords()).length, equals(100));

      // Cascade delete vehicle 5 (index 4)
      final targetDeleteId = vehicleIds[4];
      await dbHelper.deleteVehicleCascade(targetDeleteId);

      // Verify vehicle 5 is gone and has 0 records
      expect(await dbHelper.getFuelRecordCountForVehicle(targetDeleteId), equals(0));
      expect((await dbHelper.getVehicles()).any((v) => v.id == targetDeleteId), isFalse);

      // Verify the remaining 9 vehicles each still have exactly 10 records (90 total)
      final remainingIds = vehicleIds.where((id) => id != targetDeleteId).toList();
      for (final vId in remainingIds) {
        expect(await dbHelper.getFuelRecordCountForVehicle(vId), equals(10));
      }
      final remainingRecords = await dbHelper.getFuelRecords();
      expect(remainingRecords.length, equals(90));
      expect(remainingRecords.every((r) => r.vehicleId != targetDeleteId), isTrue);

      // Run SQLite integrity & foreign key checks
      final integrity = await testDb.rawQuery('PRAGMA integrity_check;');
      expect(integrity.first.values.first, equals('ok'));

      final fkCheck = await testDb.rawQuery('PRAGMA foreign_key_check;');
      expect(fkCheck, isEmpty);
    });

    test('Boundary edge cases: negative, zero, and out-of-range vehicle IDs', () async {
      expect(await dbHelper.getFuelRecordCountForVehicle(-1), equals(0));
      expect(await dbHelper.getFuelRecordCountForVehicle(0), equals(0));
      expect(await dbHelper.getFuelRecordCountForVehicle(9999999), equals(0));

      // deleteVehicleCascade should not fail or throw on non-existent IDs
      await dbHelper.deleteVehicleCascade(-1);
      await dbHelper.deleteVehicleCascade(0);
      await dbHelper.deleteVehicleCascade(9999999);

      // Integrity checks remain intact
      final integrity = await testDb.rawQuery('PRAGMA integrity_check;');
      expect(integrity.first.values.first, equals('ok'));
    });
  });
}
