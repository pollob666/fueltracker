// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';

/// Base exception for backup encryption/decryption errors.
class BackupDecryptionException implements Exception {
  final String message;
  const BackupDecryptionException(this.message);
  @override
  String toString() => 'BackupDecryptionException: $message';
}

/// Thrown when authentication tag verification fails, padding is invalid, or wrong password is provided.
class BackupAuthenticationException extends BackupDecryptionException {
  const BackupAuthenticationException([
    super.message = 'Decryption failed: Incorrect password or corrupted backup data.',
  ]);
}

/// Thrown when the file header is corrupt, truncated, or has invalid magic bytes.
class BackupCorruptHeaderException extends BackupDecryptionException {
  const BackupCorruptHeaderException([
    super.message = 'Invalid backup format: Corrupted or unrecognized file header.',
  ]);
}

/// Thrown when an unsupported backup version is encountered.
class BackupUnsupportedVersionException extends BackupDecryptionException {
  final int version;
  const BackupUnsupportedVersionException(this.version)
      : super('Unsupported backup format version: $version.');
}

/// Legacy V1 backup bundle representation (JSON-based AES-256-CBC).
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
      throw const BackupCorruptHeaderException('Unrecognized backup file format.');
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
      throw BackupCorruptHeaderException('Failed to parse backup manifest: $e');
    }
  }
}

/// V2 Backup Header specification.
///
/// Binary layout (40 bytes total):
/// - [0..3]: Magic bytes ASCII "FTBK" (4 bytes)
/// - [4..5]: Format Version (uint16 big-endian, value = 2)
/// - [6..7]: KDF ID (uint16 big-endian, value = 1 for PBKDF2-HMAC-SHA256)
/// - [8..11]: Iterations (uint32 big-endian, default = 600,000)
/// - [12..27]: Salt (16 bytes random)
/// - [28..39]: Nonce / IV (12 bytes random)
class BackupHeaderV2 {
  static const List<int> magicBytes = [0x46, 0x54, 0x42, 0x4B]; // 'FTBK'
  static const int currentVersion = 2;
  static const int kdfPbkdf2HmacSha256 = 1;
  static const int headerLength = 40;
  static const int saltLength = 16;
  static const int nonceLength = 12;

  final int version;
  final int kdfId;
  final int iterations;
  final Uint8List salt;
  final Uint8List nonce;

  const BackupHeaderV2({
    this.version = currentVersion,
    this.kdfId = kdfPbkdf2HmacSha256,
    required this.iterations,
    required this.salt,
    required this.nonce,
  });

  Uint8List toBytes() {
    final bytes = Uint8List(headerLength);
    final byteData = ByteData.sublistView(bytes);

    bytes.setRange(0, 4, magicBytes);
    byteData.setUint16(4, version, Endian.big);
    byteData.setUint16(6, kdfId, Endian.big);
    byteData.setUint32(8, iterations, Endian.big);
    bytes.setRange(12, 28, salt);
    bytes.setRange(28, 40, nonce);

    return bytes;
  }

  factory BackupHeaderV2.fromBytes(Uint8List bytes) {
    if (bytes.length < headerLength) {
      throw const BackupCorruptHeaderException(
        'Backup file header is truncated or incomplete.',
      );
    }

    // Verify magic bytes "FTBK"
    if (bytes[0] != magicBytes[0] ||
        bytes[1] != magicBytes[1] ||
        bytes[2] != magicBytes[2] ||
        bytes[3] != magicBytes[3]) {
      throw const BackupCorruptHeaderException(
        'Invalid backup header magic bytes. Not a valid .ftbackup archive.',
      );
    }

    final byteData = ByteData.sublistView(bytes);
    final version = byteData.getUint16(4, Endian.big);
    if (version != currentVersion) {
      throw BackupUnsupportedVersionException(version);
    }

    final kdfId = byteData.getUint16(6, Endian.big);
    if (kdfId != kdfPbkdf2HmacSha256) {
      throw BackupCorruptHeaderException(
        'Unsupported key derivation function ID ($kdfId).',
      );
    }

    final iterations = byteData.getUint32(8, Endian.big);
    if (iterations < 1000) {
      throw const BackupCorruptHeaderException(
        'Insecure or corrupted iteration count in backup header.',
      );
    }

    final salt = Uint8List.fromList(bytes.sublist(12, 28));
    final nonce = Uint8List.fromList(bytes.sublist(28, 40));

    return BackupHeaderV2(
      version: version,
      kdfId: kdfId,
      iterations: iterations,
      salt: salt,
      nonce: nonce,
    );
  }
}

/// Isolate entrypoint for PBKDF2-HMAC-SHA256 key derivation.
Uint8List _deriveKeyIsolate(Map<String, dynamic> params) {
  final password = params['password'] as String;
  final salt = params['salt'] as Uint8List;
  final iterations = params['iterations'] as int;
  final keyLength = params['keyLength'] as int;

  final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
    ..init(pc.Pbkdf2Parameters(salt, iterations, keyLength));
  return derivator.process(Uint8List.fromList(utf8.encode(password)));
}

class BackupEncryptionService {
  static const int legacyDefaultIterations = 100000;
  static const int defaultIterationsV2 = 600000;
  static const int keyLength = 32; // 256 bits
  static const int tagLengthBits = 128; // 16 bytes authentication tag

  /// Synchronous key derivation via PBKDF2-HMAC-SHA256.
  static Uint8List deriveKey(
    String password,
    Uint8List salt, {
    int iterations = defaultIterationsV2,
  }) {
    final derivator = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(salt, iterations, keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Asynchronous key derivation run in background isolate (`compute`) to prevent UI freezes.
  static Future<Uint8List> deriveKeyAsync(
    String password,
    Uint8List salt, {
    int iterations = defaultIterationsV2,
  }) async {
    return await compute(_deriveKeyIsolate, {
      'password': password,
      'salt': salt,
      'iterations': iterations,
      'keyLength': keyLength,
    });
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

  /// Encrypts plaintext JSON payload into V2 format: AES-256-GCM authenticated container.
  ///
  /// File Structure:
  /// - Header (40 bytes): Magic 'FTBK', Version 2, KDF 1, Iterations, 16-byte Salt, 12-byte Nonce.
  /// - AAD: Exactly the 40-byte header.
  /// - Ciphertext + 16-byte GCM authentication tag.
  static Future<Uint8List> encryptBackupV2({
    required Map<String, dynamic> data,
    required String password,
    int iterations = defaultIterationsV2,
  }) async {
    if (password.trim().isEmpty) {
      throw ArgumentError('Encryption password cannot be empty.');
    }

    final salt = generateRandomBytes(BackupHeaderV2.saltLength);
    final nonce = generateRandomBytes(BackupHeaderV2.nonceLength);

    final header = BackupHeaderV2(
      iterations: iterations,
      salt: salt,
      nonce: nonce,
    );
    final headerBytes = header.toBytes();

    // Derive 256-bit key in isolate
    final keyBytes = await deriveKeyAsync(password, salt, iterations: iterations);

    // AES-256-GCM encryption with header as Additional Authenticated Data (AAD)
    final cipher = pc.GCMBlockCipher(pc.AESEngine());
    final params = pc.AEADParameters(
      pc.KeyParameter(keyBytes),
      tagLengthBits,
      nonce,
      headerBytes,
    );
    cipher.init(true, params);

    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    final ciphertextWithTag = cipher.process(jsonBytes);

    final output = Uint8List(headerBytes.length + ciphertextWithTag.length);
    output.setRange(0, headerBytes.length, headerBytes);
    output.setRange(headerBytes.length, output.length, ciphertextWithTag);

    return output;
  }

  /// Decrypts a V2 backup archive using AES-256-GCM.
  /// Throws [BackupAuthenticationException] on wrong password or tampering.
  static Future<Map<String, dynamic>> decryptBackupV2({
    required Uint8List backupBytes,
    required String password,
  }) async {
    if (password.trim().isEmpty) {
      throw const BackupAuthenticationException('Password cannot be empty.');
    }

    final header = BackupHeaderV2.fromBytes(backupBytes);
    final headerBytes = Uint8List.fromList(
      backupBytes.sublist(0, BackupHeaderV2.headerLength),
    );
    final ciphertextWithTag = Uint8List.fromList(
      backupBytes.sublist(BackupHeaderV2.headerLength),
    );

    if (ciphertextWithTag.length < 16) {
      throw const BackupAuthenticationException(
        'Backup payload is truncated or corrupted.',
      );
    }

    // Derive key using iterations specified in the header in isolate
    final keyBytes = await deriveKeyAsync(
      password,
      header.salt,
      iterations: header.iterations,
    );

    try {
      final cipher = pc.GCMBlockCipher(pc.AESEngine());
      final params = pc.AEADParameters(
        pc.KeyParameter(keyBytes),
        tagLengthBits,
        header.nonce,
        headerBytes, // Authenticate the exact header bytes as AAD
      );
      cipher.init(false, params);

      final decryptedBytes = cipher.process(ciphertextWithTag);
      final jsonString = utf8.decode(decryptedBytes);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } on pc.InvalidCipherTextException {
      throw const BackupAuthenticationException(
        'Decryption failed: Incorrect password or corrupted backup archive.',
      );
    } catch (e) {
      if (e is BackupDecryptionException) rethrow;
      throw BackupAuthenticationException(
        'Decryption failed: Incorrect password or corrupted backup archive.',
      );
    }
  }

  // =========================================================================
  // === LEGACY V1 DECRYPTION & COMPATIBILITY PATH (AES-256-CBC) ===
  // =========================================================================

  /// Legacy V1 encryptor: creates an EncryptedBackupBundle using AES-256-CBC.
  /// Maintained for test coverage and format compatibility verification.
  static EncryptedBackupBundle encryptBackupV1Legacy({
    required Map<String, dynamic> data,
    required String password,
    int iterations = legacyDefaultIterations,
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

  /// Legacy V1 decryptor: decrypts an EncryptedBackupBundle using AES-256-CBC.
  /// Throws [BackupAuthenticationException] on incorrect password or padding failure.
  static Future<Map<String, dynamic>> decryptBackupV1Legacy({
    required EncryptedBackupBundle bundle,
    required String password,
  }) async {
    if (password.trim().isEmpty) {
      throw const BackupAuthenticationException('Password cannot be empty.');
    }

    try {
      final salt = base64Decode(bundle.saltBase64);
      final ivBytes = base64Decode(bundle.ivBase64);
      final keyBytes = await deriveKeyAsync(
        password,
        salt,
        iterations: bundle.iterations,
      );

      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final decryptedText = encrypter.decrypt64(bundle.ciphertextBase64, iv: iv);
      return jsonDecode(decryptedText) as Map<String, dynamic>;
    } catch (e) {
      throw const BackupAuthenticationException(
        'Legacy V1 decryption failed: Incorrect password or corrupted backup.',
      );
    }
  }

  /// Universal decryptor that inspects incoming data format and routes:
  /// - If binary header magic matches 'FTBK', executes V2 AES-256-GCM path.
  /// - Otherwise executes clearly marked legacy V1 AES-256-CBC path.
  ///
  /// Accepts [Uint8List], [List<int>], [String] (v1 JSON), or [EncryptedBackupBundle].
  static Future<Map<String, dynamic>> decryptBackup({
    required dynamic backup,
    required String password,
  }) async {
    if (backup is EncryptedBackupBundle) {
      return await decryptBackupV1Legacy(bundle: backup, password: password);
    }

    Uint8List bytes;
    if (backup is Uint8List) {
      bytes = backup;
    } else if (backup is List<int>) {
      bytes = Uint8List.fromList(backup);
    } else if (backup is String) {
      // Check if it's a V1 JSON string
      try {
        final bundle = EncryptedBackupBundle.fromJson(backup);
        return await decryptBackupV1Legacy(bundle: bundle, password: password);
      } catch (e) {
        if (e is BackupDecryptionException) rethrow;
        throw BackupCorruptHeaderException('Unrecognized backup format: $e');
      }
    } else {
      throw const BackupCorruptHeaderException('Unsupported backup input type.');
    }

    // Check for V2 magic bytes: 'FTBK'
    if (bytes.length >= 4 &&
        bytes[0] == 0x46 &&
        bytes[1] == 0x54 &&
        bytes[2] == 0x42 &&
        bytes[3] == 0x4B) {
      return await decryptBackupV2(backupBytes: bytes, password: password);
    }

    // Not V2 magic bytes: attempt legacy V1 JSON decode
    try {
      final jsonString = utf8.decode(bytes);
      final bundle = EncryptedBackupBundle.fromJson(jsonString);
      return await decryptBackupV1Legacy(bundle: bundle, password: password);
    } catch (e) {
      if (e is BackupDecryptionException) rethrow;
      throw const BackupCorruptHeaderException(
        'Unrecognized or corrupted backup file format.',
      );
    }
  }

  /// Standard entrypoint to encrypt backups. Always writes format V2.
  static Future<Uint8List> encryptBackup({
    required Map<String, dynamic> data,
    required String password,
    int iterations = defaultIterationsV2,
  }) async {
    return await encryptBackupV2(
      data: data,
      password: password,
      iterations: iterations,
    );
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
      'version': 2,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'database': dbData,
      'settings': settings,
      'attachments': attachmentsMap,
    };
  }

  /// Creates and writes an encrypted `.ftbackup` file (Format V2) to a temporary location.
  static Future<File> createEncryptedBackupFile({
    required String password,
    bool includeAttachments = true,
    int iterations = defaultIterationsV2,
  }) async {
    final payload = await buildBackupPayload(includeAttachments: includeAttachments);
    final backupBytes = await encryptBackup(
      data: payload,
      password: password,
      iterations: iterations,
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '_');
    final backupFile = File(p.join(tempDir.path, 'fueltracker_backup_$timestamp.ftbackup'));
    await backupFile.writeAsBytes(backupBytes);
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
      'tires': (db['tires'] as List?)?.length ?? 0,
      'tireLogs': (db['tire_logs'] as List?)?.length ?? 0,
      'attachments': attachments.length,
    };
  }
}

