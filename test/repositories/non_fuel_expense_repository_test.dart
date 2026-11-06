// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/repositories/non_fuel_expense_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('SqliteNonFuelExpenseRepository CRUD and stream notifications', () async {
    const testDb = 'test_expense_repo.db';
    if (await databaseFactory.databaseExists(testDb)) {
      await databaseFactory.deleteDatabase(testDb);
    }

    final db = await databaseFactory.openDatabase(
      testDb,
      options: OpenDatabaseOptions(
        version: 10,
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

    DatabaseHelper.setDatabaseForTesting(db);
    final repo = SqliteNonFuelExpenseRepository();

    // 1. Initial empty query
    final initial = await repo.getNonFuelExpenses(vehicleId: 1);
    expect(initial, isEmpty);

    // 2. Insert expense
    final expense = NonFuelExpense(
      vehicleId: 1,
      date: DateTime.now(),
      category: ExpenseCategory.toll,
      amount: 450.0,
      notes: 'Expressway Toll',
    );
    final id = await repo.insertNonFuelExpense(expense);
    expect(id, greaterThan(0));

    // 3. Query after insert
    final list = await repo.getNonFuelExpenses(vehicleId: 1);
    expect(list.length, 1);
    expect(list.first.category, ExpenseCategory.toll);
    expect(list.first.amount, 450.0);

    // 4. Update expense
    final updated = list.first.copyWith(
      amount: 500.0,
      category: ExpenseCategory.parking,
    );
    await repo.updateNonFuelExpense(updated);
    final afterUpdate = await repo.getNonFuelExpenses(vehicleId: 1);
    expect(afterUpdate.first.amount, 500.0);
    expect(afterUpdate.first.category, ExpenseCategory.parking);

    // 5. Total expense calculation
    final total = await repo.getTotalNonFuelExpenses(vehicleId: 1);
    expect(total, 500.0);

    // 6. Delete expense
    await repo.deleteNonFuelExpense(id, vehicleId: 1);
    final afterDelete = await repo.getNonFuelExpenses(vehicleId: 1);
    expect(afterDelete, isEmpty);

    repo.dispose();
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
    if (await databaseFactory.databaseExists(testDb)) {
      await databaseFactory.deleteDatabase(testDb);
    }
  });
}
