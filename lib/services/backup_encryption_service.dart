// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';

class BackupDecryptionException implements Exception {
  final String message;
  const BackupDecryptionException(this.message);
  @override
  String toString() => 'BackupDecryptionException: $message';
}

class EncryptedBackupBundle {
  final String format;
  final int version;
  final DateTime createdAt;
  final String saltBase64;
  final String ivBase64;
  final int iterations;
  final String ciphertextBase64;

  const EncryptedBackupBundle({
    this.format = 'ftbackup',
    this.version = 1,
    required this.createdAt,
    required this.saltBase64,
    required this.ivBase64,
    required this.iterations,
    required this.ciphertextBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'format': format,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'salt': saltBase64,
      'iv': ivBase64,
      'iterations': iterations,
      'ciphertext': ciphertextBase64,
    };
  }

  factory EncryptedBackupBundle.fromMap(Map<String, dynamic> map) {
    if (map['format'] != 'ftbackup') {
      throw const BackupDecryptionException('Unrecognized backup file format.');
    }
    return EncryptedBackupBundle(
      format: map['format'] as String? ?? 'ftbackup',
      version: map['version'] as int? ?? 1,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      saltBase64: map['salt'] as String,
      ivBase64: map['iv'] as String,
      iterations: map['iterations'] as int? ?? 100000,
      ciphertextBase64: map['ciphertext'] as String,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory EncryptedBackupBundle.fromJson(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return EncryptedBackupBundle.fromMap(map);
    } catch (e) {
      if (e is BackupDecryptionException) rethrow;
      throw BackupDecryptionException('Failed to parse backup manifest: $e');
    }
  }
}

class BackupEncryptionService {
  static const int defaultIterations = 100000;
  static const int keyLength = 32; // 256 bits

  /// Derives a 256-bit symmetric key from password and salt using PBKDF2-HMAC-SHA256.
  static Uint8List deriveKey(String password, Uint8List salt, {int iterations = defaultIterations}) {
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(salt, iterations, keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generates cryptographically secure random bytes.
  static Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Encrypts plaintext JSON data into an authenticated AES-256-CBC bundle.
  static EncryptedBackupBundle encryptBackup({
    required Map<String, dynamic> data,
    required String password,
    int iterations = defaultIterations,
  }) {
    if (password.trim().isEmpty) {
      throw ArgumentError('Encryption password cannot be empty.');
    }

    final salt = generateRandomBytes(16);
    final keyBytes = deriveKey(password, salt, iterations: iterations);
    final ivBytes = generateRandomBytes(16);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final jsonString = jsonEncode(data);
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    return EncryptedBackupBundle(
      createdAt: DateTime.now().toUtc(),
      saltBase64: base64Encode(salt),
      ivBase64: base64Encode(ivBytes),
      iterations: iterations,
      ciphertextBase64: encrypted.base64,
    );
  }

  /// Decrypts an EncryptedBackupBundle with the specified password.
  /// Throws [BackupDecryptionException] if the password is incorrect or data is corrupted.
  static Map<String, dynamic> decryptBackup({
    required EncryptedBackupBundle bundle,
    required String password,
  }) {
    if (password.trim().isEmpty) {
      throw const BackupDecryptionException('Password cannot be empty.');
    }

    try {
      final salt = base64Decode(bundle.saltBase64);
      final ivBytes = base64Decode(bundle.ivBase64);
      final keyBytes = deriveKey(password, salt, iterations: bundle.iterations);

      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decryptedText = encrypter.decrypt64(bundle.ciphertextBase64, iv: iv);
      return jsonDecode(decryptedText) as Map<String, dynamic>;
    } catch (e) {
      throw BackupDecryptionException(
        'Decryption failed. Please verify your password. (Details: $e)',
      );
    }
  }

  /// Extracts all database records, app settings, and optionally scoped image attachments.
  static Future<Map<String, dynamic>> buildBackupPayload({
    bool includeAttachments = true,
  }) async {
    final dbData = await DatabaseHelper.instance.dumpAllData();
    final settings = AppSettings.toMap();

    final Map<String, String> attachmentsMap = {};
    if (includeAttachments) {
      try {
        final attachDirPath = await AttachmentService.getAttachmentsDirectory();
        final attachDir = Directory(attachDirPath);
        if (await attachDir.exists()) {
          final files = attachDir.listSync().whereType<File>();
          for (final f in files) {
            final fileName = p.basename(f.path);
            final bytes = await f.readAsBytes();
            attachmentsMap[fileName] = base64Encode(bytes);
          }
        }
      } catch (_) {}
    }

    return {
      'format': 'fueltracker_complete_backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'database': dbData,
      'settings': settings,
      'attachments': attachmentsMap,
    };
  }

  /// Creates and writes an encrypted `.ftbackup` file to a temporary location.
  static Future<File> createEncryptedBackupFile({
    required String password,
    bool includeAttachments = true,
    int iterations = defaultIterations,
  }) async {
    final payload = await buildBackupPayload(includeAttachments: includeAttachments);
    final bundle = encryptBackup(
      data: payload,
      password: password,
      iterations: iterations,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '_');
    final backupFile = File(p.join(tempDir.path, 'fueltracker_backup_$timestamp.ftbackup'));
    await backupFile.writeAsString(bundle.toJson());
    return backupFile;
  }

  /// Restores database, settings, and attachments from a decrypted payload.
  static Future<void> restoreFromDecryptedPayload({
    required Map<String, dynamic> payload,
    bool replaceExisting = false,
  }) async {
    final dbData = payload['database'] as Map<String, dynamic>?;
    if (dbData != null) {
      await DatabaseHelper.instance.restoreAllData(dbData, replaceExisting: replaceExisting);
    }

    final settings = payload['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      await AppSettings.fromMap(settings);
    }

    final attachments = payload['attachments'] as Map<String, dynamic>?;
    if (attachments != null && attachments.isNotEmpty) {
      try {
        final attachDirPath = await AttachmentService.getAttachmentsDirectory();
        for (final entry in attachments.entries) {
          final fileName = entry.key;
          final base64Content = entry.value as String;
          final bytes = base64Decode(base64Content);
          final file = File(p.join(attachDirPath, fileName));
          await file.writeAsBytes(bytes);
        }
      } catch (_) {}
    }
  }

  /// Summarizes payload counts for user preview before restoration.
  static Map<String, int> getPayloadSummary(Map<String, dynamic> payload) {
    final db = payload['database'] as Map<String, dynamic>? ?? {};
    final attachments = payload['attachments'] as Map<String, dynamic>? ?? {};

    return {
      'vehicles': (db['vehicles'] as List?)?.length ?? 0,
      'fuelRecords': (db['fuel_records'] as List?)?.length ?? 0,
      'serviceSessions': (db['service_sessions'] as List?)?.length ?? 0,
      'nonFuelExpenses': (db['non_fuel_expenses'] as List?)?.length ?? 0,
      'savedLocations': (db['saved_locations'] as List?)?.length ?? 0,
      'attachments': attachments.length,
    };
  }
}
