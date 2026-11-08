// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';

enum TireHealthStatus {
  good,
  advisory,
  critical;

  String get label {
    switch (this) {
      case TireHealthStatus.good:
        return 'Healthy';
      case TireHealthStatus.advisory:
        return 'Wear Advisory';
      case TireHealthStatus.critical:
        return 'Replace Immediately';
    }
  }

  Color get color {
    switch (this) {
      case TireHealthStatus.good:
        return const Color(0xFF1B873F);
      case TireHealthStatus.advisory:
        return const Color(0xFFB26A00);
      case TireHealthStatus.critical:
        return const Color(0xFFBA1A1A);
    }
  }
}

class TireCalculator {
  static const double legalMinimumDepthMm = 1.6;
  static const double advisoryDepthMm = 4.0;
  static const double defaultRotationIntervalKm = 10000.0;

  /// Evaluates wear health status based on current tread depth.
  static TireHealthStatus evaluateStatus(double depthMm) {
    if (depthMm >= advisoryDepthMm) {
      return TireHealthStatus.good;
    } else if (depthMm >= 2.0) {
      return TireHealthStatus.advisory;
    } else {
      return TireHealthStatus.critical;
    }
  }

  /// Calculates wear rate in mm per 1,000 km.
  static double calculateWearRatePer1000Km({
    required double initialDepthMm,
    required double currentDepthMm,
    required double deltaKm,
  }) {
    if (deltaKm <= 0) return 0.0;
    final wear = initialDepthMm - currentDepthMm;
    if (wear <= 0) return 0.0;
    return (wear / deltaKm) * 1000.0;
  }

  /// Estimates remaining distance in km before reaching the legal wear limit (1.6mm).
  static double? estimateRemainingDistanceKm({
    required double currentDepthMm,
    required double wearRatePer1000Km,
  }) {
    if (wearRatePer1000Km <= 0) return null;
    final usableDepth = currentDepthMm - legalMinimumDepthMm;
    if (usableDepth <= 0) return 0.0;
    return (usableDepth / wearRatePer1000Km) * 1000.0;
  }

  /// Checks if tire rotation is due based on distance traveled since last rotation.
  static bool isRotationDue({
    required double currentOdometer,
    required double lastRotationOdometer,
    double intervalKm = defaultRotationIntervalKm,
  }) {
    return (currentOdometer - lastRotationOdometer) >= intervalKm;
  }
}
