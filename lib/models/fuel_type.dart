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
      category: FuelCategory.values.firstWhere(
        (e) => e.name == map['category'] || e.toString() == map['category'],
        orElse: () => FuelCategory.gasoline,
      ),
      unit: FuelUnit.values.firstWhere(
        (e) => e.name == map['unit'] || e.toString() == map['unit'],
        orElse: () => FuelUnit.litre,
      ),
    );
  }

  FuelType copyWith({
    int? id,
    String? name,
    FuelCategory? category,
    FuelUnit? unit,
  }) {
    return FuelType(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
    );
  }
}
