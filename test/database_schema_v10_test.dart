// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('DatabaseHelper upgrades from v9 to v10 and creates non_fuel_expenses', () async {
    const testDbPath = 'test_v10_migration.db';
    if (await databaseFactory.databaseExists(testDbPath)) {
      await databaseFactory.deleteDatabase(testDbPath);
    }

    // Open at version 9 baseline
    Database db = await databaseFactory.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 9,
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
              odometer REAL NOT NULL,
              date TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    await db.close();

    // Reopen with v10 migration
    db = await databaseFactory.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 10,
        onUpgrade: (db, oldVersion, newVersion) async {
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
        },
      ),
    );

    // Verify non_fuel_expenses table exists and has proper columns
    final cols = await db.rawQuery('PRAGMA table_info(non_fuel_expenses)');
    final colNames = cols.map((c) => c['name'] as String).toList();
    expect(colNames, contains('id'));
    expect(colNames, contains('vehicleId'));
    expect(colNames, contains('date'));
    expect(colNames, contains('odometer'));
    expect(colNames, contains('category'));
    expect(colNames, contains('amount'));
    expect(colNames, contains('currencyCode'));
    expect(colNames, contains('notes'));
    expect(colNames, contains('receiptImagePath'));

    // Verify index exists
    final indexes = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'");
    final indexNames = indexes.map((i) => i['name'] as String).toList();
    expect(indexNames, contains('idx_non_fuel_expenses_vehicle_date'));

    // Test insert and query
    final expense = NonFuelExpense(
      vehicleId: 1,
      date: DateTime.now(),
      category: ExpenseCategory.toll,
      amount: 300.0,
      notes: 'Padma Bridge Toll',
    );

    final id = await db.insert('non_fuel_expenses', expense.toMap());
    expect(id, greaterThan(0));

    final queried = await db.query('non_fuel_expenses', where: 'id = ?', whereArgs: [id]);
    expect(queried.length, 1);
    expect(queried.first['category'], 'toll');
    expect(queried.first['amount'], 300.0);

    await db.close();
    if (await databaseFactory.databaseExists(testDbPath)) {
      await databaseFactory.deleteDatabase(testDbPath);
    }
  });
}
