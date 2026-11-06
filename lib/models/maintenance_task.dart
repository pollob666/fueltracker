// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

class MaintenanceTask {
  int? id;
  int vehicleId;
  String? taskKey;
  String title;
  double intervalKm;
  int? intervalMonths;
  double lastServiceOdo;
  DateTime lastServiceDate;
  double reminderBufferKm;
  bool isEnabled;

  MaintenanceTask({
    this.id,
    required this.vehicleId,
    this.taskKey,
    required this.title,
    required this.intervalKm,
    this.intervalMonths,
    required this.lastServiceOdo,
    required this.lastServiceDate,
    this.reminderBufferKm = 100.0,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'taskKey': taskKey,
      'title': title,
      'intervalKm': intervalKm,
      'intervalMonths': intervalMonths,
      'lastServiceOdo': lastServiceOdo,
      'lastServiceDate': lastServiceDate.toIso8601String(),
      'reminderBufferKm': reminderBufferKm,
      'isEnabled': isEnabled ? 1 : 0,
    };
  }

  factory MaintenanceTask.fromMap(Map<String, dynamic> map) {
    return MaintenanceTask(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int,
      taskKey: map['taskKey'] as String?,
      title: map['title'] as String,
      intervalKm: (map['intervalKm'] as num).toDouble(),
      intervalMonths: map['intervalMonths'] as int?,
      lastServiceOdo: (map['lastServiceOdo'] as num).toDouble(),
      lastServiceDate: DateTime.parse(map['lastServiceDate'] as String),
      reminderBufferKm:
          map['reminderBufferKm'] != null ? (map['reminderBufferKm'] as num).toDouble() : 100.0,
      isEnabled: map['isEnabled'] == null || map['isEnabled'] == 1,
    );
  }

  MaintenanceTask copyWith({
    int? id,
    int? vehicleId,
    String? taskKey,
    String? title,
    double? intervalKm,
    int? intervalMonths,
    double? lastServiceOdo,
    DateTime? lastServiceDate,
    double? reminderBufferKm,
    bool? isEnabled,
  }) {
    return MaintenanceTask(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      taskKey: taskKey ?? this.taskKey,
      title: title ?? this.title,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      lastServiceOdo: lastServiceOdo ?? this.lastServiceOdo,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      reminderBufferKm: reminderBufferKm ?? this.reminderBufferKm,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
