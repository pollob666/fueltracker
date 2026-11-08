// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:fuel_tracker/services/analytics_service.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

final selectedTimeWindowProvider =
    StateProvider.autoDispose<AnalyticsTimeWindow>((ref) => AnalyticsTimeWindow.allTime);

final customAnalyticsDateRangeProvider =
    StateProvider.autoDispose<DateTimeRange?>((ref) => null);

final savedLocationsMapProvider =
    FutureProvider.autoDispose<Map<int, SavedLocation>>((ref) async {
  final locations = await DatabaseHelper.instance.getSavedLocations();
  return {for (var loc in locations) if (loc.id != null) loc.id!: loc};
});

final fuelTypesMapProvider =
    FutureProvider.autoDispose<Map<int, FuelType>>((ref) async {
  final service = FuelTypeService();
  final list = await service.getFuelTypes();
  return {for (var ft in list) if (ft.id != null) ft.id!: ft};
});

final filteredAnalyticsRecordsProvider =
    Provider.autoDispose.family<List<FuelRecord>, int>((ref, vehicleId) {
  final recordsAsync = ref.watch(fuelRecordsProvider(vehicleId));
  final timeWindow = ref.watch(selectedTimeWindowProvider);
  final customRange = ref.watch(customAnalyticsDateRangeProvider);

  return recordsAsync.maybeWhen(
    data: (records) => AnalyticsService.filterByTimeWindow(
      records,
      timeWindow,
      customRange: customRange,
    ),
    orElse: () => [],
  );
});

final priceTrendsProvider =
    Provider.autoDispose.family<Map<int, List<PriceTrendPoint>>, int>((ref, vehicleId) {
  final records = ref.watch(filteredAnalyticsRecordsProvider(vehicleId));
  final locations = ref.watch(savedLocationsMapProvider).value ?? {};
  return AnalyticsService.computePriceTrends(records, locationMap: locations);
});

final stationEfficiencyPointsProvider =
    Provider.autoDispose.family<List<StationEfficiencyPoint>, int>((ref, vehicleId) {
  final records = ref.watch(filteredAnalyticsRecordsProvider(vehicleId));
  final locations = ref.watch(savedLocationsMapProvider).value ?? {};
  return AnalyticsService.computeStationEfficiency(records, locationMap: locations);
});

final conditionDeltaProvider =
    Provider.autoDispose.family<ConditionDeltaSummary, int>((ref, vehicleId) {
  final records = ref.watch(filteredAnalyticsRecordsProvider(vehicleId));
  return AnalyticsService.computeConditionDelta(records);
});

final carbonFootprintProvider =
    Provider.autoDispose.family<CarbonFootprintResult, int>((ref, vehicleId) {
  final records = ref.watch(filteredAnalyticsRecordsProvider(vehicleId));
  final fuelTypes = ref.watch(fuelTypesMapProvider).value ?? {};
  return MileageCalculator.calculateCarbonFootprint(records, fuelTypeMap: fuelTypes);
});
