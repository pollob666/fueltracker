// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart'; // Import localization
import 'dart:math';

class AllDataPage extends StatefulWidget {
  const AllDataPage({super.key});

  @override
  State<AllDataPage> createState() => _AllDataPageState();
}

class _AllDataPageState extends State<AllDataPage> {
  List<FuelRecord> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    List<FuelRecord> recs = await DatabaseHelper.instance.getFuelRecords();
    // Sort records by date descending
    recs.sort((a, b) => b.date.compareTo(a.date));
    setState(() {
      records = recs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Calculate summary values if records exist, else default to 0.
    double maxOdometer =
        records.isNotEmpty ? records.map((r) => r.odometer).reduce(max) : 0.0;
    double avgRate = records.isNotEmpty
        ? records.map((r) => r.rate).reduce((a, b) => a + b) / records.length
        : 0.0;
    double sumVolume = records.isNotEmpty
        ? records.map((r) => r.volume).reduce((a, b) => a + b)
        : 0.0;
    double sumPaid = records.isNotEmpty
        ? records.map((r) => r.paidAmount).reduce((a, b) => a + b)
        : 0.0;
    double sumActualBill = records.isNotEmpty
        ? records.map((r) => r.rate * r.volume).reduce((a, b) => a + b)
        : 0.0;
    double sumSavings = sumActualBill - sumPaid;

    // Create the summary row.
    final DataRow summaryRow = DataRow(
      // Using a different color or text style for differentiation.
      color: MaterialStateProperty.all(theme.colorScheme.surfaceVariant),
      cells: [
        DataCell(Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(maxOdometer.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(const Text('')), // fuelType column left empty.
        DataCell(Text(avgRate.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(sumVolume.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(sumPaid.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(sumActualBill.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(sumSavings.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant))),
        DataCell(const Text('')), // Empty cell for the new column
      ],
    );

    // Build the data rows for each record.
    List<DataRow> dataRows = [];
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final actualBill = record.rate * record.volume;
      final difference = actualBill - record.paidAmount;

      double averageMileage = 0;
      if (i < records.length - 1) {
        final previousRecord = records[i + 1];
        if (previousRecord.volume > 0) {
          averageMileage = (record.odometer - previousRecord.odometer) /
              previousRecord.volume;
        }
      }

      dataRows.add(DataRow(
        color: MaterialStateProperty.resolveWith<Color?>((states) {
          double expected = record.volume * record.rate;
          if (record.paidAmount < expected) {
            return theme.colorScheme.tertiaryContainer.withOpacity(0.3);
          }
          if (record.paidAmount > expected) {
            return theme.colorScheme.errorContainer.withOpacity(0.3);
          }
          return null;
        }),
        cells: [
          DataCell(Text(record.date.toLocal().toString().substring(0, 16))),
          DataCell(Text(record.odometer.toStringAsFixed(2))),
          DataCell(Text(record.fuelType)),
          DataCell(Text(record.rate.toStringAsFixed(2))),
          DataCell(Text(record.volume.toStringAsFixed(2))),
          DataCell(Text(record.paidAmount.toStringAsFixed(2))),
          DataCell(Text(actualBill.toStringAsFixed(2))),
          DataCell(Text(difference.toStringAsFixed(2))),
          DataCell(Text(averageMileage.toStringAsFixed(2))),
        ],
      ));
    }

    // Insert the summary row as the first row.
    final List<DataRow> allRows = [summaryRow, ...dataRows];

    return Scaffold(
      appBar: AppBar(title: Text(localizations.allData)),
      drawer: const MyDrawer(),
      body: InteractiveViewer(
        constrained: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 100.0),
          child: DataTable(
            columns: [
              DataColumn(label: Text(localizations.dateAndTime)),
              DataColumn(label: Text(localizations.odometerReading)),
              DataColumn(label: Text(localizations.fuelType)),
              DataColumn(label: Text(localizations.fuelPriceRate)),
              DataColumn(label: Text(localizations.totalVolume)),
              DataColumn(label: Text(localizations.paidAmount)),
              DataColumn(label: Text(localizations.actualBill)),
              DataColumn(label: Text(localizations.savings)),
              DataColumn(label: Text(localizations.averageMileage)),
            ],
            rows: allRows,
          ),
        ),
      ),
    );
  }
}
