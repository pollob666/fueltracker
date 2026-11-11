// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/pages/analytics_page.dart';
import 'package:fuel_tracker/providers/analytics_providers.dart';
import 'package:fuel_tracker/providers/vehicle_providers.dart';
import 'package:fuel_tracker/utils/app_settings.dart';

class MiniTelemetrySparklineWidget extends ConsumerWidget {
  final int vehicleId;

  const MiniTelemetrySparklineWidget({
    super.key,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vehicles = ref.watch(vehiclesProvider).value ?? [];
    final activeVehicle = vehicles.where((v) => v.id == vehicleId).firstOrNull ?? ref.watch(activeVehicleProvider);
    final trends = ref.watch(priceTrendsProvider(vehicleId));

    final points = trends.values.expand((p) => p).toList();
    final hasEnoughPoints = points.length >= 2;

    double? trendDeltaPct;
    if (hasEnoughPoints) {
      final latestRate = points.last.rate;
      final prevRate = points[points.length - 2].rate;
      if (prevRate > 0) {
        trendDeltaPct = ((latestRate - prevRate) / prevRate) * 100.0;
      }
    }

    final currencySym = activeVehicle?.baseCurrency ?? AppSettings.defaultBaseCurrency;
    final volSym = activeVehicle?.fuelVolumeUnit.symbol ?? 'L';

    return Semantics(
      label: 'Visual Analytics and Trends. Tap to view detailed fuel price and station reports.',
      button: true,
      child: Card(
        elevation: 1.0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnalyticsPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.insights, color: colorScheme.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visual Analytics & Trends',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          hasEnoughPoints
                              ? 'Latest: $currencySym${points.last.rate.toStringAsFixed(2)}/$volSym'
                              : 'Tap to view interactive graphs & reports',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trendDeltaPct != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: trendDeltaPct <= 0
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${trendDeltaPct >= 0 ? '+' : ''}${trendDeltaPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: trendDeltaPct <= 0 ? Colors.green.shade700 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
                ],
              ),
              if (hasEnoughPoints) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: LineChart(
                    LineChartData(
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (int i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].rate),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: colorScheme.primary,
                          barWidth: 2.2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
