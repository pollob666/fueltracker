// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/models/tire.dart';
import 'package:fuel_tracker/models/tire_log.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  @visibleForTesting
  static void setDatabaseForTesting(Database? db) {
    _database = db;
  }

  @visibleForTesting
  Future<void> createTablesForTesting(Database db) async {
    await _createTables(db);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "fuel_tracker.db");
    return await openDatabase(
      path,
      version: 11,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Legacy fallback from v1/v2 schema
      await db.execute('DROP TABLE IF EXISTS fuel_records');
      await db.execute('DROP TABLE IF EXISTS fuel_types');
      await db.execute('DROP TABLE IF EXISTS vehicles');
      await _createTables(db);
      return;
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE fuel_records ADD COLUMN isFullTank INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN missedPrevious INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN tripDistance REAL');
    }

    if (oldVersion < 5) {
      await db.execute("ALTER TABLE vehicles ADD COLUMN tripMeterMode TEXT NOT NULL DEFAULT 'none'");
      await db.execute('ALTER TABLE fuel_records ADD COLUMN secondaryTripDistance REAL');
      await db.execute("ALTER TABLE fuel_records ADD COLUMN drivingCondition TEXT NOT NULL DEFAULT 'mixed'");
    }

    if (oldVersion < 6) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN volumeReminderEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE vehicles ADD COLUMN volumeReminderValue REAL NOT NULL DEFAULT 3.0');
      await db.execute('ALTER TABLE vehicles ADD COLUMN distanceReminderEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE vehicles ADD COLUMN distanceReminderValue REAL NOT NULL DEFAULT 50.0');
    }

    if (oldVersion < 7) {
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

      final vehicles = await db.query('vehicles');
      for (final v in vehicles) {
        final vehicleId = v['id'] as int;
        final lastRecord = await db.query(
          'fuel_records',
          where: 'vehicleId = ?',
          whereArgs: [vehicleId],
          orderBy: 'odometer DESC',
          limit: 1,
        );
        final double lastOdo = lastRecord.isNotEmpty
            ? (lastRecord.first['odometer'] as num).toDouble()
            : 0.0;
        final String lastDate = lastRecord.isNotEmpty
            ? (lastRecord.first['date'] as String)
            : DateTime.now().toIso8601String();

        await _seedDefaultTasksForVehicle(
          db,
          vehicleId,
          lastOdo,
          DateTime.parse(lastDate),
        );
      }
    }

    if (oldVersion < 8) {
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

      await db.execute('ALTER TABLE fuel_records ADD COLUMN locationId INTEGER REFERENCES saved_locations (id) ON DELETE SET NULL');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN longitude REAL');

      await db.execute('ALTER TABLE service_sessions ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE service_sessions ADD COLUMN longitude REAL');
    }

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

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS non_fuel_expenses (
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
      await db.execute('CREATE INDEX IF NOT EXISTS idx_non_fuel_expenses_vehicle_date ON non_fuel_expenses(vehicleId, date);');
    }

    if (oldVersion < 11) {
      // 1. Vehicle International Units & Powertrain
      await db.execute("ALTER TABLE vehicles ADD COLUMN distanceUnit TEXT NOT NULL DEFAULT 'km'");
      await db.execute("ALTER TABLE vehicles ADD COLUMN fuelVolumeUnit TEXT NOT NULL DEFAULT 'litre'");
      await db.execute("ALTER TABLE vehicles ADD COLUMN consumptionUnit TEXT NOT NULL DEFAULT 'kmPerLitre'");
      await db.execute("ALTER TABLE vehicles ADD COLUMN baseCurrency TEXT NOT NULL DEFAULT 'BDT'");
      await db.execute("ALTER TABLE vehicles ADD COLUMN powertrainType TEXT NOT NULL DEFAULT 'ice'");
      await db.execute('ALTER TABLE vehicles ADD COLUMN batteryCapacityKwh REAL');

      // 2. EV Charging & Foreign Currency on fuel_records
      await db.execute('ALTER TABLE fuel_records ADD COLUMN energyKwh REAL');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN socStart REAL');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN socEnd REAL');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN chargingPowerKw REAL');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN chargeType TEXT');
      await db.execute('ALTER TABLE fuel_records ADD COLUMN exchangeRateToBase REAL NOT NULL DEFAULT 1.0');

      // 3. Tire Management Tables & Indexes
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tires (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicleId INTEGER NOT NULL,
          brand TEXT NOT NULL,
          model TEXT,
          size TEXT NOT NULL,
          dotCode TEXT,
          installedOdo REAL NOT NULL,
          installedDate TEXT NOT NULL,
          initialTreadDepthMm REAL NOT NULL,
          currentTreadDepthMm REAL NOT NULL,
          isArchived INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS tire_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tireId INTEGER NOT NULL,
          date TEXT NOT NULL,
          odometer REAL NOT NULL,
          position TEXT NOT NULL,
          treadDepthMm REAL NOT NULL,
          notes TEXT,
          FOREIGN KEY (tireId) REFERENCES tires (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_tires_vehicle ON tires(vehicleId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tire_logs_tire_date ON tire_logs(tireId, date);');
    }
  }

  Future<void> _createTables(Database db) async {
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
        exchangeRateToBase REAL NOT NULL DEFAULT 1.0,
        energyKwh REAL,
        socStart REAL,
        socEnd REAL,
        chargingPowerKw REAL,
        chargeType TEXT,
        FOREIGN KEY (fuelTypeId) REFERENCES fuel_types (id),
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id),
        FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
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
        invoiceImagePath TEXT,
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE,
        FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
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
        FOREIGN KEY (taskId) REFERENCES maintenance_tasks (id) ON DELETE CASCADE,
        FOREIGN KEY (locationId) REFERENCES saved_locations (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_records_vehicle_date ON fuel_records(vehicleId, date);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_records_odometer ON fuel_records(odometer);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_service_sessions_vehicle ON service_sessions(vehicleId, serviceDate);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saved_locations_coords ON saved_locations(latitude, longitude);');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS non_fuel_expenses (
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
    await db.execute('CREATE INDEX IF NOT EXISTS idx_non_fuel_expenses_vehicle_date ON non_fuel_expenses(vehicleId, date);');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tires (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicleId INTEGER NOT NULL,
        brand TEXT NOT NULL,
        model TEXT,
        size TEXT NOT NULL,
        dotCode TEXT,
        installedOdo REAL NOT NULL,
        installedDate TEXT NOT NULL,
        initialTreadDepthMm REAL NOT NULL,
        currentTreadDepthMm REAL NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tire_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tireId INTEGER NOT NULL,
        date TEXT NOT NULL,
        odometer REAL NOT NULL,
        position TEXT NOT NULL,
        treadDepthMm REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (tireId) REFERENCES tires (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_tires_vehicle ON tires(vehicleId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tire_logs_tire_date ON tire_logs(tireId, date);');
  }

  static Future<void> _seedDefaultTasksForVehicle(
    DatabaseExecutor db,
    int vehicleId,
    double initialOdo,
    DateTime initialDate,
  ) async {
    final defaultTasks = [
      {
        'vehicleId': vehicleId,
        'taskKey': 'engine_oil',
        'title': 'Engine Oil Change',
        'intervalKm': 3000.0,
        'intervalMonths': 3,
        'lastServiceOdo': initialOdo,
        'lastServiceDate': initialDate.toIso8601String(),
        'reminderBufferKm': 100.0,
        'isEnabled': 0,
      },
      {
        'vehicleId': vehicleId,
        'taskKey': 'oil_filter',
        'title': 'Engine Oil Filter',
        'intervalKm': 6000.0,
        'intervalMonths': 6,
        'lastServiceOdo': initialOdo,
        'lastServiceDate': initialDate.toIso8601String(),
        'reminderBufferKm': 100.0,
        'isEnabled': 0,
      },
      {
        'vehicleId': vehicleId,
        'taskKey': 'air_filter',
        'title': 'Air Filter Clean / Replace',
        'intervalKm': 4000.0,
        'intervalMonths': 6,
        'lastServiceOdo': initialOdo,
        'lastServiceDate': initialDate.toIso8601String(),
        'reminderBufferKm': 100.0,
        'isEnabled': 0,
      },
      {
        'vehicleId': vehicleId,
        'taskKey': 'general_servicing',
        'title': 'General Servicing',
        'intervalKm': 5000.0,
        'intervalMonths': 6,
        'lastServiceOdo': initialOdo,
        'lastServiceDate': initialDate.toIso8601String(),
        'reminderBufferKm': 150.0,
        'isEnabled': 0,
      },
    ];

    for (final task in defaultTasks) {
      await db.insert('maintenance_tasks', task);
    }
  }

  Future<int> insertFuelRecord(FuelRecord record) async {
    Database db = await instance.database;
    return await db.insert('fuel_records', record.toMap());
  }

  Future<List<FuelRecord>> getFuelRecords() async {
    Database db = await instance.database;
    var records = await db.query('fuel_records', orderBy: 'date ASC');
    return records.isNotEmpty
        ? records.map((e) => FuelRecord.fromMap(e)).toList()
        : [];
  }

  Future<int> deleteFuelRecord(int id) async {
    Database db = await instance.database;
    try {
      final records = await db.query(
        'fuel_records',
        columns: ['receiptImagePath', 'odometerImagePath'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (records.isNotEmpty) {
        final r = records.first;
        if (r['receiptImagePath'] != null) {
          await AttachmentService.deleteAttachment(r['receiptImagePath'] as String);
        }
        if (r['odometerImagePath'] != null) {
          await AttachmentService.deleteAttachment(r['odometerImagePath'] as String);
        }
      }
    } catch (_) {}
    return await db.delete('fuel_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateFuelRecord(FuelRecord record) async {
    Database db = await instance.database;
    return await db.update('fuel_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  // FuelType CRUD methods
  Future<int> insertFuelType(FuelType fuelType) async {
    Database db = await instance.database;
    return await db.insert('fuel_types', fuelType.toMap());
  }

  Future<List<FuelType>> getFuelTypes() async {
    Database db = await instance.database;
    var fuelTypes = await db.query('fuel_types');
    return fuelTypes.isNotEmpty
        ? fuelTypes.map((e) => FuelType.fromMap(e)).toList()
        : [];
  }

  Future<int> updateFuelType(FuelType fuelType) async {
    Database db = await instance.database;
    return await db.update('fuel_types', fuelType.toMap(), where: 'id = ?', whereArgs: [fuelType.id]);
  }

  Future<int> deleteFuelType(int id) async {
    Database db = await instance.database;
    return await db.delete('fuel_types', where: 'id = ?', whereArgs: [id]);
  }

  // Vehicle CRUD methods
  Future<int> insertVehicle(Vehicle vehicle) async {
    Database db = await instance.database;
    final id = await db.insert('vehicles', vehicle.toMap());
    await _seedDefaultTasksForVehicle(db, id, 0.0, DateTime.now());
    return id;
  }

  Future<List<Vehicle>> getVehicles() async {
    Database db = await instance.database;
    var vehicles = await db.query('vehicles');
    return vehicles.isNotEmpty
        ? vehicles.map((e) => Vehicle.fromMap(e)).toList()
        : [];
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    Database db = await instance.database;
    return await db.update('vehicles', vehicle.toMap(), where: 'id = ?', whereArgs: [vehicle.id]);
  }

  Future<int> deleteVehicle(int id) async {
    Database db = await instance.database;
    return await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getFuelRecordCountForVehicle(int vehicleId) async {
    Database db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM fuel_records WHERE vehicleId = ?',
      [vehicleId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteVehicleCascade(int vehicleId) async {
    Database db = await instance.database;
    final List<String> pathsToDelete = [];

    final existingTables = <String>{};
    try {
      final res = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      for (final row in res) {
        if (row['name'] != null) {
          existingTables.add(row['name'] as String);
        }
      }
    } catch (_) {}

    if (existingTables.contains('fuel_records')) {
      try {
        final fuelRecords = await db.query(
          'fuel_records',
          columns: ['receiptImagePath', 'odometerImagePath'],
          where: 'vehicleId = ?',
          whereArgs: [vehicleId],
        );
        for (final row in fuelRecords) {
          if (row['receiptImagePath'] != null) {
            pathsToDelete.add(row['receiptImagePath'] as String);
          }
          if (row['odometerImagePath'] != null) {
            pathsToDelete.add(row['odometerImagePath'] as String);
          }
        }
      } catch (_) {}
    }

    if (existingTables.contains('service_sessions')) {
      try {
        final serviceSessions = await db.query(
          'service_sessions',
          columns: ['invoiceImagePath'],
          where: 'vehicleId = ?',
          whereArgs: [vehicleId],
        );
        for (final row in serviceSessions) {
          if (row['invoiceImagePath'] != null) {
            pathsToDelete.add(row['invoiceImagePath'] as String);
          }
        }
      } catch (_) {}
    }

    if (existingTables.contains('non_fuel_expenses')) {
      try {
        final expenses = await db.query(
          'non_fuel_expenses',
          columns: ['receiptImagePath'],
          where: 'vehicleId = ?',
          whereArgs: [vehicleId],
        );
        for (final row in expenses) {
          if (row['receiptImagePath'] != null) {
            pathsToDelete.add(row['receiptImagePath'] as String);
          }
        }
      } catch (_) {}
    }

    await db.transaction((txn) async {
      if (existingTables.contains('service_sessions')) {
        await txn.delete('service_sessions', where: 'vehicleId = ?', whereArgs: [vehicleId]);
      }
      if (existingTables.contains('non_fuel_expenses')) {
        await txn.delete('non_fuel_expenses', where: 'vehicleId = ?', whereArgs: [vehicleId]);
      }
      if (existingTables.contains('tires')) {
        await txn.delete('tires', where: 'vehicleId = ?', whereArgs: [vehicleId]);
      }
      if (existingTables.contains('maintenance_tasks')) {
        await txn.delete('maintenance_tasks', where: 'vehicleId = ?', whereArgs: [vehicleId]);
      }
      await txn.delete('fuel_records', where: 'vehicleId = ?', whereArgs: [vehicleId]);
      await txn.delete('vehicles', where: 'id = ?', whereArgs: [vehicleId]);
    });

    for (final path in pathsToDelete) {
      await AttachmentService.deleteAttachment(path);
    }
  }

  // Maintenance Tasks CRUD methods
  Future<List<MaintenanceTask>> getMaintenanceTasks(int vehicleId) async {
    Database db = await instance.database;
    final results = await db.query(
      'maintenance_tasks',
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'id ASC',
    );
    return results.map((m) => MaintenanceTask.fromMap(m)).toList();
  }

  Future<int> insertMaintenanceTask(MaintenanceTask task) async {
    Database db = await instance.database;
    return await db.insert('maintenance_tasks', task.toMap());
  }

  Future<int> updateMaintenanceTask(MaintenanceTask task) async {
    Database db = await instance.database;
    return await db.update(
      'maintenance_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteMaintenanceTask(int id) async {
    Database db = await instance.database;
    return await db.delete(
      'maintenance_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> quickResetMaintenanceTask(int taskId, double odo, DateTime date) async {
    Database db = await instance.database;
    return await db.update(
      'maintenance_tasks',
      {
        'lastServiceOdo': odo,
        'lastServiceDate': date.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // Service Sessions CRUD methods
  Future<List<ServiceSession>> getServiceSessions(int vehicleId) async {
    Database db = await instance.database;
    final sessionRows = await db.query(
      'service_sessions',
      where: 'vehicleId = ?',
      whereArgs: [vehicleId],
      orderBy: 'odometer DESC, serviceDate DESC',
    );

    final List<ServiceSession> sessions = [];
    for (final sRow in sessionRows) {
      final sessionId = sRow['id'] as int;
      final itemRows = await db.rawQuery('''
        SELECT ssi.*, mt.title as taskTitle
        FROM service_session_items ssi
        LEFT JOIN maintenance_tasks mt ON ssi.taskId = mt.id
        WHERE ssi.sessionId = ?
      ''', [sessionId]);

      final items = itemRows.map((i) => ServiceSessionItem.fromMap(i)).toList();
      sessions.add(ServiceSession.fromMap(sRow, items: items));
    }
    return sessions;
  }

  Future<int> insertServiceSession(ServiceSession session) async {
    Database db = await instance.database;
    return await db.transaction((txn) async {
      final sessionId = await txn.insert('service_sessions', session.toMap());
      for (final item in session.items) {
        final itemMap = Map<String, dynamic>.from(item.toMap());
        itemMap['sessionId'] = sessionId;
        await txn.insert('service_session_items', itemMap);

        // Atomically update last service odo & date for each completed task
        await txn.update(
          'maintenance_tasks',
          {
            'lastServiceOdo': session.odometer,
            'lastServiceDate': session.serviceDate.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.taskId],
        );
      }
      return sessionId;
    });
  }

  Future<int> updateServiceSession(ServiceSession session) async {
    Database db = await instance.database;
    return await db.transaction((txn) async {
      final sessionId = session.id!;
      await txn.update(
        'service_sessions',
        session.toMap(),
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      await txn.delete(
        'service_session_items',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
      );

      for (final item in session.items) {
        final itemMap = Map<String, dynamic>.from(item.toMap());
        itemMap['sessionId'] = sessionId;
        await txn.insert('service_session_items', itemMap);

        await txn.update(
          'maintenance_tasks',
          {
            'lastServiceOdo': session.odometer,
            'lastServiceDate': session.serviceDate.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.taskId],
        );
      }
      return sessionId;
    });
  }

  Future<int> deleteServiceSession(int sessionId) async {
    Database db = await instance.database;
    try {
      final sessions = await db.query(
        'service_sessions',
        columns: ['invoiceImagePath'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isNotEmpty && sessions.first['invoiceImagePath'] != null) {
        await AttachmentService.deleteAttachment(sessions.first['invoiceImagePath'] as String);
      }
    } catch (_) {}
    return await db.transaction((txn) async {
      await txn.delete(
        'service_session_items',
        where: 'sessionId = ?',
        whereArgs: [sessionId],
      );
      return await txn.delete(
        'service_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<bool> hasAnyEnabledRoutine() async {
    Database db = await instance.database;
    final vehicleCheck = await db.rawQuery('''
      SELECT COUNT(*) as count FROM vehicles 
      WHERE volumeReminderEnabled = 1 OR distanceReminderEnabled = 1
    ''');
    final vCount = Sqflite.firstIntValue(vehicleCheck) ?? 0;
    if (vCount > 0) return true;

    final taskCheck = await db.rawQuery('''
      SELECT COUNT(*) as count FROM maintenance_tasks
      WHERE isEnabled = 1
    ''');
    final tCount = Sqflite.firstIntValue(taskCheck) ?? 0;
    return tCount > 0;
  }

  Future<double?> getEstimatedServiceCost(int vehicleId) async {
    Database db = await instance.database;
    final results = await db.rawQuery('''
      SELECT totalCost FROM service_sessions 
      WHERE vehicleId = ? AND totalCost IS NOT NULL AND totalCost > 0
      ORDER BY odometer DESC, serviceDate DESC
      LIMIT 1
    ''', [vehicleId]);
    if (results.isNotEmpty) {
      final val = results.first['totalCost'];
      if (val is num) return val.toDouble();
    }
    return null;
  }

  // SavedLocation CRUD methods
  Future<int> insertSavedLocation(SavedLocation location) async {
    Database db = await instance.database;
    return await db.insert('saved_locations', location.toMap());
  }

  Future<int> updateSavedLocation(SavedLocation location) async {
    Database db = await instance.database;
    return await db.update(
      'saved_locations',
      location.toMap(),
      where: 'id = ?',
      whereArgs: [location.id],
    );
  }

  Future<int> deleteSavedLocation(int id) async {
    Database db = await instance.database;
    return await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE fuel_records SET locationId = NULL WHERE locationId = ?', [id]);
      await txn.rawUpdate('UPDATE service_sessions SET locationId = NULL WHERE locationId = ?', [id]);
      await txn.rawUpdate('UPDATE service_session_items SET locationId = NULL WHERE locationId = ?', [id]);
      return await txn.delete('saved_locations', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<SavedLocation>> getSavedLocations({
    String? type,
    bool? onlyNamed,
    bool? onlySuspect,
    bool? onlyRecommended,
  }) async {
    Database db = await instance.database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (type != null && type.isNotEmpty && type != 'all') {
      whereClauses.add('(type = ? OR type = ?)');
      whereArgs.add(type);
      whereArgs.add('both');
    }

    if (onlyNamed == true) {
      whereClauses.add('isNamed = 1');
    }

    if (onlySuspect == true) {
      whereClauses.add('(isSuspectFuel = 1 OR isSuspectServiceOrParts = 1)');
    }

    if (onlyRecommended == true) {
      whereClauses.add('(isRecommendedFuel = 1 OR isRecommendedServiceOrParts = 1)');
    }

    String? where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final results = await db.query(
      'saved_locations',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'isNamed DESC, name ASC',
    );

    return results.map((e) => SavedLocation.fromMap(e)).toList();
  }

  Future<SavedLocation?> getSavedLocationById(int id) async {
    Database db = await instance.database;
    final results = await db.query(
      'saved_locations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return SavedLocation.fromMap(results.first);
    }
    return null;
  }

  Future<int> markLocationSuspect(
    int id, {
    String? reason,
    bool forFuel = false,
    bool forService = false,
  }) async {
    Database db = await instance.database;
    Map<String, dynamic> updates = {};
    if (forFuel) updates['isSuspectFuel'] = 1;
    if (forService) updates['isSuspectServiceOrParts'] = 1;
    if (reason != null && reason.isNotEmpty) updates['suspectReason'] = reason;
    return await db.update(
      'saved_locations',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markLocationRecommended(
    int id, {
    String? reason,
    bool forFuel = false,
    bool forService = false,
  }) async {
    Database db = await instance.database;
    Map<String, dynamic> updates = {};
    if (forFuel) updates['isRecommendedFuel'] = 1;
    if (forService) updates['isRecommendedServiceOrParts'] = 1;
    if (reason != null && reason.isNotEmpty) updates['performanceReason'] = reason;
    return await db.update(
      'saved_locations',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearLocationSuspectFlag(int id) async {
    Database db = await instance.database;
    return await db.update(
      'saved_locations',
      {
        'isSuspectFuel': 0,
        'isSuspectServiceOrParts': 0,
        'suspectReason': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearLocationRecommendedFlag(int id) async {
    Database db = await instance.database;
    return await db.update(
      'saved_locations',
      {
        'isRecommendedFuel': 0,
        'isRecommendedServiceOrParts': 0,
        'performanceReason': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // NonFuelExpense CRUD methods
  Future<int> insertNonFuelExpense(NonFuelExpense expense) async {
    Database db = await instance.database;
    return await db.insert('non_fuel_expenses', expense.toMap());
  }

  Future<List<NonFuelExpense>> getNonFuelExpenses({int? vehicleId}) async {
    Database db = await instance.database;
    final results = await db.query(
      'non_fuel_expenses',
      where: vehicleId != null ? 'vehicleId = ?' : null,
      whereArgs: vehicleId != null ? [vehicleId] : null,
      orderBy: 'date DESC, id DESC',
    );
    return results.map((e) => NonFuelExpense.fromMap(e)).toList();
  }

  Future<int> updateNonFuelExpense(NonFuelExpense expense) async {
    Database db = await instance.database;
    return await db.update(
      'non_fuel_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteNonFuelExpense(int id) async {
    Database db = await instance.database;
    try {
      final expenses = await db.query(
        'non_fuel_expenses',
        columns: ['receiptImagePath'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (expenses.isNotEmpty && expenses.first['receiptImagePath'] != null) {
        await AttachmentService.deleteAttachment(expenses.first['receiptImagePath'] as String);
      }
    } catch (_) {}
    return await db.delete(
      'non_fuel_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalNonFuelExpenses({int? vehicleId}) async {
    Database db = await instance.database;
    final results = await db.rawQuery(
      'SELECT SUM(amount) as total FROM non_fuel_expenses${vehicleId != null ? ' WHERE vehicleId = ?' : ''}',
      vehicleId != null ? [vehicleId] : [],
    );
    if (results.isNotEmpty && results.first['total'] != null) {
      return (results.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Tire CRUD methods
  Future<int> insertTire(Tire tire) async {
    Database db = await instance.database;
    return await db.insert('tires', tire.toMap());
  }

  Future<List<Tire>> getTiresForVehicle(int vehicleId, {bool includeArchived = false}) async {
    Database db = await instance.database;
    final where = includeArchived ? 'vehicleId = ?' : 'vehicleId = ? AND isArchived = 0';
    final results = await db.query(
      'tires',
      where: where,
      whereArgs: [vehicleId],
      orderBy: 'id ASC',
    );
    return results.map((e) => Tire.fromMap(e)).toList();
  }

  Future<Tire?> getTireById(int id) async {
    Database db = await instance.database;
    final results = await db.query('tires', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Tire.fromMap(results.first);
  }

  Future<int> updateTire(Tire tire) async {
    Database db = await instance.database;
    return await db.update('tires', tire.toMap(), where: 'id = ?', whereArgs: [tire.id]);
  }

  Future<int> deleteTire(int id) async {
    Database db = await instance.database;
    return await db.delete('tires', where: 'id = ?', whereArgs: [id]);
  }

  // TireLog CRUD methods
  Future<int> insertTireLog(TireLog log) async {
    Database db = await instance.database;
    final id = await db.insert('tire_logs', log.toMap());
    await db.update(
      'tires',
      {'currentTreadDepthMm': log.treadDepthMm},
      where: 'id = ?',
      whereArgs: [log.tireId],
    );
    return id;
  }

  Future<List<TireLog>> getTireLogsForTire(int tireId) async {
    Database db = await instance.database;
    final results = await db.query(
      'tire_logs',
      where: 'tireId = ?',
      whereArgs: [tireId],
      orderBy: 'date DESC, odometer DESC, id DESC',
    );
    return results.map((e) => TireLog.fromMap(e)).toList();
  }

  Future<List<TireLog>> getLatestTireLogsForVehicle(int vehicleId) async {
    Database db = await instance.database;
    final results = await db.rawQuery('''
      SELECT tl.* FROM tire_logs tl
      INNER JOIN tires t ON tl.tireId = t.id
      WHERE t.vehicleId = ?
      ORDER BY tl.date DESC, tl.odometer DESC, tl.id DESC
    ''', [vehicleId]);
    return results.map((e) => TireLog.fromMap(e)).toList();
  }

  Future<int> deleteTireLog(int id) async {
    Database db = await instance.database;
    return await db.delete('tire_logs', where: 'id = ?', whereArgs: [id]);
  }

  /// Atomically clears all database tables, respecting foreign keys.
  Future<void> clearAllData() async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('tire_logs');
      await txn.delete('tires');
      await txn.delete('non_fuel_expenses');
      await txn.delete('service_session_items');
      await txn.delete('service_sessions');
      await txn.delete('fuel_records');
      await txn.delete('maintenance_tasks');
      await txn.delete('vehicles');
      await txn.delete('saved_locations');
      await txn.delete('fuel_types');
    });
  }

  /// Exports raw database tables as a Map for backup bundling.
  Future<Map<String, dynamic>> dumpAllData() async {
    Database db = await instance.database;
    final fuelTypes = await db.query('fuel_types');
    final savedLocations = await db.query('saved_locations');
    final vehicles = await db.query('vehicles');
    final maintenanceTasks = await db.query('maintenance_tasks');
    final fuelRecords = await db.query('fuel_records');
    final serviceSessions = await db.query('service_sessions');
    final serviceSessionItems = await db.query('service_session_items');
    final nonFuelExpenses = await db.query('non_fuel_expenses');
    final tires = await db.query('tires');
    final tireLogs = await db.query('tire_logs');

    return {
      'schemaVersion': 11,
      'fuel_types': fuelTypes,
      'saved_locations': savedLocations,
      'vehicles': vehicles,
      'maintenance_tasks': maintenanceTasks,
      'fuel_records': fuelRecords,
      'service_sessions': serviceSessions,
      'service_session_items': serviceSessionItems,
      'non_fuel_expenses': nonFuelExpenses,
      'tires': tires,
      'tire_logs': tireLogs,
    };
  }

  /// Restores raw database tables atomically.
  Future<void> restoreAllData(Map<String, dynamic> data, {bool replaceExisting = false}) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      if (replaceExisting) {
        await txn.delete('tire_logs');
        await txn.delete('tires');
        await txn.delete('non_fuel_expenses');
        await txn.delete('service_session_items');
        await txn.delete('service_sessions');
        await txn.delete('fuel_records');
        await txn.delete('maintenance_tasks');
        await txn.delete('vehicles');
        await txn.delete('saved_locations');
        await txn.delete('fuel_types');
      }

      final fuelTypes = (data['fuel_types'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final savedLocations = (data['saved_locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final vehicles = (data['vehicles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final maintenanceTasks = (data['maintenance_tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final fuelRecords = (data['fuel_records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final serviceSessions = (data['service_sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final serviceSessionItems = (data['service_session_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final nonFuelExpenses = (data['non_fuel_expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final tires = (data['tires'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final tireLogs = (data['tire_logs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final row in fuelTypes) {
        await txn.insert('fuel_types', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in savedLocations) {
        await txn.insert('saved_locations', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in vehicles) {
        await txn.insert('vehicles', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in maintenanceTasks) {
        await txn.insert('maintenance_tasks', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in fuelRecords) {
        await txn.insert('fuel_records', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in serviceSessions) {
        await txn.insert('service_sessions', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in serviceSessionItems) {
        await txn.insert('service_session_items', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in nonFuelExpenses) {
        await txn.insert('non_fuel_expenses', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in tires) {
        await txn.insert('tires', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final row in tireLogs) {
        await txn.insert('tire_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
