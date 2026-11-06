// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/add_data_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MockGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

class MockDatabase implements Database {
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

  final List<Map<String, Object?>> fuelRecords = [];
  final List<Map<String, Object?>> savedLocations = [];

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
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    if (table == 'fuel_records') {
      final map = Map<String, Object?>.from(values);
      map['id'] = fuelRecords.length + 1;
      fuelRecords.add(map);
      return map['id'] as int;
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GeolocatorPlatform.instance = MockGeolocatorPlatform();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermission') {
          return 0; // LocationPermission.denied
        }
        if (methodCall.method == 'isLocationServiceEnabled') {
          return false;
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator_android'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermission') {
          return 0; // LocationPermission.denied
        }
        if (methodCall.method == 'isLocationServiceEnabled') {
          return false;
        }
        return null;
      },
    );
  });

  testWidgets('AddDataPage bidirectional calculation locks work correctly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockDb = MockDatabase();
    DatabaseHelper.setDatabaseForTesting(mockDb);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en')],
          home: AddDataPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Default target is Paid Amount auto-calculated
    // Enter Rate: 2.0, Volume: 10.0 -> Paid Amount should become 20.00
    final rateFinder = find.widgetWithText(TextFormField, 'Fuel Price/Rate');
    final volumeFinder = find.widgetWithText(TextFormField, 'Total Volume');
    final paidFinder = find.widgetWithText(TextFormField, 'Paid Amount');

    expect(rateFinder, findsOneWidget);
    expect(volumeFinder, findsOneWidget);
    expect(paidFinder, findsOneWidget);

    await tester.enterText(rateFinder, '2.0');
    await tester.enterText(volumeFinder, '10.0');
    await tester.pump(const Duration(milliseconds: 100));

    final paidField = tester.widget<TextFormField>(paidFinder);
    expect(paidField.controller?.text, equals('20.00'));

    // Switch lock to Volume (click lock icon next to Total Volume)
    final volumeLockFinder = find.byTooltip('Click to auto-calculate Volume');
    expect(volumeLockFinder, findsOneWidget);
    await tester.ensureVisible(volumeLockFinder);
    await tester.pumpAndSettle();
    await tester.tap(volumeLockFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // Now enter Paid Amount: 30.0 -> Volume should become 15.00
    await tester.enterText(paidFinder, '30.0');
    await tester.pump(const Duration(milliseconds: 100));

    final volumeField = tester.widget<TextFormField>(volumeFinder);
    expect(volumeField.controller?.text, equals('15.00'));

    // Switch lock to Rate (click lock icon next to Fuel Price/Rate)
    final rateLockFinder = find.byTooltip('Click to auto-calculate Rate');
    expect(rateLockFinder, findsOneWidget);
    await tester.ensureVisible(rateLockFinder);
    await tester.pumpAndSettle();
    await tester.tap(rateLockFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // Now enter Volume: 10.0 and Paid Amount: 25.0 -> Rate should become 2.50
    await tester.enterText(volumeFinder, '10.0');
    await tester.enterText(paidFinder, '25.0');
    await tester.pump(const Duration(milliseconds: 100));

    final rateField = tester.widget<TextFormField>(rateFinder);
    expect(rateField.controller?.text, equals('2.50'));

    DatabaseHelper.setDatabaseForTesting(null);
  });
}
