// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:math';
import 'package:fuel_tracker/models/maintenance_task.dart';

enum MaintenanceStatus {
  healthy,
  dueSoon,
  overdue,
}

class TaskPredictionResult {
  final MaintenanceStatus status;
  final double kmRemaining;
  final int? daysRemaining;
  final double progressFraction;
  final DateTime? projectedDueDate;
  final double targetOdo;
  final DateTime? targetCalendarDate;
  final bool isOverdueByKm;
  final bool isOverdueByCalendar;
  final bool isDueSoonByKm;
  final bool isDueSoonByCalendar;

  const TaskPredictionResult({
    required this.status,
    required this.kmRemaining,
    this.daysRemaining,
    required this.progressFraction,
    this.projectedDueDate,
    required this.targetOdo,
    this.targetCalendarDate,
    required this.isOverdueByKm,
    required this.isOverdueByCalendar,
    required this.isDueSoonByKm,
    required this.isDueSoonByCalendar,
  });

  bool get isActionRequired => status != MaintenanceStatus.healthy;
}

class MaintenanceCalculator {
  /// Evaluates the real-time operational status, remaining limits, and projected due dates for a task.
  static TaskPredictionResult calculateTaskStatus({
    required MaintenanceTask task,
    required double currentOdo,
    required DateTime currentDate,
    required double dailyKmRate,
  }) {
    final double targetOdo = task.lastServiceOdo + task.intervalKm;
    final double kmRemaining = targetOdo - currentOdo;
    final bool isOverdueByKm = kmRemaining <= 0;
    final bool isDueSoonByKm = kmRemaining > 0 && kmRemaining <= task.reminderBufferKm;

    DateTime? targetCalendarDate;
    int? daysRemainingByCalendar;
    bool isOverdueByCalendar = false;
    bool isDueSoonByCalendar = false;

    if (task.intervalMonths != null && task.intervalMonths! > 0) {
      targetCalendarDate = DateTime(
        task.lastServiceDate.year,
        task.lastServiceDate.month + task.intervalMonths!,
        task.lastServiceDate.day,
      );
      daysRemainingByCalendar = targetCalendarDate.difference(currentDate).inDays;
      isOverdueByCalendar = daysRemainingByCalendar <= 0;
      isDueSoonByCalendar = daysRemainingByCalendar > 0 && daysRemainingByCalendar <= 7;
    }

    int? daysRemainingByOdo;
    if (dailyKmRate > 0) {
      daysRemainingByOdo = kmRemaining <= 0 ? 0 : (kmRemaining / dailyKmRate).round();
    }

    int? projectedDaysRemaining;
    if (daysRemainingByOdo != null && daysRemainingByCalendar != null) {
      projectedDaysRemaining = min(daysRemainingByOdo, daysRemainingByCalendar);
    } else if (daysRemainingByOdo != null) {
      projectedDaysRemaining = daysRemainingByOdo;
    } else if (daysRemainingByCalendar != null) {
      projectedDaysRemaining = daysRemainingByCalendar;
    }

    DateTime? projectedDueDate;
    if (projectedDaysRemaining != null) {
      projectedDueDate = currentDate.add(Duration(days: projectedDaysRemaining));
    }

    MaintenanceStatus status;
    if (isOverdueByKm || isOverdueByCalendar) {
      status = MaintenanceStatus.overdue;
    } else if (isDueSoonByKm || isDueSoonByCalendar) {
      status = MaintenanceStatus.dueSoon;
    } else {
      status = MaintenanceStatus.healthy;
    }

    final double distDriven = currentOdo - task.lastServiceOdo;
    final double distanceFraction =
        task.intervalKm > 0 ? (distDriven / task.intervalKm).clamp(0.0, 2.0) : 0.0;

    double progressFraction = distanceFraction;
    if (targetCalendarDate != null) {
      final int totalDays = targetCalendarDate.difference(task.lastServiceDate).inDays;
      final int elapsedDays = currentDate.difference(task.lastServiceDate).inDays;
      final double calendarFraction =
          totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 2.0) : 0.0;
      progressFraction = max(distanceFraction, calendarFraction);
    }

    return TaskPredictionResult(
      status: status,
      kmRemaining: kmRemaining,
      daysRemaining: projectedDaysRemaining,
      progressFraction: progressFraction,
      projectedDueDate: projectedDueDate,
      targetOdo: targetOdo,
      targetCalendarDate: targetCalendarDate,
      isOverdueByKm: isOverdueByKm,
      isOverdueByCalendar: isOverdueByCalendar,
      isDueSoonByKm: isDueSoonByKm,
      isDueSoonByCalendar: isDueSoonByCalendar,
    );
  }
}
