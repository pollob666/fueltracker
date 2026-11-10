// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAdFreeProductId = 'fueltracker_remove_ads';
const String kPrefKeyIsAdsRemoved = 'is_ads_removed';

final isAdRemovedProvider = StateNotifierProvider<AdRemovalNotifier, bool>((ref) {
  final notifier = AdRemovalNotifier();
  InAppPurchaseService.instance.registerNotifier(notifier);
  return notifier;
});

class AdRemovalNotifier extends StateNotifier<bool> {
  AdRemovalNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(kPrefKeyIsAdsRemoved) ?? false;
  }

  Future<void> setAdRemoved(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefKeyIsAdsRemoved, value);
  }
}

class InAppPurchaseService {
  static final InAppPurchaseService instance = InAppPurchaseService._internal();
  InAppPurchaseService._internal();

  InAppPurchase? _customIap;
  InAppPurchase get _iap => _customIap ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Timer? _retryTimer;
  bool _isAvailable = false;
  bool _isOffline = false;
  ProductDetails? _adFreeProduct;
  AdRemovalNotifier? _registeredNotifier;
  dynamic _lastRef;

  /// Testing override for development sandbox bypass.
  @visibleForTesting
  static bool enableDebugSandboxBypass = true;

  @visibleForTesting
  void setInAppPurchaseForTesting(InAppPurchase iap) {
    _customIap = iap;
  }

  void registerNotifier(AdRemovalNotifier notifier) {
    _registeredNotifier = notifier;
  }

  bool get isAvailable => _isAvailable;
  bool get isOffline => _isOffline;
  ProductDetails? get adFreeProduct => _adFreeProduct;

  /// Initializes IAP, listens to purchase stream, queries product details,
  /// and reconciles past purchases against local cached license state.
  Future<void> initialize(dynamic ref) async {
    _lastRef = ref;
    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        _isOffline = false;
        _subscription?.cancel();
        _subscription = _iap.purchaseStream.listen(
          (purchases) => _handlePurchases(purchases, ref ?? _lastRef),
          onError: (err) {
            debugPrint('IAP purchase stream error: $err');
          },
        );

        final response = await _iap.queryProductDetails({kAdFreeProductId});
        if (response.notFoundIDs.isEmpty && response.productDetails.isNotEmpty) {
          _adFreeProduct = response.productDetails.first;
        }

        // On app start: reconcile against store purchases
        await reconcilePurchases(ref: ref ?? _lastRef);
      } else {
        _handleOfflineState();
      }
    } catch (e) {
      debugPrint('IAP initialize error: $e');
      _handleOfflineState();
    }
  }

  /// Handles offline or store-unavailable conditions by keeping the cached value
  /// and scheduling a retry.
  void _handleOfflineState() {
    _isAvailable = false;
    _isOffline = true;
    debugPrint('IAP store unavailable on startup (offline). Keeping cached SharedPreferences license.');
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 45), () {
      if (_isOffline) {
        debugPrint('Retrying IAP store connection and reconciliation...');
        initialize(_lastRef);
      }
    });
  }

  /// Reconciles purchase state: store state is authoritative and wins.
  /// If offline, retains cached state.
  Future<void> reconcilePurchases({dynamic ref}) async {
    if (!_isAvailable) {
      debugPrint('Reconciliation skipped: store is offline. Retaining cache.');
      return;
    }

    try {
      // Query past purchases via store restore
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Error restoring purchases during reconciliation: $e');
      _handleOfflineState();
    }
  }

  /// Purchase ad-free upgrade.
  /// Sandbox bypass is strictly guarded by `!kReleaseMode` and tree-shakeable assert.
  Future<bool> buyAdFreeUpgrade({dynamic ref}) async {
    final effectiveRef = ref ?? _lastRef;

    if (!_isAvailable || _adFreeProduct == null) {
      // -----------------------------------------------------------------------
      // Development Sandbox Bypass Guard:
      // In release builds, `kReleaseMode` is a compile-time constant `true`.
      // The Dart AOT compiler evaluates `!kReleaseMode` as `false` and completely
      // tree-shakes / prunes this branch from the compiled output.
      // -----------------------------------------------------------------------
      if (!kReleaseMode) {
        bool isDebugEnvironment = false;
        assert(() {
          isDebugEnvironment = true;
          return true;
        }());

        if (isDebugEnvironment && enableDebugSandboxBypass) {
          debugPrint('Store unavailable or product not found. Using debug sandbox bypass.');
          await _updateAdRemovalState(effectiveRef, true);
          return true;
        }
      }

      debugPrint('In-app purchase store is unavailable or product not found.');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: _adFreeProduct!);
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Explicit user-initiated restore purchases.
  Future<void> restorePurchases({dynamic ref}) async {
    final effectiveRef = ref ?? _lastRef;
    if (_isAvailable) {
      await _iap.restorePurchases();
    } else {
      // Offline fallback: keep cached SharedPreferences state
      debugPrint('Restore called while store offline. Keeping cached state.');
      final prefs = await SharedPreferences.getInstance();
      final isRemoved = prefs.getBool(kPrefKeyIsAdsRemoved) ?? false;
      await _updateAdRemovalState(effectiveRef, isRemoved);
    }
  }

  /// Internal handler for incoming purchase updates from `purchaseStream`.
  /// Handles pending, purchased, restored, error, and canceled states.
  /// Always calls `completePurchase` when `pendingCompletePurchase` is true.
  Future<void> _handlePurchases(List<PurchaseDetails> purchases, dynamic ref) async {
    final effectiveRef = ref ?? _lastRef;

    for (final purchase in purchases) {
      if (purchase.productID == kAdFreeProductId) {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            debugPrint('IAP Purchase pending for ${purchase.productID} (ID: ${purchase.purchaseID})');
            // Do not grant ad-free license while payment is pending.
            break;

          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            debugPrint('IAP Purchase ${purchase.status.name} for ${purchase.productID}');
            await _updateAdRemovalState(effectiveRef, true);
            break;

          case PurchaseStatus.error:
            debugPrint('IAP Purchase error for ${purchase.productID}: ${purchase.error}');
            // Payment error occurred: Do not grant license.
            break;

          case PurchaseStatus.canceled:
            debugPrint('IAP Purchase canceled for ${purchase.productID}');
            // User canceled transaction: Do not grant license.
            break;
        }

        // Requirement: Always complete purchases that require completion
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
            debugPrint('IAP completed purchase transaction for ${purchase.productID}');
          } catch (e) {
            debugPrint('Failed to complete purchase: $e');
          }
        }
      }
    }
  }

  /// Updates both Riverpod provider (if ref or notifier available) and persistent SharedPreferences.
  Future<void> _updateAdRemovalState(dynamic ref, bool value) async {
    if (ref != null) {
      if (ref is WidgetRef) {
        await ref.read(isAdRemovedProvider.notifier).setAdRemoved(value);
      } else if (ref is Ref) {
        await ref.read(isAdRemovedProvider.notifier).setAdRemoved(value);
      } else if (ref is AdRemovalNotifier) {
        await ref.setAdRemoved(value);
      }
    } else if (_registeredNotifier != null) {
      await _registeredNotifier!.setAdRemoved(value);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefKeyIsAdsRemoved, value);
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _subscription?.cancel();
    _registeredNotifier = null;
    _lastRef = null;
  }
}

