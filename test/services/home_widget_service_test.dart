// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/app_shortcuts_service.dart';
import 'package:fuel_tracker/services/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel quickActionsChannel = MethodChannel('plugins.flutter.io/quick_actions');
  const MethodChannel homeWidgetChannel = MethodChannel('home_widget');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      quickActionsChannel,
      (MethodCall call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      homeWidgetChannel,
      (MethodCall call) async => true,
    );
  });

  group('AppShortcutsService Tests', () {
    test('instance initializes callback handler without crash', () {
      bool shortcutFired = false;
      AppShortcutsService.instance.initialize(
        onShortcut: (type) {
          shortcutFired = true;
        },
      );
      expect(AppShortcutsService.instance, isNotNull);
      expect(shortcutFired, isFalse);
    });
  });

  group('HomeWidgetService Tests', () {
    test('updateGlanceWidget executes gracefully with sample records', () async {
      final vehicle = Vehicle(
        id: 1,
        name: 'Land Cruiser',
        type: VehicleType.suv,
        primaryFuelTypeId: 1,
        primaryFuelCapacity: 90.0,
      );

      final records = [
        FuelRecord(
          id: 1,
          date: DateTime.now().subtract(const Duration(days: 5)),
          odometer: 10000.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 50.0,
          paidAmount: 6500.0,
          isFullTank: true,
        ),
        FuelRecord(
          id: 2,
          date: DateTime.now(),
          odometer: 10500.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 130.0,
          volume: 45.0,
          paidAmount: 5850.0,
          isFullTank: true,
        ),
      ];

      await HomeWidgetService.updateGlanceWidget(
        vehicle: vehicle,
        fuelRecords: records,
      );
    });
  });
}
