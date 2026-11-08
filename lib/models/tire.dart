// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

class Tire {
  int? id;
  int vehicleId;
  String brand;
  String? model;
  String size;
  String? dotCode;
  double installedOdo;
  DateTime installedDate;
  double initialTreadDepthMm;
  double currentTreadDepthMm;
  bool isArchived;

  Tire({
    this.id,
    required this.vehicleId,
    required this.brand,
    this.model,
    required this.size,
    this.dotCode,
    required this.installedOdo,
    required this.installedDate,
    required this.initialTreadDepthMm,
    required this.currentTreadDepthMm,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'vehicleId': vehicleId,
      'brand': brand,
      'model': model,
      'size': size,
      'dotCode': dotCode,
      'installedOdo': installedOdo,
      'installedDate': installedDate.toIso8601String(),
      'initialTreadDepthMm': initialTreadDepthMm,
      'currentTreadDepthMm': currentTreadDepthMm,
      'isArchived': isArchived ? 1 : 0,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Tire.fromMap(Map<String, dynamic> map) {
    return Tire(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int,
      brand: map['brand'] as String,
      model: map['model'] as String?,
      size: map['size'] as String,
      dotCode: map['dotCode'] as String?,
      installedOdo: (map['installedOdo'] as num).toDouble(),
      installedDate: DateTime.parse(map['installedDate'] as String),
      initialTreadDepthMm: (map['initialTreadDepthMm'] as num).toDouble(),
      currentTreadDepthMm: (map['currentTreadDepthMm'] as num).toDouble(),
      isArchived: map['isArchived'] == 1 || map['isArchived'] == true,
    );
  }

  Tire copyWith({
    int? id,
    int? vehicleId,
    String? brand,
    String? model,
    String? size,
    String? dotCode,
    double? installedOdo,
    DateTime? installedDate,
    double? initialTreadDepthMm,
    double? currentTreadDepthMm,
    bool? isArchived,
  }) {
    return Tire(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      size: size ?? this.size,
      dotCode: dotCode ?? this.dotCode,
      installedOdo: installedOdo ?? this.installedOdo,
      installedDate: installedDate ?? this.installedDate,
      initialTreadDepthMm: initialTreadDepthMm ?? this.initialTreadDepthMm,
      currentTreadDepthMm: currentTreadDepthMm ?? this.currentTreadDepthMm,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
