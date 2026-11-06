// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/export_page.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MockPdfDatabase extends Fake implements Database {
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'vehicles') {
      return [
        {
          'id': 1,
          'name': 'Toyota Prado',
          'type': VehicleType.suv.toString(),
          'primaryFuelTypeId': 1,
          'primaryFuelCapacity': 87.0,
          'tripMeterMode': 'none',
          'volumeReminderEnabled': 0,
          'volumeReminderValue': 3.0,
          'distanceReminderEnabled': 0,
          'distanceReminderValue': 50.0,
        },
      ];
    }
    if (table == 'fuel_types') {
      return [
        {
          'id': 1,
          'name': 'Octane',
          'category': 'gasoline',
          'unit': 'litre',
        },
      ];
    }
    if (table == 'fuel_records' ||
        table == 'service_sessions' ||
        table == 'non_fuel_expenses' ||
        table == 'saved_locations') {
      return [];
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'export_sequence': 1});
    DatabaseHelper.setDatabaseForTesting(MockPdfDatabase());
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  testWidgets('ExportPage renders PDF Fleet Report section with controls and actions',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExportPage(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.widgetWithText(AppBar, 'Export'), findsOneWidget);

    // Verify CSV section is present
    expect(find.byType(CheckboxListTile), findsNWidgets(5));

    // Verify Printable PDF section is present
    expect(find.text('Printable Tax & Fleet PDF'), findsOneWidget);
    expect(find.text('Audit-ready expense & mileage reports for write-offs'), findsOneWidget);
    expect(find.text('Reporting Date Range'), findsOneWidget);

    // Verify Quick Date Presets
    expect(find.text('Last 30 Days'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('All Time'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Preview & Print'), findsOneWidget);
    expect(find.text('Share PDF'), findsOneWidget);

    // Tap 'All Time' preset chip
    await tester.tap(find.text('All Time'));
    await tester.pumpAndSettle();

    // Tap 'This Month' preset chip
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();
  });
}
