// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';

abstract class NonFuelExpenseRepository {
  Future<List<NonFuelExpense>> getNonFuelExpenses({int? vehicleId});
  Stream<List<NonFuelExpense>> watchNonFuelExpenses(int vehicleId);
  Future<int> insertNonFuelExpense(NonFuelExpense expense);
  Future<int> updateNonFuelExpense(NonFuelExpense expense);
  Future<int> deleteNonFuelExpense(int id, {int? vehicleId});
  Future<double> getTotalNonFuelExpenses({int? vehicleId});
  void notifyChanged([int? vehicleId]);
  void dispose();
}

class SqliteNonFuelExpenseRepository implements NonFuelExpenseRepository {
  final DatabaseHelper _dbHelper;
  final _changeStreamController = StreamController<int?>.broadcast();

  SqliteNonFuelExpenseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<NonFuelExpense>> getNonFuelExpenses({int? vehicleId}) async {
    return await _dbHelper.getNonFuelExpenses(vehicleId: vehicleId);
  }

  @override
  Stream<List<NonFuelExpense>> watchNonFuelExpenses(int vehicleId) {
    late StreamController<List<NonFuelExpense>> controller;
    StreamSubscription<int?>? sub;

    controller = StreamController<List<NonFuelExpense>>.broadcast(
      onListen: () async {
        controller.add(await getNonFuelExpenses(vehicleId: vehicleId));
        sub = _changeStreamController.stream.listen((changedVehicleId) async {
          if (changedVehicleId == null || changedVehicleId == vehicleId) {
            if (!controller.isClosed) {
              controller.add(await getNonFuelExpenses(vehicleId: vehicleId));
            }
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<int> insertNonFuelExpense(NonFuelExpense expense) async {
    final id = await _dbHelper.insertNonFuelExpense(expense);
    notifyChanged(expense.vehicleId);
    return id;
  }

  @override
  Future<int> updateNonFuelExpense(NonFuelExpense expense) async {
    final count = await _dbHelper.updateNonFuelExpense(expense);
    notifyChanged(expense.vehicleId);
    return count;
  }

  @override
  Future<int> deleteNonFuelExpense(int id, {int? vehicleId}) async {
    final count = await _dbHelper.deleteNonFuelExpense(id);
    notifyChanged(vehicleId);
    return count;
  }

  @override
  Future<double> getTotalNonFuelExpenses({int? vehicleId}) async {
    return await _dbHelper.getTotalNonFuelExpenses(vehicleId: vehicleId);
  }

  @override
  void notifyChanged([int? vehicleId]) {
    if (!_changeStreamController.isClosed) {
      _changeStreamController.add(vehicleId);
    }
  }

  @override
  void dispose() {
    _changeStreamController.close();
  }
}
