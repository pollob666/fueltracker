// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/services/analytics_service.dart';
import 'package:intl/intl.dart';

class StationEfficiencyScatterWidget extends StatelessWidget {
  final List<StationEfficiencyPoint> points;
  final double runningAverage;
  final void Function(FuelRecord record)? onRecordTap;
  final String economyUnit;

  const StationEfficiencyScatterWidget({
    super.key,
    required this.points,
    required this.runningAverage,
    this.onRecordTap,
    this.economyUnit = 'km/L',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (points.isEmpty) {
      return _buildEmptyState(theme, 'Need at least two full tank fill-ups for interval mileage');
    }

    double minMileage = points.map((p) => p.intervalMileage).reduce((a, b) => a < b ? a : b);
    double maxMileage = points.map((p) => p.intervalMileage).reduce((a, b) => a > b ? a : b);

    if (runningAverage > 0) {
      if (runningAverage < minMileage) minMileage = runningAverage;
      if (runningAverage > maxMileage) maxMileage = runningAverage;
    }

    final padding = ((maxMileage - minMileage) * 0.2).clamp(1.5, 10.0);
    final minY = (minMileage - padding).clamp(0.0, double.infinity);
    final maxY = maxMileage + padding;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].intervalMileage));
    }

    final suspectCount = points.where((p) => p.isSuspect).length;
    final boostCount = points.where((p) => p.isBoost).length;

    return Card(
      elevation: 1.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Station Efficiency Variance',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Interval economy vs ${runningAverage.toStringAsFixed(2)} km/L running average',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (boostCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🟢 +$boostCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (suspectCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⚠️ $suspectCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      final isAvg = (value - runningAverage).abs() < 0.2;
                      return FlLine(
                        color: isAvg
                            ? colorScheme.primary.withValues(alpha: 0.6)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                        strokeWidth: isAvg ? 1.5 : 1.0,
                        dashArray: isAvg ? [6, 4] : [4, 4],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (points.length / 4).clamp(1.0, double.infinity),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '#${points[idx].intervalIndex}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (runningAverage > 0)
                        HorizontalLine(
                          y: runningAverage,
                          color: colorScheme.primary,
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(right: 6, bottom: 2),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                            labelResolver: (_) => 'Avg: ${runningAverage.toStringAsFixed(1)} $economyUnit',
                          ),
                        ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final pt = points[index];
                          Color dotColor = colorScheme.primary;
                          if (pt.isBoost) {
                            dotColor = Colors.green.shade600;
                          } else if (pt.isSuspect) {
                            dotColor = Colors.amber.shade700;
                          }
                          return FlDotCirclePainter(
                            radius: (pt.isBoost || pt.isSuspect) ? 6 : 4,
                            color: dotColor,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (event is FlTapUpEvent &&
                          touchResponse != null &&
                          touchResponse.lineBarSpots != null &&
                          touchResponse.lineBarSpots!.isNotEmpty) {
                        final spot = touchResponse.lineBarSpots!.first;
                        final idx = spot.spotIndex;
                        if (idx >= 0 && idx < points.length) {
                          final targetRecord = points[idx].record;
                          if (onRecordTap != null) {
                            HapticFeedback.lightImpact();
                            onRecordTap!(targetRecord);
                          }
                        }
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
                      tooltipRoundedRadius: 10,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          if (idx >= 0 && idx < points.length) {
                            final pt = points[idx];
                            final sign = pt.deltaPercent >= 0 ? '+' : '';
                            final station = pt.stationName != null ? '\nStation: ${pt.stationName}' : '';
                            return LineTooltipItem(
                              'Fill #${pt.intervalIndex} (${DateFormat('dd MMM').format(pt.date)})\n'
                              'Economy: ${pt.intervalMileage.toStringAsFixed(2)} $economyUnit\n'
                              'Variance: $sign${pt.deltaPercent.toStringAsFixed(1)}%$station\n'
                              '👉 Tap to inspect / edit',
                              theme.textTheme.bodySmall!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: pt.isBoost
                                    ? Colors.green.shade700
                                    : pt.isSuspect
                                        ? Colors.amber.shade900
                                        : theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Card(
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bubble_chart, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
