// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/unified_backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('UnifiedBackupService Validation Tests', () {
    test('validates valid single JSON backup and extracts summary', () {
      final sampleBackup = {
        'schema_version': 2,
        'app_version': '3.3.0',
        'export_timestamp': '2026-11-08T10:00:00.000Z',
        'device_info': 'Android',
        'vehicles': [
          {'id': 1, 'name': 'Toyota Premio', 'type': 'carOrSedan', 'primaryFuelTypeId': 1},
          {'id': 2, 'name': 'Honda Civic', 'type': 'carOrSedan', 'primaryFuelTypeId': 1},
        ],
        'fuel_types': [
          {'id': 1, 'name': 'Octane', 'category': 'petrol', 'unit': 'L'},
        ],
        'fuel_records': [
          {
            'id': 101,
            'vehicleId': 1,
            'odometer': 52100.0,
            'date': '2026-11-08T09:00:00.000',
            'fuelTypeId': 1,
            'rate': 125.0,
            'volume': 40.0,
            'paidAmount': 5000.0,
            'isFullTank': 1,
            'missedPrevious': 0,
            'drivingCondition': 'city',
          },
        ],
        'service_sessions': [
          {
            'id': 201,
            'vehicleId': 1,
            'odometer': 50000.0,
            'serviceDate': '2026-10-15T10:00:00.000',
            'totalCost': 3500.0,
          },
        ],
        'service_session_items': [
          {
            'id': 301,
            'serviceSessionId': 201,
            'taskId': 1,
            'brandOrSpec': 'Mobil 1',
            'cost': 3500.0,
          },
        ],
        'saved_locations': [
          {
            'id': 401,
            'name': 'Padma Oil Filling Station',
            'isNamed': 1,
            'type': 'fuel_station',
          },
        ],
        'non_fuel_expenses': [
          {
            'id': 501,
            'vehicleId': 1,
            'category': 'toll',
            'amount': 300.0,
            'date': '2026-11-05T08:00:00.000',
          },
        ],
        'app_settings': {
          'themeMode': 'system',
          'reminderHour': 9,
        },
        'attachments': {
          'receipt_101.jpg': 'base64testdata==',
        },
      };

      final jsonString = jsonEncode(sampleBackup);
      final summary = UnifiedBackupService.validateBackupPayload(jsonString);

      expect(summary.isValid, isTrue);
      expect(summary.schemaVersion, equals(2));
      expect(summary.appVersion, equals('3.3.0'));
      expect(summary.deviceInfo, equals('Android'));
      expect(summary.vehicleCount, equals(2));
      expect(summary.vehicleNames, containsAll(['Toyota Premio', 'Honda Civic']));
      expect(summary.refuelCount, equals(1));
      expect(summary.serviceSessionCount, equals(1));
      expect(summary.serviceItemCount, equals(1));
      expect(summary.locationCount, equals(1));
      expect(summary.expenseCount, equals(1));
      expect(summary.hasAppSettings, isTrue);
      expect(summary.attachmentCount, equals(1));
    });

    test('returns invalid summary when json syntax is broken', () {
      const brokenJson = '{"schema_version": 2, "vehicles": [BROKEN}';
      final summary = UnifiedBackupService.validateBackupPayload(brokenJson);

      expect(summary.isValid, isFalse);
      expect(summary.errorMessage, isNotNull);
    });

    test('returns invalid summary when json is not an object', () {
      const arrayJson = '["not", "an", "object"]';
      final summary = UnifiedBackupService.validateBackupPayload(arrayJson);

      expect(summary.isValid, isFalse);
    });
  });

  group('UnifiedBackupService Database Transactional Import Tests', () {
    late Database testDb;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 10,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
        onCreate: (db, version) async => await DatabaseHelper.instance.createTablesForTesting(db),
      );
      DatabaseHelper.setDatabaseForTesting(testDb);
    });

    tearDown(() async {
      DatabaseHelper.setDatabaseForTesting(null);
      await testDb.close();
    });

    test('imports selected categories with overwriteExisting strategy', () async {
      final payload = {
        'schema_version': 2,
        'vehicles': [
          {
            'id': 10,
            'name': 'Initial Vehicle',
            'type': 'carOrSedan',
            'primaryFuelTypeId': 1,
            'tripMeterMode': 'none',
          },
        ],
        'fuel_types': [
          {'id': 1, 'name': 'Octane', 'category': 'petrol', 'unit': 'L'},
        ],
        'fuel_records': [
          {
            'id': 100,
            'vehicleId': 10,
            'odometer': 12000.0,
            'date': '2026-11-01T10:00:00.000',
            'fuelTypeId': 1,
            'rate': 125.0,
            'volume': 30.0,
            'paidAmount': 3750.0,
            'isFullTank': 1,
            'missedPrevious': 0,
            'drivingCondition': 'city',
          },
        ],
        'saved_locations': [
          {
            'id': 50,
            'name': 'Test Station',
            'isNamed': 1,
            'type': 'fuel_station',
          },
        ],
        'non_fuel_expenses': [
          {
            'id': 70,
            'vehicleId': 10,
            'category': 'parking',
            'amount': 150.0,
            'date': '2026-11-02T10:00:00.000',
          },
        ],
      };

      final result = await UnifiedBackupService.executeImport(
        payload: payload,
        selectedCategories: {
          ImportCategory.vehicles,
          ImportCategory.fuelRecords,
          ImportCategory.savedLocations,
          ImportCategory.nonFuelExpenses,
        },
        conflictStrategy: ConflictResolutionStrategy.overwriteExisting,
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.importedVehicles, equals(1));
      expect(result.importedRefuels, equals(1));
      expect(result.importedLocations, equals(1));
      expect(result.importedExpenses, equals(1));

      final vehicles = await DatabaseHelper.instance.getVehicles();
      expect(vehicles.length, equals(1));
      expect(vehicles.first.name, equals('Initial Vehicle'));

      final records = await DatabaseHelper.instance.getFuelRecords();
      expect(records.length, equals(1));
      expect(records.first.odometer, equals(12000.0));

      final locations = await DatabaseHelper.instance.getSavedLocations();
      expect(locations.length, equals(1));
      expect(locations.first.name, equals('Test Station'));

      final expenses = await DatabaseHelper.instance.getNonFuelExpenses();
      expect(expenses.length, equals(1));
      expect(expenses.first.amount, equals(150.0));
    });

    test('copyMergeAll creates new IDs preserving existing records', () async {
      // Pre-populate DB with existing vehicle and fuel record
      final db = await DatabaseHelper.instance.database;
      await db.insert('fuel_types', {'id': 1, 'name': 'Octane', 'category': 'petrol', 'unit': 'L'});
      await db.insert('vehicles', {
        'id': 10,
        'name': 'Existing Vehicle',
        'type': 'carOrSedan',
        'primaryFuelTypeId': 1,
        'tripMeterMode': 'none',
      });
      await db.insert('fuel_records', {
        'id': 100,
        'vehicleId': 10,
        'odometer': 10000.0,
        'date': '2026-10-01T10:00:00.000',
        'fuelTypeId': 1,
        'rate': 120.0,
        'volume': 20.0,
        'paidAmount': 2400.0,
        'isFullTank': 1,
        'missedPrevious': 0,
        'drivingCondition': 'city',
      });

      // Payload has same IDs (id: 10, id: 100)
      final payload = {
        'vehicles': [
          {
            'id': 10,
            'name': 'Imported Copy Vehicle',
            'type': 'carOrSedan',
            'primaryFuelTypeId': 1,
            'tripMeterMode': 'none',
          },
        ],
        'fuel_types': [
          {'id': 1, 'name': 'Octane', 'category': 'petrol', 'unit': 'L'},
        ],
        'fuel_records': [
          {
            'id': 100,
            'vehicleId': 10,
            'odometer': 20000.0,
            'date': '2026-11-01T10:00:00.000',
            'fuelTypeId': 1,
            'rate': 125.0,
            'volume': 35.0,
            'paidAmount': 4375.0,
            'isFullTank': 1,
            'missedPrevious': 0,
            'drivingCondition': 'city',
          },
        ],
      };

      final result = await UnifiedBackupService.executeImport(
        payload: payload,
        selectedCategories: {
          ImportCategory.vehicles,
          ImportCategory.fuelRecords,
        },
        conflictStrategy: ConflictResolutionStrategy.copyMergeAll,
      );

      expect(result.success, isTrue, reason: result.message);

      final vehicles = await DatabaseHelper.instance.getVehicles();
      expect(vehicles.length, equals(2)); // Both existing and copy exist
      expect(vehicles.map((v) => v.name), containsAll(['Existing Vehicle', 'Imported Copy Vehicle']));

      final records = await DatabaseHelper.instance.getFuelRecords();
      expect(records.length, equals(2)); // Both records exist
      expect(records.map((r) => r.odometer), containsAll([10000.0, 20000.0]));
    });

    test('selective import excludes unselected categories', () async {
      final payload = {
        'vehicles': [
          {'id': 1, 'name': 'Car 1', 'type': 'carOrSedan', 'primaryFuelTypeId': 1, 'tripMeterMode': 'none'},
        ],
        'fuel_types': [
          {'id': 1, 'name': 'Octane', 'category': 'petrol', 'unit': 'L'},
        ],
        'fuel_records': [
          {
            'id': 101,
            'vehicleId': 1,
            'odometer': 5000.0,
            'date': '2026-11-01T10:00:00.000',
            'fuelTypeId': 1,
            'rate': 120.0,
            'volume': 20.0,
            'paidAmount': 2400.0,
            'isFullTank': 1,
            'missedPrevious': 0,
            'drivingCondition': 'city',
          },
        ],
        'non_fuel_expenses': [
          {
            'id': 201,
            'vehicleId': 1,
            'category': 'toll',
            'amount': 250.0,
            'date': '2026-11-02T10:00:00.000',
          },
        ],
      };

      // Only import vehicles and expenses, skip fuel records
      final result = await UnifiedBackupService.executeImport(
        payload: payload,
        selectedCategories: {
          ImportCategory.vehicles,
          ImportCategory.nonFuelExpenses,
        },
        conflictStrategy: ConflictResolutionStrategy.overwriteExisting,
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.importedVehicles, equals(1));
      expect(result.importedRefuels, equals(0)); // Skipped
      expect(result.importedExpenses, equals(1));

      final records = await DatabaseHelper.instance.getFuelRecords();
      expect(records, isEmpty);

      final expenses = await DatabaseHelper.instance.getNonFuelExpenses();
      expect(expenses.length, equals(1));
    });
  });
}
