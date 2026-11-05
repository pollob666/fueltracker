// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>


enum VehicleType {
  carOrSedan,
  motorcycle,
  scooterOrMoped,
  suv,
  pickupOrTruck,
}

enum TripMeterMode {
  none,
  single,
  dual,
}

class Vehicle {
  int? id;
  String name;
  VehicleType type;
  int primaryFuelTypeId;
  double? primaryFuelCapacity;
  int? secondaryFuelTypeId;
  double? secondaryFuelCapacity;
  TripMeterMode tripMeterMode;

  bool get isDualFuel => secondaryFuelTypeId != null;

  Vehicle({
    this.id,
    required this.name,
    required this.type,
    required this.primaryFuelTypeId,
    this.primaryFuelCapacity,
    this.secondaryFuelTypeId,
    this.secondaryFuelCapacity,
    this.tripMeterMode = TripMeterMode.none,
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
      'tripMeterMode': tripMeterMode.name,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    TripMeterMode mode = TripMeterMode.none;
    if (map['tripMeterMode'] != null) {
      mode = TripMeterMode.values.firstWhere(
        (e) => e.name == map['tripMeterMode'] || e.toString() == map['tripMeterMode'],
        orElse: () => TripMeterMode.none,
      );
    }

    return Vehicle(
      id: map['id'],
      name: map['name'],
      type: VehicleType.values.firstWhere((e) => e.toString() == map['type']),
      primaryFuelTypeId: map['primaryFuelTypeId'],
      primaryFuelCapacity: map['primaryFuelCapacity'],
      secondaryFuelTypeId: map['secondaryFuelTypeId'],
      secondaryFuelCapacity: map['secondaryFuelCapacity'],
      tripMeterMode: mode,
    );
  }
}
