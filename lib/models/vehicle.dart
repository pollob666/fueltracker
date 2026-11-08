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
  bool volumeReminderEnabled;
  double volumeReminderValue;
  bool distanceReminderEnabled;
  double distanceReminderValue;

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
    this.volumeReminderEnabled = false,
    this.volumeReminderValue = 3.0,
    this.distanceReminderEnabled = false,
    this.distanceReminderValue = 50.0,
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
      'volumeReminderEnabled': volumeReminderEnabled ? 1 : 0,
      'volumeReminderValue': volumeReminderValue,
      'distanceReminderEnabled': distanceReminderEnabled ? 1 : 0,
      'distanceReminderValue': distanceReminderValue,
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
      type: VehicleType.values.firstWhere(
        (e) => e.name == map['type'] || e.toString() == map['type'],
        orElse: () => VehicleType.carOrSedan,
      ),
      primaryFuelTypeId: map['primaryFuelTypeId'],
      primaryFuelCapacity: map['primaryFuelCapacity'],
      secondaryFuelTypeId: map['secondaryFuelTypeId'],
      secondaryFuelCapacity: map['secondaryFuelCapacity'],
      tripMeterMode: mode,
      volumeReminderEnabled: map['volumeReminderEnabled'] == 1 || map['volumeReminderEnabled'] == true,
      volumeReminderValue: (map['volumeReminderValue'] as num?)?.toDouble() ?? 3.0,
      distanceReminderEnabled: map['distanceReminderEnabled'] == 1 || map['distanceReminderEnabled'] == true,
      distanceReminderValue: (map['distanceReminderValue'] as num?)?.toDouble() ?? 50.0,
    );
  }

  Vehicle copyWith({
    int? id,
    String? name,
    VehicleType? type,
    int? primaryFuelTypeId,
    double? primaryFuelCapacity,
    int? secondaryFuelTypeId,
    double? secondaryFuelCapacity,
    TripMeterMode? tripMeterMode,
    bool? volumeReminderEnabled,
    double? volumeReminderValue,
    bool? distanceReminderEnabled,
    double? distanceReminderValue,
  }) {
    return Vehicle(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      primaryFuelTypeId: primaryFuelTypeId ?? this.primaryFuelTypeId,
      primaryFuelCapacity: primaryFuelCapacity ?? this.primaryFuelCapacity,
      secondaryFuelTypeId: secondaryFuelTypeId ?? this.secondaryFuelTypeId,
      secondaryFuelCapacity: secondaryFuelCapacity ?? this.secondaryFuelCapacity,
      tripMeterMode: tripMeterMode ?? this.tripMeterMode,
      volumeReminderEnabled: volumeReminderEnabled ?? this.volumeReminderEnabled,
      volumeReminderValue: volumeReminderValue ?? this.volumeReminderValue,
      distanceReminderEnabled: distanceReminderEnabled ?? this.distanceReminderEnabled,
      distanceReminderValue: distanceReminderValue ?? this.distanceReminderValue,
    );
  }
}
