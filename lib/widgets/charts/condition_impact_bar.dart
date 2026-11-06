// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/services/analytics_service.dart';

class ConditionImpactBarWidget extends StatelessWidget {
  final ConditionDeltaSummary summary;

  const ConditionImpactBarWidget({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasAnyData = summary.city.recordCount > 0 ||
        summary.highway.recordCount > 0 ||
        summary.mixed.recordCount > 0;

    if (!hasAnyData) {
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
                Icon(Icons.alt_route, size: 40, color: colorScheme.outline),
                const SizedBox(height: 8),
                Text(
                  'No driving condition tagged records found',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
            Text(
              'Driving Condition Impact',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Real-world consumption and cost segregation across road environments',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: '🏙️',
                    title: 'City Traffic',
                    metric: summary.city,
                    accentColor: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: '🔄',
                    title: 'Mixed',
                    metric: summary.mixed,
                    accentColor: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    icon: '🛣️',
                    title: 'Highway',
                    metric: summary.highway,
                    accentColor: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required String icon,
    required String title,
    required ConditionMetric metric,
    required Color accentColor,
  }) {
    final hasRecords = metric.recordCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (hasRecords && metric.mileage > 0) ...[
            Text(
              '${metric.mileage.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            Text(
              'km/L',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              '${metric.costPerKm.toStringAsFixed(2)} /km',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              hasRecords ? '${metric.totalVolume.toStringAsFixed(1)} L' : 'No data',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Text(
            '${metric.recordCount} fills',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
