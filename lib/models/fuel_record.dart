// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

class FuelRecord {
  int? id;
  DateTime date;
  double odometer;
  int fuelTypeId;
  int vehicleId; // Added vehicleId
  double rate;
  double volume;
  double paidAmount;

  FuelRecord({
    this.id,
    required this.date,
    required this.odometer,
    required this.fuelTypeId,
    required this.vehicleId, // Updated constructor
    required this.rate,
    required this.volume,
    required this.paidAmount,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'date': date.toIso8601String(),
      'odometer': odometer,
      'fuelTypeId': fuelTypeId,
      'vehicleId': vehicleId, // Updated to use vehicleId
      'rate': rate,
      'volume': volume,
      'paidAmount': paidAmount,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'dateTime': date.toIso8601String(),
      'odometer': odometer,
      'fuelTypeId': fuelTypeId,
      'vehicleId': vehicleId, // Updated for consistency
      'fuelRate': rate,
      'volume': volume,
      'amountPaid': paidAmount,
    };
  }

  factory FuelRecord.fromMap(Map<String, dynamic> map) {
    return FuelRecord(
      id: map['id'],
      date: DateTime.parse(map['date']),
      odometer: map['odometer'],
      fuelTypeId: map['fuelTypeId'],
      vehicleId: map['vehicleId'], // Updated to use vehicleId
      rate: map['rate'],
      volume: map['volume'],
      paidAmount: map['paidAmount'],
    );
  }

  factory FuelRecord.fromJson(Map<String, dynamic> json) {
    return FuelRecord(
      date: DateTime.parse(json['dateTime']),
      odometer: json['odometer'],
      fuelTypeId: json['fuelTypeId'],
      vehicleId: json['vehicleId'], // Updated for consistency
      rate: json['fuelRate'].toDouble(),
      volume: json['volume'].toDouble(),
      paidAmount: json['amountPaid'].toDouble(),
    );
  }
}
