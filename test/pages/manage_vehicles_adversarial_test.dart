// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/manage_vehicles_page.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class ControllableMockDatabase implements Database {
  List<Map<String, Object?>> vehiclesTable = [];
  int recordCount = 0;
  Completer<int>? recordCountCompleter;
  Completer<void>? deleteCompleter;
  final List<String> log = [];

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
    log.add('query:$table');
    if (table == 'vehicles') {
      return List.from(vehiclesTable);
    }
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    log.add('rawQuery:$sql args:$arguments');
    if (recordCountCompleter != null) {
      final res = await recordCountCompleter!.future;
      return [{'count': res}];
    }
    return [{'count': recordCount}];
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    log.add('transaction:start');
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    final txn = MockTxn(this);
    final result = await action(txn);
    log.add('transaction:end');
    return result;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    log.add('delete:$table where=$where args=$whereArgs');
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    if (table == 'vehicles' && whereArgs != null && whereArgs.isNotEmpty) {
      final id = whereArgs.first as int;
      vehiclesTable.removeWhere((v) => v['id'] == id);
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTxn implements Transaction {
  final ControllableMockDatabase db;
  MockTxn(this.db);

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    db.log.add('txn:delete:$table where=$where args=$whereArgs');
    if (table == 'vehicles' && whereArgs != null && whereArgs.isNotEmpty) {
      final id = whereArgs.first as int;
      db.vehiclesTable.removeWhere((v) => v['id'] == id);
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _vehicleMap(int id, String name) {
  return Vehicle(
    id: id,
    name: name,
    type: VehicleType.carOrSedan,
    primaryFuelTypeId: 1,
    primaryFuelCapacity: 45.0,
  ).toMap();
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ControllableMockDatabase mockDb;

  setUp(() {
    mockDb = ControllableMockDatabase();
    DatabaseHelper.setDatabaseForTesting(mockDb);
    AppSettings.adsEnabled = false;
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  group('ManageVehiclesPage Adversarial Challenges', () {
    testWidgets(
      'Challenge 1: Deleting default vehicle updates fallback to first remaining vehicle, refreshes _defaultVehicleId, and moves Default Vehicle Chip',
      (WidgetTester tester) async {
        // Given two vehicles: Car A (id: 1, default) and Car B (id: 2)
        SharedPreferences.setMockInitialValues({'default_vehicle': 1});
        mockDb.vehiclesTable = [
          _vehicleMap(1, 'Car Alpha'),
          _vehicleMap(2, 'Car Beta'),
        ];
        mockDb.recordCount = 3;

        await tester.pumpWidget(_buildTestApp(const ManageVehiclesPage()));
        await tester.pumpAndSettle();

        // Verify initial state: Car Alpha is rendered with default chip
        expect(find.text('Car Alpha'), findsOneWidget);
        expect(find.text('Car Beta'), findsOneWidget);
        expect(find.widgetWithText(Chip, 'Default Vehicle'), findsOneWidget);

        // Find delete button for Car Alpha (first vehicle card)
        final deleteButtons = find.byIcon(Icons.delete_outline);
        expect(deleteButtons, findsNWidgets(2));

        // Tap delete on Car Alpha
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Verify cascade confirmation dialog is shown with record count (3)
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('3'), findsOneWidget);

        // Confirm deletion
        final deleteConfirmButton = find.widgetWithText(ElevatedButton, 'Delete');
        expect(deleteConfirmButton, findsOneWidget);
        await tester.tap(deleteConfirmButton);
        await tester.pumpAndSettle();

        // Verify Car Alpha is gone and only Car Beta remains
        expect(find.text('Car Alpha'), findsNothing);
        expect(find.text('Car Beta'), findsOneWidget);

        // Verify Car Beta now has the Default Vehicle Chip!
        expect(find.widgetWithText(Chip, 'Default Vehicle'), findsOneWidget);

        // Verify SharedPreferences persisted fallback default vehicle ID = 2
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('default_vehicle'), equals(2));

        // Verify Car Beta's delete button is now disabled (since length == 1)
        final remainingDeleteButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete_outline),
        );
        expect(remainingDeleteButton.onPressed, isNull);
        expect(remainingDeleteButton.tooltip, equals('Cannot delete the only remaining vehicle.'));
      },
    );

    testWidgets(
      'Challenge 2: Deleting non-default vehicle leaves default vehicle and Chip unchanged, disables delete button on remaining default vehicle',
      (WidgetTester tester) async {
        // Given two vehicles: Car A (id: 1, default) and Car B (id: 2)
        SharedPreferences.setMockInitialValues({'default_vehicle': 1});
        mockDb.vehiclesTable = [
          _vehicleMap(1, 'Car Alpha'),
          _vehicleMap(2, 'Car Beta'),
        ];
        mockDb.recordCount = 0;

        await tester.pumpWidget(_buildTestApp(const ManageVehiclesPage()));
        await tester.pumpAndSettle();

        // Tap delete on Car Beta (second card)
        final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete_outline);
        await tester.tap(deleteButtons.last);
        await tester.pumpAndSettle();

        // Dialog with 0 records confirmation
        expect(find.byType(AlertDialog), findsOneWidget);
        final deleteConfirmButton = find.widgetWithText(ElevatedButton, 'Delete');
        await tester.tap(deleteConfirmButton);
        await tester.pumpAndSettle();

        // Car Alpha remains and is still default
        expect(find.text('Car Alpha'), findsOneWidget);
        expect(find.text('Car Beta'), findsNothing);
        expect(find.widgetWithText(Chip, 'Default Vehicle'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('default_vehicle'), equals(1));

        // Delete button disabled on sole remaining vehicle
        final remainingDeleteButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete_outline),
        );
        expect(remainingDeleteButton.onPressed, isNull);
      },
    );

    testWidgets(
      'Challenge 3: Canceling deletion dialog preserves state and vehicles without changes',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'default_vehicle': 1});
        mockDb.vehiclesTable = [
          _vehicleMap(1, 'Car Alpha'),
          _vehicleMap(2, 'Car Beta'),
        ];
        mockDb.recordCount = 5;

        await tester.pumpWidget(_buildTestApp(const ManageVehiclesPage()));
        await tester.pumpAndSettle();

        final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete_outline);
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Cancel
        final cancelButton = find.widgetWithText(TextButton, 'Cancel');
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();

        // Dialog dismissed, both vehicles still present
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Car Alpha'), findsOneWidget);
        expect(find.text('Car Beta'), findsOneWidget);
        expect(mockDb.vehiclesTable.length, equals(2));
      },
    );

    testWidgets(
      'Challenge 4: Single vehicle initial state disables delete button and blocks execution',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'default_vehicle': 1});
        mockDb.vehiclesTable = [
          _vehicleMap(1, 'Solo Car'),
        ];

        await tester.pumpWidget(_buildTestApp(const ManageVehiclesPage()));
        await tester.pumpAndSettle();

        final deleteButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.delete_outline),
        );
        expect(deleteButton.onPressed, isNull);
        expect(deleteButton.tooltip, equals('Cannot delete the only remaining vehicle.'));
      },
    );

    testWidgets(
      'Challenge 5: Navigation pop while getRecordCountForVehicle is in flight is safely handled by if (!mounted) return;',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'default_vehicle': 1});
        mockDb.vehiclesTable = [
          _vehicleMap(1, 'Car Alpha'),
          _vehicleMap(2, 'Car Beta'),
        ];
        // Introduce a completer to hold getFuelRecordCountForVehicle in flight
        mockDb.recordCountCompleter = Completer<int>();

        // Build a navigator containing ManageVehiclesPage pushed onto stack
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const ManageVehiclesPage()),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        // Open ManageVehiclesPage
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(ManageVehiclesPage), findsOneWidget);

        // Tap delete icon on Car Alpha -> starts _confirmDeleteVehicle and halts in rawQuery
        final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete_outline);
        await tester.tap(deleteButtons.first);
        await tester.pump(); // Start async work without settling

        // Pop the route while getRecordCountForVehicle is pending
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle(); // Settle the pop animation

        // Verify ManageVehiclesPage is unmounted
        expect(find.byType(ManageVehiclesPage), findsNothing);

        // Now complete the pending record count query
        mockDb.recordCountCompleter!.complete(10);
        await tester.pumpAndSettle(); // Execute unmounted callback

        // No exception thrown, no dialog popped on dead route
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'Challenge 6: Navigation pop while deleteVehicle is in flight is safely handled by if (!mounted) return;',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'default_vehicle': 1});
        mockDb.vehiclesTable = [
          _vehicleMap(1, 'Car Alpha'),
          _vehicleMap(2, 'Car Beta'),
        ];
        mockDb.recordCount = 0;
        // Hold delete transaction in flight
        mockDb.deleteCompleter = Completer<void>();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const ManageVehiclesPage()),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        // Open ManageVehiclesPage
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap delete
        final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete_outline);
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Confirm dialog
        final deleteConfirmButton = find.widgetWithText(ElevatedButton, 'Delete');
        await tester.tap(deleteConfirmButton);
        await tester.pump(); // Closes dialog, triggers deleteVehicle, which blocks on deleteCompleter

        // Now pop the ManageVehiclesPage route while delete is in flight
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.pop();
        await tester.pumpAndSettle();

        expect(find.byType(ManageVehiclesPage), findsNothing);

        // Complete the delete transaction
        mockDb.deleteCompleter!.complete();
        await tester.pumpAndSettle();

        // Verify no crash, no setState() called after dispose() error
        expect(tester.takeException(), isNull);
      },
    );
  });
}
