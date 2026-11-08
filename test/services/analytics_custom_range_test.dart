// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/services/analytics_service.dart';

void main() {
  group('AnalyticsService Custom Date Range & Point Record Linking Tests', () {
    final records = <FuelRecord>[
      FuelRecord(
        id: 101,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 9, 15, 10, 30),
        odometer: 10000,
        rate: 1.25,
        volume: 35.0,
        paidAmount: 43.75,
        isFullTank: true,
      ),
      FuelRecord(
        id: 102,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 5, 14, 0),
        odometer: 10450,
        rate: 1.27,
        volume: 36.0,
        paidAmount: 45.72,
        isFullTank: true,
      ),
      FuelRecord(
        id: 103,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 25, 9, 15),
        odometer: 10920,
        rate: 1.29,
        volume: 37.0,
        paidAmount: 47.73,
        isFullTank: true,
      ),
      FuelRecord(
        id: 104,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 11, 2, 16, 45),
        odometer: 11400,
        rate: 1.30,
        volume: 38.0,
        paidAmount: 49.40,
        isFullTank: true,
      ),
    ];

    test('filterByTimeWindow filters strictly within custom DateTimeRange', () {
      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 31),
      );

      final filtered = AnalyticsService.filterByTimeWindow(
        records,
        AnalyticsTimeWindow.custom,
        customRange: range,
      );

      expect(filtered.length, 2);
      expect(filtered.map((r) => r.id).toList(), [102, 103]);
    });

    test('filterByTimeWindow handles single day custom range inclusively', () {
      final singleDayRange = DateTimeRange(
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 5),
      );

      final filtered = AnalyticsService.filterByTimeWindow(
        records,
        AnalyticsTimeWindow.custom,
        customRange: singleDayRange,
      );

      expect(filtered.length, 1);
      expect(filtered.first.id, 102);
    });

    test('computePriceTrends links source FuelRecord in PriceTrendPoint', () {
      final trends = AnalyticsService.computePriceTrends(records);
      expect(trends.containsKey(1), isTrue);

      final points = trends[1]!;
      expect(points.length, 4);
      expect(points.first.record, isNotNull);
      expect(points.first.record!.id, 101);
      expect(points.last.record!.id, 104);
    });
  });
}
