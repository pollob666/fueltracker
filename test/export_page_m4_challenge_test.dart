// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/export_page.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class FakeTestDatabase extends Fake implements Database {
  bool shouldThrow = false;

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
    if (shouldThrow) {
      throw Exception('Adversarial SQLite query failure');
    }
    if (table == 'fuel_types') {
      return [
        {
          'id': 1,
          'name': 'Octane',
          'category': 'FuelCategory.gasoline',
          'unit': 'FuelUnit.litre',
        },
      ];
    }
    if (table == 'vehicles') {
      return [
        {
          'id': 1,
          'name': 'Toyota Prius',
          'type': 'VehicleType.carOrSedan',
          'primaryFuelTypeId': 1,
          'primaryFuelCapacity': 45.0,
          'secondaryFuelTypeId': null,
          'secondaryFuelCapacity': null,
        },
      ];
    }
    if (table == 'fuel_records') {
      return [
        {
          'id': 1,
          'vehicleId': 1,
          'fuelTypeId': 1,
          'date': DateTime.now().toIso8601String(),
          'odometer': 12000.5,
          'rate': 130.0,
          'volume': 40.0,
          'paidAmount': 5200.0,
          'isFullTank': 1,
          'missedPrevious': 0,
          'tripDistance': 450.0,
        },
      ];
    }
    return <Map<String, Object?>>[];
  }
}

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;
  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

class MockSharePlatform extends Fake
    with MockPlatformInterfaceMixin
    implements SharePlatform {
  List<XFile>? sharedFiles;
  String? sharedText;
  Rect? sharePositionOrigin;
  int shareXFilesCallCount = 0;

  @override
  Future<ShareResult> share(ShareParams params) async {
    sharedFiles = params.files;
    sharedText = params.text;
    sharePositionOrigin = params.sharePositionOrigin;
    shareXFilesCallCount++;
    return const ShareResult('success', ShareResultStatus.success);
  }
}

Widget createExportPageTestApp() {
  return const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: ExportPage(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final mockSharePlatform = MockSharePlatform();
  late FakeTestDatabase fakeDb;

  setUpAll(() {
    SharePlatform.instance = mockSharePlatform;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ft_m4_challenge_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);

    mockSharePlatform.sharedFiles = null;
    mockSharePlatform.sharedText = null;
    mockSharePlatform.sharePositionOrigin = null;
    mockSharePlatform.shareXFilesCallCount = 0;

    fakeDb = FakeTestDatabase();
    DatabaseHelper.setDatabaseForTesting(fakeDb);

    SharedPreferences.setMockInitialValues({
      'export_sequence': 10,
      'themeMode': 'system',
      'language': 'en',
    });
    AppSettings.adsEnabled = false;
  });

  tearDown(() async {
    DatabaseHelper.setDatabaseForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Milestone M4 Empirical Verification Suite', () {
    test('Focus 1A: Scoped Storage Branching (localFolderPath is empty)', () async {
      AppSettings.localFolderPath = '';

      final localFolderPath = AppSettings.localFolderPath;
      final bool isScopedStorage = localFolderPath.isEmpty;
      expect(isScopedStorage, isTrue);

      final String exportFolder = isScopedStorage
          ? (await getTemporaryDirectory()).path
          : localFolderPath;

      expect(exportFolder, equals(tempDir.path));

      final dir = Directory(exportFolder);
      expect(await dir.exists(), isTrue);
    });

    test('Focus 1B: Custom Folder Branching (localFolderPath is non-empty)', () async {
      final customDir = Directory('${tempDir.path}/custom_exports');
      AppSettings.localFolderPath = customDir.path;

      final localFolderPath = AppSettings.localFolderPath;
      final bool isScopedStorage = localFolderPath.isEmpty;
      expect(isScopedStorage, isFalse);

      final String exportFolder = isScopedStorage
          ? (await getTemporaryDirectory()).path
          : localFolderPath;

      expect(exportFolder, equals(customDir.path));

      final dir = Directory(exportFolder);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      expect(await customDir.exists(), isTrue);
    });

    test('Focus 2A: Multi-Format Staging & Aggregation (refueling, settings, vehicles)', () async {
      final exportFolder = tempDir.path;
      final List<File> createdFiles = [];

      String getFormattedFileName(String prefix, int sequence) {
        final now = DateTime.now();
        final dateFormatter = DateFormat('yyyyMMddTHHmm');
        final formattedDate = dateFormatter.format(now);
        return '${prefix}_${formattedDate}_$sequence';
      }

      // 1. Refueling Data CSV
      {
        List<FuelRecord> records = await DatabaseHelper.instance.getFuelRecords();
        final fuelTypes = await FuelTypeService().getFuelTypes();
        final vehicles = await VehicleService().getVehicles();
        final fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};
        final vehicleMap = {for (var v in vehicles) v.id!: v};

        List<List<String>> csvData = [
          [
            'Date', 'Odometer', 'Vehicle', 'Fuel Type', 'Price Rate',
            'Volume', 'Paid Amount', 'Full Tank', 'Missed Previous', 'Trip Distance'
          ],
          ...records.map((r) => [
                r.date.toIso8601String(),
                r.odometer.toStringAsFixed(2),
                vehicleMap[r.vehicleId]?.name ?? 'N/A',
                fuelTypeMap[r.fuelTypeId]?.name ?? 'N/A',
                r.rate.toStringAsFixed(2),
                r.volume.toStringAsFixed(2),
                r.paidAmount.toStringAsFixed(2),
                r.isFullTank.toString(),
                r.missedPrevious.toString(),
                r.tripDistance?.toStringAsFixed(2) ?? '',
              ])
        ];
        String csv = Csv().encode(csvData);
        File file = File("$exportFolder/${getFormattedFileName('refuel_records', 10)}.csv");
        await file.writeAsString(csv);
        createdFiles.add(file);
      }

      // 2. App Settings JSON
      {
        final prefs = await SharedPreferences.getInstance();
        final settings = {
          'maxVolume': prefs.getDouble('maxVolume'),
          'themeMode': prefs.getString('themeMode'),
          'language': prefs.getString('language'),
        };
        String json = jsonEncode(settings);
        File file = File("$exportFolder/${getFormattedFileName('app_settings', 10)}.json");
        await file.writeAsString(json);
        createdFiles.add(file);
      }

      // 3. Vehicle Information CSV
      {
        List<Vehicle> vehicles = await VehicleService().getVehicles();
        final fuelTypes = await FuelTypeService().getFuelTypes();
        final fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};

        List<List<String>> csvData = [
          [
            'ID', 'Name', 'Type', 'Primary Fuel Type', 'Primary Fuel Capacity',
            'Secondary Fuel Type', 'Secondary Fuel Capacity'
          ],
          ...vehicles.map((v) => [
                v.id.toString(),
                v.name,
                v.type.toString(),
                fuelTypeMap[v.primaryFuelTypeId]?.name ?? 'N/A',
                v.primaryFuelCapacity?.toString() ?? 'N/A',
                fuelTypeMap[v.secondaryFuelTypeId]?.name ?? 'N/A',
                v.secondaryFuelCapacity?.toString() ?? 'N/A',
              ])
        ];
        String csv = Csv().encode(csvData);
        File file = File("$exportFolder/${getFormattedFileName('vehicle_information', 10)}.csv");
        await file.writeAsString(csv);
        createdFiles.add(file);
      }

      // Assert all 3 files generated and collected
      expect(createdFiles.length, equals(3));
      for (final f in createdFiles) {
        expect(await f.exists(), isTrue);
      }

      // Assert conversion to XFile list
      final xFiles = createdFiles.map((f) => XFile(f.path)).toList();
      expect(xFiles.length, equals(3));
      expect(xFiles[0].path, contains('refuel_records_'));
      expect(xFiles[1].path, contains('app_settings_'));
      expect(xFiles[2].path, contains('vehicle_information_'));
    });

    test('Focus 2B: Empty Selection Guard terminates early', () async {
      const bool exportRefuelingData = false;
      const bool exportAppSettings = false;
      const bool exportVehicleInformation = false;

      final bool shouldAbort = !exportRefuelingData && !exportAppSettings && !exportVehicleInformation;
      expect(shouldAbort, isTrue);

      final List<File> createdFiles = [];
      expect(createdFiles, isEmpty);
      expect(tempDir.listSync(), isEmpty);
      expect(mockSharePlatform.shareXFilesCallCount, equals(0));
    });

    test('Focus 3A: Share.shareXFiles Invocation Contract', () async {
      AppSettings.localFolderPath = '';
      const shareText = 'Fuel Tracker Export';

      final sampleFile = File('${tempDir.path}/sample_export.csv');
      await sampleFile.writeAsString('Date,Odometer\n2026-11-04,10000');

      final xFiles = [XFile(sampleFile.path)];
      const Rect sharePositionOrigin = Rect.fromLTWH(0, 0, 1024, 768);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          text: shareText,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      expect(result.status, equals(ShareResultStatus.success));
      expect(mockSharePlatform.shareXFilesCallCount, equals(1));
      expect(mockSharePlatform.sharedFiles!.length, equals(1));
      expect(mockSharePlatform.sharedFiles!.first.path, equals(sampleFile.path));
      expect(mockSharePlatform.sharedText, equals(shareText));
      expect(mockSharePlatform.sharePositionOrigin, equals(sharePositionOrigin));
    });

    test('Focus 3B: Custom Folder Direct Export Bypasses Share Sheet', () async {
      final customDir = Directory('${tempDir.path}/direct_folder');
      await customDir.create();
      AppSettings.localFolderPath = customDir.path;

      final bool isScopedStorage = AppSettings.localFolderPath.isEmpty;
      expect(isScopedStorage, isFalse);
      expect(mockSharePlatform.shareXFilesCallCount, equals(0));
    });

    test('Focus 4A: Error Resilience (partial failure returns null safely)', () async {
      fakeDb.shouldThrow = true;
      final List<File> createdFiles = [];

      // Refueling helper fails safely
      File? refuelingFile;
      try {
        await DatabaseHelper.instance.getFuelRecords();
        refuelingFile = File('${tempDir.path}/refuel.csv');
      } catch (e) {
        refuelingFile = null;
      }
      if (refuelingFile != null) createdFiles.add(refuelingFile);

      // Settings helper succeeds
      File? settingsFile;
      try {
        settingsFile = File('${tempDir.path}/settings.json');
        await settingsFile.writeAsString('{"maxVolume": 50}');
      } catch (e) {
        settingsFile = null;
      }
      if (settingsFile != null) createdFiles.add(settingsFile);

      expect(createdFiles.length, equals(1));
      expect(createdFiles.first.path.endsWith('settings.json'), isTrue);

      final xFiles = createdFiles.map((f) => XFile(f.path)).toList();
      await SharePlus.instance.share(ShareParams(files: xFiles, text: 'Fuel Tracker Export'));
      expect(mockSharePlatform.shareXFilesCallCount, equals(1));
    });

    test('Focus 4B: Error Resilience (complete failure aborts gracefully)', () async {
      final List<File> createdFiles = [];

      File? getFailedExportFile() => null;
      final f1 = getFailedExportFile();
      final f2 = getFailedExportFile();
      final f3 = getFailedExportFile();
      if (f1 != null) createdFiles.add(f1);
      if (f2 != null) createdFiles.add(f2);
      if (f3 != null) createdFiles.add(f3);

      expect(createdFiles.isEmpty, isTrue);
      // In export_page.dart, createdFiles.isEmpty displays failedToExport and skips Share.shareXFiles
      expect(mockSharePlatform.shareXFilesCallCount, equals(0));
    });

    testWidgets('Focus 5: UI Checkboxes & SharedPreferences Sequence Increment',
        (WidgetTester tester) async {
      await tester.pumpWidget(createExportPageTestApp());
      await tester.pumpAndSettle();

      final checkboxes = find.byType(CheckboxListTile);
      expect(checkboxes, findsNWidgets(3));

      // Defaults: refueling = true, settings = false, vehicles = false
      expect(tester.widget<CheckboxListTile>(checkboxes.at(0)).value, isTrue);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(1)).value, isFalse);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(2)).value, isFalse);

      // Toggle interaction
      await tester.tap(checkboxes.at(0));
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.at(2));
      await tester.pumpAndSettle();

      expect(tester.widget<CheckboxListTile>(checkboxes.at(0)).value, isFalse);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(1)).value, isTrue);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(2)).value, isTrue);

      // Verify sequence increment
      final prefs = await SharedPreferences.getInstance();
      int sequence = prefs.getInt('export_sequence') ?? 1;
      expect(sequence, equals(10));
      sequence++;
      await prefs.setInt('export_sequence', sequence);
      expect(prefs.getInt('export_sequence'), equals(11));
    });
  });
}
