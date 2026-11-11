// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

class CarbonFootprintCardWidget extends StatelessWidget {
  final CarbonFootprintResult result;

  const CarbonFootprintCardWidget({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (result.totalVolume <= 0) {
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
                Icon(Icons.eco_outlined, size: 40, color: colorScheme.outline),
                const SizedBox(height: 8),
                Text(
                  'No emissions data available for this period',
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Color ratingColor = Colors.green.shade600;
    if (result.ecoRating == 'C' || result.ecoRating == 'D') {
      ratingColor = Colors.orange.shade700;
    } else if (result.ecoRating == 'B') {
      ratingColor = Colors.teal;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carbon Footprint',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Estimated emissions based on fuel volume consumed',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (result.ecoRating != 'N/A') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ratingColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ratingColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Eco: ${result.ecoRating}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ratingColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total CO₂ Emitted',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${result.totalCo2Kg.toStringAsFixed(1)} kg',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Text(
                          'From ${result.totalVolume.toStringAsFixed(1)} L consumed',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emissions Rate',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.gramsCo2PerKm != null
                              ? '${result.gramsCo2PerKm!.toStringAsFixed(0)} g/km'
                              : 'N/A',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ratingColor,
                          ),
                        ),
                        Text(
                          result.totalDistance > 0
                              ? 'Over ${result.totalDistance.toStringAsFixed(0)} km'
                              : 'Waiting for distance',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Text('🌳', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requires approximately ${result.treeOffsetCount} tree sapling${result.treeOffsetCount == 1 ? '' : 's'} (growing 1 year) to offset these emissions.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.brightness == Brightness.dark
                            ? Colors.green.shade300
                            : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
