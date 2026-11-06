// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:intl/intl.dart';

class RefuelTimelineCard extends StatelessWidget {
  final FuelRecord record;
  final IntervalResult? interval;
  final double runningAverage;
  final String fuelTypeName;
  final String vehicleName;
  final String? stationName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RefuelTimelineCard({
    super.key,
    required this.record,
    this.interval,
    required this.runningAverage,
    required this.fuelTypeName,
    required this.vehicleName,
    this.stationName,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(recordDay).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 30) return '$difference days ago';
    if (difference < 365) {
      final months = (difference / 30).floor();
      return '$months mo ago';
    }
    return '${(difference / 365).floor()} yr ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final double? tripMileage = interval?.mileage;
    Color? economyBadgeColor;
    Color? economyTextColor;
    String? deltaText;

    if (tripMileage != null && tripMileage > 0 && runningAverage > 0) {
      final differencePercent =
          ((tripMileage - runningAverage) / runningAverage) * 100.0;
      if (differencePercent <= -10.0) {
        economyBadgeColor = colorScheme.errorContainer;
        economyTextColor = colorScheme.onErrorContainer;
        deltaText = '${differencePercent.toStringAsFixed(1)}%';
      } else if (differencePercent >= 10.0) {
        economyBadgeColor = Colors.green.withValues(alpha: 0.15);
        economyTextColor = Colors.green.shade800;
        deltaText = '+${differencePercent.toStringAsFixed(1)}%';
      } else {
        economyBadgeColor = colorScheme.surfaceContainerHighest;
        economyTextColor = colorScheme.onSurfaceVariant;
        deltaText = '${differencePercent >= 0 ? '+' : ''}${differencePercent.toStringAsFixed(1)}%';
      }
    }

    final displayName = stationName ?? 'Refueling';

    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: economyTextColor != null && economyBadgeColor == colorScheme.errorContainer
              ? colorScheme.error.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Station Name, Tank Badge, Relative Date, Economy Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        record.isFullTank ? '⛽' : '🪣',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: record.isFullTank
                                    ? Colors.teal.withValues(alpha: 0.12)
                                    : Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                record.isFullTank ? 'Full' : 'Partial',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: record.isFullTank
                                      ? Colors.teal.shade800
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd MMM yyyy, hh:mm a').format(record.date.toLocal())} • ${_formatRelativeTime(record.date)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Interval Economy Badge
                  if (interval != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (interval!.isMissed) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Missed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ] else if (interval!.isPartial) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Partial',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ] else if (tripMileage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: economyBadgeColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (economyTextColor ?? colorScheme.primary)
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '${tripMileage.toStringAsFixed(2)} km/L',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: economyTextColor,
                              ),
                            ),
                          ),
                          if (deltaText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0, right: 2.0),
                              child: Text(
                                deltaText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: economyTextColor,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics Grid: Odometer, Trip, Volume & Rate, Total Cost
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Odometer',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${record.odometer.toStringAsFixed(1)} km',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (record.tripDistance != null || interval?.distance != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.tripDistance != null ? 'Trip Distance' : 'Delta Odo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${(record.tripDistance ?? interval?.distance ?? 0.0).toStringAsFixed(1)} km',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Volume & Rate',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${record.volume.toStringAsFixed(1)}L @ ${record.rate.toStringAsFixed(1)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Paid',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${record.paidAmount.toStringAsFixed(1)} ৳',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Footer: Tags (Fuel, Condition, Attachment) and Quick Actions (Edit, Delete)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Fuel Type Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          fuelTypeName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Driving Condition Tag
                      if (record.drivingCondition != DrivingCondition.mixed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            record.drivingCondition == DrivingCondition.city
                                ? '🏙️ City'
                                : '🛣️ Highway',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // Receipt Attachment Tag
                      if (record.receiptImagePath != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_outlined, size: 11, color: Colors.blue),
                              const SizedBox(width: 2),
                              Text(
                                'Receipt',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Edit Record',
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: colorScheme.error),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete Record',
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
