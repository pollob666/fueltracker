// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_type.dart';

class FuelTypeService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<FuelType>> getFuelTypes() async {
    final fuelTypes = await _dbHelper.getFuelTypes();
    if (fuelTypes.isEmpty) {
      await _addDefaultFuelTypes();
      return _dbHelper.getFuelTypes();
    }
    return fuelTypes;
  }

  Future<void> _addDefaultFuelTypes() async {
    final defaults = [
      FuelType(name: 'Octane', category: FuelCategory.gasoline, unit: FuelUnit.litre),
      FuelType(name: 'Petrol', category: FuelCategory.gasoline, unit: FuelUnit.litre),
      FuelType(name: 'Diesel', category: FuelCategory.diesel, unit: FuelUnit.litre),
      FuelType(name: 'CNG', category: FuelCategory.gas, unit: FuelUnit.cubicMeter),
      FuelType(name: 'LPG', category: FuelCategory.gas, unit: FuelUnit.litre),
    ];

    for (var ft in defaults) {
      await _dbHelper.insertFuelType(ft);
    }
  }

  Future<FuelType?> getFuelTypeById(int id) async {
    final allTypes = await getFuelTypes();
    return allTypes.firstWhere((type) => type.id == id);
  }
}
