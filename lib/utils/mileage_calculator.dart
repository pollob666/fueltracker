// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:math' as math;
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';

/// Holds the computed efficiency metrics for a specific fuel record interval.
class IntervalResult {
  final FuelRecord record;
  final double distance;
  final double consumedVolume;
  final double consumedCost;
  final double? mileage;
  final bool isValidFullTank;
  final bool isPartial;
  final bool isMissed;

  const IntervalResult({
    required this.record,
    required this.distance,
    required this.consumedVolume,
    required this.consumedCost,
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
    double pendingPartialCost = 0.0;

    for (final record in sorted) {
      if (record.missedPrevious) {
        // Gap in data: previous fills were missed. Discard pending partials and reset baseline.
        pendingPartialVolume = 0.0;
        pendingPartialCost = 0.0;
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
          consumedCost: record.basePaidAmount,
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
          pendingPartialCost = 0.0;
          results.add(IntervalResult(
            record: record,
            distance: 0.0,
            consumedVolume: record.volume,
            consumedCost: record.basePaidAmount,
            mileage: null,
            isValidFullTank: false,
            isPartial: false,
            isMissed: false,
          ));
        } else {
          pendingPartialVolume += record.volume;
          pendingPartialCost += record.basePaidAmount;
          results.add(IntervalResult(
            record: record,
            distance: 0.0,
            consumedVolume: record.volume,
            consumedCost: record.basePaidAmount,
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
        // Intermediate partial fill: accumulate volume and cost
        pendingPartialVolume += record.volume;
        pendingPartialCost += record.basePaidAmount;
        results.add(IntervalResult(
          record: record,
          distance: 0.0,
          consumedVolume: record.volume,
          consumedCost: record.basePaidAmount,
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
          pendingPartialCost = 0.0;
          results.add(IntervalResult(
            record: record,
            distance: distance,
            consumedVolume: record.volume + pendingPartialVolume,
            consumedCost: record.basePaidAmount + pendingPartialCost,
            mileage: null,
            isValidFullTank: false,
            isPartial: false,
            isMissed: false,
          ));
        } else {
          final totalConsumedVolume = pendingPartialVolume + record.volume;
          final totalConsumedCost = pendingPartialCost + record.basePaidAmount;
          final double? mileage = totalConsumedVolume > 0
              ? distance / totalConsumedVolume
              : null;

          results.add(IntervalResult(
            record: record,
            distance: distance,
            consumedVolume: totalConsumedVolume,
            consumedCost: totalConsumedCost,
            mileage: mileage,
            isValidFullTank: true,
            isPartial: false,
            isMissed: false,
          ));

          // Reset baseline for the next cycle
          pendingPartialVolume = 0.0;
          pendingPartialCost = 0.0;
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

  /// Calculates average cost per distance unit across all eligible intervals (post-baseline).
  static double calculateCostPerKm(List<FuelRecord> records) {
    if (records.length < 2) return 0.0;

    final intervals = calculateIntervalResults(records);
    double totalDistance = 0.0;
    double totalConsumedCost = 0.0;

    for (final item in intervals) {
      if (item.isValidFullTank && item.distance > 0 && item.consumedCost > 0) {
        totalDistance += item.distance;
        totalConsumedCost += item.consumedCost;
      }
    }

    if (totalDistance > 0 && totalConsumedCost > 0) {
      return totalConsumedCost / totalDistance;
    }

    // Fallback if no complete full-to-full cycle yet:
    final sorted = sortChronological(records);
    final totalDistanceAll = sorted.last.odometer - sorted.first.odometer;
    if (totalDistanceAll <= 0) return 0.0;
    final postBaselineCost = sorted.skip(1).map((r) => r.basePaidAmount).fold(0.0, (a, b) => a + b);
    return postBaselineCost > 0
        ? postBaselineCost / totalDistanceAll
        : sorted.map((r) => r.basePaidAmount).reduce((a, b) => a + b) / totalDistanceAll;
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

    final double totalCost = records.map((r) => r.basePaidAmount).reduce((a, b) => a + b);
    if (records.length < 2) return totalCost;

    final sorted = sortChronological(records);
    final int days = sorted.last.date.difference(sorted.first.date).inDays;

    if (days <= 0) return totalCost;
    return totalCost / days;
  }

  /// Calculates the average number of days between consecutive refuel events.
  /// Returns 0.0 if fewer than 2 records are available.
  static double calculateAverageRefuelCadence(List<FuelRecord> records) {
    if (records.length < 2) return 0.0;
    final sorted = sortChronological(records);
    final int totalDays = sorted.last.date.difference(sorted.first.date).inDays;
    final int intervals = sorted.length - 1;
    if (intervals <= 0 || totalDays <= 0) return 0.0;
    return totalDays / intervals;
  }

  /// Calculates weighted running average for records matching a specific driving condition.
  static double calculateConditionAverage(List<FuelRecord> records, DrivingCondition condition) {
    if (records.length < 2) return 0.0;

    final intervals = calculateIntervalResults(records);
    double condDistance = 0.0;
    double condVolume = 0.0;

    for (final item in intervals) {
      if (item.isValidFullTank &&
          item.record.drivingCondition == condition &&
          item.distance > 0 &&
          item.consumedVolume > 0) {
        condDistance += item.distance;
        condVolume += item.consumedVolume;
      }
    }

    if (condVolume <= 0) return 0.0;
    return condDistance / condVolume;
  }

  /// Calculates predictive fuel level and range forecasting for a given vehicle.
  static RefuelPredictionResult calculateRefuelPrediction({
    required Vehicle vehicle,
    required List<FuelRecord> records,
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();
    final bool isVolEn = vehicle.volumeReminderEnabled;
    final bool isDistEn = vehicle.distanceReminderEnabled;
    final double volThresh = vehicle.volumeReminderValue;
    final double distThresh = vehicle.distanceReminderValue;

    final double? primaryCap = vehicle.primaryFuelCapacity;
    if (primaryCap == null || primaryCap <= 0) {
      return RefuelPredictionResult(
        isVolumeEnabled: isVolEn,
        isDistanceEnabled: isDistEn,
        isCalibrated: false,
        isVolumeTriggered: false,
        isDistanceTriggered: false,
        volumeThreshold: volThresh,
        distanceThreshold: distThresh,
      );
    }

    final vehicleRecords =
        records.where((r) => r.vehicleId == vehicle.id).toList();
    if (vehicleRecords.isEmpty) {
      return RefuelPredictionResult(
        isVolumeEnabled: isVolEn,
        isDistanceEnabled: isDistEn,
        isCalibrated: false,
        primaryTankCapacity: primaryCap,
        isVolumeTriggered: false,
        isDistanceTriggered: false,
        volumeThreshold: volThresh,
        distanceThreshold: distThresh,
      );
    }

    final sorted = sortChronological(vehicleRecords);
    final primaryRecords = sorted
        .where((r) => r.fuelTypeId == vehicle.primaryFuelTypeId)
        .toList();
    final int lastFullIdx = primaryRecords.lastIndexWhere((r) => r.isFullTank);

    if (lastFullIdx < 0) {
      return RefuelPredictionResult(
        isVolumeEnabled: isVolEn,
        isDistanceEnabled: isDistEn,
        isCalibrated: false,
        primaryTankCapacity: primaryCap,
        isVolumeTriggered: false,
        isDistanceTriggered: false,
        volumeThreshold: volThresh,
        distanceThreshold: distThresh,
      );
    }

    final fullRecord = primaryRecords[lastFullIdx];
    double runningEffPrimary = calculateWeightedRunningAverage(primaryRecords);
    if (runningEffPrimary <= 0) {
      runningEffPrimary = (vehicle.type == VehicleType.motorcycle ||
              vehicle.type == VehicleType.scooterOrMoped)
          ? 35.0
          : 12.0;
    }

    double currentPrimaryFuel = primaryCap;
    for (int i = lastFullIdx + 1; i < primaryRecords.length; i++) {
      currentPrimaryFuel += primaryRecords[i].volume;
    }

    final latestRecord = sorted.last;
    final double odoDeltaLogged =
        math.max(0.0, latestRecord.odometer - fullRecord.odometer);

    double dailyRun = calculateDailyAverageRun(sorted);
    if (dailyRun <= 0) {
      dailyRun = 20.0;
    }

    final int daysSinceLatest =
        math.max(0, now.difference(latestRecord.date).inDays);
    final double projectedDistanceSinceLatest = daysSinceLatest * dailyRun;
    final double totalDistanceSinceAnchor =
        odoDeltaLogged + projectedDistanceSinceLatest;

    final double fuelBurned = totalDistanceSinceAnchor / runningEffPrimary;
    double primaryRemaining = math.max(0.0, currentPrimaryFuel - fuelBurned);
    if (primaryRemaining > primaryCap) {
      primaryRemaining = primaryCap;
    }

    final double primaryPct = (primaryRemaining / primaryCap) * 100.0;
    final double primaryDte = primaryRemaining * runningEffPrimary;

    double? secRemaining;
    double? secDte;
    if (vehicle.isDualFuel &&
        vehicle.secondaryFuelTypeId != null &&
        vehicle.secondaryFuelCapacity != null &&
        vehicle.secondaryFuelCapacity! > 0) {
      final secCap = vehicle.secondaryFuelCapacity!;
      final secRecords = sorted
          .where((r) => r.fuelTypeId == vehicle.secondaryFuelTypeId)
          .toList();
      if (secRecords.isNotEmpty) {
        final int secLastFullIdx =
            secRecords.lastIndexWhere((r) => r.isFullTank);
        double secEff = calculateWeightedRunningAverage(secRecords);
        if (secEff <= 0) secEff = runningEffPrimary;

        if (secLastFullIdx >= 0) {
          final secAnchor = secRecords[secLastFullIdx];
          double secFuel = secCap;
          for (int i = secLastFullIdx + 1; i < secRecords.length; i++) {
            secFuel += secRecords[i].volume;
          }
          final double secDistLogged =
              math.max(0.0, latestRecord.odometer - secAnchor.odometer);
          final double secTotalDist =
              secDistLogged + projectedDistanceSinceLatest;
          final double secBurned = secTotalDist / secEff;
          secRemaining = math.max(0.0, math.min(secCap, secFuel - secBurned));
          secDte = secRemaining * secEff;
        } else {
          final lastSec = secRecords.last;
          secRemaining = math.max(
              0.0, lastSec.volume - (projectedDistanceSinceLatest / secEff));
          secDte = secRemaining * secEff;
        }
      }
    }

    final double totalDte = primaryDte + (secDte ?? 0.0);

    final bool isVolTriggered =
        isVolEn && (primaryRemaining <= volThresh);
    final bool isDistTriggered =
        isDistEn && (totalDte <= distThresh);

    int? daysLeft;
    DateTime? projectedDate;

    double? kmToThreshold;
    if (isVolEn && isDistEn) {
      final double kmToVol =
          math.max(0.0, (primaryRemaining - volThresh) * runningEffPrimary);
      final double kmToDist = math.max(0.0, totalDte - distThresh);
      kmToThreshold = math.min(kmToVol, kmToDist);
    } else if (isVolEn) {
      kmToThreshold =
          math.max(0.0, (primaryRemaining - volThresh) * runningEffPrimary);
    } else if (isDistEn) {
      kmToThreshold = math.max(0.0, totalDte - distThresh);
    }

    if (kmToThreshold != null) {
      daysLeft = (kmToThreshold / dailyRun).ceil();
      if (daysLeft < 0) daysLeft = 0;
      projectedDate = now.add(Duration(days: daysLeft));
    }

    return RefuelPredictionResult(
      isVolumeEnabled: isVolEn,
      isDistanceEnabled: isDistEn,
      isCalibrated: true,
      primaryRemainingFuel: primaryRemaining,
      primaryTankCapacity: primaryCap,
      primaryFuelPercentage: primaryPct,
      primaryDte: primaryDte,
      secondaryRemainingFuel: secRemaining,
      secondaryDte: secDte,
      totalDte: totalDte,
      daysRemaining: daysLeft,
      projectedRefuelDate: projectedDate,
      isVolumeTriggered: isVolTriggered,
      isDistanceTriggered: isDistTriggered,
      volumeThreshold: volThresh,
      distanceThreshold: distThresh,
    );
  }

  /// Evaluates the most recent eligible full-tank interval against rolling efficiency.
  /// Detects drops (>15% below rolling average) or boosts (>15% above rolling average).
  static MileageAnomalyResult? checkMileageAnomaly(List<FuelRecord> records) {
    if (records.length < 2) return null;

    final sorted = sortChronological(records);
    final intervals = calculateIntervalResults(sorted);

    IntervalResult? latestFullTank;
    int latestIntervalIdx = -1;
    for (int i = intervals.length - 1; i >= 0; i--) {
      if (intervals[i].isValidFullTank && intervals[i].mileage != null && intervals[i].mileage! > 0) {
        latestFullTank = intervals[i];
        latestIntervalIdx = i;
        break;
      }
    }

    if (latestFullTank == null || latestIntervalIdx < 0) return null;

    // Find the baseline record for this interval
    FuelRecord? baselineRecord;
    for (int i = latestIntervalIdx - 1; i >= 0; i--) {
      if (sorted[i].isFullTank && !sorted[i].missedPrevious) {
        baselineRecord = sorted[i];
        break;
      }
    }

    // Historical records strictly prior to this cycle to establish baseline rolling average
    final priorRecords = sorted.take(latestIntervalIdx).toList();
    double runningAverage = 0.0;
    if (priorRecords.length >= 2) {
      runningAverage = calculateWeightedRunningAverage(priorRecords);
    }

    if (runningAverage <= 0.0) {
      // Fallback: entire dataset
      runningAverage = calculateWeightedRunningAverage(sorted);
    }

    if (runningAverage <= 0.0) return null;

    final double intervalMileage = latestFullTank.mileage!;
    final double percentageChange = ((intervalMileage - runningAverage) / runningAverage) * 100.0;

    final bool isDrop = percentageChange <= -15.0;
    final bool isBoost = percentageChange >= 15.0;

    return MileageAnomalyResult(
      isDrop: isDrop,
      isBoost: isBoost,
      intervalMileage: intervalMileage,
      runningAverage: runningAverage,
      percentageChange: percentageChange,
      baselineRecord: baselineRecord,
      currentRecord: latestFullTank.record,
    );
  }

  /// Computes carbon footprint (kg CO2) using standard emission factors:
  /// - Gasoline: 2.31 kg/L
  /// - Diesel: 2.68 kg/L
  /// - Gas (CNG): 2.75 kg/m3 (or 1.51 kg/L for LPG)
  static CarbonFootprintResult calculateCarbonFootprint(
    List<FuelRecord> records, {
    Map<int, FuelType>? fuelTypeMap,
  }) {
    double totalCo2 = 0.0;
    double totalVolume = 0.0;
    double totalDistance = 0.0;

    for (final record in records) {
      final fuelType = fuelTypeMap?[record.fuelTypeId];
      double factor = 2.31;
      if (fuelType != null) {
        switch (fuelType.category) {
          case FuelCategory.diesel:
            factor = 2.68;
            break;
          case FuelCategory.gas:
            factor = fuelType.name.toLowerCase().contains('lpg') ? 1.51 : 2.75;
            break;
          case FuelCategory.gasoline:
            factor = 2.31;
            break;
          case FuelCategory.electricity:
            factor = 0.0; // 0 direct tailpipe emissions
            break;
        }
      }
      totalCo2 += record.volume * factor;
      totalVolume += record.volume;
    }

    double postBaselineCo2 = 0.0;
    if (records.isNotEmpty) {
      final sorted = sortChronological(records);
      final intervals = calculateIntervalResults(sorted);
      for (final interval in intervals) {
        if (interval.isValidFullTank && interval.distance > 0) {
          totalDistance += interval.distance;
          final fuelType = fuelTypeMap?[interval.record.fuelTypeId];
          double factor = 2.31;
          if (fuelType != null) {
            switch (fuelType.category) {
              case FuelCategory.diesel:
                factor = 2.68;
                break;
              case FuelCategory.gas:
                factor = fuelType.name.toLowerCase().contains('lpg') ? 1.51 : 2.75;
                break;
              case FuelCategory.gasoline:
                factor = 2.31;
                break;
              case FuelCategory.electricity:
                factor = 0.0;
                break;
            }
          }
          postBaselineCo2 += interval.consumedVolume * factor;
        }
      }
    }

    double? gramsPerKm;
    String ecoRating = 'N/A';
    if (totalDistance > 0) {
      final effectiveCo2 = postBaselineCo2 > 0 ? postBaselineCo2 : totalCo2;
      gramsPerKm = (effectiveCo2 * 1000.0) / totalDistance;
      if (gramsPerKm < 120) {
        ecoRating = 'A+';
      } else if (gramsPerKm < 160) {
        ecoRating = 'A';
      } else if (gramsPerKm < 200) {
        ecoRating = 'B';
      } else if (gramsPerKm < 250) {
        ecoRating = 'C';
      } else {
        ecoRating = 'D';
      }
    }

    final treeCount = (totalCo2 / 22.0).ceil();

    return CarbonFootprintResult(
      totalCo2Kg: totalCo2,
      totalVolume: totalVolume,
      totalDistance: totalDistance,
      gramsCo2PerKm: gramsPerKm,
      treeOffsetCount: math.max(0, treeCount),
      ecoRating: ecoRating,
    );
  }
}

/// Holds computed CO2 emissions and environmental metrics.
class CarbonFootprintResult {
  final double totalCo2Kg;
  final double totalVolume;
  final double totalDistance;
  final double? gramsCo2PerKm;
  final int treeOffsetCount;
  final String ecoRating;

  const CarbonFootprintResult({
    required this.totalCo2Kg,
    required this.totalVolume,
    required this.totalDistance,
    required this.gramsCo2PerKm,
    required this.treeOffsetCount,
    required this.ecoRating,
  });
}

/// Represents the calculated forecast and warning states for a vehicle's refuel status.
class RefuelPredictionResult {
  final bool isVolumeEnabled;
  final bool isDistanceEnabled;
  final bool isCalibrated;
  final double? primaryRemainingFuel;
  final double? primaryTankCapacity;
  final double? primaryFuelPercentage;
  final double? primaryDte;
  final double? secondaryRemainingFuel;
  final double? secondaryDte;
  final double? totalDte;
  final int? daysRemaining;
  final DateTime? projectedRefuelDate;
  final bool isVolumeTriggered;
  final bool isDistanceTriggered;
  final double volumeThreshold;
  final double distanceThreshold;

  const RefuelPredictionResult({
    required this.isVolumeEnabled,
    required this.isDistanceEnabled,
    required this.isCalibrated,
    this.primaryRemainingFuel,
    this.primaryTankCapacity,
    this.primaryFuelPercentage,
    this.primaryDte,
    this.secondaryRemainingFuel,
    this.secondaryDte,
    this.totalDte,
    this.daysRemaining,
    this.projectedRefuelDate,
    required this.isVolumeTriggered,
    required this.isDistanceTriggered,
    required this.volumeThreshold,
    required this.distanceThreshold,
  });

  bool get isAlertActive =>
      (isVolumeEnabled && isVolumeTriggered) ||
      (isDistanceEnabled && isDistanceTriggered);

  bool get hasAnyReminderEnabled => isVolumeEnabled || isDistanceEnabled;
}

/// Represents the evaluation of interval efficiency against running average for anomalies or boosts.
class MileageAnomalyResult {
  final bool isDrop;
  final bool isBoost;
  final double intervalMileage;
  final double runningAverage;
  final double percentageChange;
  final FuelRecord? baselineRecord;
  final FuelRecord currentRecord;

  const MileageAnomalyResult({
    required this.isDrop,
    required this.isBoost,
    required this.intervalMileage,
    required this.runningAverage,
    required this.percentageChange,
    this.baselineRecord,
    required this.currentRecord,
  });

  bool get hasAnomaly => isDrop || isBoost;
}
