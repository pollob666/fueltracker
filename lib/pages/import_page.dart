// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<List<dynamic>> _previewData = [];
  String? _filePath;

  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
      });
      await _previewFile();
    }
  }

  Future<void> _previewFile() async {
    if (_filePath == null) return;

    try {
      final file = File(_filePath!);
      final content = await file.readAsString();

      List<List<dynamic>> csvTable = const CsvToListConverter().convert(content);

      if (csvTable.isNotEmpty) {
        setState(() {
          _previewData = csvTable;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.csvFileEmptyOrIncorrectlyFormatted)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.errorReadingCSVFile}$e")));
    }
  }

  Future<void> _importData() async {
    if (_previewData.length < 2) return;

    final headers = _previewData.first.map((e) => e.toString()).toList();
    final bool hasVehicleColumn = headers.contains('Vehicle');

    int? vehicleId;
    if (!hasVehicleColumn) {
      vehicleId = await _showVehicleSelectionDialog();
      if (vehicleId == null) return;
    }

    try {
      final fuelTypes = await _fuelTypeService.getFuelTypes();
      final vehicles = await _vehicleService.getVehicles();
      final fuelTypeMap = {for (var ft in fuelTypes) ft.name: ft.id};
      final vehicleMap = {for (var v in vehicles) v.name: v.id};

      List<FuelRecord> entries = _previewData.skip(1).map((row) {
        try {
          int currentVehicleId;
          int fuelTypeIndex;
          if (hasVehicleColumn) {
            final vehicleName = row[2].toString();
            currentVehicleId = vehicleMap[vehicleName]!;
            fuelTypeIndex = 3;
          } else {
            currentVehicleId = vehicleId!;
            fuelTypeIndex = 2;
          }

          final fuelTypeName = row[fuelTypeIndex].toString();
          final fuelTypeId = fuelTypeMap[fuelTypeName];

          if (fuelTypeId == null) {
            return null;
          }

          return FuelRecord(
            date: DateTime.parse(row[0]),
            odometer: double.tryParse(row[1].toString()) ?? 0,
            vehicleId: currentVehicleId,
            fuelTypeId: fuelTypeId,
            rate: double.tryParse(row[fuelTypeIndex + 1].toString()) ?? 0.0,
            volume: double.tryParse(row[fuelTypeIndex + 2].toString()) ?? 0.0,
            paidAmount: double.tryParse(row[fuelTypeIndex + 3].toString()) ?? 0.0,
          );
        } catch (e) {
          return null;
        }
      }).whereType<FuelRecord>().toList();

      for (var record in entries) {
        await DatabaseHelper.instance.insertFuelRecord(record);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.dataImportedSuccessfully)));

      setState(() {
        _previewData = [];
        _filePath = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.errorImportingData}$e")));
    }
  }

  Future<int?> _showVehicleSelectionDialog() async {
    final vehicles = await _vehicleService.getVehicles();
    if (vehicles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noVehiclesFound)),
        );
      }
      return null;
    }

    if (!mounted) return null;

    int? selectedVehicleId = vehicles.first.id;

    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.importToVehicle),
            content: DropdownButton<int>(
              value: selectedVehicleId,
              items: vehicles.map((vehicle) {
                return DropdownMenuItem<int>(
                  value: vehicle.id,
                  child: Text(vehicle.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedVehicleId = val;
                });
              },
            ),
            actions: <Widget>[
              TextButton(
                child: Text(AppLocalizations.of(context)!.cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(AppLocalizations.of(context)!.ok),
                onPressed: () {
                  Navigator.of(context).pop(selectedVehicleId);
                },
              ),
            ],
          );
        });
      },
    );
  }

  List<DataColumn> _getColumns() {
    if (_previewData.isEmpty) return [];
    return _previewData.first
        .map((cell) => DataColumn(label: Text(cell.toString())))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.import)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _pickFile,
                child: Text(localizations.selectCSVFile),
              ),
              if (_filePath != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                      '${localizations.selectedFile}: $_filePath',
                      style: theme.textTheme.titleMedium),
                ),
              _previewData.length > 1
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: _getColumns(),
                        rows: _previewData.skip(1).map((row) {
                          return DataRow(
                              cells: row
                                  .map((cell) => DataCell(Text(cell.toString())))
                                  .toList());
                        }).toList(),
                      ),
                    )
                  : Center(
                      child: Text(localizations.noDataPreviewAvailable),
                    ),
              if (_previewData.length > 1)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _importData,
                    child: Text(localizations.importData),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
