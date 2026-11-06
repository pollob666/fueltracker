// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/repositories/fuel_record_repository.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

final fuelRecordRepositoryProvider = Provider<FuelRecordRepository>((ref) {
  final repo = SqliteFuelRecordRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

final fuelRecordsProvider =
    StreamProvider.autoDispose.family<List<FuelRecord>, int>((ref, vehicleId) {
  final repo = ref.watch(fuelRecordRepositoryProvider);
  return repo.watchFuelRecords(vehicleId);
});

final allFuelRecordsProvider =
    FutureProvider.autoDispose<List<FuelRecord>>((ref) async {
  final repo = ref.watch(fuelRecordRepositoryProvider);
  return repo.getFuelRecords();
});

final vehicleIntervalResultsProvider =
    Provider.autoDispose.family<List<IntervalResult>, int>((ref, vehicleId) {
  final recordsAsync = ref.watch(fuelRecordsProvider(vehicleId));
  return recordsAsync.maybeWhen(
    data: (records) => MileageCalculator.calculateIntervalResults(records),
    orElse: () => [],
  );
});

final vehicleRunningAverageProvider =
    Provider.autoDispose.family<double, int>((ref, vehicleId) {
  final recordsAsync = ref.watch(fuelRecordsProvider(vehicleId));
  return recordsAsync.maybeWhen(
    data: (records) => MileageCalculator.calculateWeightedRunningAverage(records),
    orElse: () => 0.0,
  );
});

final vehicleCostPerKmProvider =
    Provider.autoDispose.family<double, int>((ref, vehicleId) {
  final recordsAsync = ref.watch(fuelRecordsProvider(vehicleId));
  return recordsAsync.maybeWhen(
    data: (records) => MileageCalculator.calculateCostPerKm(records),
    orElse: () => 0.0,
  );
});
