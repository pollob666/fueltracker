// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/import_dry_run_sheet.dart';

void main() {
  test('ImportDryRunSheet computeFingerprint is deterministic and unique', () {
    final fp1 = ImportDryRunSheet.computeFingerprint(
      vehicleId: 1,
      date: DateTime.parse('2026-05-10T12:00:00'),
      odometer: 15420.0,
      volume: 45.2,
    );

    final fp2 = ImportDryRunSheet.computeFingerprint(
      vehicleId: 1,
      date: DateTime.parse('2026-05-10T08:30:00'), // same day
      odometer: 15420.0,
      volume: 45.2,
    );

    final fpDifferent = ImportDryRunSheet.computeFingerprint(
      vehicleId: 2, // different vehicle
      date: DateTime.parse('2026-05-10T12:00:00'),
      odometer: 15420.0,
      volume: 45.2,
    );

    expect(fp1, equals(fp2)); // Same day, odo, vol, vehicle -> same fingerprint
    expect(fp1, isNot(equals(fpDifferent)));
  });

  testWidgets('ImportDryRunSheet renders stats and switches conflict strategy', (tester) async {
    final existing = FuelRecord(
      id: 10,
      date: DateTime.parse('2026-01-01'),
      odometer: 1000.0,
      fuelTypeId: 1,
      vehicleId: 1,
      rate: 130.0,
      volume: 30.0,
      paidAmount: 3900.0,
    );

    final duplicateEntry = FuelRecord(
      date: DateTime.parse('2026-01-01'),
      odometer: 1000.0,
      fuelTypeId: 1,
      vehicleId: 1,
      rate: 130.0,
      volume: 30.0,
      paidAmount: 3900.0,
    );

    final newEntry = FuelRecord(
      date: DateTime.parse('2026-01-05'),
      odometer: 1500.0,
      fuelTypeId: 1,
      vehicleId: 1,
      rate: 130.0,
      volume: 25.0,
      paidAmount: 3250.0,
    );

    final summary = ImportDryRunSummary(
      newRecords: [newEntry],
      duplicatePairs: [MapEntry(duplicateEntry, existing)],
      totalFound: 2,
      corruptedCount: 0,
    );

    ConflictStrategy? chosenStrategy;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportDryRunSheet(
            summary: summary,
            onCommit: (strategy) async {
              chosenStrategy = strategy;
            },
          ),
        ),
      ),
    );

    expect(find.text('Import Preview'), findsOneWidget);
    expect(find.text('2 found'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Duplicates'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // 1 new, 1 duplicate

    // Default strategy is skip (1 record to commit)
    expect(find.text('Commit 1 Records'), findsOneWidget);

    // Switch to Overwrite
    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();
    expect(find.text('Commit 2 Records'), findsOneWidget);

    // Tap Commit
    await tester.tap(find.text('Commit 2 Records'));
    await tester.pumpAndSettle();
    expect(chosenStrategy, equals(ConflictStrategy.overwrite));
  });
}
