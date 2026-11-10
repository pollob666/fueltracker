// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base exception for backup archive operations.
class BackupArchiveException implements Exception {
  final String message;
  final dynamic cause;
  const BackupArchiveException(this.message, [this.cause]);

  @override
  String toString() => 'BackupArchiveException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Thrown when archive file signature is invalid, archive is truncated, or CRC fails.
class BackupCorruptArchiveException extends BackupArchiveException {
  const BackupCorruptArchiveException(super.message, [super.cause]);

  @override
  String toString() => 'BackupCorruptArchiveException: $message${cause != null ? ' ($cause)' : ''}';
}

typedef BackupProgressCallback = void Function(int current, int total, String status);

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
  final int formatVersion;
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
    this.formatVersion = 1,
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
      formatVersion: 0,
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

class Crc32 {
  static final List<int> _table = () {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int j = 0; j < 8; j++) {
        c = (c & 1 != 0) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[i] = c;
    }
    return table;
  }();

  int _crc = 0xFFFFFFFF;

  void add(List<int> chunk) {
    for (int i = 0; i < chunk.length; i++) {
      _crc = _table[(_crc ^ chunk[i]) & 0xFF] ^ (_crc >>> 8);
    }
  }

  int get value => (_crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

class _ZipEntryMeta {
  final String name;
  final List<int> nameBytes;
  final int crc32;
  final int size;
  final int localHeaderOffset;

  _ZipEntryMeta({
    required this.name,
    required this.nameBytes,
    required this.crc32,
    required this.size,
    required this.localHeaderOffset,
  });
}

class StreamingZipWriter {
  final RandomAccessFile _raf;
  final List<_ZipEntryMeta> _entries = [];
  bool _closed = false;

  StreamingZipWriter._(this._raf);

  static Future<StreamingZipWriter> open(File file) async {
    final raf = await file.open(mode: FileMode.write);
    return StreamingZipWriter._(raf);
  }

  Future<void> addBytes(String entryName, List<int> data) async {
    final nameBytes = utf8.encode(entryName);
    final crc = Crc32()..add(data);
    final entryCrc = crc.value;
    final size = data.length;
    final headerOffset = await _raf.position();

    final header = ByteData(30);
    header.setUint32(0, 0x04034b50, Endian.little);
    header.setUint16(4, 20, Endian.little);
    header.setUint16(6, 0x0800, Endian.little); // UTF-8
    header.setUint16(8, 0, Endian.little); // STORED
    header.setUint16(10, 0, Endian.little); // time
    header.setUint16(12, 0x5421, Endian.little); // date
    header.setUint32(14, entryCrc, Endian.little);
    header.setUint32(18, size, Endian.little);
    header.setUint32(22, size, Endian.little);
    header.setUint16(26, nameBytes.length, Endian.little);
    header.setUint16(28, 0, Endian.little);

    await _raf.writeFrom(header.buffer.asUint8List());
    await _raf.writeFrom(nameBytes);
    await _raf.writeFrom(data);

    _entries.add(_ZipEntryMeta(
      name: entryName,
      nameBytes: nameBytes,
      crc32: entryCrc,
      size: size,
      localHeaderOffset: headerOffset,
    ));
  }

  Future<void> addFile(String entryName, File file, {int chunkSize = 64 * 1024}) async {
    final nameBytes = utf8.encode(entryName);
    final headerOffset = await _raf.position();

    final header = ByteData(30);
    header.setUint32(0, 0x04034b50, Endian.little);
    header.setUint16(4, 20, Endian.little);
    header.setUint16(6, 0x0800, Endian.little); // UTF-8
    header.setUint16(8, 0, Endian.little); // STORED
    header.setUint16(10, 0, Endian.little);
    header.setUint16(12, 0x5421, Endian.little);
    header.setUint32(14, 0, Endian.little); // CRC placeholder
    header.setUint32(18, 0, Endian.little); // comp size placeholder
    header.setUint32(22, 0, Endian.little); // uncomp size placeholder
    header.setUint16(26, nameBytes.length, Endian.little);
    header.setUint16(28, 0, Endian.little);

    await _raf.writeFrom(header.buffer.asUint8List());
    await _raf.writeFrom(nameBytes);

    final crc = Crc32();
    int totalBytes = 0;

    final inStream = file.openRead();
    await for (final chunk in inStream) {
      crc.add(chunk);
      totalBytes += chunk.length;
      await _raf.writeFrom(chunk);
    }

    final dataEnd = await _raf.position();

    await _raf.setPosition(headerOffset + 14);
    final patch = ByteData(12);
    patch.setUint32(0, crc.value, Endian.little);
    patch.setUint32(4, totalBytes, Endian.little);
    patch.setUint32(8, totalBytes, Endian.little);
    await _raf.writeFrom(patch.buffer.asUint8List());

    await _raf.setPosition(dataEnd);

    _entries.add(_ZipEntryMeta(
      name: entryName,
      nameBytes: nameBytes,
      crc32: crc.value,
      size: totalBytes,
      localHeaderOffset: headerOffset,
    ));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    final cdStart = await _raf.position();

    for (final entry in _entries) {
      final cdHeader = ByteData(46);
      cdHeader.setUint32(0, 0x02014b50, Endian.little);
      cdHeader.setUint16(4, 20, Endian.little);
      cdHeader.setUint16(6, 20, Endian.little);
      cdHeader.setUint16(8, 0x0800, Endian.little);
      cdHeader.setUint16(10, 0, Endian.little);
      cdHeader.setUint16(12, 0, Endian.little);
      cdHeader.setUint16(14, 0x5421, Endian.little);
      cdHeader.setUint32(16, entry.crc32, Endian.little);
      cdHeader.setUint32(20, entry.size, Endian.little);
      cdHeader.setUint32(24, entry.size, Endian.little);
      cdHeader.setUint16(28, entry.nameBytes.length, Endian.little);
      cdHeader.setUint16(30, 0, Endian.little);
      cdHeader.setUint16(32, 0, Endian.little);
      cdHeader.setUint16(34, 0, Endian.little);
      cdHeader.setUint16(36, 0, Endian.little);
      cdHeader.setUint32(38, 0, Endian.little);
      cdHeader.setUint32(42, entry.localHeaderOffset, Endian.little);

      await _raf.writeFrom(cdHeader.buffer.asUint8List());
      await _raf.writeFrom(entry.nameBytes);
    }

    final cdEnd = await _raf.position();
    final cdSize = cdEnd - cdStart;

    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little);
    eocd.setUint16(4, 0, Endian.little);
    eocd.setUint16(6, 0, Endian.little);
    eocd.setUint16(8, _entries.length, Endian.little);
    eocd.setUint16(10, _entries.length, Endian.little);
    eocd.setUint32(12, cdSize, Endian.little);
    eocd.setUint32(16, cdStart, Endian.little);
    eocd.setUint16(20, 0, Endian.little);

    await _raf.writeFrom(eocd.buffer.asUint8List());
    await _raf.close();
  }
}

class ZipReadEntry {
  final String name;
  final int size;
  final int crc32;
  final int dataOffset;

  ZipReadEntry({
    required this.name,
    required this.size,
    required this.crc32,
    required this.dataOffset,
  });
}

class StreamingZipReader {
  final RandomAccessFile _raf;
  final List<ZipReadEntry> entries;

  StreamingZipReader._(this._raf, this.entries);

  static Future<StreamingZipReader> open(File file) async {
    final raf = await file.open(mode: FileMode.read);
    final fileLen = await raf.length();
    if (fileLen < 22) {
      await raf.close();
      throw BackupCorruptArchiveException('Archive truncated: file length $fileLen < 22 bytes');
    }

    final entries = <ZipReadEntry>[];
    int pos = 0;
    while (pos + 4 <= fileLen) {
      await raf.setPosition(pos);
      final sigBytes = await raf.read(4);
      if (sigBytes.length < 4) break;
      final sig = ByteData.sublistView(sigBytes).getUint32(0, Endian.little);

      if (sig == 0x04034b50) {
        final headerBytes = await raf.read(26);
        if (headerBytes.length < 26) {
          await raf.close();
          throw const BackupCorruptArchiveException('Corrupted local header in zip');
        }
        final bd = ByteData.sublistView(headerBytes);
        final compression = bd.getUint16(4, Endian.little);
        final crc32 = bd.getUint32(10, Endian.little);
        final compSize = bd.getUint32(14, Endian.little);
        final uncompSize = bd.getUint32(18, Endian.little);
        final nameLen = bd.getUint16(22, Endian.little);
        final extraLen = bd.getUint16(24, Endian.little);

        if (compression != 0) {
          await raf.close();
          throw BackupCorruptArchiveException('Unsupported compression method: $compression');
        }

        final nameBytes = await raf.read(nameLen);
        if (nameBytes.length < nameLen) {
          await raf.close();
          throw const BackupCorruptArchiveException('Truncated file name in zip');
        }
        final name = utf8.decode(nameBytes);
        final dataOffset = pos + 30 + nameLen + extraLen;

        if (dataOffset + compSize > fileLen) {
          await raf.close();
          throw BackupCorruptArchiveException('Entry $name data extends beyond archive length');
        }

        entries.add(ZipReadEntry(
          name: name,
          size: uncompSize,
          crc32: crc32,
          dataOffset: dataOffset,
        ));

        pos = dataOffset + compSize;
      } else if (sig == 0x02014b50 || sig == 0x06054b50) {
        break;
      } else {
        await raf.close();
        throw BackupCorruptArchiveException('Unexpected zip header signature: 0x${sig.toRadixString(16)}');
      }
    }

    if (entries.isEmpty) {
      await raf.close();
      throw const BackupCorruptArchiveException('Archive contains no file entries');
    }

    return StreamingZipReader._(raf, entries);
  }

  Future<Uint8List> readEntryBytes(ZipReadEntry entry) async {
    await _raf.setPosition(entry.dataOffset);
    final bytes = await _raf.read(entry.size);
    if (bytes.length < entry.size) {
      throw BackupCorruptArchiveException('Truncated entry data for ${entry.name}');
    }
    final crc = Crc32()..add(bytes);
    if (crc.value != entry.crc32) {
      throw BackupCorruptArchiveException('CRC mismatch for ${entry.name}: expected 0x${entry.crc32.toRadixString(16)}, got 0x${crc.value.toRadixString(16)}');
    }
    return bytes;
  }

  Future<void> extractEntryToFile(ZipReadEntry entry, File targetFile, {int chunkSize = 64 * 1024}) async {
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    await _raf.setPosition(entry.dataOffset);
    final outRaf = await targetFile.open(mode: FileMode.write);
    final crc = Crc32();
    int remaining = entry.size;

    try {
      while (remaining > 0) {
        final toRead = remaining > chunkSize ? chunkSize : remaining;
        final chunk = await _raf.read(toRead);
        if (chunk.isEmpty) {
          throw BackupCorruptArchiveException('Unexpected EOF extracting ${entry.name}');
        }
        crc.add(chunk);
        await outRaf.writeFrom(chunk);
        remaining -= chunk.length;
      }
    } finally {
      await outRaf.close();
    }

    if (crc.value != entry.crc32) {
      if (await targetFile.exists()) await targetFile.delete();
      throw BackupCorruptArchiveException('CRC mismatch extracting ${entry.name}');
    }
  }

  Future<void> close() async {
    await _raf.close();
  }
}

class _ExportWorkerParams {
  final SendPort sendPort;
  final String targetZipPath;
  final Map<String, dynamic> dbSnapshot;
  final List<Map<String, String>> attachmentEntries;

  _ExportWorkerParams({
    required this.sendPort,
    required this.targetZipPath,
    required this.dbSnapshot,
    required this.attachmentEntries,
  });
}

void _isolateExportWorker(_ExportWorkerParams params) async {
  try {
    final zipFile = File(params.targetZipPath);
    final writer = await StreamingZipWriter.open(zipFile);

    final dataJsonBytes = utf8.encode(jsonEncode(params.dbSnapshot));
    await writer.addBytes('data.json', dataJsonBytes);
    params.sendPort.send({
      'type': 'progress',
      'current': 0,
      'total': params.attachmentEntries.length,
      'status': 'Database records written',
    });

    final total = params.attachmentEntries.length;
    for (int i = 0; i < total; i++) {
      final entry = params.attachmentEntries[i];
      final file = File(entry['sourcePath']!);
      if (await file.exists()) {
        await writer.addFile(entry['entryName']!, file);
      }
      params.sendPort.send({
        'type': 'progress',
        'current': i + 1,
        'total': total,
        'status': 'Archiving attachment ${i + 1} of $total',
      });
    }

    await writer.close();
    params.sendPort.send({'type': 'done'});
  } catch (e, stack) {
    params.sendPort.send({
      'type': 'error',
      'error': e.toString(),
      'stack': stack.toString(),
    });
  }
}

class _ExtractWorkerParams {
  final SendPort sendPort;
  final String archivePath;
  final String targetAttachmentsDir;
  final bool skipExisting;

  _ExtractWorkerParams({
    required this.sendPort,
    required this.archivePath,
    required this.targetAttachmentsDir,
    required this.skipExisting,
  });
}

void _isolateExtractWorker(_ExtractWorkerParams params) async {
  try {
    final archiveFile = File(params.archivePath);
    final reader = await StreamingZipReader.open(archiveFile);
    final attachmentEntries = reader.entries
        .where((e) => e.name.startsWith('attachments/') && !e.name.endsWith('/'))
        .toList();

    final targetDir = Directory(params.targetAttachmentsDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final total = attachmentEntries.length;
    int extracted = 0;
    for (int i = 0; i < total; i++) {
      final entry = attachmentEntries[i];
      final filename = p.basename(entry.name);
      final targetFile = File(p.join(targetDir.path, filename));

      if (params.skipExisting && await targetFile.exists()) {
        // Skip existing attachment file
      } else {
        await reader.extractEntryToFile(entry, targetFile);
        extracted++;
      }

      params.sendPort.send({
        'type': 'progress',
        'current': i + 1,
        'total': total,
        'status': 'Extracting attachment ${i + 1} of $total',
      });
    }

    await reader.close();
    params.sendPort.send({'type': 'done', 'extractedCount': extracted});
  } catch (e, stack) {
    params.sendPort.send({
      'type': 'error',
      'error': e.toString(),
      'isCorrupt': e is BackupCorruptArchiveException,
      'stack': stack.toString(),
    });
  }
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
      'format_version': 1,
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

      final formatVersion = decoded['format_version'] as int? ?? 1;
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
        formatVersion: formatVersion,
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

  /// Generates a structured database snapshot Map for streaming ZIP backup.
  /// Attachment files are listed by filename in 'attachment_files', never as in-memory Base64 strings.
  static Future<Map<String, dynamic>> createDbSnapshotMap({
    bool includeVehicles = true,
    bool includeRefuelRecords = true,
    bool includeServiceRecords = true,
    bool includeSavedLocations = true,
    bool includeNonFuelExpenses = true,
    bool includeAppSettings = true,
    List<String> attachmentFileNames = const [],
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

    return {
      'format_version': 2,
      'format': 'fueltracker_zip_backup',
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
      'attachments': <String, dynamic>{},
      'attachment_files': attachmentFileNames,
    };
  }

  /// Exports backup to a streaming ZIP archive with `data.json` + `attachments/<filename>` entries.
  /// Streams files one-by-one with O(1) buffer memory, optionally running encode and I/O in a background isolate.
  static Future<File> exportBackupZip({
    required File targetZipFile,
    bool includeVehicles = true,
    bool includeRefuelRecords = true,
    bool includeServiceRecords = true,
    bool includeSavedLocations = true,
    bool includeNonFuelExpenses = true,
    bool includeAppSettings = true,
    bool includeAttachments = true,
    String? customAttachmentsDir,
    BackupProgressCallback? onProgress,
    bool runInIsolate = true,
  }) async {
    final List<Map<String, String>> attachmentEntries = [];
    final List<String> attachmentFileNames = [];

    if (includeAttachments) {
      final attachDirPath = customAttachmentsDir ?? await AttachmentService.getAttachmentsDirectory();
      final attachDir = Directory(attachDirPath);
      if (await attachDir.exists()) {
        final files = attachDir.listSync().whereType<File>().toList();
        for (final file in files) {
          final fileName = p.basename(file.path);
          attachmentFileNames.add(fileName);
          attachmentEntries.add({
            'entryName': 'attachments/$fileName',
            'sourcePath': file.path,
          });
        }
      }
    }

    final dbSnapshot = await createDbSnapshotMap(
      includeVehicles: includeVehicles,
      includeRefuelRecords: includeRefuelRecords,
      includeServiceRecords: includeServiceRecords,
      includeSavedLocations: includeSavedLocations,
      includeNonFuelExpenses: includeNonFuelExpenses,
      includeAppSettings: includeAppSettings,
      attachmentFileNames: attachmentFileNames,
    );

    if (runInIsolate) {
      final receivePort = ReceivePort();
      final params = _ExportWorkerParams(
        sendPort: receivePort.sendPort,
        targetZipPath: targetZipFile.path,
        dbSnapshot: dbSnapshot,
        attachmentEntries: attachmentEntries,
      );

      final isolate = await Isolate.spawn(_isolateExportWorker, params);
      try {
        await for (final msg in receivePort) {
          if (msg is Map) {
            final type = msg['type'] as String?;
            if (type == 'progress') {
              onProgress?.call(
                msg['current'] as int? ?? 0,
                msg['total'] as int? ?? 0,
                msg['status'] as String? ?? '',
              );
            } else if (type == 'done') {
              break;
            } else if (type == 'error') {
              throw BackupArchiveException(
                'Isolate backup export failed: ${msg['error']}',
              );
            }
          }
        }
      } finally {
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      }
    } else {
      final writer = await StreamingZipWriter.open(targetZipFile);
      final dataJsonBytes = utf8.encode(jsonEncode(dbSnapshot));
      await writer.addBytes('data.json', dataJsonBytes);
      onProgress?.call(0, attachmentEntries.length, 'Database records written');

      final total = attachmentEntries.length;
      for (int i = 0; i < total; i++) {
        final entry = attachmentEntries[i];
        final file = File(entry['sourcePath']!);
        if (await file.exists()) {
          await writer.addFile(entry['entryName']!, file);
        }
        onProgress?.call(i + 1, total, 'Archiving attachment ${i + 1} of $total');
      }

      await writer.close();
    }

    return targetZipFile;
  }

  /// Saves backup archive using Android SAF (Storage Access Framework).
  static Future<Uri?> saveBackupZipViaSaf({
    required File zipFile,
    String? customFileName,
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 15);
    final fileName = customFileName ?? 'fueltracker_backup_$timestamp.zip';
    final bytes = await zipFile.readAsBytes();

    return await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/zip',
      dialogTitle: 'Save Backup Archive',
    );
  }

  /// Validates a backup archive (streaming ZIP v2 or legacy JSON v1) and returns a structured summary.
  /// Throws [BackupCorruptArchiveException] if the archive is corrupt, truncated, or tampered.
  static Future<BackupValidationSummary> validateBackupArchive(File archiveFile) async {
    if (!await archiveFile.exists()) {
      throw const BackupArchiveException('Backup file does not exist');
    }

    final len = await archiveFile.length();
    if (len < 4) {
      throw const BackupCorruptArchiveException('Archive file is truncated or empty.');
    }

    final raf = await archiveFile.open(mode: FileMode.read);
    final headerBytes = await raf.read(4);
    await raf.close();

    final bool looksLikeZip = (headerBytes.length == 4 &&
            headerBytes[0] == 0x50 &&
            headerBytes[1] == 0x4B &&
            headerBytes[2] == 0x03 &&
            headerBytes[3] == 0x04) ||
        archiveFile.path.toLowerCase().endsWith('.zip');

    if (looksLikeZip) {
      if (headerBytes.length < 4 ||
          headerBytes[0] != 0x50 ||
          headerBytes[1] != 0x4B ||
          headerBytes[2] != 0x03 ||
          headerBytes[3] != 0x04) {
        throw const BackupCorruptArchiveException('Corrupted ZIP archive: invalid magic header');
      }

      StreamingZipReader? reader;
      try {
        reader = await StreamingZipReader.open(archiveFile);
        final dataJsonEntry = reader.entries.firstWhere(
          (e) => e.name == 'data.json',
          orElse: () => throw const BackupCorruptArchiveException('Archive does not contain data.json entry'),
        );

        final jsonBytes = await reader.readEntryBytes(dataJsonEntry);
        final jsonString = utf8.decode(jsonBytes);
        final decoded = jsonDecode(jsonString);
        if (decoded is! Map<String, dynamic>) {
          throw const BackupCorruptArchiveException('data.json is not a valid JSON object');
        }

        final formatVersion = decoded['format_version'] as int? ?? 2;
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

        final zipAttachmentCount = reader.entries
            .where((e) => e.name.startsWith('attachments/') && !e.name.endsWith('/'))
            .length;

        final attachmentCount = zipAttachmentCount > 0
            ? zipAttachmentCount
            : ((decoded['attachment_files'] as List?)?.length ??
                ((decoded['attachments'] as Map?)?.length ?? 0));

        return BackupValidationSummary(
          formatVersion: formatVersion,
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
          attachmentCount: attachmentCount,
          isValid: true,
        );
      } finally {
        await reader?.close();
      }
    } else {
      // Legacy JSON file
      try {
        final content = await archiveFile.readAsString();
        final summary = validateBackupPayload(content);
        if (!summary.isValid) {
          throw BackupCorruptArchiveException(summary.errorMessage ?? 'Invalid backup payload format');
        }
        return summary;
      } catch (e) {
        if (e is BackupCorruptArchiveException) rethrow;
        throw BackupCorruptArchiveException('Corrupted backup file: $e');
      }
    }
  }

  /// Executes transactional import from archive (streaming ZIP or legacy JSON).
  /// Streams attachments entry-by-entry to disk, preserves conflict resolution strategies,
  /// and updates progress via [onProgress].
  static Future<ImportExecutionResult> executeImportFromArchive({
    required File archiveFile,
    required Set<ImportCategory> selectedCategories,
    required ConflictResolutionStrategy conflictStrategy,
    BackupProgressCallback? onProgress,
    bool runInIsolate = true,
    String? customAttachmentsDir,
  }) async {
    final len = await archiveFile.length();
    if (len < 4) {
      throw const BackupCorruptArchiveException('Archive file is truncated or empty.');
    }

    final raf = await archiveFile.open(mode: FileMode.read);
    final headerBytes = await raf.read(4);
    await raf.close();

    final bool looksLikeZip = (headerBytes.length == 4 &&
            headerBytes[0] == 0x50 &&
            headerBytes[1] == 0x4B &&
            headerBytes[2] == 0x03 &&
            headerBytes[3] == 0x04) ||
        archiveFile.path.toLowerCase().endsWith('.zip');

    if (looksLikeZip) {
      if (headerBytes.length < 4 ||
          headerBytes[0] != 0x50 ||
          headerBytes[1] != 0x4B ||
          headerBytes[2] != 0x03 ||
          headerBytes[3] != 0x04) {
        throw const BackupCorruptArchiveException('Corrupted ZIP archive: invalid magic header');
      }
    } else {
      // Legacy JSON path
      final String content;
      try {
        content = await archiveFile.readAsString();
      } catch (e) {
        throw BackupCorruptArchiveException('Corrupted backup file: cannot read as text ($e)');
      }
      final dynamic decoded;
      try {
        decoded = jsonDecode(content);
      } catch (e) {
        throw BackupCorruptArchiveException('Corrupted backup JSON syntax: $e');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const BackupArchiveException('Legacy file content is not a valid JSON map.');
      }
      return await executeImport(
        payload: decoded,
        selectedCategories: selectedCategories,
        conflictStrategy: conflictStrategy,
      );
    }

    // ZIP archive path
    StreamingZipReader? reader;
    try {
      reader = await StreamingZipReader.open(archiveFile);
      final dataJsonEntry = reader.entries.firstWhere(
        (e) => e.name == 'data.json',
        orElse: () => throw const BackupCorruptArchiveException('Archive missing data.json entry'),
      );

      final jsonBytes = await reader.readEntryBytes(dataJsonEntry);
      final jsonString = utf8.decode(jsonBytes);
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      await reader.close();
      reader = null;

      int importedAttachments = 0;
      if (selectedCategories.contains(ImportCategory.attachments)) {
        final targetAttachmentsDir = customAttachmentsDir ?? await AttachmentService.getAttachmentsDirectory();
        final skipExisting = conflictStrategy == ConflictResolutionStrategy.skipExisting;

        if (runInIsolate) {
          final receivePort = ReceivePort();
          final params = _ExtractWorkerParams(
            sendPort: receivePort.sendPort,
            archivePath: archiveFile.path,
            targetAttachmentsDir: targetAttachmentsDir,
            skipExisting: skipExisting,
          );

          final isolate = await Isolate.spawn(_isolateExtractWorker, params);
          try {
            await for (final msg in receivePort) {
              if (msg is Map) {
                final type = msg['type'] as String?;
                if (type == 'progress') {
                  onProgress?.call(
                    msg['current'] as int? ?? 0,
                    msg['total'] as int? ?? 0,
                    msg['status'] as String? ?? '',
                  );
                } else if (type == 'done') {
                  importedAttachments = msg['extractedCount'] as int? ?? 0;
                  break;
                } else if (type == 'error') {
                  if (msg['isCorrupt'] == true) {
                    throw BackupCorruptArchiveException(msg['error'].toString());
                  }
                  throw BackupArchiveException('Isolate extraction failed: ${msg['error']}');
                }
              }
            }
          } finally {
            receivePort.close();
            isolate.kill(priority: Isolate.immediate);
          }
        } else {
          final syncReader = await StreamingZipReader.open(archiveFile);
          try {
            final attachmentEntries = syncReader.entries
                .where((e) => e.name.startsWith('attachments/') && !e.name.endsWith('/'))
                .toList();

            final targetDir = Directory(targetAttachmentsDir);
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }

            final total = attachmentEntries.length;
            for (int i = 0; i < total; i++) {
              final entry = attachmentEntries[i];
              final filename = p.basename(entry.name);
              final targetFile = File(p.join(targetDir.path, filename));

              if (skipExisting && await targetFile.exists()) {
                // skip existing file
              } else {
                await syncReader.extractEntryToFile(entry, targetFile);
                importedAttachments++;
              }
              onProgress?.call(i + 1, total, 'Extracting attachment ${i + 1} of $total');
            }
          } finally {
            await syncReader.close();
          }
        }
      }

      // Execute SQLite database transaction (excluding attachments since already extracted)
      final categoriesForDb = Set<ImportCategory>.from(selectedCategories)
        ..remove(ImportCategory.attachments);

      final dbResult = await executeImport(
        payload: payload,
        selectedCategories: categoriesForDb,
        conflictStrategy: conflictStrategy,
      );

      return ImportExecutionResult(
        success: dbResult.success,
        message: dbResult.message,
        importedVehicles: dbResult.importedVehicles,
        importedRefuels: dbResult.importedRefuels,
        importedServices: dbResult.importedServices,
        importedLocations: dbResult.importedLocations,
        importedExpenses: dbResult.importedExpenses,
        importedSettings: dbResult.importedSettings,
        importedAttachments: importedAttachments,
      );
    } finally {
      await reader?.close();
    }
  }
}
