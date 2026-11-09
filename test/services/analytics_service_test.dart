// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/services/analytics_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

void main() {
  group('AnalyticsService Tests', () {
    final anchor = DateTime(2026, 10, 30);

    final records = <FuelRecord>[
      FuelRecord(
        id: 1,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2025, 8, 1),
        odometer: 10000,
        rate: 130,
        volume: 30,
        paidAmount: 3900,
        isFullTank: true,
        missedPrevious: false,
        drivingCondition: DrivingCondition.mixed,
      ),
      FuelRecord(
        id: 2,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 6, 1),
        odometer: 10400,
        rate: 130,
        volume: 32,
        paidAmount: 4160,
        isFullTank: true,
        missedPrevious: false,
        locationId: 10,
        drivingCondition: DrivingCondition.city,
      ),
      FuelRecord(
        id: 3,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 9, 1),
        odometer: 10800,
        rate: 130,
        volume: 35,
        paidAmount: 4550,
        isFullTank: true,
        missedPrevious: false,
        locationId: 20,
        drivingCondition: DrivingCondition.highway,
      ),
      FuelRecord(
        id: 4,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 15),
        odometer: 11300,
        rate: 132,
        volume: 33,
        paidAmount: 4356,
        isFullTank: true,
        missedPrevious: false,
        locationId: 30,
        drivingCondition: DrivingCondition.mixed,
      ),
    ];

    final locationMap = {
      10: SavedLocation(
        id: 10,
        name: 'Station Alpha',
        isNamed: true,
        createdAt: DateTime(2026, 1, 1),
      ),
      20: SavedLocation(
        id: 20,
        name: 'Station Beta',
        isNamed: true,
        createdAt: DateTime(2026, 1, 1),
      ),
      30: SavedLocation(
        id: 30,
        name: 'Station Gamma',
        isNamed: true,
        createdAt: DateTime(2026, 1, 1),
      ),
    };

    test('filterByTimeWindow properly filters by date ranges', () {
      final oneMonth = AnalyticsService.filterByTimeWindow(
        records,
        AnalyticsTimeWindow.oneMonth,
        anchorDate: anchor,
      );
      expect(oneMonth.length, 1);
      expect(oneMonth.first.id, 4);

      final threeMonths = AnalyticsService.filterByTimeWindow(
        records,
        AnalyticsTimeWindow.threeMonths,
        anchorDate: anchor,
      );
      expect(threeMonths.length, 2);

      final sixMonths = AnalyticsService.filterByTimeWindow(
        records,
        AnalyticsTimeWindow.sixMonths,
        anchorDate: anchor,
      );
      expect(sixMonths.length, 3);

      final allTime = AnalyticsService.filterByTimeWindow(
        records,
        AnalyticsTimeWindow.allTime,
      );
      expect(allTime.length, 4);
    });

    test('computePriceTrends computes rates and 30-day moving averages', () {
      final trends = AnalyticsService.computePriceTrends(
        records,
        locationMap: locationMap,
      );

      expect(trends.containsKey(1), isTrue);
      final list = trends[1]!;
      expect(list.length, 4);

      // Verify points
      expect(list[0].rate, 130.0);
      expect(list[1].rate, 130.0);
      expect(list[1].stationName, 'Station Alpha');
      expect(list[3].rate, 132.0);
      expect(list[3].stationName, 'Station Gamma');
    });

    test('computeStationEfficiency attributes to station at N-1', () {
      final points = AnalyticsService.computeStationEfficiency(
        records,
        locationMap: locationMap,
      );

      // 4 full tanks = 3 interval results
      expect(points.length, 3);

      // Interval 1 (from fill 1 to fill 2: 400km / 32L = 12.5 km/L)
      // Fuel consumed was bought at fill 1 (no location)
      expect(points[0].intervalIndex, 1);
      expect(points[0].intervalMileage, 12.5);

      // Interval 2 (from fill 2 to fill 3: 400km / 35L = 11.43 km/L)
      // Fuel consumed was bought at fill 2 (Station Alpha)
      expect(points[1].stationName, 'Station Alpha');

      // Interval 3 (from fill 3 to fill 4: 500km / 33L = 15.15 km/L)
      // Fuel consumed was bought at fill 3 (Station Beta)
      expect(points[2].stationName, 'Station Beta');
    });

    test('computeConditionDelta segregates by road environment', () {
      final summary = AnalyticsService.computeConditionDelta(records);

      expect(summary.city.recordCount, 1);
      expect(summary.highway.recordCount, 1);
      expect(summary.mixed.recordCount, 1); // Anchor record excluded from interval analytics (CRIT-01 fix)

      expect(summary.city.totalVolume, 32.0);
      expect(summary.highway.totalVolume, 35.0);
      expect(summary.city.totalDistance, 400.0);
      expect(summary.highway.totalDistance, 400.0);
    });

    test('calculateCarbonFootprint computes CO2 and eco rating correctly', () {
      final fuelTypeMap = {
        1: FuelType(
          id: 1,
          name: 'Octane',
          category: FuelCategory.gasoline,
          unit: FuelUnit.litre,
        ),
      };

      final footprint = MileageCalculator.calculateCarbonFootprint(
        records,
        fuelTypeMap: fuelTypeMap,
      );

      // Total cumulative volume: 30 + 32 + 35 + 33 = 130 L
      // Factor for gasoline: 2.31 kg/L
      // 130 * 2.31 = 300.3 kg CO2
      expect(footprint.totalVolume, 130.0);
      expect(footprint.totalCo2Kg, closeTo(300.3, 0.01));

      // Post-baseline interval distance: 400 + 400 + 500 = 1300 km
      expect(footprint.totalDistance, 1300.0);

      // Grams per km over post-baseline intervals: (100 L consumed * 2.31 kg/L * 1000) / 1300 km = 177.69 g/km (Class B)
      expect(footprint.gramsCo2PerKm, closeTo(177.69, 0.1));
      expect(footprint.ecoRating, 'B');

      // Tree offset: 300.3 / 22 = ceil(13.65) = 14 trees
      expect(footprint.treeOffsetCount, 14);
    });
  });
}
