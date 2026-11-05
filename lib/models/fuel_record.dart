// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

enum DrivingCondition {
  mixed,
  city,
  highway,
}

class FuelRecord {
  int? id;
  DateTime date;
  double odometer;
  int fuelTypeId;
  int vehicleId;
  double rate;
  double volume;
  double paidAmount;
  bool isFullTank;
  bool missedPrevious;
  double? tripDistance;
  double? secondaryTripDistance;
  DrivingCondition drivingCondition;

  FuelRecord({
    this.id,
    required this.date,
    required this.odometer,
    required this.fuelTypeId,
    required this.vehicleId,
    required this.rate,
    required this.volume,
    required this.paidAmount,
    this.isFullTank = true,
    this.missedPrevious = false,
    this.tripDistance,
    this.secondaryTripDistance,
    this.drivingCondition = DrivingCondition.mixed,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'date': date.toIso8601String(),
      'odometer': odometer,
      'fuelTypeId': fuelTypeId,
      'vehicleId': vehicleId,
      'rate': rate,
      'volume': volume,
      'paidAmount': paidAmount,
      'isFullTank': isFullTank ? 1 : 0,
      'missedPrevious': missedPrevious ? 1 : 0,
      'tripDistance': tripDistance,
      'secondaryTripDistance': secondaryTripDistance,
      'drivingCondition': drivingCondition.name,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'dateTime': date.toIso8601String(),
      'odometer': odometer,
      'fuelTypeId': fuelTypeId,
      'vehicleId': vehicleId,
      'fuelRate': rate,
      'volume': volume,
      'amountPaid': paidAmount,
      'isFullTank': isFullTank,
      'missedPrevious': missedPrevious,
      'tripDistance': tripDistance,
      'secondaryTripDistance': secondaryTripDistance,
      'drivingCondition': drivingCondition.name,
    };
  }

  factory FuelRecord.fromMap(Map<String, dynamic> map) {
    DrivingCondition condition = DrivingCondition.mixed;
    if (map['drivingCondition'] != null) {
      condition = DrivingCondition.values.firstWhere(
        (e) => e.name == map['drivingCondition'] || e.toString() == map['drivingCondition'],
        orElse: () => DrivingCondition.mixed,
      );
    }

    return FuelRecord(
      id: map['id'],
      date: DateTime.parse(map['date']),
      odometer: (map['odometer'] as num).toDouble(),
      fuelTypeId: map['fuelTypeId'],
      vehicleId: map['vehicleId'],
      rate: (map['rate'] as num).toDouble(),
      volume: (map['volume'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num).toDouble(),
      isFullTank: map['isFullTank'] == null
          ? true
          : (map['isFullTank'] == 1 || map['isFullTank'] == true),
      missedPrevious: map['missedPrevious'] == null
          ? false
          : (map['missedPrevious'] == 1 || map['missedPrevious'] == true),
      tripDistance: map['tripDistance'] != null
          ? (map['tripDistance'] as num).toDouble()
          : null,
      secondaryTripDistance: map['secondaryTripDistance'] != null
          ? (map['secondaryTripDistance'] as num).toDouble()
          : null,
      drivingCondition: condition,
    );
  }

  factory FuelRecord.fromJson(Map<String, dynamic> json) {
    DrivingCondition condition = DrivingCondition.mixed;
    if (json['drivingCondition'] != null) {
      condition = DrivingCondition.values.firstWhere(
        (e) => e.name == json['drivingCondition'] || e.toString() == json['drivingCondition'],
        orElse: () => DrivingCondition.mixed,
      );
    }

    return FuelRecord(
      date: DateTime.parse(json['dateTime']),
      odometer: (json['odometer'] as num).toDouble(),
      fuelTypeId: json['fuelTypeId'],
      vehicleId: json['vehicleId'],
      rate: (json['fuelRate'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
      paidAmount: (json['amountPaid'] as num).toDouble(),
      isFullTank: json['isFullTank'] == null
          ? true
          : (json['isFullTank'] == 1 || json['isFullTank'] == true),
      missedPrevious: json['missedPrevious'] == null
          ? false
          : (json['missedPrevious'] == 1 || json['missedPrevious'] == true),
      tripDistance: json['tripDistance'] != null
          ? (json['tripDistance'] as num).toDouble()
          : null,
      secondaryTripDistance: json['secondaryTripDistance'] != null
          ? (json['secondaryTripDistance'] as num).toDouble()
          : null,
      drivingCondition: condition,
    );
  }

  FuelRecord copyWith({
    int? id,
    DateTime? date,
    double? odometer,
    int? fuelTypeId,
    int? vehicleId,
    double? rate,
    double? volume,
    double? paidAmount,
    bool? isFullTank,
    bool? missedPrevious,
    double? tripDistance,
    double? secondaryTripDistance,
    DrivingCondition? drivingCondition,
  }) {
    return FuelRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      fuelTypeId: fuelTypeId ?? this.fuelTypeId,
      vehicleId: vehicleId ?? this.vehicleId,
      rate: rate ?? this.rate,
      volume: volume ?? this.volume,
      paidAmount: paidAmount ?? this.paidAmount,
      isFullTank: isFullTank ?? this.isFullTank,
      missedPrevious: missedPrevious ?? this.missedPrevious,
      tripDistance: tripDistance ?? this.tripDistance,
      secondaryTripDistance: secondaryTripDistance ?? this.secondaryTripDistance,
      drivingCondition: drivingCondition ?? this.drivingCondition,
    );
  }
}
