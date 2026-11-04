// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fuel_tracker/models/fuel_record.dart';

/// Holds the computed efficiency metrics for a specific fuel record interval.
class IntervalResult {
  final FuelRecord record;
  final double distance;
  final double consumedVolume;
  final double? mileage;
  final bool isValidFullTank;
  final bool isPartial;
  final bool isMissed;

  const IntervalResult({
    required this.record,
    required this.distance,
    required this.consumedVolume,
    required this.mileage,
    required this.isValidFullTank,
    required this.isPartial,
    required this.isMissed,
  });
}

class MileageCalculator {
  /// Sorts records in chronological order (date ASC, odometer ASC).
  static List<FuelRecord> sortChronological(List<FuelRecord> records) {
    final list = List<FuelRecord>.from(records);
    list.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.odometer.compareTo(b.odometer);
    });
    return list;
  }

  /// Calculates interval-by-interval results using the standard Full-to-Full algorithm.
  ///
  /// - Full Tank after Full Tank: distance = current - baseline; volume = current fill volume.
  /// - Partial Fills: accumulate volume until the next full tank completes the cycle.
  /// - Missed Previous Fill: resets the baseline; no interval mileage is computed for the gap.
  /// - Trip Distance: if provided on the record, overrides the odometer delta.
  static List<IntervalResult> calculateIntervalResults(List<FuelRecord> records) {
    if (records.isEmpty) return [];

    final sorted = sortChronological(records);
    final results = <IntervalResult>[];

    FuelRecord? baselineRecord;
    bool hasValidBaseline = false;
    double pendingPartialVolume = 0.0;

    for (final record in sorted) {
      if (record.missedPrevious) {
        // Gap in data: previous fills were missed. Discard pending partials and reset baseline.
        pendingPartialVolume = 0.0;
        if (record.isFullTank) {
          baselineRecord = record;
          hasValidBaseline = true;
        } else {
          hasValidBaseline = false;
          baselineRecord = null;
        }

        results.add(IntervalResult(
          record: record,
          distance: 0.0,
          consumedVolume: record.volume,
          mileage: null,
          isValidFullTank: false,
          isPartial: !record.isFullTank,
          isMissed: true,
        ));
        continue;
      }

      if (!hasValidBaseline || baselineRecord == null) {
        if (record.isFullTank) {
          baselineRecord = record;
          hasValidBaseline = true;
          pendingPartialVolume = 0.0;
          results.add(IntervalResult(
            record: record,
            distance: 0.0,
            consumedVolume: record.volume,
            mileage: null,
            isValidFullTank: false,
            isPartial: false,
            isMissed: false,
          ));
        } else {
          pendingPartialVolume += record.volume;
          results.add(IntervalResult(
            record: record,
            distance: 0.0,
            consumedVolume: record.volume,
            mileage: null,
            isValidFullTank: false,
            isPartial: true,
            isMissed: false,
          ));
        }
        continue;
      }

      // We have a valid baseline
      if (!record.isFullTank) {
        // Intermediate partial fill: accumulate volume
        pendingPartialVolume += record.volume;
        results.add(IntervalResult(
          record: record,
          distance: 0.0,
          consumedVolume: record.volume,
          mileage: null,
          isValidFullTank: false,
          isPartial: true,
          isMissed: false,
        ));
      } else {
        // Full tank completes the cycle
        double distance = 0.0;
        if (record.tripDistance != null && record.tripDistance! > 0) {
          distance = record.tripDistance!;
        } else {
          distance = record.odometer - baselineRecord.odometer;
        }

        if (distance <= 0) {
          // Negative or zero distance (anomaly or odometer reset)
          baselineRecord = record;
          pendingPartialVolume = 0.0;
          results.add(IntervalResult(
            record: record,
            distance: distance,
            consumedVolume: record.volume + pendingPartialVolume,
            mileage: null,
            isValidFullTank: false,
            isPartial: false,
            isMissed: false,
          ));
        } else {
          final totalConsumedVolume = pendingPartialVolume + record.volume;
          final double? mileage = totalConsumedVolume > 0
              ? distance / totalConsumedVolume
              : null;

          results.add(IntervalResult(
            record: record,
            distance: distance,
            consumedVolume: totalConsumedVolume,
            mileage: mileage,
            isValidFullTank: true,
            isPartial: false,
            isMissed: false,
          ));

          // Reset baseline for the next cycle
          pendingPartialVolume = 0.0;
          baselineRecord = record;
        }
      }
    }

    return results;
  }

  /// Calculates the weighted running average mileage across all eligible full-tank intervals.
  ///
  /// Weighted ratio: (sum of eligible distances) / (sum of eligible consumed volumes).
  /// This eliminates statistical skew caused by unweighted averages of ratios.
  static double calculateWeightedRunningAverage(List<FuelRecord> records) {
    if (records.length < 2) return 0.0;

    final intervals = calculateIntervalResults(records);
    double totalDistance = 0.0;
    double totalConsumedVolume = 0.0;

    for (final item in intervals) {
      if (item.isValidFullTank && item.mileage != null && item.distance > 0 && item.consumedVolume > 0) {
        totalDistance += item.distance;
        totalConsumedVolume += item.consumedVolume;
      }
    }

    if (totalConsumedVolume <= 0) return 0.0;
    return totalDistance / totalConsumedVolume;
  }

  /// Returns the mileage of the most recent eligible full-tank interval.
  static double calculateLastIntervalMileage(List<FuelRecord> records) {
    if (records.length < 2) return 0.0;

    final intervals = calculateIntervalResults(records);
    for (int i = intervals.length - 1; i >= 0; i--) {
      final item = intervals[i];
      if (item.isValidFullTank && item.mileage != null && item.mileage! > 0) {
        return item.mileage!;
      }
    }
    return 0.0;
  }

  /// Calculates average cost per distance unit across all records.
  static double calculateCostPerKm(List<FuelRecord> records) {
    if (records.length < 2) return 0.0;

    final sorted = sortChronological(records);
    final double totalCost = sorted.map((r) => r.paidAmount).reduce((a, b) => a + b);
    final double totalDistance = sorted.last.odometer - sorted.first.odometer;

    if (totalDistance <= 0) return 0.0;
    return totalCost / totalDistance;
  }

  /// Calculates average distance traveled per day between first and last record.
  static double calculateDailyAverageRun(List<FuelRecord> records) {
    if (records.length < 2) return 0.0;

    final sorted = sortChronological(records);
    final double totalDistance = sorted.last.odometer - sorted.first.odometer;
    final int days = sorted.last.date.difference(sorted.first.date).inDays;

    if (days <= 0) return totalDistance;
    return totalDistance / days;
  }

  /// Calculates average fuel cost spent per day between first and last record.
  static double calculateDailyAverageCost(List<FuelRecord> records) {
    if (records.isEmpty) return 0.0;

    final double totalCost = records.map((r) => r.paidAmount).reduce((a, b) => a + b);
    if (records.length < 2) return totalCost;

    final sorted = sortChronological(records);
    final int days = sorted.last.date.difference(sorted.first.date).inDays;

    if (days <= 0) return totalCost;
    return totalCost / days;
  }
}
