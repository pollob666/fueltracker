// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart'; // Import localization
import 'dart:math';

class AllDataPage extends StatefulWidget {
  const AllDataPage({super.key});

  @override
  State<AllDataPage> createState() => _AllDataPageState();
}

class _AllDataPageState extends State<AllDataPage> {
  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();

  List<FuelRecord> _allRecords = [];
  List<FuelRecord> _filteredRecords = [];
  Map<int, FuelType> _fuelTypeMap = {};
  Map<int, Vehicle> _vehicleMap = {};
  List<Vehicle> _vehicles = [];
  int? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    List<FuelRecord> recs = await DatabaseHelper.instance.getFuelRecords();
    List<FuelType> fuelTypes = await _fuelTypeService.getFuelTypes();
    List<Vehicle> vehicles = await _vehicleService.getVehicles();

    recs.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _allRecords = recs;
        _vehicles = vehicles;
        _fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};
        _vehicleMap = {for (var v in vehicles) v.id!: v};
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first.id;
          _filterRecords();
        }
      });
    }
  }

  void _filterRecords() {
    if (_selectedVehicleId == null) {
      _filteredRecords = _allRecords;
    } else {
      _filteredRecords =
          _allRecords.where((r) => r.vehicleId == _selectedVehicleId).toList();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    double overallAverageMileage = 0;
    if (_filteredRecords.length > 1) {
      final totalDistance =
          _filteredRecords.first.odometer - _filteredRecords.last.odometer;
      final totalConsumedVolume =
          _filteredRecords.skip(1).map((r) => r.volume).reduce((a, b) => a + b);
      if (totalConsumedVolume > 0) {
        overallAverageMileage = totalDistance / totalConsumedVolume;
      }
    }

    double maxOdometer = _filteredRecords.isNotEmpty
        ? _filteredRecords.map((r) => r.odometer).reduce(max)
        : 0.0;
    double avgRate = _filteredRecords.isNotEmpty
        ? _filteredRecords.map((r) => r.rate).reduce((a, b) => a + b) /
            _filteredRecords.length
        : 0.0;
    double sumVolume = _filteredRecords.isNotEmpty
        ? _filteredRecords.map((r) => r.volume).reduce((a, b) => a + b)
        : 0.0;
    double sumPaid = _filteredRecords.isNotEmpty
        ? _filteredRecords.map((r) => r.paidAmount).reduce((a, b) => a + b)
        : 0.0;

    final DataRow summaryRow = DataRow(
      color: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest),
      cells: [
        DataCell(Text('Summary',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(maxOdometer.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
        DataCell(const Text('')), // Vehicle column
        DataCell(const Text('')), // FuelType column
        DataCell(Text(avgRate.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(sumVolume.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
        DataCell(Text(sumPaid.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
        DataCell(const Text('')), // Empty cell for the trip mileage column
        DataCell(Text(overallAverageMileage.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
      ],
    );

    List<DataRow> dataRows = [];
    for (int i = 0; i < _filteredRecords.length; i++) {
      final record = _filteredRecords[i];

      double tripMileage = 0;
      if (i < _filteredRecords.length - 1) {
        final previousRecord = _filteredRecords[i + 1];
        if (previousRecord.volume > 0) {
          tripMileage =
              (record.odometer - previousRecord.odometer) / previousRecord.volume;
        }
      }

      final fuelTypeName =
          _fuelTypeMap[record.fuelTypeId]?.name ?? localizations.notAvailable;
      final vehicleName =
          _vehicleMap[record.vehicleId]?.name ?? localizations.notAvailable;

      Color? rowColor;
      if (tripMileage > 0 && overallAverageMileage > 0) {
        final differencePercent =
            (tripMileage - overallAverageMileage) / overallAverageMileage;
        if (differencePercent < -0.10) {
          // >10% less than running average
          rowColor = theme.colorScheme.errorContainer.withAlpha(77);
        } else if (differencePercent > 0.10) {
          // >10% more than running average
          rowColor = theme.colorScheme.tertiaryContainer.withAlpha(77);
        }
      }

      dataRows.add(DataRow(
        color: WidgetStateProperty.all(rowColor),
        cells: [
          DataCell(Text(record.date.toLocal().toString().substring(0, 16))),
          DataCell(Text(record.odometer.toStringAsFixed(2))),
          DataCell(Text(vehicleName)),
          DataCell(Text(fuelTypeName)),
          DataCell(Text(record.rate.toStringAsFixed(2))),
          DataCell(Text(record.volume.toStringAsFixed(2))),
          DataCell(Text(record.paidAmount.toStringAsFixed(2))),
          DataCell(Text(tripMileage.toStringAsFixed(2))),
          DataCell(Text(overallAverageMileage.toStringAsFixed(2))),
        ],
      ));
    }

    final List<DataRow> allRows = [summaryRow, ...dataRows];

    return Scaffold(
      appBar: AppBar(title: Text(localizations.allData)),
      drawer: const MyDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<int>(
              initialValue: _selectedVehicleId,
              items: _vehicles.map((vehicle) {
                return DropdownMenuItem<int>(
                  value: vehicle.id,
                  child: Text(vehicle.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedVehicleId = val;
                  _filterRecords();
                });
              },
              decoration: InputDecoration(
                labelText: localizations.vehicle,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100.0),
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(localizations.dateAndTime)),
                    DataColumn(label: Text(localizations.odometerReading)),
                    DataColumn(label: Text(localizations.vehicle)),
                    DataColumn(label: Text(localizations.fuelType)),
                    DataColumn(label: Text(localizations.fuelPriceRate)),
                    DataColumn(label: Text(localizations.totalVolume)),
                    DataColumn(label: Text(localizations.paidAmount)),
                    DataColumn(label: Text(localizations.averageMileage)),
                    DataColumn(label: Text(localizations.runningAverage)),
                  ],
                  rows: allRows,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
