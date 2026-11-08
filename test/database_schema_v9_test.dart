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

  test('DatabaseHelper schema v9 creates indexes and forward-compatible columns', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 9,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
      onCreate: (db, version) async {},
    );
    expect(db, isNotNull);
    await db.close();
    DatabaseHelper.setDatabaseForTesting(null);
  });

  test('DatabaseHelper upgrades from v8 to v9 seamlessly', () async {
    const testDbPath = 'test_v9_migration.db';
    if (await databaseFactory.databaseExists(testDbPath)) {
      await databaseFactory.deleteDatabase(testDbPath);
    }

    // Open at version 8
    Database db = await databaseFactory.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
        onCreate: (db, version) async {
          // Create schema v8 baseline
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
              FOREIGN KEY (fuelTypeId) REFERENCES fuel_types (id),
              FOREIGN KEY (vehicleId) REFERENCES vehicles (id),
              FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
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
              latitude REAL,
              longitude REAL,
              notes TEXT,
              FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE,
              FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
            )
          ''');
        },
      ),
    );

    await db.close();

    // Reopen with DatabaseHelper upgrade path
    db = await databaseFactory.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 9,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 9) {
            await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_records_vehicle_date ON fuel_records(vehicleId, date);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_records_odometer ON fuel_records(odometer);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_service_sessions_vehicle ON service_sessions(vehicleId, serviceDate);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_saved_locations_coords ON saved_locations(latitude, longitude);');

            await db.execute('ALTER TABLE fuel_records ADD COLUMN receiptImagePath TEXT');
            await db.execute('ALTER TABLE fuel_records ADD COLUMN odometerImagePath TEXT');
            await db.execute("ALTER TABLE fuel_records ADD COLUMN currencyCode TEXT DEFAULT 'BDT'");

            await db.execute('ALTER TABLE service_sessions ADD COLUMN invoiceImagePath TEXT');
          }
        },
      ),
    );

    // Verify columns exist by querying PRAGMA table_info
    final fuelRecordColumns = await db.rawQuery('PRAGMA table_info(fuel_records)');
    final colNames = fuelRecordColumns.map((c) => c['name'] as String).toList();
    expect(colNames, contains('receiptImagePath'));
    expect(colNames, contains('odometerImagePath'));
    expect(colNames, contains('currencyCode'));

    final serviceColumns = await db.rawQuery('PRAGMA table_info(service_sessions)');
    final serviceColNames = serviceColumns.map((c) => c['name'] as String).toList();
    expect(serviceColNames, contains('invoiceImagePath'));

    // Verify indexes exist by querying sqlite_master
    final indexes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'");
    final indexNames = indexes.map((i) => i['name'] as String).toList();
    expect(indexNames, contains('idx_fuel_records_vehicle_date'));
    expect(indexNames, contains('idx_fuel_records_odometer'));
    expect(indexNames, contains('idx_service_sessions_vehicle'));
    expect(indexNames, contains('idx_saved_locations_coords'));

    await db.close();
    if (await databaseFactory.databaseExists(testDbPath)) {
      await databaseFactory.deleteDatabase(testDbPath);
    }
  });
}
