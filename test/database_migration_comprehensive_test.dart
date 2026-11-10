// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  group('Database Migration Comprehensive Tests (Versions 3..10 -> 11)', () {
    // ------------------------------------------------------------------------
    // v3 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v3 to v11: sample rows survive and all new tables/columns created', () async {
      const dbPath = 'test_v3_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      // 1. Create baseline database at version 3
      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 3,
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
                FOREIGN KEY (fuelTypeId) REFERENCES fuel_types (id),
                FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
              )
            ''');
          },
        ),
      );

      // Insert sample rows at v3
      await db.insert('fuel_types', {'id': 1, 'name': 'Octane', 'category': 'liquid', 'unit': 'L'});
      await db.insert('vehicles', {
        'id': 1,
        'name': 'Corolla v3',
        'type': 'Sedan',
        'primaryFuelTypeId': 1,
        'primaryFuelCapacity': 50.0,
      });
      await db.insert('fuel_records', {
        'id': 1,
        'date': '2026-01-01T10:00:00.000',
        'odometer': 10000.0,
        'fuelTypeId': 1,
        'vehicleId': 1,
        'rate': 125.0,
        'volume': 40.0,
        'paidAmount': 5000.0,
      });
      await db.close();

      // 2. Migrate to latest (v11) using DatabaseHelper
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      // 3. Assert sample rows survived
      final vehicles = await db.query('vehicles', where: 'id = ?', whereArgs: [1]);
      expect(vehicles.length, 1);
      expect(vehicles.first['name'], 'Corolla v3');
      // Verify new v11 columns exist with defaults
      expect(vehicles.first['distanceUnit'], 'km');
      expect(vehicles.first['fuelVolumeUnit'], 'litre');
      expect(vehicles.first['consumptionUnit'], 'kmPerLitre');
      expect(vehicles.first['tripMeterMode'], 'none');

      final records = await db.query('fuel_records', where: 'id = ?', whereArgs: [1]);
      expect(records.length, 1);
      expect(records.first['odometer'], 10000.0);
      expect(records.first['isFullTank'], 1); // v4 default
      expect(records.first['missedPrevious'], 0); // v4 default
      expect(records.first['drivingCondition'], 'mixed'); // v5 default
      expect(records.first['exchangeRateToBase'], 1.0); // v11 default

      // Assert new tables exist
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames, containsAll(['maintenance_tasks', 'service_sessions', 'service_session_items', 'saved_locations', 'non_fuel_expenses', 'tires', 'tire_logs']));

      // Assert foreign key constraints are active
      expect(
        () async => await db.insert('fuel_records', {
          'date': '2026-01-02T10:00:00.000',
          'odometer': 10500.0,
          'fuelTypeId': 999, // Non-existent fuel type
          'vehicleId': 1,
          'rate': 100.0,
          'volume': 10.0,
          'paidAmount': 1000.0,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Verify cascade delete
      await db.delete('vehicles', where: 'id = ?', whereArgs: [1]);
      final survivingRecords = await db.query('fuel_records', where: 'vehicleId = ?', whereArgs: [1]);
      expect(survivingRecords, isEmpty);

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v4 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v4 to v11: v4 columns survive and upgrades complete', () async {
      const dbPath = 'test_v4_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 4,
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
                secondaryFuelCapacity REAL
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
                FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
              )
            ''');
          },
        ),
      );

      await db.insert('fuel_types', {'id': 1, 'name': 'Diesel', 'category': 'liquid', 'unit': 'L'});
      await db.insert('vehicles', {'id': 1, 'name': 'Truck v4', 'type': 'Truck', 'primaryFuelTypeId': 1});
      await db.insert('fuel_records', {
        'id': 10,
        'date': '2026-02-01T10:00:00.000',
        'odometer': 50000.0,
        'fuelTypeId': 1,
        'vehicleId': 1,
        'rate': 110.0,
        'volume': 60.0,
        'paidAmount': 6600.0,
        'isFullTank': 0, // custom non-default
        'missedPrevious': 1,
        'tripDistance': 450.5,
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      final records = await db.query('fuel_records', where: 'id = ?', whereArgs: [10]);
      expect(records.first['isFullTank'], 0);
      expect(records.first['missedPrevious'], 1);
      expect(records.first['tripDistance'], 450.5);
      expect(records.first['drivingCondition'], 'mixed');

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v5 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v5 to v11: tripMeterMode and drivingCondition survive', () async {
      const dbPath = 'test_v5_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 5,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                primaryFuelTypeId INTEGER NOT NULL,
                tripMeterMode TEXT NOT NULL DEFAULT 'none'
              )
            ''');
            await db.execute('''
              CREATE TABLE fuel_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                date TEXT NOT NULL,
                odometer REAL NOT NULL,
                rate REAL NOT NULL,
                volume REAL NOT NULL,
                paidAmount REAL NOT NULL,
                fuelTypeId INTEGER NOT NULL,
                secondaryTripDistance REAL,
                drivingCondition TEXT NOT NULL DEFAULT 'mixed'
              )
            ''');
          },
        ),
      );

      await db.insert('vehicles', {'id': 1, 'name': 'Prius v5', 'type': 'Hybrid', 'primaryFuelTypeId': 1, 'tripMeterMode': 'dual'});
      await db.insert('fuel_records', {
        'id': 20,
        'vehicleId': 1,
        'date': '2026-03-01T10:00:00.000',
        'odometer': 20000.0,
        'fuelTypeId': 1,
        'rate': 120.0,
        'volume': 35.0,
        'paidAmount': 4200.0,
        'secondaryTripDistance': 15.2,
        'drivingCondition': 'city',
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      final vehicle = await db.query('vehicles', where: 'id = ?', whereArgs: [1]);
      expect(vehicle.first['tripMeterMode'], 'dual');
      final record = await db.query('fuel_records', where: 'id = ?', whereArgs: [20]);
      expect(record.first['secondaryTripDistance'], 15.2);
      expect(record.first['drivingCondition'], 'city');

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v6 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v6 to v11: vehicle reminder thresholds survive and tasks are seeded', () async {
      const dbPath = 'test_v6_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 6,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                primaryFuelTypeId INTEGER NOT NULL,
                volumeReminderEnabled INTEGER NOT NULL DEFAULT 0,
                volumeReminderValue REAL NOT NULL DEFAULT 3.0,
                distanceReminderEnabled INTEGER NOT NULL DEFAULT 0,
                distanceReminderValue REAL NOT NULL DEFAULT 50.0
              )
            ''');
            await db.execute('''
              CREATE TABLE fuel_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                date TEXT NOT NULL,
                odometer REAL NOT NULL
              )
            ''');
          },
        ),
      );

      await db.insert('vehicles', {
        'id': 1,
        'name': 'Civic v6',
        'type': 'Sedan',
        'primaryFuelTypeId': 1,
        'volumeReminderEnabled': 1,
        'volumeReminderValue': 7.5,
        'distanceReminderEnabled': 1,
        'distanceReminderValue': 65.0,
      });
      await db.insert('fuel_records', {
        'id': 1,
        'vehicleId': 1,
        'date': '2026-04-01T10:00:00.000',
        'odometer': 35000.0,
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      final v = await db.query('vehicles', where: 'id = ?', whereArgs: [1]);
      expect(v.first['volumeReminderEnabled'], 1);
      expect(v.first['volumeReminderValue'], 7.5);
      expect(v.first['distanceReminderEnabled'], 1);
      expect(v.first['distanceReminderValue'], 65.0);

      // Verify maintenance tasks were automatically seeded during v6 -> v7 migration
      final tasks = await db.query('maintenance_tasks', where: 'vehicleId = ?', whereArgs: [1]);
      expect(tasks, isNotEmpty);
      expect(tasks.first['lastServiceOdo'], 35000.0);

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v7 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v7 to v11: maintenance tasks and service sessions survive with constraints', () async {
      const dbPath = 'test_v7_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 7,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                primaryFuelTypeId INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE fuel_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                odometer REAL NOT NULL,
                date TEXT NOT NULL
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
                isEnabled INTEGER DEFAULT 1,
                FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
              )
            ''');
            await db.execute('''
              CREATE TABLE service_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                odometer REAL NOT NULL,
                serviceDate TEXT NOT NULL,
                totalCost REAL,
                workshopName TEXT,
                locationId INTEGER,
                notes TEXT,
                FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
              )
            ''');
            await db.execute('''
              CREATE TABLE service_session_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sessionId INTEGER NOT NULL,
                taskId INTEGER NOT NULL,
                brandOrSpec TEXT,
                cost REAL,
                locationId INTEGER,
                notes TEXT,
                FOREIGN KEY (sessionId) REFERENCES service_sessions (id) ON DELETE CASCADE,
                FOREIGN KEY (taskId) REFERENCES maintenance_tasks (id) ON DELETE CASCADE
              )
            ''');
          },
        ),
      );

      await db.insert('vehicles', {'id': 1, 'name': 'BMW v7', 'type': 'Sedan', 'primaryFuelTypeId': 1});
      await db.insert('maintenance_tasks', {
        'id': 1,
        'vehicleId': 1,
        'taskKey': 'engine_oil',
        'title': 'Engine Oil',
        'intervalKm': 5000.0,
        'lastServiceOdo': 12000.0,
        'lastServiceDate': '2026-05-01T10:00:00.000',
      });
      await db.insert('service_sessions', {
        'id': 100,
        'vehicleId': 1,
        'odometer': 12000.0,
        'serviceDate': '2026-05-01T10:00:00.000',
        'totalCost': 3500.0,
        'workshopName': 'Bosch Service',
      });
      await db.insert('service_session_items', {
        'id': 200,
        'sessionId': 100,
        'taskId': 1,
        'brandOrSpec': 'Castrol 5W-30',
        'cost': 3500.0,
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      final session = await db.query('service_sessions', where: 'id = ?', whereArgs: [100]);
      expect(session.first['workshopName'], 'Bosch Service');
      final item = await db.query('service_session_items', where: 'id = ?', whereArgs: [200]);
      expect(item.first['brandOrSpec'], 'Castrol 5W-30');

      // Verify cascading deletion across service sessions and items
      await db.delete('vehicles', where: 'id = ?', whereArgs: [1]);
      final survivingSessions = await db.query('service_sessions', where: 'vehicleId = ?', whereArgs: [1]);
      expect(survivingSessions, isEmpty);
      final survivingItems = await db.query('service_session_items', where: 'sessionId = ?', whereArgs: [100]);
      expect(survivingItems, isEmpty);

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v8 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v8 to v11: saved_locations and location associations survive', () async {
      const dbPath = 'test_v8_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 8,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE saved_locations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                isNamed INTEGER NOT NULL DEFAULT 0,
                type TEXT NOT NULL DEFAULT 'fuel_station',
                latitude REAL,
                longitude REAL,
                radiusMeters REAL NOT NULL DEFAULT 80.0,
                isSuspectFuel INTEGER NOT NULL DEFAULT 0,
                isSuspectServiceOrParts INTEGER NOT NULL DEFAULT 0,
                suspectReason TEXT,
                isRecommendedFuel INTEGER NOT NULL DEFAULT 0,
                isRecommendedServiceOrParts INTEGER NOT NULL DEFAULT 0,
                performanceReason TEXT,
                rating REAL,
                notes TEXT,
                createdAt TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                primaryFuelTypeId INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE fuel_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                odometer REAL NOT NULL,
                date TEXT NOT NULL,
                locationId INTEGER,
                latitude REAL,
                longitude REAL
              )
            ''');
            await db.execute('''
              CREATE TABLE service_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                odometer REAL NOT NULL,
                serviceDate TEXT NOT NULL,
                latitude REAL,
                longitude REAL
              )
            ''');
          },
        ),
      );

      await db.insert('saved_locations', {
        'id': 50,
        'name': 'Shell Central',
        'isNamed': 1,
        'latitude': 23.8103,
        'longitude': 90.4125,
        'createdAt': '2026-06-01T10:00:00.000',
      });
      await db.insert('vehicles', {'id': 1, 'name': 'Corolla v8', 'type': 'Sedan', 'primaryFuelTypeId': 1});
      await db.insert('fuel_records', {
        'id': 1,
        'vehicleId': 1,
        'odometer': 15000.0,
        'date': '2026-06-01T10:00:00.000',
        'locationId': 50,
        'latitude': 23.8103,
        'longitude': 90.4125,
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      final loc = await db.query('saved_locations', where: 'id = ?', whereArgs: [50]);
      expect(loc.first['name'], 'Shell Central');
      final rec = await db.query('fuel_records', where: 'id = ?', whereArgs: [1]);
      expect(rec.first['locationId'], 50);

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v9 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v9 to v11: v9 media & currency columns survive and non_fuel_expenses is added', () async {
      const dbPath = 'test_v9_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 9,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                primaryFuelTypeId INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE fuel_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                odometer REAL NOT NULL,
                date TEXT NOT NULL,
                receiptImagePath TEXT,
                odometerImagePath TEXT,
                currencyCode TEXT DEFAULT 'BDT'
              )
            ''');
          },
        ),
      );

      await db.insert('vehicles', {'id': 1, 'name': 'Golf v9', 'type': 'Hatchback', 'primaryFuelTypeId': 1});
      await db.insert('fuel_records', {
        'id': 1,
        'vehicleId': 1,
        'odometer': 25000.0,
        'date': '2026-07-01T10:00:00.000',
        'receiptImagePath': '/attachments/receipt_123.jpg',
        'odometerImagePath': '/attachments/odo_123.jpg',
        'currencyCode': 'EUR',
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      final rec = await db.query('fuel_records', where: 'id = ?', whereArgs: [1]);
      expect(rec.first['receiptImagePath'], '/attachments/receipt_123.jpg');
      expect(rec.first['currencyCode'], 'EUR');

      // Verify v10 table non_fuel_expenses exists and is queryable
      final expenses = await db.query('non_fuel_expenses');
      expect(expenses, isEmpty);

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // v10 -> v11
    // ------------------------------------------------------------------------
    test('Migrate schema v10 to v11: non_fuel_expenses survive and v11 international/tire tables added', () async {
      const dbPath = 'test_v10_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 10,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                primaryFuelTypeId INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE fuel_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                odometer REAL NOT NULL,
                date TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE non_fuel_expenses (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vehicleId INTEGER NOT NULL,
                date TEXT NOT NULL,
                odometer REAL,
                category TEXT NOT NULL,
                amount REAL NOT NULL,
                currencyCode TEXT DEFAULT 'BDT',
                notes TEXT,
                receiptImagePath TEXT,
                FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
              )
            ''');
          },
        ),
      );

      await db.insert('vehicles', {'id': 1, 'name': 'Tesla v10', 'type': 'BEV', 'primaryFuelTypeId': 1});
      await db.insert('non_fuel_expenses', {
        'id': 101,
        'vehicleId': 1,
        'date': '2026-08-01T10:00:00.000',
        'odometer': 15000.0,
        'category': 'Parking',
        'amount': 250.0,
        'currencyCode': 'USD',
        'notes': 'Airport parking',
      });
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      // Verify non-fuel expense row survived
      final expense = await db.query('non_fuel_expenses', where: 'id = ?', whereArgs: [101]);
      expect(expense.length, 1);
      expect(expense.first['category'], 'Parking');
      expect(expense.first['amount'], 250.0);
      expect(expense.first['currencyCode'], 'USD');

      // Verify v11 tables (tires, tire_logs) exist
      await db.insert('tires', {
        'id': 1,
        'vehicleId': 1,
        'brand': 'Michelin',
        'size': '225/45R17',
        'installedOdo': 15000.0,
        'installedDate': '2026-08-01T10:00:00.000',
        'initialTreadDepthMm': 8.0,
        'currentTreadDepthMm': 7.5,
      });

      final tire = await db.query('tires', where: 'id = ?', whereArgs: [1]);
      expect(tire.first['brand'], 'Michelin');

      // Cascade test: deleting vehicle deletes tire and expense
      await db.delete('vehicles', where: 'id = ?', whereArgs: [1]);
      final survivingTires = await db.query('tires', where: 'vehicleId = ?', whereArgs: [1]);
      expect(survivingTires, isEmpty);
      final survivingExpenses = await db.query('non_fuel_expenses', where: 'vehicleId = ?', whereArgs: [1]);
      expect(survivingExpenses, isEmpty);

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });

    // ------------------------------------------------------------------------
    // Versions < 3 Note: Document missing schemas & destructive recreate behavior
    // ------------------------------------------------------------------------
    test('Versions < 3 (v1/v2) documentation: migration code drops and recreates tables', () async {
      // The migration code in DatabaseHelper._onUpgrade explicitly defines:
      // if (oldVersion < 3) {
      //   await db.execute('DROP TABLE IF EXISTS fuel_records');
      //   await db.execute('DROP TABLE IF EXISTS fuel_types');
      //   await db.execute('DROP TABLE IF EXISTS vehicles');
      //   await _createTables(db);
      //   return;
      // }
      // This proves that schemas prior to v3 are not preserved and lack versioned DDLs in the repository.
      const dbPath = 'test_v2_to_v11.db';
      if (await databaseFactory.databaseExists(dbPath)) {
        await databaseFactory.deleteDatabase(dbPath);
      }

      Database db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE vehicles (id INTEGER PRIMARY KEY, name TEXT)');
          },
        ),
      );
      await db.insert('vehicles', {'id': 1, 'name': 'Old Legacy'});
      await db.close();

      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onUpgrade: (db, oldVersion, newVersion) async {
            await DatabaseHelper.instance.onUpgradeForTesting(db, oldVersion, newVersion);
          },
        ),
      );

      // Verify that for < 3, tables are cleanly recreated to full latest schema
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames, containsAll(['vehicles', 'fuel_records', 'fuel_types', 'saved_locations', 'maintenance_tasks', 'non_fuel_expenses', 'tires', 'tire_logs']));

      await db.close();
      await databaseFactory.deleteDatabase(dbPath);
    });
  });
}
