// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/in_app_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeInAppPurchase extends Fake implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  List<ProductDetails> products = [
    ProductDetails(
      id: kAdFreeProductId,
      title: 'Remove Ads',
      description: 'Ad-Free FuelTracker',
      price: '\$1.99',
      rawPrice: 1.99,
      currencyCode: 'USD',
    ),
  ];
  List<PurchaseDetails> completedPurchases = [];
  bool restorePurchasesCalled = false;
  Future<void> Function()? onRestorePurchases;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: products.where((p) => identifiers.contains(p.id)).toList(),
      notFoundIDs: identifiers.difference(products.map((p) => p.id).toSet()).toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return true;
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) async {
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restorePurchasesCalled = true;
    if (onRestorePurchases != null) {
      await onRestorePurchases!();
    }
  }

  void dispose() {
    controller.close();
  }
}

PurchaseDetails createTestPurchase({
  required PurchaseStatus status,
  String productID = kAdFreeProductId,
  String purchaseID = 'test_order_123',
  bool pendingComplete = true,
  IAPError? error,
}) {
  final purchase = PurchaseDetails(
    productID: productID,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local_token_mock',
      serverVerificationData: 'server_token_mock',
      source: 'google_play',
    ),
    transactionDate: '1730000000000',
    status: status,
    purchaseID: purchaseID,
  );
  purchase.pendingCompletePurchase = pendingComplete;
  purchase.error = error;
  return purchase;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeInAppPurchase fakeIap;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeIap = FakeInAppPurchase();
    InAppPurchaseService.enableDebugSandboxBypass = true;
    InAppPurchaseService.instance.setInAppPurchaseForTesting(fakeIap);
  });

  tearDown(() {
    InAppPurchaseService.instance.dispose();
    fakeIap.dispose();
  });

  group('AdRemovalNotifier Tests', () {
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
  });

  group('Sandbox Bypass Release Guard Tests', () {
    test('Sandbox bypass succeeds in debug/test when explicitly enabled', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      fakeIap.available = false; // Store unavailable
      InAppPurchaseService.enableDebugSandboxBypass = true;

      final success = await InAppPurchaseService.instance.buyAdFreeUpgrade(
        ref: container.read(isAdRemovedProvider.notifier),
      );

      expect(success, isTrue);
      expect(container.read(isAdRemovedProvider), isTrue);
    });

    test('Sandbox bypass is strictly blocked when disabled (simulating release mode)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      fakeIap.available = false; // Store unavailable
      InAppPurchaseService.enableDebugSandboxBypass = false; // Guarded

      final success = await InAppPurchaseService.instance.buyAdFreeUpgrade(
        ref: container.read(isAdRemovedProvider.notifier),
      );

      expect(success, isFalse);
      expect(container.read(isAdRemovedProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefKeyIsAdsRemoved) ?? false, isFalse);
    });
  });

  group('Purchase Stream State Handling & completePurchase Guarantees', () {
    test('PurchaseStatus.purchased: unlocks ad-free and calls completePurchase', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));

      final purchase = createTestPurchase(status: PurchaseStatus.purchased);
      fakeIap.controller.add([purchase]);
      await pumpEventQueue();

      expect(container.read(isAdRemovedProvider), isTrue);
      expect(fakeIap.completedPurchases, contains(purchase));
    });

    test('PurchaseStatus.restored: unlocks ad-free and calls completePurchase', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));

      final purchase = createTestPurchase(status: PurchaseStatus.restored);
      fakeIap.controller.add([purchase]);
      await pumpEventQueue();

      expect(container.read(isAdRemovedProvider), isTrue);
      expect(fakeIap.completedPurchases, contains(purchase));
    });

    test('PurchaseStatus.pending: does NOT unlock, but completes if pendingCompletePurchase is true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));

      final purchase = createTestPurchase(status: PurchaseStatus.pending);
      fakeIap.controller.add([purchase]);
      await pumpEventQueue();

      expect(container.read(isAdRemovedProvider), isFalse);
      expect(fakeIap.completedPurchases, contains(purchase));
    });

    test('PurchaseStatus.error: does NOT unlock, and calls completePurchase to finalize transaction', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));

      final purchase = createTestPurchase(
        status: PurchaseStatus.error,
        error: IAPError(
          source: 'google_play',
          code: 'BILLING_ERROR',
          message: 'Payment rejected',
        ),
      );
      fakeIap.controller.add([purchase]);
      await pumpEventQueue();

      expect(container.read(isAdRemovedProvider), isFalse);
      expect(fakeIap.completedPurchases, contains(purchase));
    });

    test('PurchaseStatus.canceled: does NOT unlock, and calls completePurchase', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));

      final purchase = createTestPurchase(status: PurchaseStatus.canceled);
      fakeIap.controller.add([purchase]);
      await pumpEventQueue();

      expect(container.read(isAdRemovedProvider), isFalse);
      expect(fakeIap.completedPurchases, contains(purchase));
    });
  });

  group('Startup Purchase Reconciliation & Offline Handling', () {
    test('On app start: calls restorePurchases and reconciles active purchase from store', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      fakeIap.onRestorePurchases = () async {
        fakeIap.controller.add([
          createTestPurchase(status: PurchaseStatus.restored),
        ]);
      };

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));
      await pumpEventQueue();

      expect(fakeIap.restorePurchasesCalled, isTrue);
      expect(container.read(isAdRemovedProvider), isTrue);
    });

    test('On app start: when offline, retains cached SharedPreferences value and marks offline', () async {
      SharedPreferences.setMockInitialValues({kPrefKeyIsAdsRemoved: true});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify cached value loaded into notifier after async prefs load
      container.read(isAdRemovedProvider);
      await pumpEventQueue();
      expect(container.read(isAdRemovedProvider), isTrue);

      // Simulate offline store
      fakeIap.available = false;

      await InAppPurchaseService.instance.initialize(container.read(isAdRemovedProvider.notifier));
      await pumpEventQueue();

      // Offline store should NOT wipe cached ad-free license
      expect(InAppPurchaseService.instance.isOffline, isTrue);
      expect(container.read(isAdRemovedProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kPrefKeyIsAdsRemoved), isTrue);
    });
  });
}
