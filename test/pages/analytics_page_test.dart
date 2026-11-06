// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/analytics_page.dart';
import 'package:fuel_tracker/providers/analytics_providers.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:fuel_tracker/providers/vehicle_providers.dart';

class MockVehiclesNotifier extends VehiclesNotifier {
  final List<Vehicle> initial;
  MockVehiclesNotifier(this.initial);

  @override
  Future<List<Vehicle>> build() async => initial;
}

void main() {
  testWidgets('AnalyticsPage renders with vehicles, time chips, and charts',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));

    final testVehicles = [
      Vehicle(
        id: 1,
        name: 'Toyota Corolla',
        type: VehicleType.carOrSedan,
        primaryFuelTypeId: 1,
        primaryFuelCapacity: 50.0,
      ),
    ];

    final testRecords = <FuelRecord>[
      FuelRecord(
        id: 1,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 1),
        odometer: 10000,
        rate: 130,
        volume: 30,
        paidAmount: 3900,
        isFullTank: true,
        missedPrevious: false,
        drivingCondition: DrivingCondition.city,
      ),
      FuelRecord(
        id: 2,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 15),
        odometer: 10400,
        rate: 130,
        volume: 32,
        paidAmount: 4160,
        isFullTank: true,
        missedPrevious: false,
        drivingCondition: DrivingCondition.highway,
      ),
    ];

    final testFuelTypes = {
      1: FuelType(
        id: 1,
        name: 'Octane',
        category: FuelCategory.gasoline,
        unit: FuelUnit.litre,
      ),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiclesProvider.overrideWith(() => MockVehiclesNotifier(testVehicles)),
          activeVehicleIdProvider.overrideWith((ref) => 1),
          fuelRecordsProvider(1).overrideWith((ref) => Stream.value(testRecords)),
          fuelTypesMapProvider.overrideWith((ref) => Future.value(testFuelTypes)),
          savedLocationsMapProvider.overrideWith((ref) => Future.value({})),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AnalyticsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('Visual Analytics'), findsOneWidget);
    expect(find.text('Toyota Corolla'), findsOneWidget);

    // Verify Time Window Chips
    expect(find.text('1 Month'), findsOneWidget);
    expect(find.text('3 Months'), findsOneWidget);
    expect(find.text('All Time'), findsOneWidget);

    // Verify Section Titles
    expect(find.text('Fuel Price Trends'), findsOneWidget);
    expect(find.text('Station Efficiency Variance'), findsOneWidget);
    expect(find.text('Driving Condition Impact'), findsOneWidget);
    expect(find.text('Carbon Footprint'), findsOneWidget);

    // Tap on 1 Month Chip
    await tester.tap(find.text('1 Month'));
    await tester.pumpAndSettle();
  });
}
