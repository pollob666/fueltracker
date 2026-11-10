// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/utils/unit_converter.dart';

void main() {
  group('Mileage Engine Comprehensive Unit Tests', () {
    // 1. Full-to-full
    test('1. Full-to-full interval calculation calculates exact distance, volume, and mileage', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 50.0,
          odometer: 1500.0,
          paidAmount: 5000.0,
          date: DateTime(2026, 1, 8),
          isFullTank: true,
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 30.0,
          odometer: 1860.0,
          paidAmount: 3000.0,
          date: DateTime(2026, 1, 15),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals.length, 3);

      // Anchor record
      expect(intervals[0].isValidFullTank, isFalse);
      expect(intervals[0].distance, 0.0);
      expect(intervals[0].mileage, isNull);

      // Interval 1: 500 km / 50 L = 10.0 km/L
      expect(intervals[1].isValidFullTank, isTrue);
      expect(intervals[1].distance, 500.0);
      expect(intervals[1].consumedVolume, 50.0);
      expect(intervals[1].mileage, 10.0);

      // Interval 2: 360 km / 30 L = 12.0 km/L
      expect(intervals[2].isValidFullTank, isTrue);
      expect(intervals[2].distance, 360.0);
      expect(intervals[2].consumedVolume, 30.0);
      expect(intervals[2].mileage, 12.0);
    });

    // 2. Partial fill accumulation
    test('2. Partial fill accumulates intermediate volumes and costs until cycle is completed by full tank', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 50.0,
          odometer: 1000.0,
          paidAmount: 5000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 15.0,
          odometer: 1200.0,
          paidAmount: 1500.0,
          date: DateTime(2026, 1, 4),
          isFullTank: false, // partial fill 1
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 10.0,
          odometer: 1350.0,
          paidAmount: 1000.0,
          date: DateTime(2026, 1, 7),
          isFullTank: false, // partial fill 2
        ),
        FuelRecord(
          id: 4,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 25.0,
          odometer: 1600.0,
          paidAmount: 2500.0,
          date: DateTime(2026, 1, 10),
          isFullTank: true, // completes cycle
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals.length, 4);

      // Partials must have isValidFullTank = false and mileage = null
      expect(intervals[1].isPartial, isTrue);
      expect(intervals[1].isValidFullTank, isFalse);
      expect(intervals[1].mileage, isNull);

      expect(intervals[2].isPartial, isTrue);
      expect(intervals[2].isValidFullTank, isFalse);
      expect(intervals[2].mileage, isNull);

      // Cycle completion: distance = 1600 - 1000 = 600 km; volume = 15 + 10 + 25 = 50 L; mileage = 600 / 50 = 12.0 km/L
      expect(intervals[3].isValidFullTank, isTrue);
      expect(intervals[3].distance, 600.0);
      expect(intervals[3].consumedVolume, 50.0);
      expect(intervals[3].consumedCost, 5000.0);
      expect(intervals[3].mileage, 12.0);
    });

    // 3. Missed fill
    test('3. Missed fill discards pending partials, prevents cross-gap mileage, and resets baseline', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 15.0,
          odometer: 1200.0,
          paidAmount: 1500.0,
          date: DateTime(2026, 1, 4),
          isFullTank: false,
        ),
        // Missed previous fill gap
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1800.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 10),
          isFullTank: true,
          missedPrevious: true,
        ),
        // Subsequent fill after new baseline
        FuelRecord(
          id: 4,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 2200.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 16),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals.length, 4);

      // Missed fill interval has no valid mileage across gap
      expect(intervals[2].isMissed, isTrue);
      expect(intervals[2].isValidFullTank, isFalse);
      expect(intervals[2].mileage, isNull);

      // Subsequent interval uses missed fill as new baseline (2200 - 1800 = 400 km, 40 L -> 10 km/L)
      expect(intervals[3].isValidFullTank, isTrue);
      expect(intervals[3].distance, 400.0);
      expect(intervals[3].consumedVolume, 40.0);
      expect(intervals[3].mileage, 10.0);
    });

    // 4. First record baseline
    test('4. First record baseline acts strictly as anchor with no interval mileage and zero running average', () {
      final singleRecord = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 45.0,
          odometer: 1000.0,
          paidAmount: 4500.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(singleRecord);
      expect(intervals.length, 1);
      expect(intervals[0].isValidFullTank, isFalse);
      expect(intervals[0].distance, 0.0);
      expect(intervals[0].mileage, isNull);

      expect(MileageCalculator.calculateWeightedRunningAverage(singleRecord), 0.0);
      expect(MileageCalculator.calculateCostPerKm(singleRecord), 0.0);
      expect(MileageCalculator.calculateLastIntervalMileage(singleRecord), 0.0);
    });

    // 5. Weighted running average (Simpson's Paradox avoidance)
    test('5. Weighted running average weights total distance over total volume preventing skew', () {
      // Interval 1: 100 km / 10 L = 10 km/L
      // Interval 2: 900 km / 50 L = 18 km/L
      // Unweighted mean of rates = (10 + 18) / 2 = 14.0 km/L
      // True weighted average = (100 + 900) / (10 + 50) = 1000 / 60 = 16.6666... km/L
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 10.0,
          odometer: 1100.0,
          paidAmount: 1000.0,
          date: DateTime(2026, 1, 3),
          isFullTank: true,
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 50.0,
          odometer: 2000.0,
          paidAmount: 5000.0,
          date: DateTime(2026, 1, 10),
          isFullTank: true,
        ),
      ];

      final weightedAvg = MileageCalculator.calculateWeightedRunningAverage(records);
      expect(weightedAvg, closeTo(1000.0 / 60.0, 0.0001));
      expect(weightedAvg, isNot(14.0));
    });

    // 6. Unit conversions (km/L, L/100km, MPG US/UK, km/kWh)
    test('6. UnitConverter correctly converts km/L into all supported standards and handles boundaries', () {
      const double kmPerL = 15.0;

      // km/L -> km/L
      final kmL = UnitConverter.convertConsumption(kmPerL, ConsumptionUnit.kmPerLitre);
      expect(kmL, 15.0);

      // km/L -> L/100km: 100 / 15.0 = 6.6666...
      final l100km = UnitConverter.convertConsumption(kmPerL, ConsumptionUnit.litrePer100Km);
      expect(l100km, closeTo(100.0 / 15.0, 0.0001));

      // km/L -> MPG (US): 15.0 * 2.35214583 = 35.28218745
      final mpgUs = UnitConverter.convertConsumption(kmPerL, ConsumptionUnit.mpgUs);
      expect(mpgUs, closeTo(15.0 * 2.35214583, 0.0001));

      // km/L -> MPG (UK): 15.0 * 2.82480936 = 42.3721404
      final mpgUk = UnitConverter.convertConsumption(kmPerL, ConsumptionUnit.mpgUk);
      expect(mpgUk, closeTo(15.0 * 2.82480936, 0.0001));

      // km/L -> km/kWh
      final kmKwh = UnitConverter.convertConsumption(kmPerL, ConsumptionUnit.kmPerKwh);
      expect(kmKwh, 15.0);

      // km/L -> kWh/100km
      final kwh100km = UnitConverter.convertConsumption(kmPerL, ConsumptionUnit.kwhPer100Km);
      expect(kwh100km, closeTo(100.0 / 15.0, 0.0001));

      // Boundary values
      expect(UnitConverter.convertConsumption(null, ConsumptionUnit.kmPerLitre), isNull);
      expect(UnitConverter.convertConsumption(0.0, ConsumptionUnit.kmPerLitre), isNull);
      expect(UnitConverter.convertConsumption(-5.0, ConsumptionUnit.kmPerLitre), isNull);
    });

    // 7. Anomaly thresholds at exactly ±15% and just beyond
    group('7. Anomaly threshold boundary tests (rolling average = 10.0 km/L)', () {
      // Baseline records establishing rolling average of 10.0 km/L
      List<FuelRecord> makeBaseRecords() => [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1400.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 8),
          isFullTank: true,
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1800.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 15),
          isFullTank: true,
        ),
      ];

      test('Exact -15.0% drop threshold (8.5 km/L on 40 L) flags isDrop true', () {
        final records = makeBaseRecords()..add(
          FuelRecord(
            id: 4,
            vehicleId: 1,
            fuelTypeId: 1,
            rate: 100.0,
            volume: 40.0,
            odometer: 1800.0 + 340.0, // 340 / 40 = 8.5 km/L (-15.0%)
            paidAmount: 4000.0,
            date: DateTime(2026, 1, 22),
            isFullTank: true,
          ),
        );

        final anomaly = MileageCalculator.checkMileageAnomaly(records);
        expect(anomaly, isNotNull);
        expect(anomaly!.percentageChange, closeTo(-15.0, 0.001));
        expect(anomaly.isDrop, isTrue);
        expect(anomaly.isBoost, isFalse);
      });

      test('Just inside drop threshold (-14.99% change, 8.501 km/L) flags isDrop false', () {
        final records = makeBaseRecords()..add(
          FuelRecord(
            id: 4,
            vehicleId: 1,
            fuelTypeId: 1,
            rate: 100.0,
            volume: 40.0,
            odometer: 1800.0 + 340.04, // 340.04 / 40 = 8.501 km/L (-14.99%)
            paidAmount: 4000.0,
            date: DateTime(2026, 1, 22),
            isFullTank: true,
          ),
        );

        final anomaly = MileageCalculator.checkMileageAnomaly(records);
        expect(anomaly, isNotNull);
        expect(anomaly!.percentageChange, greaterThan(-15.0));
        expect(anomaly.isDrop, isFalse);
        expect(anomaly.isBoost, isFalse);
      });

      test('Just beyond drop threshold (-15.01% change, 8.499 km/L) flags isDrop true', () {
        final records = makeBaseRecords()..add(
          FuelRecord(
            id: 4,
            vehicleId: 1,
            fuelTypeId: 1,
            rate: 100.0,
            volume: 40.0,
            odometer: 1800.0 + 339.96, // 339.96 / 40 = 8.499 km/L (-15.01%)
            paidAmount: 4000.0,
            date: DateTime(2026, 1, 22),
            isFullTank: true,
          ),
        );

        final anomaly = MileageCalculator.checkMileageAnomaly(records);
        expect(anomaly, isNotNull);
        expect(anomaly!.percentageChange, lessThan(-15.0));
        expect(anomaly.isDrop, isTrue);
        expect(anomaly.isBoost, isFalse);
      });

      test('Exact +15.0% boost threshold (11.5 km/L on 40 L) flags isBoost true', () {
        final records = makeBaseRecords()..add(
          FuelRecord(
            id: 4,
            vehicleId: 1,
            fuelTypeId: 1,
            rate: 100.0,
            volume: 40.0,
            odometer: 1800.0 + 460.0, // 460 / 40 = 11.5 km/L (+15.0%)
            paidAmount: 4000.0,
            date: DateTime(2026, 1, 22),
            isFullTank: true,
          ),
        );

        final anomaly = MileageCalculator.checkMileageAnomaly(records);
        expect(anomaly, isNotNull);
        expect(anomaly!.percentageChange, closeTo(15.0, 0.001));
        expect(anomaly.isBoost, isTrue);
        expect(anomaly.isDrop, isFalse);
      });

      test('Just inside boost threshold (+14.99% change, 11.499 km/L) flags isBoost false', () {
        final records = makeBaseRecords()..add(
          FuelRecord(
            id: 4,
            vehicleId: 1,
            fuelTypeId: 1,
            rate: 100.0,
            volume: 40.0,
            odometer: 1800.0 + 459.96, // 459.96 / 40 = 11.499 km/L (+14.99%)
            paidAmount: 4000.0,
            date: DateTime(2026, 1, 22),
            isFullTank: true,
          ),
        );

        final anomaly = MileageCalculator.checkMileageAnomaly(records);
        expect(anomaly, isNotNull);
        expect(anomaly!.percentageChange, lessThan(15.0));
        expect(anomaly.isBoost, isFalse);
        expect(anomaly.isDrop, isFalse);
      });

      test('Just beyond boost threshold (+15.01% change, 11.501 km/L) flags isBoost true', () {
        final records = makeBaseRecords()..add(
          FuelRecord(
            id: 4,
            vehicleId: 1,
            fuelTypeId: 1,
            rate: 100.0,
            volume: 40.0,
            odometer: 1800.0 + 460.04, // 460.04 / 40 = 11.501 km/L (+15.01%)
            paidAmount: 4000.0,
            date: DateTime(2026, 1, 22),
            isFullTank: true,
          ),
        );

        final anomaly = MileageCalculator.checkMileageAnomaly(records);
        expect(anomaly, isNotNull);
        expect(anomaly!.percentageChange, greaterThan(15.0));
        expect(anomaly.isBoost, isTrue);
        expect(anomaly.isDrop, isFalse);
      });
    });

    // 8. Zero and negative volume handling
    test('8. Zero and negative volume records yield null mileage and are excluded from weighted running average', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 0.0,
          volume: 0.0, // zero volume
          odometer: 1400.0,
          paidAmount: 0.0,
          date: DateTime(2026, 1, 8),
          isFullTank: true,
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: -10.0, // negative volume anomaly
          odometer: 1800.0,
          paidAmount: -1000.0,
          date: DateTime(2026, 1, 15),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals.length, 3);
      // Zero volume interval
      expect(intervals[1].consumedVolume, 0.0);
      expect(intervals[1].mileage, isNull);

      // Negative volume interval
      expect(intervals[2].consumedVolume, -10.0);
      expect(intervals[2].mileage, isNull);

      // Running average cannot include invalid non-positive volume intervals
      expect(MileageCalculator.calculateWeightedRunningAverage(records), 0.0);
    });

    // 9. Odometer <= previous
    test('9. Odometer <= previous reading produces null mileage and resets baseline anchor', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        // Odometer identical to previous (delta = 0)
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1000.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 5),
          isFullTank: true,
        ),
        // Odometer less than previous (delta < 0, reset or error)
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 950.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 8),
          isFullTank: true,
        ),
        // Normal subsequent record following reset
        FuelRecord(
          id: 4,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 40.0,
          odometer: 1350.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 15),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals.length, 4);

      // Identical odometer delta <= 0
      expect(intervals[1].distance, 0.0);
      expect(intervals[1].isValidFullTank, isFalse);
      expect(intervals[1].mileage, isNull);

      // Decreasing odometer delta < 0
      expect(intervals[2].distance, lessThan(0.0));
      expect(intervals[2].isValidFullTank, isFalse);
      expect(intervals[2].mileage, isNull);

      // Interval 3 builds off new baseline (1350 - 950 = 400 km / 40 L = 10 km/L)
      expect(intervals[3].isValidFullTank, isTrue);
      expect(intervals[3].distance, 400.0);
      expect(intervals[3].consumedVolume, 40.0);
      expect(intervals[3].mileage, 10.0);
    });
  });
}
