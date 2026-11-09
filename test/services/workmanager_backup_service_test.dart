// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/workmanager_backup_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workmanager_android/workmanager_android.dart';
import 'package:workmanager_platform_interface/workmanager_platform_interface.dart';

class FakeWorkmanagerPlatform extends WorkmanagerAndroid {
  final List<String> periodicTasks = [];
  final List<String> cancelledTasks = [];

  @override
  Future<void> initialize(Function callbackDispatcher, {bool isInDebugMode = false}) async {}

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    periodicTasks.add(uniqueName);
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelledTasks.add(uniqueName);
  }

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late FakeWorkmanagerPlatform fakeWorkmanager;
  late Directory mockDocsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    mockDocsDir = Directory.systemTemp.createTempSync('ft_test_docs_');

    // Mock path_provider channel with stable directory
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return mockDocsDir.path;
      },
    );
  });

  setUp(() async {
    fakeWorkmanager = FakeWorkmanagerPlatform();
    WorkmanagerPlatform.instance = fakeWorkmanager;
    WorkManagerBackupService.forceEnabledForTesting = true;

    SharedPreferences.setMockInitialValues({
      'autoBackupEnabled': true,
      'autoBackupFrequencyDays': 3,
      'autoBackupWifiOnly': true,
    });
    await AppSettings.loadSettings();

    testDb = await openDatabase(
      inMemoryDatabasePath,
      version: 10,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
      onCreate: (db, version) async => await DatabaseHelper.instance.createTablesForTesting(db),
    );
    DatabaseHelper.setDatabaseForTesting(testDb);
  });

  tearDown(() async {
    WorkManagerBackupService.forceEnabledForTesting = false;
    DatabaseHelper.setDatabaseForTesting(null);
    await testDb.close();
  });

  group('WorkManagerBackupService Tests', () {
    test('schedules periodic background auto-backup with constraints', () async {
      await WorkManagerBackupService.schedulePeriodicBackup(
        frequencyDays: 3,
        wifiOnly: true,
      );

      expect(fakeWorkmanager.periodicTasks, contains(WorkManagerBackupService.autoBackupUniqueWork));
    });

    test('cancels scheduled background auto-backup by unique name', () async {
      await WorkManagerBackupService.cancelScheduledBackup();

      expect(fakeWorkmanager.cancelledTasks, contains(WorkManagerBackupService.autoBackupUniqueWork));
    });

    test('executeHeadlessBackup creates backup and retains maximum 7 files', () async {
      final backupFolder = Directory(p.join(mockDocsDir.path, 'Backups'));
      if (await backupFolder.exists()) {
        await backupFolder.delete(recursive: true);
      }
      await backupFolder.create(recursive: true);

      // Pre-create 8 dummy backup files with staggered timestamps
      for (int i = 1; i <= 8; i++) {
        final dummyFile = File(p.join(backupFolder.path, 'fueltracker_auto_backup_20261101_00000$i.json'));
        await dummyFile.writeAsString('{"dummy": $i}');
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final beforeCount = backupFolder.listSync().whereType<File>().length;
      expect(beforeCount, equals(8));

      // Run headless backup
      final success = await WorkManagerBackupService.executeHeadlessBackup();
      expect(success, isTrue);

      // Verify that after execution, directory is pruned to max 7 files
      final filesAfter = backupFolder.listSync().whereType<File>().toList();
      expect(filesAfter.length, lessThanOrEqualTo(WorkManagerBackupService.maxRetainedLocalBackups));
    });
  });
}
