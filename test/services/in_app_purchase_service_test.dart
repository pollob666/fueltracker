// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/in_app_purchase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppPurchaseService & AdRemovalNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial ad removal state is false by default', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isRemoved = container.read(isAdRemovedProvider);
      expect(isRemoved, isFalse);
    });

    test('AdRemovalNotifier updates state and persists in SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(isAdRemovedProvider.notifier).setAdRemoved(true);
      expect(container.read(isAdRemovedProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefKeyIsAdsRemoved), isTrue);

      await container.read(isAdRemovedProvider.notifier).setAdRemoved(false);
      expect(container.read(isAdRemovedProvider), isFalse);
      expect(prefs.getBool(kPrefKeyIsAdsRemoved), isFalse);
    });

    test('InAppPurchaseService sandbox fallback sets ad removal', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // In tests/headless, store is unavailable, so buyAdFreeUpgrade triggers fallback
      final success = await InAppPurchaseService.instance.buyAdFreeUpgrade(
        ref: container.read(isAdRemovedProvider.notifier) as dynamic,
      );

      expect(success, isTrue);
    });
  });
}
