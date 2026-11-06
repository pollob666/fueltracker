// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:fuel_tracker/utils/maintenance_calculator.dart';

void main() {
  group('MaintenanceCalculator', () {
    test('reports healthy when well within distance and calendar intervals', () {
      final task = MaintenanceTask(
        id: 1,
        vehicleId: 1,
        title: 'Engine Oil Change',
        intervalKm: 3000.0,
        intervalMonths: 3,
        lastServiceOdo: 10000.0,
        lastServiceDate: DateTime(2026, 1, 1),
        reminderBufferKm: 100.0,
      );

      final result = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 11500.0, // 1,500 km remaining out of 3,000
        currentDate: DateTime(2026, 2, 1), // 1 month elapsed out of 3
        dailyKmRate: 50.0,
      );

      expect(result.status, MaintenanceStatus.healthy);
      expect(result.kmRemaining, 1500.0);
      expect(result.targetOdo, 13000.0);
      expect(result.isActionRequired, false);
      expect(result.progressFraction, closeTo(0.5, 0.05));
      // 1500 km / 50 km/day = 30 days
      expect(result.daysRemaining, 30);
    });

    test('reports dueSoon when remaining distance is within bufferKm', () {
      final task = MaintenanceTask(
        id: 1,
        vehicleId: 1,
        title: 'Engine Oil Change',
        intervalKm: 3000.0,
        intervalMonths: 6,
        lastServiceOdo: 10000.0,
        lastServiceDate: DateTime(2026, 1, 1),
        reminderBufferKm: 150.0,
      );

      final result = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 12900.0, // 100 km remaining <= 150 buffer
        currentDate: DateTime(2026, 2, 1),
        dailyKmRate: 20.0,
      );

      expect(result.status, MaintenanceStatus.dueSoon);
      expect(result.isDueSoonByKm, true);
      expect(result.isActionRequired, true);
      expect(result.kmRemaining, 100.0);
      expect(result.daysRemaining, 5); // 100 / 20 = 5 days
    });

    test('reports overdue when current odometer exceeds interval target', () {
      final task = MaintenanceTask(
        id: 1,
        vehicleId: 1,
        title: 'Oil Filter Replacement',
        intervalKm: 6000.0,
        lastServiceOdo: 10000.0,
        lastServiceDate: DateTime(2026, 1, 1),
      );

      final result = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 16250.0, // Exceeded by 250 km
        currentDate: DateTime(2026, 1, 15),
        dailyKmRate: 25.0,
      );

      expect(result.status, MaintenanceStatus.overdue);
      expect(result.isOverdueByKm, true);
      expect(result.kmRemaining, -250.0);
      expect(result.progressFraction, greaterThan(1.0));
      expect(result.daysRemaining, 0);
    });

    test('reports dueSoon and overdue based on calendar interval when distance is healthy', () {
      final task = MaintenanceTask(
        id: 1,
        vehicleId: 1,
        title: 'Air Filter Clean',
        intervalKm: 10000.0, // Large km interval
        intervalMonths: 3,
        lastServiceOdo: 10000.0,
        lastServiceDate: DateTime(2026, 1, 1), // Target date: 2026-04-01
      );

      // 5 days before calendar target (dueSoon window <= 7 days)
      final dueSoonResult = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 11000.0,
        currentDate: DateTime(2026, 3, 27),
        dailyKmRate: 10.0,
      );
      expect(dueSoonResult.status, MaintenanceStatus.dueSoon);
      expect(dueSoonResult.isDueSoonByCalendar, true);

      // 2 days after calendar target
      final overdueResult = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 11000.0,
        currentDate: DateTime(2026, 4, 3),
        dailyKmRate: 10.0,
      );
      expect(overdueResult.status, MaintenanceStatus.overdue);
      expect(overdueResult.isOverdueByCalendar, true);
    });

    test('hybrid projection selects the minimum between odometer and calendar days', () {
      final task = MaintenanceTask(
        id: 1,
        vehicleId: 1,
        title: 'General Servicing',
        intervalKm: 4000.0,
        intervalMonths: 6,
        lastServiceOdo: 20000.0,
        lastServiceDate: DateTime(2026, 1, 1), // Target date: 2026-07-01 (~181 days)
      );

      // Fast driver: 50 km/day -> remaining 1,000 km will be covered in 20 days (< 181 days)
      final fastResult = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 23000.0, // 1000 km left
        currentDate: DateTime(2026, 1, 10),
        dailyKmRate: 50.0,
      );
      expect(fastResult.daysRemaining, 20);

      // Slow driver: 2 km/day -> 1,000 km would take 500 days, but calendar due in ~170 days
      final slowResult = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: 23000.0,
        currentDate: DateTime(2026, 1, 10),
        dailyKmRate: 2.0,
      );
      expect(slowResult.daysRemaining, lessThan(180));
    });

    test('ServiceSession and ServiceSessionItem serialize and deserialize correctly', () {
      final session = ServiceSession(
        id: 1,
        vehicleId: 2,
        odometer: 25000.0,
        serviceDate: DateTime(2026, 3, 15),
        totalCost: 3500.0,
        workshopName: 'Navana Workshop',
        notes: 'Oil and filter replaced',
        items: [
          ServiceSessionItem(
            id: 10,
            sessionId: 1,
            taskId: 101,
            cost: 2500.0,
            taskTitle: 'Engine Oil',
          ),
          ServiceSessionItem(
            id: 11,
            sessionId: 1,
            taskId: 102,
            cost: 1000.0,
            taskTitle: 'Oil Filter',
          ),
        ],
      );

      final map = session.toMap();
      expect(map['vehicleId'], 2);
      expect(map['odometer'], 25000.0);
      expect(map['totalCost'], 3500.0);
      expect(map['workshopName'], 'Navana Workshop');

      final reconstructed = ServiceSession.fromMap(map, items: session.items);
      expect(reconstructed.odometer, 25000.0);
      expect(reconstructed.items.length, 2);
      expect(reconstructed.items.first.taskTitle, 'Engine Oil');
    });

    test('NotificationService.getMaintenanceNotifId produces deterministic and distinct IDs', () {
      final id1 = NotificationService.getMaintenanceNotifId(1, 10);
      final id2 = NotificationService.getMaintenanceNotifId(1, 11);
      final id3 = NotificationService.getMaintenanceNotifId(2, 10);

      expect(id1, isNot(id2));
      expect(id1, isNot(id3));
      expect(id1 >= 100000, true);
      // Deterministic
      expect(id1, NotificationService.getMaintenanceNotifId(1, 10));
    });
  });
}
