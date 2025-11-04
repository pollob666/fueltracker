// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdService {
  InterstitialAd? _interstitialAd;

  static const String _androidAdUnitId = 'ca-app-pub-4519441960386265/5857468544';
  static const String _iosAdUnitId = 'ca-app-pub-4519441960386265/5087312358';

  String get _adUnitId => Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;

  void loadAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
        },
      ),
    );
  }

  void showAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadAd();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          loadAd();
        },
      );
      _interstitialAd!.show();
    }
  }
}
