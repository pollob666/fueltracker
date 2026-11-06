// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/location_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

class AnomalyDiagnosticDialog extends StatefulWidget {
  final int vehicleId;
  final MileageAnomalyResult anomaly;
  final VoidCallback onResolved;

  const AnomalyDiagnosticDialog({
    super.key,
    required this.vehicleId,
    required this.anomaly,
    required this.onResolved,
  });

  static Future<void> show({
    required BuildContext context,
    required int vehicleId,
    required MileageAnomalyResult anomaly,
    required VoidCallback onResolved,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnomalyDiagnosticDialog(
        vehicleId: vehicleId,
        anomaly: anomaly,
        onResolved: onResolved,
      ),
    );
  }

  @override
  State<AnomalyDiagnosticDialog> createState() => _AnomalyDiagnosticDialogState();
}

class _AnomalyDiagnosticDialogState extends State<AnomalyDiagnosticDialog> {
  List<AnomalyAttributionItem> _candidates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final list = await LocationService.instance.findAttributionCandidates(
      vehicleId: widget.vehicleId,
      anomaly: widget.anomaly,
    );
    if (mounted) {
      setState(() {
        _candidates = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFlags() async {
    final isDrop = widget.anomaly.isDrop;
    final pctStr = widget.anomaly.percentageChange.abs().toStringAsFixed(1);

    for (final item in _candidates) {
      if (item.isSelected && item.locationId != null) {
        if (isDrop) {
          await DatabaseHelper.instance.markLocationSuspect(
            item.locationId!,
            reason: 'Mileage dropped $pctStr% after visit (${widget.anomaly.intervalMileage.toStringAsFixed(1)} vs ${widget.anomaly.runningAverage.toStringAsFixed(1)} avg)',
            forFuel: item.isFuel,
            forService: item.isService,
          );
        } else {
          await DatabaseHelper.instance.markLocationRecommended(
            item.locationId!,
            reason: 'Mileage boosted +$pctStr% after visit (${widget.anomaly.intervalMileage.toStringAsFixed(1)} vs ${widget.anomaly.runningAverage.toStringAsFixed(1)} avg)',
            forFuel: item.isFuel,
            forService: item.isService,
          );
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onResolved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDrop
                ? 'Flagged selected locations for suspect quality.'
                : 'Marked selected locations as high-efficiency.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDrop = widget.anomaly.isDrop;
    final theme = Theme.of(context);
    final accentColor = isDrop ? Colors.red.shade700 : Colors.green.shade700;
    final icon = isDrop ? Icons.warning_amber_rounded : Icons.eco;
    final title = isDrop ? 'Mileage Drop Anomaly Detected' : 'Mileage Boost Detected';
    final pctStr =
        '${widget.anomaly.percentageChange >= 0 ? '+' : ''}${widget.anomaly.percentageChange.toStringAsFixed(1)}%';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDrop ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDrop ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interval: ${widget.anomaly.intervalMileage.toStringAsFixed(1)} km/L',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Rolling Avg: ${widget.anomaly.runningAverage.toStringAsFixed(1)} km/L',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        pctStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isDrop
                    ? 'Attribute suspect cause to warn on return:'
                    : 'Acknowledge top-performing provider (Mark Green):',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No saved fuel station or workshop found for this interval. Location data was either not recorded or not saved.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                )
              else
                ..._candidates.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      dense: true,
                      value: item.isSelected,
                      onChanged: (val) {
                        setState(() {
                          item.isSelected = val ?? false;
                        });
                      },
                      title: Text(
                        item.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        item.subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onResolved();
          },
          child: const Text('Dismiss (Normal Driving)'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: accentColor),
          icon: Icon(isDrop ? Icons.flag : Icons.check_circle, size: 16),
          label: Text(isDrop ? 'Apply Flags' : 'Mark Location Green'),
          onPressed: _candidates.any((c) => c.isSelected) ? _applyFlags : null,
        ),
      ],
    );
  }
}
