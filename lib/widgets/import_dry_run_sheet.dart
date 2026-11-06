// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:fuel_tracker/models/fuel_record.dart';

enum ConflictStrategy {
  skip,
  overwrite,
  merge,
}

class ImportDryRunSummary {
  final List<FuelRecord> newRecords;
  final List<MapEntry<FuelRecord, FuelRecord>> duplicatePairs; // Entry<FileRecord, ExistingRecord>
  final int totalFound;
  final int corruptedCount;

  ImportDryRunSummary({
    required this.newRecords,
    required this.duplicatePairs,
    required this.totalFound,
    required this.corruptedCount,
  });

  int get duplicateCount => duplicatePairs.length;
}

class ImportDryRunSheet extends StatefulWidget {
  final ImportDryRunSummary summary;
  final Future<void> Function(ConflictStrategy strategy) onCommit;

  const ImportDryRunSheet({
    super.key,
    required this.summary,
    required this.onCommit,
  });

  static String computeFingerprint({
    required int vehicleId,
    required DateTime date,
    required double odometer,
    required double volume,
  }) {
    final input =
        '$vehicleId|${date.toIso8601String().substring(0, 10)}|${odometer.toStringAsFixed(2)}|${volume.toStringAsFixed(2)}';
    return sha256.convert(utf8.encode(input)).toString();
  }

  static Future<void> show({
    required BuildContext context,
    required ImportDryRunSummary summary,
    required Future<void> Function(ConflictStrategy strategy) onCommit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ImportDryRunSheet(
        summary: summary,
        onCommit: onCommit,
      ),
    );
  }

  @override
  State<ImportDryRunSheet> createState() => _ImportDryRunSheetState();
}

class _ImportDryRunSheetState extends State<ImportDryRunSheet> {
  ConflictStrategy _strategy = ConflictStrategy.skip;
  bool _isCommitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = widget.summary;

    int commitCount;
    if (_strategy == ConflictStrategy.skip) {
      commitCount = summary.newRecords.length;
    } else if (_strategy == ConflictStrategy.overwrite) {
      commitCount = summary.newRecords.length + summary.duplicateCount;
    } else {
      commitCount = summary.newRecords.length + summary.duplicateCount;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.rate_review_outlined, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Import Preview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary.totalFound} found',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'New',
                  count: summary.newRecords.length,
                  color: Colors.green.shade700,
                  bgColor: Colors.green.shade50,
                  icon: Icons.add_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Duplicates',
                  count: summary.duplicateCount,
                  color: Colors.amber.shade800,
                  bgColor: Colors.amber.shade50,
                  icon: Icons.copy_outlined,
                ),
              ),
              if (summary.corruptedCount > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Invalid',
                    count: summary.corruptedCount,
                    color: colorScheme.error,
                    bgColor: colorScheme.errorContainer.withValues(alpha: 0.5),
                    icon: Icons.error_outline,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Conflict resolution selector
          if (summary.duplicateCount > 0) ...[
            Text(
              'Duplicate Resolution:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ConflictStrategy>(
              segments: const [
                ButtonSegment(
                  value: ConflictStrategy.skip,
                  label: Text('Skip'),
                  icon: Icon(Icons.shield_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ConflictStrategy.overwrite,
                  label: Text('Overwrite'),
                  icon: Icon(Icons.sync_outlined, size: 16),
                ),
                ButtonSegment(
                  value: ConflictStrategy.merge,
                  label: Text('Merge'),
                  icon: Icon(Icons.add_outlined, size: 16),
                ),
              ],
              selected: {_strategy},
              onSelectionChanged: (selected) {
                setState(() {
                  _strategy = selected.first;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              _strategy == ConflictStrategy.skip
                  ? 'Keep existing records; skip duplicates in file.'
                  : _strategy == ConflictStrategy.overwrite
                      ? 'Update matching records in database with file data.'
                      : 'Import all records from file, even if matching existing entries.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Commit button
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isCommitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: _isCommitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_isCommitting ? 'Importing...' : 'Commit $commitCount Records'),
                  onPressed: _isCommitting || commitCount == 0
                      ? null
                      : () async {
                          setState(() => _isCommitting = true);
                          await widget.onCommit(_strategy);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
