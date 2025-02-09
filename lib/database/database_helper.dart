import 'dart:io';
import 'package:fuel_tracker/models/fuel_record.dart';
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
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fuel_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        odometer REAL NOT NULL,
        fuelType TEXT NOT NULL,
        rate REAL NOT NULL,
        volume REAL NOT NULL,
        paidAmount REAL NOT NULL
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
}
