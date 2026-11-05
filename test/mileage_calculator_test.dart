import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

void main() {
  group('MileageCalculator', () {
    test('calculates standard full-to-full intervals correctly', () {
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
          volume: 40.0,
          odometer: 1400.0,
          paidAmount: 4000.0,
          date: DateTime(2026, 1, 8),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals.length, 2);
      expect(intervals[0].isValidFullTank, false); // anchor
      expect(intervals[1].isValidFullTank, true);
      expect(intervals[1].distance, 400.0);
      expect(intervals[1].consumedVolume, 40.0);
      expect(intervals[1].mileage, 10.0);

      final avg = MileageCalculator.calculateWeightedRunningAverage(records);
      expect(avg, 10.0);
    });

    test('handles partial fill accumulation correctly', () {
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
          volume: 10.0,
          odometer: 1200.0,
          paidAmount: 1000.0,
          date: DateTime(2026, 1, 4),
          isFullTank: false, // partial fill
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 15.0,
          odometer: 1500.0,
          paidAmount: 1500.0,
          date: DateTime(2026, 1, 8),
          isFullTank: true, // full fill
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals[1].isValidFullTank, false); // partial fill has no mileage
      expect(intervals[1].isPartial, true);
      expect(intervals[2].isValidFullTank, true);
      expect(intervals[2].distance, 500.0); // 1500 - 1000
      expect(intervals[2].consumedVolume, 25.0); // 10 + 15
      expect(intervals[2].mileage, 20.0); // 500 / 25
    });

    test('handles missed previous fill flag correctly', () {
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
          volume: 35.0,
          odometer: 1600.0,
          paidAmount: 3500.0,
          date: DateTime(2026, 1, 15),
          isFullTank: true,
          missedPrevious: true, // untracked fill occurred between 1 and 2
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals[1].isValidFullTank, false);
      expect(intervals[1].isMissed, true);
      expect(intervals[1].mileage, isNull);
    });

    test('uses tripDistance when provided for bi-fuel vehicle', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 15.0,
          odometer: 5000.0,
          paidAmount: 1500.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 10.0,
          odometer: 5300.0, // total odometer diff is 300 km (shared with petrol)
          tripDistance: 120.0, // specific trip on this fuel
          paidAmount: 1000.0,
          date: DateTime(2026, 1, 5),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals[1].isValidFullTank, true);
      expect(intervals[1].distance, 120.0);
      expect(intervals[1].consumedVolume, 10.0);
      expect(intervals[1].mileage, 12.0); // 120 / 10
    });

    test('calculates weighted running average preventing Simpson paradox skew', () {
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
          odometer: 1100.0, // 100km / 10L = 10 km/L
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
          odometer: 2100.0, // 1000km / 50L = 20 km/L
          paidAmount: 5000.0,
          date: DateTime(2026, 1, 10),
          isFullTank: true,
        ),
      ];

      // Arithmetic mean: (10 + 20) / 2 = 15.0 km/L
      // Weighted mean: (100 + 1000) / (10 + 50) = 1100 / 60 = 18.333... km/L
      final weightedAvg = MileageCalculator.calculateWeightedRunningAverage(records);
      expect(weightedAvg, closeTo(18.333, 0.001));
    });

    test('calculates cost per km and daily averages correctly', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1000.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 110.0,
          volume: 20.0,
          odometer: 1200.0,
          paidAmount: 2200.0,
          date: DateTime(2026, 1, 11), // 10 days later
          isFullTank: true,
        ),
      ];

      // Total distance: 200 km across 10 days -> 20 km/day
      expect(MileageCalculator.calculateDailyAverageRun(records), 20.0);

      // Total cost: 4200 across 10 days -> 420/day
      expect(MileageCalculator.calculateDailyAverageCost(records), 420.0);

      // Cost per km across all records: (2000 + 2200) / 200 = 21.0
      expect(MileageCalculator.calculateCostPerKm(records), 21.0);
    });

    test('calculates average refuel cadence correctly', () {
      expect(MileageCalculator.calculateAverageRefuelCadence([]), 0.0);

      final singleRecord = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1000.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
      ];
      expect(MileageCalculator.calculateAverageRefuelCadence(singleRecord), 0.0);

      final multiRecords = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1000.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1200.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 5),
          isFullTank: true,
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1400.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 11),
          isFullTank: true,
        ),
      ];

      // Total 10 days across 2 intervals = 5.0 days/refuel
      expect(MileageCalculator.calculateAverageRefuelCadence(multiRecords), 5.0);
    });

    test('calculates driving condition mileage averages correctly', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1000.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
          drivingCondition: DrivingCondition.city,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1200.0, // 200 km / 20 L = 10 km/l (City)
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 5),
          isFullTank: true,
          drivingCondition: DrivingCondition.city,
        ),
        FuelRecord(
          id: 3,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1500.0, // 300 km / 20 L = 15 km/l (Highway)
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 10),
          isFullTank: true,
          drivingCondition: DrivingCondition.highway,
        ),
        FuelRecord(
          id: 4,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1800.0, // 300 km / 20 L = 15 km/l (Highway)
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 15),
          isFullTank: true,
          drivingCondition: DrivingCondition.highway,
        ),
      ];

      final cityAvg = MileageCalculator.calculateConditionAverage(
          records, DrivingCondition.city);
      expect(cityAvg, 10.0);

      final highwayAvg = MileageCalculator.calculateConditionAverage(
          records, DrivingCondition.highway);
      // 600 km total / 40 L total = 15.0 km/l
      expect(highwayAvg, 15.0);

      final mixedAvg = MileageCalculator.calculateConditionAverage(
          records, DrivingCondition.mixed);
      expect(mixedAvg, 0.0);
    });

    test('tripDistance overrides odometer delta in interval distance', () {
      final records = [
        FuelRecord(
          id: 1,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1000.0,
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 1),
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          vehicleId: 1,
          fuelTypeId: 1,
          rate: 100.0,
          volume: 20.0,
          odometer: 1250.0, // Delta = 250
          tripDistance: 240.0, // Specific trip meter distance override
          paidAmount: 2000.0,
          date: DateTime(2026, 1, 5),
          isFullTank: true,
        ),
      ];

      final intervals = MileageCalculator.calculateIntervalResults(records);
      expect(intervals[1].distance, 240.0);
      expect(intervals[1].mileage, 12.0); // 240 / 20 = 12.0
    });
  });
}
