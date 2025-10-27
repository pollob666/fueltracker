// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>


enum VehicleType {
  carOrSedan,
  motorcycle,
  scooterOrMoped,
  suv,
  pickupOrTruck,
}

class Vehicle {
  int? id;
  String name;
  VehicleType type;
  int primaryFuelTypeId;
  double? primaryFuelCapacity;
  int? secondaryFuelTypeId;
  double? secondaryFuelCapacity;

  Vehicle({
    this.id,
    required this.name,
    required this.type,
    required this.primaryFuelTypeId,
    this.primaryFuelCapacity,
    this.secondaryFuelTypeId,
    this.secondaryFuelCapacity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'primaryFuelTypeId': primaryFuelTypeId,
      'primaryFuelCapacity': primaryFuelCapacity,
      'secondaryFuelTypeId': secondaryFuelTypeId,
      'secondaryFuelCapacity': secondaryFuelCapacity,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      name: map['name'],
      type: VehicleType.values.firstWhere((e) => e.toString() == map['type']),
      primaryFuelTypeId: map['primaryFuelTypeId'],
      primaryFuelCapacity: map['primaryFuelCapacity'],
      secondaryFuelTypeId: map['secondaryFuelTypeId'],
      secondaryFuelCapacity: map['secondaryFuelCapacity'],
    );
  }
}
