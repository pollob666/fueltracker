// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:fuel_tracker/repositories/non_fuel_expense_repository.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

final nonFuelExpenseRepositoryProvider = Provider<NonFuelExpenseRepository>((ref) {
  final repo = SqliteNonFuelExpenseRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

final nonFuelExpensesProvider =
    StreamProvider.autoDispose.family<List<NonFuelExpense>, int>((ref, vehicleId) {
  final repo = ref.watch(nonFuelExpenseRepositoryProvider);
  return repo.watchNonFuelExpenses(vehicleId);
});

final serviceSessionsProvider =
    FutureProvider.autoDispose.family<List<ServiceSession>, int>((ref, vehicleId) async {
  return await DatabaseHelper.instance.getServiceSessions(vehicleId);
});

class MonthlyTcoDataPoint {
  final DateTime month; // First day of the month
  final double fuelSpend;
  final double serviceSpend;
  final double nonFuelSpend;
  final double distance;

  const MonthlyTcoDataPoint({
    required this.month,
    required this.fuelSpend,
    required this.serviceSpend,
    required this.nonFuelSpend,
    required this.distance,
  });

  double get totalSpend => fuelSpend + serviceSpend + nonFuelSpend;

  double get costPerKm => distance > 0 ? totalSpend / distance : 0.0;
}

class TcoOverviewSummary {
  final double totalFuelSpend;
  final double totalServiceSpend;
  final double totalNonFuelSpend;
  final double totalDistance;
  final List<MonthlyTcoDataPoint> monthlyData;

  const TcoOverviewSummary({
    required this.totalFuelSpend,
    required this.totalServiceSpend,
    required this.totalNonFuelSpend,
    required this.totalDistance,
    required this.monthlyData,
  });

  double get totalSpend => totalFuelSpend + totalServiceSpend + totalNonFuelSpend;
  double get allInclusiveCostPerKm => totalDistance > 0 ? totalSpend / totalDistance : 0.0;

  static const empty = TcoOverviewSummary(
    totalFuelSpend: 0.0,
    totalServiceSpend: 0.0,
    totalNonFuelSpend: 0.0,
    totalDistance: 0.0,
    monthlyData: [],
  );
}

final tcoOverviewProvider =
    Provider.autoDispose.family<TcoOverviewSummary, int>((ref, vehicleId) {
  final fuelRecords = ref.watch(fuelRecordsProvider(vehicleId)).value ?? [];
  final nonFuelExpenses = ref.watch(nonFuelExpensesProvider(vehicleId)).value ?? [];
  final serviceSessions = ref.watch(serviceSessionsProvider(vehicleId)).value ?? [];

  if (fuelRecords.isEmpty && nonFuelExpenses.isEmpty && serviceSessions.isEmpty) {
    return TcoOverviewSummary.empty;
  }

  // Group by year and month: key format 'YYYY-MM'
  final monthMap = <String, Map<String, double>>{};

  void ensureMonth(DateTime d) {
    final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
    monthMap.putIfAbsent(key, () => {
          'fuel': 0.0,
          'service': 0.0,
          'nonFuel': 0.0,
          'distance': 0.0,
        });
  }

  // 1. Process Fuel Records
  double totalFuelSpend = 0.0;
  for (final r in fuelRecords) {
    ensureMonth(r.date);
    final key = '${r.date.year.toString().padLeft(4, '0')}-${r.date.month.toString().padLeft(2, '0')}';
    monthMap[key]!['fuel'] = monthMap[key]!['fuel']! + r.paidAmount;
    totalFuelSpend += r.paidAmount;
  }

  // Compute interval distances
  double totalDistance = 0.0;
  if (fuelRecords.isNotEmpty) {
    final sorted = MileageCalculator.sortChronological(fuelRecords);
    final intervals = MileageCalculator.calculateIntervalResults(sorted);
    for (final inv in intervals) {
      if (inv.distance > 0) {
        final d = inv.record.date;
        ensureMonth(d);
        final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
        monthMap[key]!['distance'] = monthMap[key]!['distance']! + inv.distance;
        totalDistance += inv.distance;
      }
    }
  }

  // 2. Process Service Sessions
  double totalServiceSpend = 0.0;
  for (final s in serviceSessions) {
    ensureMonth(s.serviceDate);
    final key = '${s.serviceDate.year.toString().padLeft(4, '0')}-${s.serviceDate.month.toString().padLeft(2, '0')}';
    final cost = s.totalCost ?? 0.0;
    monthMap[key]!['service'] = monthMap[key]!['service']! + cost;
    totalServiceSpend += cost;
  }

  // 3. Process Non-Fuel Expenses
  double totalNonFuelSpend = 0.0;
  for (final nfe in nonFuelExpenses) {
    ensureMonth(nfe.date);
    final key = '${nfe.date.year.toString().padLeft(4, '0')}-${nfe.date.month.toString().padLeft(2, '0')}';
    monthMap[key]!['nonFuel'] = monthMap[key]!['nonFuel']! + nfe.amount;
    totalNonFuelSpend += nfe.amount;
  }

  final sortedKeys = monthMap.keys.toList()..sort();
  final monthlyData = sortedKeys.map((k) {
    final parts = k.split('-');
    final monthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    final entry = monthMap[k]!;
    return MonthlyTcoDataPoint(
      month: monthDate,
      fuelSpend: entry['fuel']!,
      serviceSpend: entry['service']!,
      nonFuelSpend: entry['nonFuel']!,
      distance: entry['distance']!,
    );
  }).toList();

  return TcoOverviewSummary(
    totalFuelSpend: totalFuelSpend,
    totalServiceSpend: totalServiceSpend,
    totalNonFuelSpend: totalNonFuelSpend,
    totalDistance: totalDistance,
    monthlyData: monthlyData,
  );
});
