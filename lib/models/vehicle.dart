// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/utils/unit_converter.dart';

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

  // Tier 3: International Units, Currency & Alternative Powertrains
  DistanceUnit distanceUnit;
  FuelVolumeUnit fuelVolumeUnit;
  ConsumptionUnit consumptionUnit;
  String baseCurrency;
  PowertrainType powertrainType;
  double? batteryCapacityKwh;

  bool get isDualFuel => secondaryFuelTypeId != null;
  bool get isElectric => powertrainType == PowertrainType.bev;
  bool get hasElectricMotor => powertrainType == PowertrainType.bev ||
                              powertrainType == PowertrainType.phev ||
                              powertrainType == PowertrainType.hybrid;
  bool get isTwoWheeler =>
      type == VehicleType.motorcycle || type == VehicleType.scooterOrMoped;
  bool get supportsTireTracking => !isTwoWheeler;

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
    this.distanceUnit = DistanceUnit.km,
    this.fuelVolumeUnit = FuelVolumeUnit.litre,
    this.consumptionUnit = ConsumptionUnit.kmPerLitre,
    this.baseCurrency = 'BDT',
    this.powertrainType = PowertrainType.ice,
    this.batteryCapacityKwh,
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
      'distanceUnit': distanceUnit.name,
      'fuelVolumeUnit': fuelVolumeUnit.name,
      'consumptionUnit': consumptionUnit.name,
      'baseCurrency': baseCurrency,
      'powertrainType': powertrainType.name,
      'batteryCapacityKwh': batteryCapacityKwh,
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
      distanceUnit: DistanceUnit.fromString(map['distanceUnit'] as String?),
      fuelVolumeUnit: FuelVolumeUnit.fromString(map['fuelVolumeUnit'] as String?),
      consumptionUnit: ConsumptionUnit.fromString(map['consumptionUnit'] as String?),
      baseCurrency: (map['baseCurrency'] as String?) ?? 'BDT',
      powertrainType: PowertrainType.fromString(map['powertrainType'] as String?),
      batteryCapacityKwh: (map['batteryCapacityKwh'] as num?)?.toDouble(),
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
    DistanceUnit? distanceUnit,
    FuelVolumeUnit? fuelVolumeUnit,
    ConsumptionUnit? consumptionUnit,
    String? baseCurrency,
    PowertrainType? powertrainType,
    double? batteryCapacityKwh,
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
      distanceUnit: distanceUnit ?? this.distanceUnit,
      fuelVolumeUnit: fuelVolumeUnit ?? this.fuelVolumeUnit,
      consumptionUnit: consumptionUnit ?? this.consumptionUnit,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      powertrainType: powertrainType ?? this.powertrainType,
      batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
    );
  }
}
