// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _isBannerVisible = true;
  bool _canClose = false;

  static const String _androidAdUnitId = 'ca-app-pub-4519441960386265/5683467903';
  static const String _iosAdUnitId = 'ca-app-pub-4519441960386265/5589589826';

  String get _adUnitId => Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _canClose = true;
        });
      }
    });
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    );
    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBannerAdReady && _isBannerVisible) {
      return Container(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        height: _bannerAd!.size.height.toDouble(),
        width: _bannerAd!.size.width.toDouble(),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            AdWidget(ad: _bannerAd!),
            if (_canClose)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  setState(() {
                    _isBannerVisible = false;
                  });
                },
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
