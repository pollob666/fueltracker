// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/services/analytics_service.dart';
import 'package:intl/intl.dart';

class PriceTrendChartWidget extends StatelessWidget {
  final Map<int, List<PriceTrendPoint>> priceTrends;
  final Map<int, FuelType> fuelTypeMap;
  final void Function(FuelRecord record)? onRecordTap;
  final String? currencySymbol;
  final String? volumeUnit;

  const PriceTrendChartWidget({
    super.key,
    required this.priceTrends,
    required this.fuelTypeMap,
    this.onRecordTap,
    this.currencySymbol,
    this.volumeUnit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (priceTrends.isEmpty || priceTrends.values.every((list) => list.isEmpty)) {
      return _buildEmptyState(theme, 'No fuel price data in this period');
    }

    // Collect all points across series to find bounds
    final allPoints = priceTrends.values.expand((p) => p).toList();
    if (allPoints.isEmpty) {
      return _buildEmptyState(theme, 'No fuel price data in this period');
    }

    double minRate = allPoints.map((p) => p.rate).reduce((a, b) => a < b ? a : b);
    double maxRate = allPoints.map((p) => p.rate).reduce((a, b) => a > b ? a : b);

    if ((maxRate - minRate).abs() < 1.0) {
      minRate -= 2.0;
      maxRate += 2.0;
    } else {
      final padding = (maxRate - minRate) * 0.15;
      minRate = (minRate - padding).clamp(0.0, double.infinity);
      maxRate += padding;
    }

    final seriesColors = [
      colorScheme.primary,
      colorScheme.tertiary,
      Colors.amber.shade700,
      Colors.indigo.shade600,
    ];

    int colorIndex = 0;
    final lineBarsData = <LineChartBarData>[];
    final legendItems = <Widget>[];
    final barToPointsMap = <int, List<PriceTrendPoint>>{};

    priceTrends.forEach((fuelTypeId, points) {
      if (points.isEmpty) return;
      final fuelName = fuelTypeMap[fuelTypeId]?.name ?? 'Fuel #$fuelTypeId';
      final color = seriesColors[colorIndex % seriesColors.length];
      colorIndex++;

      legendItems.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(fuelName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ));

      // Actual rates line
      final spots = <FlSpot>[];
      for (int i = 0; i < points.length; i++) {
        spots.add(FlSpot(i.toDouble(), points[i].rate));
      }

      lineBarsData.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.25,
        color: color,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeWidth: 2,
              strokeColor: theme.colorScheme.surface,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.12),
        ),
      ));
      barToPointsMap[lineBarsData.length - 1] = points;

      // 30-day moving average trend line
      if (points.length >= 3) {
        final maSpots = <FlSpot>[];
        for (int i = 0; i < points.length; i++) {
          maSpots.add(FlSpot(i.toDouble(), points[i].movingAverageRate));
        }

        lineBarsData.add(LineChartBarData(
          spots: maSpots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: color.withValues(alpha: 0.6),
          barWidth: 1.5,
          dashArray: [5, 4],
          dotData: const FlDotData(show: false),
        ));
        barToPointsMap[lineBarsData.length - 1] = points;
      }
    });

    final primarySeries = priceTrends.values.firstWhere(
      (list) => list.isNotEmpty,
      orElse: () => [],
    );

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fuel Price Trends',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rate per volume with 30-day moving average',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (legendItems.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Wrap(spacing: 8, children: legendItems),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minRate,
                  maxY: maxRate,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((maxRate - minRate) / 4).clamp(1.0, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          final sym = currencySymbol ?? '';
                          return Text(
                            '$sym${value.toStringAsFixed(1)}',
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
                        interval: (primarySeries.length / 4).clamp(1.0, double.infinity),
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= primarySeries.length) {
                            return const SizedBox.shrink();
                          }
                          final date = primarySeries[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              DateFormat('dd MMM').format(date),
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
                  lineBarsData: lineBarsData,
                  lineTouchData: LineTouchData(
                    touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      if (event is FlTapUpEvent &&
                          touchResponse != null &&
                          touchResponse.lineBarSpots != null &&
                          touchResponse.lineBarSpots!.isNotEmpty) {
                        final spot = touchResponse.lineBarSpots!.first;
                        final pointsList = barToPointsMap[spot.barIndex];
                        if (pointsList != null && spot.spotIndex >= 0 && spot.spotIndex < pointsList.length) {
                          final targetRecord = pointsList[spot.spotIndex].record;
                          if (targetRecord != null && onRecordTap != null) {
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
                          final pointsList = barToPointsMap[spot.barIndex] ?? primarySeries;
                          final idx = spot.spotIndex;
                          if (idx >= 0 && idx < pointsList.length) {
                            final pt = pointsList[idx];
                            final sym = currencySymbol ?? '';
                            final volStr = volumeUnit != null ? ' / $volumeUnit' : '';
                            final station = pt.stationName != null ? '\nStation: ${pt.stationName}' : '';
                            return LineTooltipItem(
                              '${DateFormat('dd MMM yyyy').format(pt.date)}\n'
                              'Rate: $sym${pt.rate.toStringAsFixed(2)}$volStr$station\n'
                              '👉 Tap to inspect / edit',
                              theme.textTheme.bodySmall!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          }
                          return LineTooltipItem(
                            spot.y.toStringAsFixed(2),
                            theme.textTheme.bodySmall!,
                          );
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
              Icon(Icons.show_chart, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
