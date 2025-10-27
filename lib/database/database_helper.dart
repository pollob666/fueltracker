// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "fuel_tracker.db");
    return await openDatabase(path, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // For simplicity, we're dropping and recreating tables.
      // In a real-world app, you'd migrate data.
      await db.execute('DROP TABLE IF EXISTS fuel_records');
      await db.execute('DROP TABLE IF EXISTS fuel_types');
      await db.execute('DROP TABLE IF EXISTS vehicles');
      await _createTables(db);
    }
  }

  Future<void> _createTables(Database db) async {
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
        FOREIGN KEY (vehicleId) REFERENCES vehicles (id)
      )
    ''');
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
    return await db.delete('fuel_records', where: 'id = ?', whereArgs: [id]);
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
    return await db.insert('vehicles', vehicle.toMap());
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
}
