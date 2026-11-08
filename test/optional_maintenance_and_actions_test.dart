// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database testDb;
  late DatabaseHelper dbHelper;

  setUp(() async {
    testDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await testDb.execute('PRAGMA foreign_keys = ON;');

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
        exchangeRateToBase REAL NOT NULL DEFAULT 1.0,
        energyKwh REAL,
        socStart REAL,
        socEnd REAL,
        chargingPowerKw REAL,
        chargeType TEXT,
        FOREIGN KEY (fuelTypeId) REFERENCES fuel_types (id),
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id)
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
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
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
        FOREIGN KEY (taskId) REFERENCES maintenance_tasks (id) ON DELETE CASCADE
      )
    ''');

    await testDb.insert('fuel_types', {
      'name': 'Octane',
      'category': 'gasoline',
      'unit': 'litre',
    });

    DatabaseHelper.setDatabaseForTesting(testDb);
    dbHelper = DatabaseHelper.instance;
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    await testDb.close();
  });

  test('hasAnyEnabledRoutine returns false when no vehicle has reminders and tasks are disabled', () async {
    final vId = await dbHelper.insertVehicle(Vehicle(
      name: 'Test Car',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
      volumeReminderEnabled: false,
      distanceReminderEnabled: false,
    ));

    // By default, tasks seeded for new vehicle have isEnabled = 0
    final tasks = await dbHelper.getMaintenanceTasks(vId);
    expect(tasks.isNotEmpty, true);
    expect(tasks.every((t) => !t.isEnabled), true);

    final hasRoutines = await dbHelper.hasAnyEnabledRoutine();
    expect(hasRoutines, false);
  });

  test('hasAnyEnabledRoutine returns true when volume reminder is enabled', () async {
    await dbHelper.insertVehicle(Vehicle(
      name: 'Volume Reminder Car',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
      volumeReminderEnabled: true,
      distanceReminderEnabled: false,
    ));

    final hasRoutines = await dbHelper.hasAnyEnabledRoutine();
    expect(hasRoutines, true);
  });

  test('hasAnyEnabledRoutine returns true when distance reminder is enabled', () async {
    await dbHelper.insertVehicle(Vehicle(
      name: 'Distance Reminder Car',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
      volumeReminderEnabled: false,
      distanceReminderEnabled: true,
    ));

    final hasRoutines = await dbHelper.hasAnyEnabledRoutine();
    expect(hasRoutines, true);
  });

  test('hasAnyEnabledRoutine returns true when a maintenance task is enabled', () async {
    final vId = await dbHelper.insertVehicle(Vehicle(
      name: 'Maintenance Car',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
      volumeReminderEnabled: false,
      distanceReminderEnabled: false,
    ));

    final tasks = await dbHelper.getMaintenanceTasks(vId);
    final firstTask = tasks.first;
    await dbHelper.updateMaintenanceTask(firstTask.copyWith(isEnabled: true));

    final hasRoutines = await dbHelper.hasAnyEnabledRoutine();
    expect(hasRoutines, true);
  });

  test('getEstimatedServiceCost returns the most recent total cost for vehicle', () async {
    final vId = await dbHelper.insertVehicle(Vehicle(
      name: 'Service Cost Car',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
    ));

    expect(await dbHelper.getEstimatedServiceCost(vId), isNull);

    final tasks = await dbHelper.getMaintenanceTasks(vId);
    final taskId = tasks.first.id!;

    // Insert service session 1
    await dbHelper.insertServiceSession(ServiceSession(
      vehicleId: vId,
      odometer: 10000.0,
      serviceDate: DateTime(2025, 1, 1),
      totalCost: 1500.0,
      items: [
        ServiceSessionItem(taskId: taskId, cost: 1500.0, brandOrSpec: 'Mobil 1'),
      ],
    ));

    expect(await dbHelper.getEstimatedServiceCost(vId), 1500.0);

    // Insert service session 2 with higher odometer
    await dbHelper.insertServiceSession(ServiceSession(
      vehicleId: vId,
      odometer: 15000.0,
      serviceDate: DateTime(2025, 6, 1),
      totalCost: 2200.0,
      items: [
        ServiceSessionItem(taskId: taskId, cost: 2200.0, brandOrSpec: 'Mobil 1'),
      ],
    ));

    expect(await dbHelper.getEstimatedServiceCost(vId), 2200.0);
  });
}
