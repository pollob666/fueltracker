// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/backup_encryption_service.dart';

void main() {
  group('BackupEncryptionService Tests', () {
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

    test('encrypts and decrypts valid payload roundtrip (fast iterations)', () {
      // Use 1,000 iterations for unit test speed
      final bundle = BackupEncryptionService.encryptBackup(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      expect(bundle.format, equals('ftbackup'));
      expect(bundle.saltBase64, isNotEmpty);
      expect(bundle.ivBase64, isNotEmpty);
      expect(bundle.ciphertextBase64, isNotEmpty);

      // Decrypt
      final decrypted = BackupEncryptionService.decryptBackup(
        bundle: bundle,
        password: testPassword,
      );

      expect(decrypted['vehicles'], isList);
      expect((decrypted['vehicles'] as List).length, equals(1));
      expect(decrypted['vehicles'][0]['name'], equals('Toyota Prado'));
      expect(decrypted['fuelRecords'][0]['paidAmount'], equals(4615.0));
    });

    test('throws BackupDecryptionException when password is incorrect', () {
      final bundle = BackupEncryptionService.encryptBackup(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      expect(
        () => BackupEncryptionService.decryptBackup(
          bundle: bundle,
          password: 'WrongPassword456',
        ),
        throwsA(isA<BackupDecryptionException>()),
      );
    });

    test('serializes bundle to JSON and parses back cleanly', () {
      final bundle = BackupEncryptionService.encryptBackup(
        data: testData,
        password: testPassword,
        iterations: 1000,
      );

      final jsonString = bundle.toJson();
      expect(jsonString, contains('"format":"ftbackup"'));

      final restoredBundle = EncryptedBackupBundle.fromJson(jsonString);
      expect(restoredBundle.ciphertextBase64, equals(bundle.ciphertextBase64));

      final decrypted = BackupEncryptionService.decryptBackup(
        bundle: restoredBundle,
        password: testPassword,
      );
      expect(decrypted['vehicles'][0]['name'], equals('Toyota Prado'));
    });

    test('rejects corrupted ciphertext or invalid format', () {
      const invalidJson = '{"format":"wrong_format","ciphertext":"xyz"}';
      expect(
        () => EncryptedBackupBundle.fromJson(invalidJson),
        throwsA(isA<BackupDecryptionException>()),
      );
    });
  });
}
