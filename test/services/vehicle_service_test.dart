// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseHelper implements DatabaseHelper {
  List<Vehicle> vehicles = [];
  int recordCount = 0;
  final List<String> callLog = [];
  bool shouldThrowOnDelete = false;

  @override
  Future<List<Vehicle>> getVehicles() async {
    callLog.add('getVehicles');
    return List.from(vehicles);
  }

  @override
  Future<int> getFuelRecordCountForVehicle(int vehicleId) async {
    callLog.add('getFuelRecordCountForVehicle:$vehicleId');
    return recordCount;
  }

  @override
  Future<int> deleteVehicle(int id) async {
    callLog.add('deleteVehicle:$id');
    if (shouldThrowOnDelete) {
      throw Exception('Database deletion failed');
    }
    vehicles.removeWhere((v) => v.id == id);
    return 1;
  }

  @override
  Future<void> deleteVehicleCascade(int vehicleId) async {
    callLog.add('deleteVehicleCascade:$vehicleId');
    if (shouldThrowOnDelete) {
      throw Exception('Database cascade deletion failed');
    }
    vehicles.removeWhere((v) => v.id == vehicleId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Vehicle _createVehicle(int id, String name) {
  return Vehicle(
    id: id,
    name: name,
    type: VehicleType.carOrSedan,
    primaryFuelTypeId: 1,
    primaryFuelCapacity: 50.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseHelper mockDb;
  late VehicleService service;

  setUp(() {
    mockDb = MockDatabaseHelper();
    service = VehicleService(dbHelper: mockDb);
  });

  group('VehicleService Dependency Injection', () {
    test('accepts injected DatabaseHelper', () async {
      mockDb.vehicles = [_createVehicle(10, 'Car A')];
      final list = await service.getVehicles();
      expect(list.length, 1);
      expect(list.first.name, 'Car A');
      expect(mockDb.callLog, contains('getVehicles'));
    });

    test('defaults to DatabaseHelper.instance when dbHelper is null/omitted', () {
      final defaultService = VehicleService();
      expect(defaultService, isNotNull);
    });

    test('forwards getRecordCountForVehicle to dbHelper', () async {
      mockDb.recordCount = 42;
      final count = await service.getRecordCountForVehicle(7);
      expect(count, 42);
      expect(mockDb.callLog, contains('getFuelRecordCountForVehicle:7'));
    });
  });

  group('VehicleService Default Vehicle Fallback Permutations', () {
    test('Case A: Deleted vehicle was default, remaining has 1+ vehicles -> resets to remaining.first.id', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
        _createVehicle(3, 'Ford'),
      ];

      await service.deleteVehicle(1, cascade: true);

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 2);
    });

    test('Case B: Deleted vehicle was NOT default -> SharedPreferences default is unchanged', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
        _createVehicle(3, 'Ford'),
      ];

      await service.deleteVehicle(2, cascade: true);

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 1);
    });

    test('Case C: Deleted vehicle was default, and NO vehicles remain -> clearDefaultVehicle removes key', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Solo Car'),
      ];

      await service.deleteVehicle(1, cascade: true);

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, isNull);
    });

    test('Case D1: Stored default vehicle was dangling/stale with remaining vehicles -> healed to remaining.first.id', () async {
      // Stale default 999 does not exist in DB
      SharedPreferences.setMockInitialValues({'default_vehicle': 999});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      // Delete vehicle 1
      await service.deleteVehicle(1, cascade: true);

      // Stale 999 was invalid, remaining is [Honda (2)], so it must heal to 2
      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 2);
    });

    test('Case D2: Stored default vehicle was dangling/stale with NO remaining vehicles -> cleared', () async {
      // Stale default 999
      SharedPreferences.setMockInitialValues({'default_vehicle': 999});
      mockDb.vehicles = [
        _createVehicle(1, 'Only Car'),
      ];

      // Delete vehicle 1
      await service.deleteVehicle(1, cascade: true);

      // Remaining is empty -> key cleared
      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, isNull);
    });

    test('Case E: Initial default was null -> remains null after deletion', () async {
      SharedPreferences.setMockInitialValues({});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      await service.deleteVehicle(1, cascade: true);

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, isNull);
    });

    test('Case F: Deleting non-existent vehicle ID with valid default does not affect default', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      await service.deleteVehicle(999, cascade: true);

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 1);
    });

    test('Case G: Deleting non-existent vehicle ID which matches phantom default resets default to first remaining', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 999});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      await service.deleteVehicle(999, cascade: true);

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 1);
    });

    test('Direct setDefaultVehicle and clearDefaultVehicle roundtrip', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await service.getDefaultVehicle(), isNull);

      await service.setDefaultVehicle(42);
      expect(await service.getDefaultVehicle(), 42);

      await service.clearDefaultVehicle();
      expect(await service.getDefaultVehicle(), isNull);
    });

    test('deleteVehicle with cascade: false invokes deleteVehicle on dbHelper', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      await service.deleteVehicle(1, cascade: false);

      expect(mockDb.callLog, contains('deleteVehicle:1'));
      expect(mockDb.callLog, isNot(contains('deleteVehicleCascade:1')));
      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 2);
    });

    test('deleteVehicleCascade convenience method invokes cascade delete', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      await service.deleteVehicleCascade(1);

      expect(mockDb.callLog, contains('deleteVehicleCascade:1'));
      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 2);
    });
  });

  group('Order of Operations & Error Atomicity', () {
    test('DB deletion occurs before SharedPreferences modification', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];

      await service.deleteVehicle(1, cascade: true);

      // Verify db delete was logged before getVehicles
      final deleteIndex = mockDb.callLog.indexOf('deleteVehicleCascade:1');
      final getVehiclesIndex = mockDb.callLog.indexOf('getVehicles');
      expect(deleteIndex, isNonNegative);
      expect(getVehiclesIndex, isNonNegative);
      expect(deleteIndex, lessThan(getVehiclesIndex));
    });

    test('Failed DB delete leaves SharedPreferences completely unmodified (cascade: true)', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];
      mockDb.shouldThrowOnDelete = true;

      expect(
        () async => await service.deleteVehicle(1, cascade: true),
        throwsA(isA<Exception>()),
      );

      // Verify preferences remained untouched
      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 1);
      // Verify getVehicles was never called
      expect(mockDb.callLog, isNot(contains('getVehicles')));
    });

    test('Failed DB delete leaves SharedPreferences completely unmodified (cascade: false)', () async {
      SharedPreferences.setMockInitialValues({'default_vehicle': 1});
      mockDb.vehicles = [
        _createVehicle(1, 'Toyota'),
        _createVehicle(2, 'Honda'),
      ];
      mockDb.shouldThrowOnDelete = true;

      expect(
        () async => await service.deleteVehicle(1, cascade: false),
        throwsA(isA<Exception>()),
      );

      final currentDefault = await service.getDefaultVehicle();
      expect(currentDefault, 1);
      expect(mockDb.callLog, isNot(contains('getVehicles')));
    });
  });
}
