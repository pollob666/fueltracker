// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService V2 & V1 Tests', () {
    const testPassword = 'StrongMasterPassword123!#';
    final testData = {
      'vehicles': [
        {'id': 1, 'name': 'Toyota Prado', 'type': 'suv'},
      ],
      'fuelRecords': [
        {'id': 101, 'odometer': 45200.0, 'volume': 35.5, 'paidAmount': 4615.0},
      ],
      'settings': {
        'adsEnabled': false,
        'theme': 'dark',
      },
    };

    test('v2 round-trip: encrypts and decrypts with AES-256-GCM and authenticated header', () async {
      // 1,000 iterations for unit test speed
      final backupBytes = await BackupEncryptionService.encryptBackupV2(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      // Verify file header structure
      expect(backupBytes.length, greaterThan(BackupHeaderV2.headerLength + 16));
      expect(backupBytes.sublist(0, 4), equals([0x46, 0x54, 0x42, 0x4B])); // "FTBK"

      final header = BackupHeaderV2.fromBytes(backupBytes);
      expect(header.version, equals(2));
      expect(header.kdfId, equals(1)); // PBKDF2-HMAC-SHA256
      expect(header.iterations, equals(1000));
      expect(header.salt.length, equals(16));
      expect(header.nonce.length, equals(12));

      // Decrypt using universal decryptBackup
      final decrypted = await BackupEncryptionService.decryptBackup(
        backup: backupBytes,
        password: testPassword,
      );

      expect(decrypted['vehicles'], isList);
      expect((decrypted['vehicles'] as List).length, equals(1));
      expect(decrypted['vehicles'][0]['name'], equals('Toyota Prado'));
      expect(decrypted['fuelRecords'][0]['paidAmount'], equals(4615.0));
      expect(decrypted['settings']['theme'], equals('dark'));
    });

    test('v1 legacy read: successfully decrypts legacy V1 AES-256-CBC archives', () async {
      // Create legacy V1 bundle (1,000 iterations for speed)
      final v1Bundle = BackupEncryptionService.encryptBackupV1Legacy(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      expect(v1Bundle.format, equals('ftbackup'));
      expect(v1Bundle.version, equals(1));

      // 1. Decrypt from EncryptedBackupBundle directly
      final decryptedBundle = await BackupEncryptionService.decryptBackup(
        backup: v1Bundle,
        password: testPassword,
      );
      expect(decryptedBundle['vehicles'][0]['name'], equals('Toyota Prado'));

      // 2. Decrypt from JSON string
      final jsonString = v1Bundle.toJson();
      final decryptedJson = await BackupEncryptionService.decryptBackup(
        backup: jsonString,
        password: testPassword,
      );
      expect(decryptedJson['vehicles'][0]['name'], equals('Toyota Prado'));

      // 3. Decrypt from UTF-8 bytes (simulating reading a legacy v1 file as raw bytes)
      final rawBytes = Uint8List.fromList(utf8.encode(jsonString));
      final decryptedBytes = await BackupEncryptionService.decryptBackup(
        backup: rawBytes,
        password: testPassword,
      );
      expect(decryptedBytes['vehicles'][0]['name'], equals('Toyota Prado'));
    });

    test('tamper one byte in ciphertext -> throws BackupAuthenticationException', () async {
      final backupBytes = await BackupEncryptionService.encryptBackupV2(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      // Mutate one byte in the ciphertext / tag region (after 40-byte header)
      final tamperedBytes = Uint8List.fromList(backupBytes);
      tamperedBytes[BackupHeaderV2.headerLength + 5] ^= 0x55;

      expect(
        () async => await BackupEncryptionService.decryptBackup(
          backup: tamperedBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('tamper one byte in AAD header (nonce/salt) -> throws BackupAuthenticationException', () async {
      final backupBytes = await BackupEncryptionService.encryptBackupV2(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      // Mutate one byte of the nonce in the header (offset 30)
      final tamperedNonceBytes = Uint8List.fromList(backupBytes);
      tamperedNonceBytes[30] ^= 0x01;

      expect(
        () async => await BackupEncryptionService.decryptBackup(
          backup: tamperedNonceBytes,
          password: testPassword,
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('tamper magic bytes in header -> throws BackupCorruptHeaderException', () async {
      final backupBytes = await BackupEncryptionService.encryptBackupV2(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      // Corrupt magic byte "F" -> "X"
      final tamperedMagic = Uint8List.fromList(backupBytes);
      tamperedMagic[0] = 0x58; // 'X'

      expect(
        () async => await BackupEncryptionService.decryptBackup(
          backup: tamperedMagic,
          password: testPassword,
        ),
        throwsA(isA<BackupCorruptHeaderException>()),
      );
    });

    test('wrong password -> throws BackupAuthenticationException with user-friendly message', () async {
      final backupBytes = await BackupEncryptionService.encryptBackupV2(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      expect(
        () async => await BackupEncryptionService.decryptBackup(
          backup: backupBytes,
          password: 'IncorrectPassword999!',
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );

      // Also verify typed exception message
      try {
        await BackupEncryptionService.decryptBackup(
          backup: backupBytes,
          password: 'IncorrectPassword999!',
        );
        fail('Should have thrown BackupAuthenticationException');
      } on BackupAuthenticationException catch (e) {
        expect(e.message, contains('Incorrect password or corrupted backup'));
      }
    });

    test('header iteration count is honored dynamically during decryption', () async {
      const customIterations = 3500;
      final backupBytes = await BackupEncryptionService.encryptBackupV2(
        data: testData,
        password: testPassword,
        iterations: customIterations,
      );

      // Verify the header explicitly encodes customIterations (3500 = 0x00000DB4)
      final header = BackupHeaderV2.fromBytes(backupBytes);
      expect(header.iterations, equals(customIterations));

      // Decryption dynamically extracts and honors customIterations without caller passing it
      final decrypted = await BackupEncryptionService.decryptBackup(
        backup: backupBytes,
        password: testPassword,
      );
      expect(decrypted['vehicles'][0]['name'], equals('Toyota Prado'));

      // If header iteration count is altered, AAD mismatch or derived key mismatch causes failure
      final tamperedIterations = Uint8List.fromList(backupBytes);
      final byteData = ByteData.sublistView(tamperedIterations);
      byteData.setUint32(8, 2000, Endian.big); // Change 3500 to 2000

      expect(
        () async => await BackupEncryptionService.decryptBackup(
          backup: tamperedIterations,
          password: testPassword,
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('async isolate PBKDF2 matches synchronous derivation and defaults to 600,000 iterations', () async {
      expect(BackupEncryptionService.defaultIterationsV2, equals(600000));

      final salt = BackupEncryptionService.generateRandomBytes(16);
      final syncKey = BackupEncryptionService.deriveKey(testPassword, salt, iterations: 1000);
      final asyncKey = await BackupEncryptionService.deriveKeyAsync(testPassword, salt, iterations: 1000);

      expect(asyncKey, equals(syncKey));
      expect(asyncKey.length, equals(32));
    });
  });
}
