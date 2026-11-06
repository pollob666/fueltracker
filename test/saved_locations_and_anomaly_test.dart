// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/services/location_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SavedLocation Model Unit Tests', () {
    test('displayName returns custom name when isNamed=true', () {
      final loc = SavedLocation(
        name: 'Padma Star Station',
        isNamed: true,
        latitude: 23.7915,
        longitude: 90.4042,
      );
      expect(loc.displayName, equals('Padma Star Station'));
      expect(loc.isSuspect, isFalse);
      expect(loc.isRecommended, isFalse);
    });

    test('displayName returns formatted coords when isNamed=false', () {
      final loc = SavedLocation(
        name: 'Unnamed Location',
        isNamed: false,
        latitude: 23.79152,
        longitude: 90.40428,
      );
      expect(loc.displayName, equals('Unnamed (23.7915, 90.4043)'));
    });

    test('isSuspect and isRecommended flags evaluate correctly', () {
      final suspectLoc = SavedLocation(
        name: 'Bad Fuel Station',
        isNamed: true,
        isSuspectFuel: true,
        suspectReason: 'Dropped 18%',
      );
      expect(suspectLoc.isSuspect, isTrue);
      expect(suspectLoc.isRecommended, isFalse);

      final recommendedLoc = SavedLocation(
        name: 'High Performance Workshop',
        isNamed: true,
        type: 'service_shop',
        isRecommendedServiceOrParts: true,
        performanceReason: 'Boosted 17%',
      );
      expect(recommendedLoc.isSuspect, isFalse);
      expect(recommendedLoc.isRecommended, isTrue);
    });

    test('toMap and fromMap roundtrip preserves all fields', () {
      final loc = SavedLocation(
        id: 42,
        name: 'Meghna Pump',
        isNamed: true,
        type: 'both',
        latitude: 23.8100,
        longitude: 90.4100,
        radiusMeters: 120.0,
        isSuspectFuel: false,
        isSuspectServiceOrParts: true,
        suspectReason: 'Counterfeit Oil',
        isRecommendedFuel: false,
        isRecommendedServiceOrParts: false,
        rating: 4.5,
        notes: 'Has CNG also',
      );

      final map = loc.toMap();
      final restored = SavedLocation.fromMap(map);

      expect(restored.id, equals(42));
      expect(restored.name, equals('Meghna Pump'));
      expect(restored.isNamed, isTrue);
      expect(restored.type, equals('both'));
      expect(restored.latitude, equals(23.8100));
      expect(restored.longitude, equals(90.4100));
      expect(restored.radiusMeters, equals(120.0));
      expect(restored.isSuspectServiceOrParts, isTrue);
      expect(restored.suspectReason, equals('Counterfeit Oil'));
      expect(restored.rating, equals(4.5));
      expect(restored.notes, equals('Has CNG also'));
    });
  });

  group('Mileage Anomaly Detection (Drop & Boost) Engine Tests', () {
    test('checkMileageAnomaly returns null when fewer than 2 records', () {
      final records = [
        FuelRecord(
          id: 1,
          date: DateTime.now(),
          odometer: 1000.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
        ),
      ];
      final res = MileageCalculator.checkMileageAnomaly(records);
      expect(res, isNull);
    });

    test('Detects >15% drop anomaly and identifies baseline fuel provider', () {
      // Historical rolling average: 15 km/L
      // Interval 1: 1000 -> 1450 (450 km) on 30L = 15.0 km/L
      // Interval 2: 1450 -> 1900 (450 km) on 30L = 15.0 km/L
      // Interval 3: 1900 -> 2260 (360 km) on 30L = 12.0 km/L (-20.0% drop!)
      final records = [
        FuelRecord(
          id: 1,
          date: DateTime(2025, 1, 1),
          odometer: 1000.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
          locationId: 101, // Station A (fuel provider for interval 1)
        ),
        FuelRecord(
          id: 2,
          date: DateTime(2025, 1, 10),
          odometer: 1450.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
          locationId: 102, // Station B (fuel provider for interval 2)
        ),
        FuelRecord(
          id: 3,
          date: DateTime(2025, 1, 20),
          odometer: 1900.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
          locationId: 103, // Station C (fuel provider for interval 3)
        ),
        FuelRecord(
          id: 4,
          date: DateTime(2025, 1, 30),
          odometer: 2260.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
          locationId: 104, // Station D
        ),
      ];

      final anomaly = MileageCalculator.checkMileageAnomaly(records);
      expect(anomaly, isNotNull);
      expect(anomaly!.hasAnomaly, isTrue);
      expect(anomaly.isDrop, isTrue);
      expect(anomaly.isBoost, isFalse);
      expect(anomaly.intervalMileage, closeTo(12.0, 0.01));
      expect(anomaly.runningAverage, closeTo(15.0, 0.01));
      expect(anomaly.percentageChange, closeTo(-20.0, 0.1));
      // Fuel consumed was filled at step 3 (Station C, locationId 103)
      expect(anomaly.baselineRecord?.id, equals(3));
      expect(anomaly.baselineRecord?.locationId, equals(103));
    });

    test('Detects >15% boost (green efficiency) when mileage spikes', () {
      // Historical rolling average: 15.0 km/L
      // Interval 3: 1900 -> 2440 (540 km) on 30L = 18.0 km/L (+20.0% gain!)
      final records = [
        FuelRecord(
          id: 1,
          date: DateTime(2025, 1, 1),
          odometer: 1000.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          date: DateTime(2025, 1, 10),
          odometer: 1450.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
        ),
        FuelRecord(
          id: 3,
          date: DateTime(2025, 1, 20),
          odometer: 1900.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
          locationId: 201, // High efficiency station
        ),
        FuelRecord(
          id: 4,
          date: DateTime(2025, 1, 30),
          odometer: 2440.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 30.0,
          paidAmount: 3900.0,
          isFullTank: true,
        ),
      ];

      final anomaly = MileageCalculator.checkMileageAnomaly(records);
      expect(anomaly, isNotNull);
      expect(anomaly!.hasAnomaly, isTrue);
      expect(anomaly.isDrop, isFalse);
      expect(anomaly.isBoost, isTrue);
      expect(anomaly.intervalMileage, closeTo(18.0, 0.01));
      expect(anomaly.percentageChange, closeTo(20.0, 0.1));
      expect(anomaly.baselineRecord?.locationId, equals(201));
    });
  });

  group('DatabaseHelper Schema v8 & SavedLocation CRUD Tests', () {
    late Database testDb;
    late DatabaseHelper dbHelper;

    setUp(() async {
      testDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await testDb.execute('PRAGMA foreign_keys = ON;');

      // Schema v8 table creation
      await testDb.execute('''
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

      await testDb.execute('''
        CREATE TABLE fuel_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          unit TEXT NOT NULL
        )
      ''');

      await testDb.execute('''
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

      await testDb.execute('''
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
          FOREIGN KEY (vehicleId) REFERENCES vehicles (id),
          FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
        )
      ''');

      await testDb.execute('''
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

      await testDb.execute('''
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
          invoiceImagePath TEXT,
          FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE,
          FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
        )
      ''');

      await testDb.execute('''
        CREATE TABLE service_session_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId INTEGER NOT NULL,
          taskId INTEGER NOT NULL,
          brandOrSpec TEXT,
          cost REAL,
          locationId INTEGER,
          notes TEXT,
          FOREIGN KEY (sessionId) REFERENCES service_sessions (id) ON DELETE CASCADE,
          FOREIGN KEY (taskId) REFERENCES maintenance_tasks (id) ON DELETE CASCADE,
          FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
        )
      ''');

      DatabaseHelper.setDatabaseForTesting(testDb);
      dbHelper = DatabaseHelper.instance;

      // Seed FuelType and Vehicle
      await testDb.insert('fuel_types', {'id': 1, 'name': 'Octane', 'category': 'gasoline', 'unit': 'litre'});
      await testDb.insert('vehicles', {'id': 1, 'name': 'Toyota Corolla', 'type': 'sedan', 'primaryFuelTypeId': 1});
    });

    tearDown(() async {
      await testDb.close();
      DatabaseHelper.setDatabaseForTesting(null);
    });

    test('Insert, query, and filter saved locations', () async {
      final loc1 = SavedLocation(
        name: 'Clean Fuel Meghna',
        isNamed: true,
        type: 'fuel_station',
        latitude: 23.7915,
        longitude: 90.4042,
        isSuspectFuel: true,
        suspectReason: 'Dropped 18%',
      );
      final loc2 = SavedLocation(
        name: 'Padma Star Station',
        isNamed: true,
        type: 'fuel_station',
        latitude: 23.8200,
        longitude: 90.4100,
        isRecommendedFuel: true,
        performanceReason: 'Boosted 17%',
      );
      final loc3 = SavedLocation(
        name: 'QuickLube Workshop',
        isNamed: true,
        type: 'service_shop',
        latitude: 23.7650,
        longitude: 90.3980,
      );
      final loc4 = SavedLocation(
        name: 'Unnamed Cluster',
        isNamed: false,
        latitude: 23.7000,
        longitude: 90.3500,
      );

      final id1 = await dbHelper.insertSavedLocation(loc1);
      final id2 = await dbHelper.insertSavedLocation(loc2);
      await dbHelper.insertSavedLocation(loc3);
      await dbHelper.insertSavedLocation(loc4);

      // All locations
      final all = await dbHelper.getSavedLocations();
      expect(all.length, equals(4));

      // Filter: only named
      final namedOnly = await dbHelper.getSavedLocations(onlyNamed: true);
      expect(namedOnly.length, equals(3));

      // Filter: only suspect
      final suspectOnly = await dbHelper.getSavedLocations(onlySuspect: true);
      expect(suspectOnly.length, equals(1));
      expect(suspectOnly.first.id, equals(id1));

      // Filter: only recommended
      final recOnly = await dbHelper.getSavedLocations(onlyRecommended: true);
      expect(recOnly.length, equals(1));
      expect(recOnly.first.id, equals(id2));

      // Filter: by type 'service_shop'
      final workshops = await dbHelper.getSavedLocations(type: 'service_shop');
      expect(workshops.length, equals(1));
      expect(workshops.first.name, equals('QuickLube Workshop'));
    });

    test('Atomic deleteSavedLocation nullifies foreign keys in fuel_records and service_sessions', () async {
      final locId = await dbHelper.insertSavedLocation(SavedLocation(
        name: 'Highway Station',
        isNamed: true,
        latitude: 23.8000,
        longitude: 90.4000,
      ));

      final recId = await dbHelper.insertFuelRecord(FuelRecord(
        date: DateTime.now(),
        odometer: 1000.0,
        fuelTypeId: 1,
        vehicleId: 1,
        rate: 130.0,
        volume: 30.0,
        paidAmount: 3900.0,
        locationId: locId,
      ));

      final sessionId = await dbHelper.insertServiceSession(ServiceSession(
        vehicleId: 1,
        odometer: 1000.0,
        serviceDate: DateTime.now(),
        workshopName: 'Highway Station',
        locationId: locId,
      ));

      // Confirm links
      final recordBefore = (await dbHelper.getFuelRecords()).firstWhere((r) => r.id == recId);
      expect(recordBefore.locationId, equals(locId));

      final sessionBefore = (await dbHelper.getServiceSessions(1)).firstWhere((s) => s.id == sessionId);
      expect(sessionBefore.locationId, equals(locId));

      // Delete location
      await dbHelper.deleteSavedLocation(locId);

      // Verify location deleted
      final locAfter = await dbHelper.getSavedLocationById(locId);
      expect(locAfter, isNull);

      // Verify foreign keys set to NULL without crashing or violating constraints
      final recordAfter = (await dbHelper.getFuelRecords()).firstWhere((r) => r.id == recId);
      expect(recordAfter.locationId, isNull);

      final sessionAfter = (await dbHelper.getServiceSessions(1)).firstWhere((s) => s.id == sessionId);
      expect(sessionAfter.locationId, isNull);
    });

    test('Flagging and clearing suspect / recommended status', () async {
      final locId = await dbHelper.insertSavedLocation(SavedLocation(
        name: 'Test Pump',
        isNamed: true,
      ));

      // Mark suspect
      await dbHelper.markLocationSuspect(locId, reason: 'Bad fuel 20% drop', forFuel: true);
      var loc = await dbHelper.getSavedLocationById(locId);
      expect(loc!.isSuspectFuel, isTrue);
      expect(loc.suspectReason, equals('Bad fuel 20% drop'));

      // Clear suspect
      await dbHelper.clearLocationSuspectFlag(locId);
      loc = await dbHelper.getSavedLocationById(locId);
      expect(loc!.isSuspectFuel, isFalse);
      expect(loc.suspectReason, isNull);

      // Mark recommended
      await dbHelper.markLocationRecommended(locId, reason: '+18% boost', forFuel: true);
      loc = await dbHelper.getSavedLocationById(locId);
      expect(loc!.isRecommendedFuel, isTrue);
      expect(loc.performanceReason, equals('+18% boost'));

      // Clear recommended
      await dbHelper.clearLocationRecommendedFlag(locId);
      loc = await dbHelper.getSavedLocationById(locId);
      expect(loc!.isRecommendedFuel, isFalse);
      expect(loc.performanceReason, isNull);
    });
  });

  group('LocationService Proximity & Distance Calculation Tests', () {
    test('calculateDistance correctly calculates distance in meters', () {
      final service = LocationService.instance;
      // Distance between Dhaka Airport (23.8510, 90.4075) and Banani (23.7937, 90.4042) is ~6.4 km
      final distMeters = service.calculateDistance(23.8510, 90.4075, 23.7937, 90.4042);
      expect(distMeters, greaterThan(6000));
      expect(distMeters, lessThan(7000));
    });
  });
}
