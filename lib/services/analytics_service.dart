// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

enum AnalyticsTimeWindow {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  allTime,
  custom,
}

class PriceTrendPoint {
  final DateTime date;
  final double rate;
  final double movingAverageRate;
  final int fuelTypeId;
  final String? stationName;
  final double volume;
  final double paidAmount;
  final FuelRecord? record;

  const PriceTrendPoint({
    required this.date,
    required this.rate,
    required this.movingAverageRate,
    required this.fuelTypeId,
    this.stationName,
    required this.volume,
    required this.paidAmount,
    this.record,
  });
}

class StationEfficiencyPoint {
  final int intervalIndex;
  final DateTime date;
  final double intervalMileage;
  final double runningAverage;
  final double deltaPercent;
  final String? stationName;
  final bool isSuspect;
  final bool isBoost;
  final FuelRecord record;

  const StationEfficiencyPoint({
    required this.intervalIndex,
    required this.date,
    required this.intervalMileage,
    required this.runningAverage,
    required this.deltaPercent,
    this.stationName,
    required this.isSuspect,
    required this.isBoost,
    required this.record,
  });
}

class ConditionMetric {
  final double mileage;
  final double costPerKm;
  final double totalVolume;
  final double totalDistance;
  final double totalCost;
  final int recordCount;

  const ConditionMetric({
    required this.mileage,
    required this.costPerKm,
    required this.totalVolume,
    required this.totalDistance,
    required this.totalCost,
    required this.recordCount,
  });

  static const empty = ConditionMetric(
    mileage: 0.0,
    costPerKm: 0.0,
    totalVolume: 0.0,
    totalDistance: 0.0,
    totalCost: 0.0,
    recordCount: 0,
  );
}

class ConditionDeltaSummary {
  final ConditionMetric city;
  final ConditionMetric highway;
  final ConditionMetric mixed;

  const ConditionDeltaSummary({
    required this.city,
    required this.highway,
    required this.mixed,
  });

  static const empty = ConditionDeltaSummary(
    city: ConditionMetric.empty,
    highway: ConditionMetric.empty,
    mixed: ConditionMetric.empty,
  );
}

class AnalyticsService {
  /// Filters records according to the selected time window relative to now (or latest record date).
  static List<FuelRecord> filterByTimeWindow(
    List<FuelRecord> records,
    AnalyticsTimeWindow window, {
    DateTime? anchorDate,
    DateTimeRange? customRange,
  }) {
    if (records.isEmpty) {
      return records;
    }

    if (window == AnalyticsTimeWindow.custom && customRange != null) {
      final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
      final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);
      return records.where((r) => !r.date.isBefore(start) && !r.date.isAfter(end)).toList();
    }

    if (window == AnalyticsTimeWindow.allTime) {
      return records;
    }

    final latest = anchorDate ??
        records.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);

    DateTime cutoff;
    switch (window) {
      case AnalyticsTimeWindow.oneMonth:
        cutoff = DateTime(latest.year, latest.month - 1, latest.day);
        break;
      case AnalyticsTimeWindow.threeMonths:
        cutoff = DateTime(latest.year, latest.month - 3, latest.day);
        break;
      case AnalyticsTimeWindow.sixMonths:
        cutoff = DateTime(latest.year, latest.month - 6, latest.day);
        break;
      case AnalyticsTimeWindow.oneYear:
        cutoff = DateTime(latest.year - 1, latest.month, latest.day);
        break;
      case AnalyticsTimeWindow.allTime:
      case AnalyticsTimeWindow.custom:
        return records;
    }

    return records.where((r) => !r.date.isBefore(cutoff)).toList();
  }

  /// Extracts fuel price fluctuation trend points for each fuel type with 30-day moving average.
  static Map<int, List<PriceTrendPoint>> computePriceTrends(
    List<FuelRecord> records, {
    Map<int, SavedLocation>? locationMap,
  }) {
    final sorted = MileageCalculator.sortChronological(records);
    final byFuelType = <int, List<FuelRecord>>{};

    for (final r in sorted) {
      byFuelType.putIfAbsent(r.fuelTypeId, () => []).add(r);
    }

    final result = <int, List<PriceTrendPoint>>{};

    byFuelType.forEach((fuelTypeId, typeRecords) {
      final points = <PriceTrendPoint>[];
      for (int i = 0; i < typeRecords.length; i++) {
        final current = typeRecords[i];
        final stationName = (locationMap != null && current.locationId != null)
            ? locationMap[current.locationId]?.name
            : null;

        // 30-day moving average (all records within 30 days prior to current.date)
        final windowStart = current.date.subtract(const Duration(days: 30));
        final windowRecords = typeRecords
            .sublist(0, i + 1)
            .where((r) => !r.date.isBefore(windowStart))
            .toList();

        final avgRate = windowRecords.isNotEmpty
            ? windowRecords.map((r) => r.rate).reduce((a, b) => a + b) /
                windowRecords.length
            : current.rate;

        points.add(PriceTrendPoint(
          date: current.date,
          rate: current.rate,
          movingAverageRate: avgRate,
          fuelTypeId: fuelTypeId,
          stationName: stationName,
          volume: current.volume,
          paidAmount: current.paidAmount,
          record: current,
        ));
      }
      result[fuelTypeId] = points;
    });

    return result;
  }

  /// Extracts station efficiency scatter points comparing interval efficiency against vehicle running average.
  static List<StationEfficiencyPoint> computeStationEfficiency(
    List<FuelRecord> records, {
    Map<int, SavedLocation>? locationMap,
  }) {
    final sorted = MileageCalculator.sortChronological(records);
    final intervals = MileageCalculator.calculateIntervalResults(sorted);
    final runningAverage = MileageCalculator.calculateWeightedRunningAverage(sorted);

    final points = <StationEfficiencyPoint>[];
    int validIndex = 0;

    for (int i = 0; i < intervals.length; i++) {
      final interval = intervals[i];
      if (interval.mileage == null || interval.mileage! <= 0) continue;

      validIndex++;
      final mileage = interval.mileage!;
      final deltaPercent = runningAverage > 0
          ? ((mileage - runningAverage) / runningAverage) * 100.0
          : 0.0;

      final isSuspect = deltaPercent <= -15.0;
      final isBoost = deltaPercent >= 15.0;

      // Note: At refueling event N, interval fuel economy reflects fuel purchased at fill-up N-1.
      final stationRecord = i > 0 ? sorted[i - 1] : interval.record;
      final stationName = (locationMap != null && stationRecord.locationId != null)
          ? locationMap[stationRecord.locationId]?.name
          : null;

      points.add(StationEfficiencyPoint(
        intervalIndex: validIndex,
        date: interval.record.date,
        intervalMileage: mileage,
        runningAverage: runningAverage,
        deltaPercent: deltaPercent,
        stationName: stationName,
        isSuspect: isSuspect,
        isBoost: isBoost,
        record: interval.record,
      ));
    }

    return points;
  }

  /// Calculates segregated consumption and monetary cost across driving conditions.
  static ConditionDeltaSummary computeConditionDelta(List<FuelRecord> records) {
    final sorted = MileageCalculator.sortChronological(records);
    final intervals = MileageCalculator.calculateIntervalResults(sorted);

    double cityDistance = 0.0, cityVolume = 0.0, cityCost = 0.0;
    int cityCount = 0;

    double highwayDistance = 0.0, highwayVolume = 0.0, highwayCost = 0.0;
    int highwayCount = 0;

    double mixedDistance = 0.0, mixedVolume = 0.0, mixedCost = 0.0;
    int mixedCount = 0;

    for (final interval in intervals) {
      if (!interval.isValidFullTank || interval.distance <= 0 || interval.consumedVolume <= 0) {
        continue;
      }

      final record = interval.record;
      final distance = interval.distance;
      final volume = interval.consumedVolume;
      final cost = interval.consumedCost;

      switch (record.drivingCondition) {
        case DrivingCondition.city:
          cityDistance += distance;
          cityVolume += volume;
          cityCost += cost;
          cityCount++;
          break;
        case DrivingCondition.highway:
          highwayDistance += distance;
          highwayVolume += volume;
          highwayCost += cost;
          highwayCount++;
          break;
        case DrivingCondition.mixed:
          mixedDistance += distance;
          mixedVolume += volume;
          mixedCost += cost;
          mixedCount++;
          break;
      }
    }

    return ConditionDeltaSummary(
      city: ConditionMetric(
        mileage: cityVolume > 0 && cityDistance > 0 ? cityDistance / cityVolume : 0.0,
        costPerKm: cityDistance > 0 ? cityCost / cityDistance : 0.0,
        totalVolume: cityVolume,
        totalDistance: cityDistance,
        totalCost: cityCost,
        recordCount: cityCount,
      ),
      highway: ConditionMetric(
        mileage: highwayVolume > 0 && highwayDistance > 0 ? highwayDistance / highwayVolume : 0.0,
        costPerKm: highwayDistance > 0 ? highwayCost / highwayDistance : 0.0,
        totalVolume: highwayVolume,
        totalDistance: highwayDistance,
        totalCost: highwayCost,
        recordCount: highwayCount,
      ),
      mixed: ConditionMetric(
        mileage: mixedVolume > 0 && mixedDistance > 0 ? mixedDistance / mixedVolume : 0.0,
        costPerKm: mixedDistance > 0 ? mixedCost / mixedDistance : 0.0,
        totalVolume: mixedVolume,
        totalDistance: mixedDistance,
        totalCost: mixedCost,
        recordCount: mixedCount,
      ),
    );
  }
}
