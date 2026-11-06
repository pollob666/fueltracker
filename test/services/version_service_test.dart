// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/version_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VersionService.isDismissedForSession = false;
  });

  group('VersionService Dismissal and Skip Version Tests', () {
    test('isVersionSkipped returns false when no version is saved', () async {
      final service = VersionService();
      final isSkipped = await service.isVersionSkipped('v1.2.3');
      expect(isSkipped, isFalse);
    });

    test('skipVersion stores version and isVersionSkipped returns true', () async {
      final service = VersionService();
      await service.skipVersion('v1.2.3');

      final isSkippedCurrent = await service.isVersionSkipped('v1.2.3');
      final isSkippedNewer = await service.isVersionSkipped('v1.2.4');

      expect(isSkippedCurrent, isTrue);
      expect(isSkippedNewer, isFalse);
    });

    test('dismissForSession toggles in-memory session flag', () {
      final service = VersionService();
      expect(VersionService.isDismissedForSession, isFalse);

      service.dismissForSession();
      expect(VersionService.isDismissedForSession, isTrue);
    });
  });
}
