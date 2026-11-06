// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

class ServiceSessionItem {
  int? id;
  int? sessionId;
  int taskId;
  String? brandOrSpec;
  double? cost;
  int? locationId;
  String? notes;
  String? taskTitle; // Transient display helper

  ServiceSessionItem({
    this.id,
    this.sessionId,
    required this.taskId,
    this.brandOrSpec,
    this.cost,
    this.locationId,
    this.notes,
    this.taskTitle,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'taskId': taskId,
      'brandOrSpec': brandOrSpec,
      'cost': cost,
      'locationId': locationId,
      'notes': notes,
    };
  }

  factory ServiceSessionItem.fromMap(Map<String, dynamic> map) {
    return ServiceSessionItem(
      id: map['id'] as int?,
      sessionId: map['sessionId'] as int?,
      taskId: map['taskId'] as int,
      brandOrSpec: map['brandOrSpec'] as String?,
      cost: map['cost'] != null ? (map['cost'] as num).toDouble() : null,
      locationId: map['locationId'] as int?,
      notes: map['notes'] as String?,
      taskTitle: map['taskTitle'] as String?,
    );
  }
}

class ServiceSession {
  int? id;
  int vehicleId;
  double odometer;
  DateTime serviceDate;
  double? totalCost;
  String? workshopName;
  int? locationId;
  double? latitude;
  double? longitude;
  String? notes;
  String? invoiceImagePath;
  List<ServiceSessionItem> items;

  ServiceSession({
    this.id,
    required this.vehicleId,
    required this.odometer,
    required this.serviceDate,
    this.totalCost,
    this.workshopName,
    this.locationId,
    this.latitude,
    this.longitude,
    this.notes,
    this.invoiceImagePath,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'odometer': odometer,
      'serviceDate': serviceDate.toIso8601String(),
      'totalCost': totalCost,
      'workshopName': workshopName,
      'locationId': locationId,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'invoiceImagePath': invoiceImagePath,
    };
  }

  factory ServiceSession.fromMap(Map<String, dynamic> map, {List<ServiceSessionItem> items = const []}) {
    return ServiceSession(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int,
      odometer: (map['odometer'] as num).toDouble(),
      serviceDate: DateTime.parse(map['serviceDate'] as String),
      totalCost: map['totalCost'] != null ? (map['totalCost'] as num).toDouble() : null,
      workshopName: map['workshopName'] as String?,
      locationId: map['locationId'] as int?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      notes: map['notes'] as String?,
      invoiceImagePath: map['invoiceImagePath'] as String?,
      items: items,
    );
  }
}
