// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/export_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MockBackupDatabase extends Fake implements Database {
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
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'export_sequence': 1});
    DatabaseHelper.setDatabaseForTesting(MockBackupDatabase());
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  Widget createTestWidget() {
    return const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: ExportPage(),
    );
  }

  testWidgets('ExportPage renders Encrypted Vault & Cloud Sync section and dialogs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final exportBtn = find.text('Export .ftbackup');
    await tester.scrollUntilVisible(
      exportBtn,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Encrypted Vault & Cloud Sync'), findsOneWidget);
    expect(exportBtn, findsOneWidget);
    expect(find.text('Restore File'), findsOneWidget);

    // Tap Export .ftbackup button
    await tester.tap(exportBtn);
    await tester.pumpAndSettle();

    // Verify Master Password dialog appears
    expect(find.text('Create Encrypted Backup'), findsOneWidget);
    expect(find.text('Master Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Encrypt & Export'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final webdavBtn = find.text('WebDAV / Nextcloud Sync Settings');
    await tester.scrollUntilVisible(
      webdavBtn,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(webdavBtn, findsOneWidget);
    await tester.tap(webdavBtn);
    await tester.pumpAndSettle();

    // Verify WebDAV bottom sheet
    expect(find.text('WebDAV & Nextcloud Sync'), findsOneWidget);
    expect(find.text('WebDAV Server URL'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
    expect(find.text('Upload Backup'), findsOneWidget);
  });
}
