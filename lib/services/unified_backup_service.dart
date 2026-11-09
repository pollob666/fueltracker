// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum ConflictResolutionStrategy {
  overwriteExisting,
  skipExisting,
  copyMergeAll,
}

enum ImportCategory {
  vehicles,
  fuelRecords,
  serviceRecords,
  savedLocations,
  nonFuelExpenses,
  appSettings,
  attachments,
}

class BackupValidationSummary {
  final int schemaVersion;
  final String appVersion;
  final DateTime? exportTimestamp;
  final String? deviceInfo;
  final List<String> vehicleNames;
  final int vehicleCount;
  final int refuelCount;
  final int serviceSessionCount;
  final int serviceItemCount;
  final int locationCount;
  final int expenseCount;
  final int tireCount;
  final int tireLogCount;
  final bool hasAppSettings;
  final int attachmentCount;
  final bool isValid;
  final String? errorMessage;

  const BackupValidationSummary({
    required this.schemaVersion,
    required this.appVersion,
    this.exportTimestamp,
    this.deviceInfo,
    this.vehicleNames = const [],
    this.vehicleCount = 0,
    this.refuelCount = 0,
    this.serviceSessionCount = 0,
    this.serviceItemCount = 0,
    this.locationCount = 0,
    this.expenseCount = 0,
    this.tireCount = 0,
    this.tireLogCount = 0,
    this.hasAppSettings = false,
    this.attachmentCount = 0,
    required this.isValid,
    this.errorMessage,
  });

  factory BackupValidationSummary.invalid(String error) {
    return BackupValidationSummary(
      schemaVersion: 0,
      appVersion: '',
      isValid: false,
      errorMessage: error,
    );
  }
}

class ImportExecutionResult {
  final bool success;
  final String message;
  final int importedVehicles;
  final int importedRefuels;
  final int importedServices;
  final int importedLocations;
  final int importedExpenses;
  final bool importedSettings;
  final int importedAttachments;

  const ImportExecutionResult({
    required this.success,
    required this.message,
    this.importedVehicles = 0,
    this.importedRefuels = 0,
    this.importedServices = 0,
    this.importedLocations = 0,
    this.importedExpenses = 0,
    this.importedSettings = false,
    this.importedAttachments = 0,
  });
}

class UnifiedBackupService {
  static const int currentSchemaVersion = 2;
  static const String currentAppVersion = "3.5.0";

  /// Generates a single, comprehensive JSON payload containing all selected tables.
  /// Unchecked categories are exported as empty arrays/objects.
  static Future<Map<String, dynamic>> createBackupPayload({
    bool includeVehicles = true,
    bool includeRefuelRecords = true,
    bool includeServiceRecords = true,
    bool includeSavedLocations = true,
    bool includeNonFuelExpenses = true,
    bool includeAppSettings = true,
    bool includeAttachments = true,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final fuelTypes = includeVehicles ? await db.query('fuel_types') : <Map<String, dynamic>>[];
    final vehicles = includeVehicles ? await db.query('vehicles') : <Map<String, dynamic>>[];
    final maintenanceTasks = includeVehicles ? await db.query('maintenance_tasks') : <Map<String, dynamic>>[];
    final tires = includeVehicles ? await db.query('tires') : <Map<String, dynamic>>[];
    final tireLogs = includeVehicles ? await db.query('tire_logs') : <Map<String, dynamic>>[];
    final fuelRecords = includeRefuelRecords ? await db.query('fuel_records') : <Map<String, dynamic>>[];
    final serviceSessions = includeServiceRecords ? await db.query('service_sessions') : <Map<String, dynamic>>[];
    final serviceSessionItems = includeServiceRecords ? await db.query('service_session_items') : <Map<String, dynamic>>[];
    final savedLocations = includeSavedLocations ? await db.query('saved_locations') : <Map<String, dynamic>>[];
    final nonFuelExpenses = includeNonFuelExpenses ? await db.query('non_fuel_expenses') : <Map<String, dynamic>>[];
    final appSettings = includeAppSettings ? AppSettings.toMap() : <String, dynamic>{};

    Map<String, String> attachmentsMap = {};
    if (includeAttachments) {
      final attachDir = Directory(await AttachmentService.getAttachmentsDirectory());
      if (await attachDir.exists()) {
        final files = attachDir.listSync().whereType<File>();
        for (final file in files) {
          try {
            final bytes = await file.readAsBytes();
            attachmentsMap[p.basename(file.path)] = base64Encode(bytes);
          } catch (e) {
            debugPrint('Failed to encode attachment ${file.path}: $e');
          }
        }
      }
    }

    return {
      'schema_version': currentSchemaVersion,
      'app_version': currentAppVersion,
      'export_timestamp': DateTime.now().toUtc().toIso8601String(),
      'device_info': Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : Platform.operatingSystem),
      'fuel_types': fuelTypes,
      'vehicles': vehicles,
      'maintenance_tasks': maintenanceTasks,
      'tires': tires,
      'tire_logs': tireLogs,
      'fuel_records': fuelRecords,
      'service_sessions': serviceSessions,
      'service_session_items': serviceSessionItems,
      'saved_locations': savedLocations,
      'non_fuel_expenses': nonFuelExpenses,
      'app_settings': appSettings,
      'attachments': attachmentsMap,
    };
  }

  /// Converts payload map to a pretty-formatted JSON string.
  static String encodePayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Saves backup using Android SAF (Storage Access Framework).
  /// Launches native system DocumentsUI drawer (Google Drive, Dropbox, Device Storage).
  static Future<Uri?> saveBackupViaSaf({
    required String jsonString,
    String? customFileName,
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 15);
    final fileName = customFileName ?? 'fueltracker_backup_$timestamp.json';
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    return await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save Backup to Phone or Cloud',
    );
  }

  /// Validates a picked JSON string and returns a structured summary.
  static BackupValidationSummary validateBackupPayload(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return BackupValidationSummary.invalid('File content is not a valid JSON object.');
      }

      final schemaVersion = decoded['schema_version'] as int? ?? (decoded['schemaVersion'] as int? ?? 1);
      final appVersion = decoded['app_version'] as String? ?? 'unknown';
      DateTime? timestamp;
      if (decoded['export_timestamp'] != null) {
        timestamp = DateTime.tryParse(decoded['export_timestamp'].toString());
      }
      final deviceInfo = decoded['device_info'] as String?;

      final vehiclesList = (decoded['vehicles'] as List?) ?? [];
      final vehicleNames = vehiclesList
          .map((v) => v is Map ? (v['name']?.toString() ?? 'Unnamed') : 'Unnamed')
          .toList();

      final refuelsList = (decoded['fuel_records'] as List?) ?? [];
      final serviceSessionsList = (decoded['service_sessions'] as List?) ?? [];
      final serviceItemsList = (decoded['service_session_items'] as List?) ?? [];
      final locationsList = (decoded['saved_locations'] as List?) ?? [];
      final expensesList = (decoded['non_fuel_expenses'] as List?) ?? [];
      final tiresList = (decoded['tires'] as List?) ?? [];
      final tireLogsList = (decoded['tire_logs'] as List?) ?? [];
      final appSettingsMap = (decoded['app_settings'] as Map?) ?? {};
      final attachmentsMap = (decoded['attachments'] as Map?) ?? {};

      return BackupValidationSummary(
        schemaVersion: schemaVersion,
        appVersion: appVersion,
        exportTimestamp: timestamp,
        deviceInfo: deviceInfo,
        vehicleNames: vehicleNames,
        vehicleCount: vehiclesList.length,
        refuelCount: refuelsList.length,
        serviceSessionCount: serviceSessionsList.length,
        serviceItemCount: serviceItemsList.length,
        locationCount: locationsList.length,
        expenseCount: expensesList.length,
        tireCount: tiresList.length,
        tireLogCount: tireLogsList.length,
        hasAppSettings: appSettingsMap.isNotEmpty,
        attachmentCount: attachmentsMap.length,
        isValid: true,
      );
    } catch (e) {
      return BackupValidationSummary.invalid('Corrupted or invalid JSON format: $e');
    }
  }

  /// Executes transactional import with category selection and conflict strategy.
  static Future<ImportExecutionResult> executeImport({
    required Map<String, dynamic> payload,
    required Set<ImportCategory> selectedCategories,
    required ConflictResolutionStrategy conflictStrategy,
  }) async {
    final db = await DatabaseHelper.instance.database;

    int impVehicles = 0;
    int impRefuels = 0;
    int impServices = 0;
    int impLocations = 0;
    int impExpenses = 0;
    bool impSettings = false;
    int impAttachments = 0;

    try {
      await db.transaction((txn) async {
        final bool isSkip = conflictStrategy == ConflictResolutionStrategy.skipExisting;
        final bool isCopy = conflictStrategy == ConflictResolutionStrategy.copyMergeAll;

        ConflictAlgorithm algo = isSkip ? ConflictAlgorithm.ignore : ConflictAlgorithm.replace;

        // ID Mappings used when copyMergeAll is selected
        final Map<int, int> vehicleIdMap = {};
        final Map<int, int> locationIdMap = {};
        final Map<int, int> fuelTypeIdMap = {};
        final Map<int, int> serviceSessionIdMap = {};
        final Map<int, int> maintenanceTaskIdMap = {};

        // 1. Saved Locations
        if (selectedCategories.contains(ImportCategory.savedLocations)) {
          final locations = (payload['saved_locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in locations) {
            final row = Map<String, dynamic>.from(raw);
            row['createdAt'] ??= DateTime.now().toIso8601String();
            if (isCopy) {
              final oldId = row['id'] as int?;
              row.remove('id');
              final newId = await txn.insert('saved_locations', row);
              if (oldId != null) locationIdMap[oldId] = newId;
            } else {
              await txn.insert('saved_locations', row, conflictAlgorithm: algo);
            }
            impLocations++;
          }
        }

        // 2. Fuel Types & Vehicles
        if (selectedCategories.contains(ImportCategory.vehicles)) {
          final fuelTypes = (payload['fuel_types'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in fuelTypes) {
            final row = Map<String, dynamic>.from(raw);
            row['category'] ??= 'petrol';
            row['unit'] ??= 'L';
            if (isCopy) {
              final oldId = row['id'] as int?;
              row.remove('id');
              final newId = await txn.insert('fuel_types', row);
              if (oldId != null) fuelTypeIdMap[oldId] = newId;
            } else {
              await txn.insert('fuel_types', row, conflictAlgorithm: algo);
            }
          }

          final vehicles = (payload['vehicles'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in vehicles) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              final oldId = row['id'] as int?;
              row.remove('id');
              if (row['fuelTypeId'] != null && fuelTypeIdMap.containsKey(row['fuelTypeId'])) {
                row['fuelTypeId'] = fuelTypeIdMap[row['fuelTypeId']];
              }
              if (row['primaryFuelTypeId'] != null && fuelTypeIdMap.containsKey(row['primaryFuelTypeId'])) {
                row['primaryFuelTypeId'] = fuelTypeIdMap[row['primaryFuelTypeId']];
              }
              if (row['secondaryFuelTypeId'] != null && fuelTypeIdMap.containsKey(row['secondaryFuelTypeId'])) {
                row['secondaryFuelTypeId'] = fuelTypeIdMap[row['secondaryFuelTypeId']];
              }
              final newId = await txn.insert('vehicles', row);
              if (oldId != null) vehicleIdMap[oldId] = newId;
            } else {
              await txn.insert('vehicles', row, conflictAlgorithm: algo);
            }
            impVehicles++;
          }

          final tasks = (payload['maintenance_tasks'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in tasks) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              final oldId = row['id'] as int?;
              row.remove('id');
              if (row['vehicleId'] != null && vehicleIdMap.containsKey(row['vehicleId'])) {
                row['vehicleId'] = vehicleIdMap[row['vehicleId']];
              }
              final newId = await txn.insert('maintenance_tasks', row);
              if (oldId != null) maintenanceTaskIdMap[oldId] = newId;
            } else {
              await txn.insert('maintenance_tasks', row, conflictAlgorithm: algo);
            }
          }

          final Map<int, int> tireIdMap = {};
          final tires = (payload['tires'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in tires) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              final oldId = row['id'] as int?;
              row.remove('id');
              if (row['vehicleId'] != null && vehicleIdMap.containsKey(row['vehicleId'])) {
                row['vehicleId'] = vehicleIdMap[row['vehicleId']];
              }
              final newId = await txn.insert('tires', row);
              if (oldId != null) tireIdMap[oldId] = newId;
            } else {
              await txn.insert('tires', row, conflictAlgorithm: algo);
            }
          }

          final tireLogs = (payload['tire_logs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in tireLogs) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              row.remove('id');
              if (row['tireId'] != null && tireIdMap.containsKey(row['tireId'])) {
                row['tireId'] = tireIdMap[row['tireId']];
              }
              if (row['locationId'] != null && locationIdMap.containsKey(row['locationId'])) {
                row['locationId'] = locationIdMap[row['locationId']];
              }
              await txn.insert('tire_logs', row);
            } else {
              await txn.insert('tire_logs', row, conflictAlgorithm: algo);
            }
          }
        }

        // 3. Fuel Records
        if (selectedCategories.contains(ImportCategory.fuelRecords)) {
          final refuels = (payload['fuel_records'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in refuels) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              row.remove('id');
              if (row['vehicleId'] != null && vehicleIdMap.containsKey(row['vehicleId'])) {
                row['vehicleId'] = vehicleIdMap[row['vehicleId']];
              }
              if (row['locationId'] != null && locationIdMap.containsKey(row['locationId'])) {
                row['locationId'] = locationIdMap[row['locationId']];
              }
              if (row['fuelTypeId'] != null && fuelTypeIdMap.containsKey(row['fuelTypeId'])) {
                row['fuelTypeId'] = fuelTypeIdMap[row['fuelTypeId']];
              }
              await txn.insert('fuel_records', row);
            } else {
              await txn.insert('fuel_records', row, conflictAlgorithm: algo);
            }
            impRefuels++;
          }
        }

        // 4. Service Sessions & Items
        if (selectedCategories.contains(ImportCategory.serviceRecords)) {
          final sessions = (payload['service_sessions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in sessions) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              final oldId = row['id'] as int?;
              row.remove('id');
              if (row['vehicleId'] != null && vehicleIdMap.containsKey(row['vehicleId'])) {
                row['vehicleId'] = vehicleIdMap[row['vehicleId']];
              }
              if (row['locationId'] != null && locationIdMap.containsKey(row['locationId'])) {
                row['locationId'] = locationIdMap[row['locationId']];
              }
              final newId = await txn.insert('service_sessions', row);
              if (oldId != null) serviceSessionIdMap[oldId] = newId;
            } else {
              await txn.insert('service_sessions', row, conflictAlgorithm: algo);
            }
            impServices++;
          }

          final items = (payload['service_session_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in items) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              row.remove('id');
              if (row['serviceSessionId'] != null && serviceSessionIdMap.containsKey(row['serviceSessionId'])) {
                row['serviceSessionId'] = serviceSessionIdMap[row['serviceSessionId']];
              }
              if (row['taskId'] != null && maintenanceTaskIdMap.containsKey(row['taskId'])) {
                row['taskId'] = maintenanceTaskIdMap[row['taskId']];
              }
              await txn.insert('service_session_items', row);
            } else {
              await txn.insert('service_session_items', row, conflictAlgorithm: algo);
            }
          }
        }

        // 5. Non-Fuel Expenses
        if (selectedCategories.contains(ImportCategory.nonFuelExpenses)) {
          final expenses = (payload['non_fuel_expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          for (final raw in expenses) {
            final row = Map<String, dynamic>.from(raw);
            if (isCopy) {
              row.remove('id');
              if (row['vehicleId'] != null && vehicleIdMap.containsKey(row['vehicleId'])) {
                row['vehicleId'] = vehicleIdMap[row['vehicleId']];
              }
              await txn.insert('non_fuel_expenses', row);
            } else {
              await txn.insert('non_fuel_expenses', row, conflictAlgorithm: algo);
            }
            impExpenses++;
          }
        }
      });

      // 6. App Settings
      if (selectedCategories.contains(ImportCategory.appSettings)) {
        final settingsMap = (payload['app_settings'] as Map<String, dynamic>?) ?? {};
        if (settingsMap.isNotEmpty) {
          AppSettings.fromMap(settingsMap);
          await AppSettings.saveSettings();
          impSettings = true;
        }
      }

      // 7. Attachments
      if (selectedCategories.contains(ImportCategory.attachments)) {
        final attachmentsMap = (payload['attachments'] as Map<String, dynamic>?) ?? {};
        if (attachmentsMap.isNotEmpty) {
          final attachDir = await AttachmentService.getAttachmentsDirectory();
          for (final entry in attachmentsMap.entries) {
            try {
              final filename = entry.key;
              final base64Str = entry.value as String;
              final bytes = base64Decode(base64Str);
              final targetFile = File(p.join(attachDir, filename));
              await targetFile.writeAsBytes(bytes);
              impAttachments++;
            } catch (e) {
              debugPrint('Failed to restore attachment ${entry.key}: $e');
            }
          }
        }
      }

      return ImportExecutionResult(
        success: true,
        message: 'Import completed successfully.',
        importedVehicles: impVehicles,
        importedRefuels: impRefuels,
        importedServices: impServices,
        importedLocations: impLocations,
        importedExpenses: impExpenses,
        importedSettings: impSettings,
        importedAttachments: impAttachments,
      );
    } catch (e) {
      return ImportExecutionResult(
        success: false,
        message: 'Transaction failed and rolled back: $e',
      );
    }
  }
}
