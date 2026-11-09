// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:fuel_tracker/services/unified_backup_service.dart';
import 'package:fuel_tracker/services/webdav_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case WorkManagerBackupService.autoBackupTaskName:
        return await WorkManagerBackupService.executeHeadlessBackup();
      default:
        return Future.value(true);
    }
  });
}

class WorkManagerBackupService {
  static const String autoBackupTaskName = "com.pollob666.fueltracker.autoBackup";
  static const String autoBackupUniqueWork = "fuelTrackerPeriodicAutoBackup";
  static const int maxRetainedLocalBackups = 7;

  @visibleForTesting
  static bool forceEnabledForTesting = false;

  static bool get isSupportedPlatform =>
      forceEnabledForTesting || Platform.isAndroid || Platform.isIOS;

  /// Initializes the WorkManager plugin with top-level callback dispatcher.
  static Future<void> initialize() async {
    if (!isSupportedPlatform) return;
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
    } catch (e) {
      debugPrint('Failed to initialize WorkManager: $e');
    }
  }

  /// Schedules periodic background auto-backup according to user settings.
  static Future<void> schedulePeriodicBackup({
    required int frequencyDays,
    required bool wifiOnly,
  }) async {
    if (!isSupportedPlatform) return;
    try {
      // Workmanager frequency on Android must be at least 15 minutes.
      final frequency = Duration(days: frequencyDays.clamp(1, 30));

      await Workmanager().registerPeriodicTask(
        autoBackupUniqueWork,
        autoBackupTaskName,
        frequency: frequency,
        constraints: Constraints(
          networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      debugPrint('Scheduled WorkManager auto-backup every $frequencyDays days (wifiOnly: $wifiOnly)');
    } catch (e) {
      debugPrint('Failed to schedule WorkManager backup: $e');
    }
  }

  /// Cancels scheduled periodic background auto-backup.
  static Future<void> cancelScheduledBackup() async {
    if (!isSupportedPlatform) return;
    try {
      await Workmanager().cancelByUniqueName(autoBackupUniqueWork);
      debugPrint('Canceled WorkManager auto-backup');
    } catch (e) {
      debugPrint('Failed to cancel WorkManager backup: $e');
    }
  }

  /// Headless backup worker executed in the background:
  /// 1. Dumps DB + settings into unified single JSON.
  /// 2. Saves revolving timestamped copy in app storage (/Backups/), keeping last 7.
  /// 3. Uploads to WebDAV if configured and enabled.
  static Future<bool> executeHeadlessBackup() async {
    try {
      await AppSettings.loadSettings();

      final payload = await UnifiedBackupService.createBackupPayload(
        includeVehicles: true,
        includeRefuelRecords: true,
        includeServiceRecords: true,
        includeSavedLocations: true,
        includeNonFuelExpenses: true,
        includeAppSettings: true,
        includeAttachments: false, // Keep background backup compact & fast
      );

      final jsonString = UnifiedBackupService.encodePayload(payload);
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 15);
      final fileName = 'fueltracker_auto_backup_$timestamp.json';

      // 1. Save local rotating backup in app storage
      final docsDir = await getApplicationDocumentsDirectory();
      final backupFolder = Directory(p.join(docsDir.path, 'Backups'));
      if (!await backupFolder.exists()) {
        await backupFolder.create(recursive: true);
      }

      final localFile = File(p.join(backupFolder.path, fileName));
      await localFile.writeAsString(jsonString);

      // Prune oldest backups exceeding limit
      final existingBackups = backupFolder
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (existingBackups.length > maxRetainedLocalBackups) {
        for (int i = maxRetainedLocalBackups; i < existingBackups.length; i++) {
          try {
            await existingBackups[i].delete();
          } catch (_) {}
        }
      }

      // 2. Upload to WebDAV if enabled
      if (AppSettings.autoBackupWebDavUpload) {
        final config = await WebDavService.loadSavedConfig();
        if (config != null) {
          await WebDavService.uploadBackup(
            config: config,
            fileName: fileName,
            content: Uint8List.fromList(utf8.encode(jsonString)),
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('WorkManager executeHeadlessBackup failed: $e');
      return false;
    }
  }
}
