// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/providers/non_fuel_expense_providers.dart';
import 'package:intl/intl.dart';

class TcoStackedBarWidget extends StatelessWidget {
  final TcoOverviewSummary summary;
  final VoidCallback? onLogExpense;
  final String currencySymbol;
  final String distanceUnit;

  const TcoStackedBarWidget({
    super.key,
    required this.summary,
    this.onLogExpense,
    this.currencySymbol = '৳',
    this.distanceUnit = 'km',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (summary.monthlyData.isEmpty) {
      return Card(
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pie_chart_outline, size: 40, color: colorScheme.outline),
                const SizedBox(height: 8),
                Text(
                  'No cost ownership data available',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                if (onLogExpense != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onLogExpense,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Log Non-Fuel Expense'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final fuelColor = colorScheme.primary;
    final serviceColor = colorScheme.tertiary;
    final nonFuelColor = Colors.deepPurple.shade400;

    final double totalSpend = summary.totalSpend;
    final double fuelPct = totalSpend > 0 ? (summary.totalFuelSpend / totalSpend) * 100 : 0;
    final double servicePct = totalSpend > 0 ? (summary.totalServiceSpend / totalSpend) * 100 : 0;
    final double nonFuelPct = totalSpend > 0 ? (summary.totalNonFuelSpend / totalSpend) * 100 : 0;

    // Build BarChartGroupData for the last 6 months
    final displayData = summary.monthlyData.length > 6
        ? summary.monthlyData.sublist(summary.monthlyData.length - 6)
        : summary.monthlyData;

    double maxMonthSpend = 0.0;
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < displayData.length; i++) {
      final dp = displayData[i];
      if (dp.totalSpend > maxMonthSpend) {
        maxMonthSpend = dp.totalSpend;
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dp.totalSpend,
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              rodStackItems: [
                BarChartRodStackItem(0, dp.fuelSpend, fuelColor),
                BarChartRodStackItem(
                  dp.fuelSpend,
                  dp.fuelSpend + dp.serviceSpend,
                  serviceColor,
                ),
                BarChartRodStackItem(
                  dp.fuelSpend + dp.serviceSpend,
                  dp.totalSpend,
                  nonFuelColor,
                ),
              ],
            ),
          ],
        ),
      );
    }

    final double maxY = maxMonthSpend > 0 ? maxMonthSpend * 1.2 : 1000.0;

    return Card(
      elevation: 1.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Cost of Ownership (TCO)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Monthly stacked spend across fuel, service, and non-fuel',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (onLogExpense != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onLogExpense,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Expense', style: TextStyle(fontSize: 11)),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Overview KPI Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Spend',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '${summary.totalSpend.toStringAsFixed(0)} $currencySymbol',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (summary.totalDistance > 0)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All-Inclusive Cost',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            '${summary.allInclusiveCostPerKm.toStringAsFixed(2)} $currencySymbol/$distanceUnit',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Legend Strip
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildLegendItem('⛽ Fuel (${fuelPct.toStringAsFixed(0)}%)', fuelColor, theme),
                _buildLegendItem('🔧 Service (${servicePct.toStringAsFixed(0)}%)', serviceColor, theme),
                _buildLegendItem('🏷️ Non-Fuel (${nonFuelPct.toStringAsFixed(0)}%)', nonFuelColor, theme),
              ],
            ),
            const SizedBox(height: 16),

            // Stacked Bar Chart
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY / 4).clamp(100.0, double.infinity),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.35),
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
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= displayData.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              DateFormat('MMM').format(displayData[idx].month),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final dp = displayData[group.x.toInt()];
                        final monthStr = DateFormat('MMMM yyyy').format(dp.month);
                        return BarTooltipItem(
                          '$monthStr\n'
                          '⛽ Fuel: ${dp.fuelSpend.toStringAsFixed(0)} $currencySymbol\n'
                          '🔧 Service: ${dp.serviceSpend.toStringAsFixed(0)} $currencySymbol\n'
                          '🏷️ Non-Fuel: ${dp.nonFuelSpend.toStringAsFixed(0)} $currencySymbol\n'
                          'Total: ${dp.totalSpend.toStringAsFixed(0)} $currencySymbol',
                          TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        );
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

  Widget _buildLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
