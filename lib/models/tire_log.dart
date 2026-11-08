// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

class TireLog {
  int? id;
  int tireId;
  DateTime date;
  double odometer;
  String position;
  double treadDepthMm;
  String? notes;

  TireLog({
    this.id,
    required this.tireId,
    required this.date,
    required this.odometer,
    required this.position,
    required this.treadDepthMm,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tireId': tireId,
      'date': date.toIso8601String(),
      'odometer': odometer,
      'position': position,
      'treadDepthMm': treadDepthMm,
      'notes': notes,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TireLog.fromMap(Map<String, dynamic> map) {
    return TireLog(
      id: map['id'] as int?,
      tireId: map['tireId'] as int,
      date: DateTime.parse(map['date'] as String),
      odometer: (map['odometer'] as num).toDouble(),
      position: map['position'] as String,
      treadDepthMm: (map['treadDepthMm'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  TireLog copyWith({
    int? id,
    int? tireId,
    DateTime? date,
    double? odometer,
    String? position,
    double? treadDepthMm,
    String? notes,
  }) {
    return TireLog(
      id: id ?? this.id,
      tireId: tireId ?? this.tireId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      position: position ?? this.position,
      treadDepthMm: treadDepthMm ?? this.treadDepthMm,
      notes: notes ?? this.notes,
    );
  }
}
