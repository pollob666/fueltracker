// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

enum FuelCategory {
  gasoline,
  diesel,
  gas,
}

enum FuelUnit {
  litre,
  gallon,
  cubicMeter,
  gge, // Gasoline Gallon Equivalent
}

class FuelType {
  int? id;
  String name;
  FuelCategory category;
  FuelUnit unit;

  FuelType({
    this.id,
    required this.name,
    required this.category,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'name': name,
      'category': category.toString(),
      'unit': unit.toString(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory FuelType.fromMap(Map<String, dynamic> map) {
    return FuelType(
      id: map['id'],
      name: map['name'],
      category: FuelCategory.values.firstWhere((e) => e.toString() == map['category']),
      unit: FuelUnit.values.firstWhere((e) => e.toString() == map['unit']),
    );
  }
}
