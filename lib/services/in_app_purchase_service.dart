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
  return AdRemovalNotifier();
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

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  ProductDetails? _adFreeProduct;

  bool get isAvailable => _isAvailable;
  ProductDetails? get adFreeProduct => _adFreeProduct;

  Future<void> initialize(WidgetRef? ref) async {
    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        _subscription = _iap.purchaseStream.listen(
          (purchases) => _handlePurchases(purchases, ref),
          onError: (err) {
            debugPrint('IAP purchase stream error: $err');
          },
        );

        final response = await _iap.queryProductDetails({kAdFreeProductId});
        if (response.notFoundIDs.isEmpty && response.productDetails.isNotEmpty) {
          _adFreeProduct = response.productDetails.first;
        }
      }
    } catch (e) {
      debugPrint('IAP initialize error: $e');
      _isAvailable = false;
    }
  }

  Future<bool> buyAdFreeUpgrade({dynamic ref}) async {
    if (!_isAvailable || _adFreeProduct == null) {
      // Sandbox fallback: in local debug environments or offline test without Play Store
      debugPrint('Store unavailable or product not found. Using sandbox/mock completion.');
      if (ref != null) {
        if (ref is WidgetRef) {
          await ref.read(isAdRemovedProvider.notifier).setAdRemoved(true);
        } else if (ref is Ref) {
          await ref.read(isAdRemovedProvider.notifier).setAdRemoved(true);
        } else if (ref is AdRemovalNotifier) {
          await ref.setAdRemoved(true);
        }
      }
      return true;
    }

    final purchaseParam = PurchaseParam(productDetails: _adFreeProduct!);
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases({dynamic ref}) async {
    if (_isAvailable) {
      await _iap.restorePurchases();
    } else {
      // Refresh local SharedPreferences
      if (ref != null) {
        final prefs = await SharedPreferences.getInstance();
        final isRemoved = prefs.getBool(kPrefKeyIsAdsRemoved) ?? false;
        if (ref is WidgetRef) {
          await ref.read(isAdRemovedProvider.notifier).setAdRemoved(isRemoved);
        } else if (ref is Ref) {
          await ref.read(isAdRemovedProvider.notifier).setAdRemoved(isRemoved);
        } else if (ref is AdRemovalNotifier) {
          await ref.setAdRemoved(isRemoved);
        }
      }
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases, dynamic ref) async {
    for (var purchase in purchases) {
      if (purchase.productID == kAdFreeProductId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (ref != null) {
            if (ref is WidgetRef) {
              await ref.read(isAdRemovedProvider.notifier).setAdRemoved(true);
            } else if (ref is Ref) {
              await ref.read(isAdRemovedProvider.notifier).setAdRemoved(true);
            } else if (ref is AdRemovalNotifier) {
              await ref.setAdRemoved(true);
            }
          }
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
