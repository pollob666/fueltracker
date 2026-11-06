// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/all_data_page.dart';
import 'package:sqflite/sqflite.dart';

class MockAllDataDatabase implements Database {
  final List<Map<String, Object?>> vehicles = [
    {
      'id': 1,
      'name': 'Corolla',
      'type': VehicleType.carOrSedan.toString(),
      'primaryFuelTypeId': 1,
      'primaryFuelCapacity': 50.0,
      'tripMeterMode': 'none',
      'volumeReminderEnabled': 0,
      'volumeReminderValue': 3.0,
      'distanceReminderEnabled': 0,
      'distanceReminderValue': 50.0,
    }
  ];

  final List<Map<String, Object?>> fuelTypes = [
    {
      'id': 1,
      'name': 'Octane',
      'category': FuelCategory.gasoline.toString(),
      'unit': FuelUnit.litre.toString(),
    }
  ];

  final List<Map<String, Object?>> savedLocations = [
    {
      'id': 10,
      'name': 'Padma Fuel Station',
      'isNamed': 1,
      'type': 'fuel_station',
      'latitude': 23.81,
      'longitude': 90.41,
      'radiusMeters': 80.0,
      'isSuspectFuel': 0,
      'isSuspectServiceOrParts': 0,
      'isRecommendedFuel': 0,
      'isRecommendedServiceOrParts': 0,
      'createdAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 20,
      'name': 'Meghna Oil Depot',
      'isNamed': 1,
      'type': 'fuel_station',
      'latitude': 23.82,
      'longitude': 90.42,
      'radiusMeters': 80.0,
      'isSuspectFuel': 0,
      'isSuspectServiceOrParts': 0,
      'isRecommendedFuel': 0,
      'isRecommendedServiceOrParts': 0,
      'createdAt': '2026-01-01T00:00:00Z',
    }
  ];

  final List<Map<String, Object?>> fuelRecords = [
    {
      'id': 1,
      'vehicleId': 1,
      'fuelTypeId': 1,
      'date': '2026-10-01T10:00:00Z',
      'odometer': 10000.0,
      'volume': 30.0,
      'paidAmount': 3900.0,
      'rate': 130.0,
      'isFullTank': 1,
      'missedPrevious': 0,
      'locationId': 10,
      'drivingCondition': DrivingCondition.city.name,
    },
    {
      'id': 2,
      'vehicleId': 1,
      'fuelTypeId': 1,
      'date': '2026-10-15T15:30:00Z',
      'odometer': 10450.0,
      'volume': 34.0,
      'paidAmount': 4420.0,
      'rate': 130.0,
      'isFullTank': 1,
      'missedPrevious': 0,
      'locationId': 20,
      'drivingCondition': DrivingCondition.highway.name,
    },
  ];

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
    if (table == 'vehicles') return vehicles;
    if (table == 'fuel_types') return fuelTypes;
    if (table == 'fuel_records') return fuelRecords;
    if (table == 'saved_locations') return savedLocations;
    return [];
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (table == 'fuel_records') {
      final id = whereArgs?.first as int?;
      fuelRecords.removeWhere((r) => r['id'] == id);
      return 1;
    }
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockAllDataDatabase mockDb;

  setUp(() {
    mockDb = MockAllDataDatabase();
    DatabaseHelper.setDatabaseForTesting(mockDb);
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  testWidgets('AllDataPage renders timeline cards, search filtering, and table switcher',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AllDataPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & View Switcher
    expect(find.text('All Data'), findsOneWidget);
    expect(find.byType(SegmentedButton<HistoryViewMode>), findsOneWidget);

    // Verify Cards Mode by default
    expect(find.text('Padma Fuel Station'), findsOneWidget);
    expect(find.text('Meghna Oil Depot'), findsOneWidget);
    expect(find.text('10450.0 km'), findsOneWidget);
    expect(find.text('10000.0 km'), findsOneWidget);

    // Verify summary stats bar
    expect(find.text('2 records'), findsOneWidget);

    // Test Search Filtering: search "Padma"
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Padma');
    await tester.pumpAndSettle();

    expect(find.text('Padma Fuel Station'), findsOneWidget);
    expect(find.text('Meghna Oil Depot'), findsNothing);
    expect(find.text('1 records'), findsOneWidget);

    // Clear search
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();
    expect(find.text('Meghna Oil Depot'), findsOneWidget);

    // Switch View Mode to Table
    final tableSegment = find.byIcon(Icons.table_chart_outlined);
    expect(tableSegment, findsOneWidget);
    await tester.tap(tableSegment);
    await tester.pumpAndSettle();

    // Verify DataTable is rendered
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);

    // Switch back to Cards
    final cardsSegment = find.byIcon(Icons.view_agenda_outlined);
    await tester.tap(cardsSegment);
    await tester.pumpAndSettle();

    // Tap on card to open action sheet
    await tester.tap(find.text('Padma Fuel Station'));
    await tester.pumpAndSettle();

    // Verify bottom sheet options
    expect(find.text('Edit Record'), findsOneWidget);
    expect(find.text('Delete Record'), findsOneWidget);
  });
}
