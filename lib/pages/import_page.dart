// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';

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

  int _findColumnIndex(List<String> headers, List<String> aliases) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      for (final alias in aliases) {
        if (h == alias.trim().toLowerCase()) {
          return i;
        }
      }
    }
    return -1;
  }

  Future<void> _importData() async {
    if (_previewData.length < 2) return;

    final localizations = AppLocalizations.of(context);
    final headers = _previewData.first.map((e) => e.toString().trim()).toList();

    int dateCol = _findColumnIndex(headers, [
      'Date', 'date', 'DateTime', 'Date and Time', 'Date & Time',
      'তারিখ ও সময়', 'তারিখ এবং সময়',
      if (localizations != null) localizations.dateAndTime,
    ]);
    int odoCol = _findColumnIndex(headers, [
      'Odometer', 'odometer', 'Odometer Reading', 'Odometer reading',
      'ওডোমিটার রিডিং', 'ওডোমিটার',
      if (localizations != null) localizations.odometerReading,
    ]);
    int vehicleCol = _findColumnIndex(headers, [
      'Vehicle', 'vehicle', 'Vehicle Name', 'VehicleName',
      'যানবাহন', 'গাড়ি',
      if (localizations != null) localizations.vehicle,
    ]);
    int fuelTypeCol = _findColumnIndex(headers, [
      'Fuel Type', 'fuelType', 'Fuel', 'fuel', 'FuelType',
      'জ্বালানীর ধরন', 'জ্বালানি ধরন',
      if (localizations != null) localizations.fuelType,
    ]);
    int rateCol = _findColumnIndex(headers, [
      'Price Rate', 'Rate', 'rate', 'fuelPriceRate', 'Fuel Price Rate',
      'জ্বালানীর দামের হার', 'জ্বালানি দর',
      if (localizations != null) localizations.fuelPriceRate,
    ]);
    int volumeCol = _findColumnIndex(headers, [
      'Volume', 'volume', 'totalVolume', 'Total Volume',
      'মোট পরিমাণ',
      if (localizations != null) localizations.totalVolume,
    ]);
    int paidCol = _findColumnIndex(headers, [
      'Paid Amount', 'paidAmount', 'Amount Paid', 'Total Price', 'totalPrice',
      'পরিশোধের পরিমাণ', 'মোট খরচ',
      if (localizations != null) localizations.paidAmount,
    ]);

    // Positional fallback for legacy or non-header CSVs
    if (dateCol == -1 && headers.isNotEmpty) dateCol = 0;
    if (odoCol == -1 && headers.length > 1) odoCol = 1;
    if (vehicleCol == -1 && fuelTypeCol == -1) {
      if (headers.length >= 7) {
        vehicleCol = 2;
        fuelTypeCol = 3;
        rateCol = 4;
        volumeCol = 5;
        paidCol = 6;
      } else if (headers.length == 6) {
        fuelTypeCol = 2;
        rateCol = 3;
        volumeCol = 4;
        paidCol = 5;
      }
    } else {
      if (rateCol == -1 && fuelTypeCol != -1 && fuelTypeCol + 1 < headers.length) {
        rateCol = fuelTypeCol + 1;
      }
      if (volumeCol == -1 && rateCol != -1 && rateCol + 1 < headers.length) {
        volumeCol = rateCol + 1;
      }
      if (paidCol == -1 && volumeCol != -1 && volumeCol + 1 < headers.length) {
        paidCol = volumeCol + 1;
      }
    }

    final bool hasVehicleColumn = vehicleCol != -1;
    int? selectedVehicleId;
    if (!hasVehicleColumn) {
      selectedVehicleId = await _showVehicleSelectionDialog();
      if (selectedVehicleId == null) return;
    }

    try {
      final fuelTypes = await _fuelTypeService.getFuelTypes();
      final vehicles = await _vehicleService.getVehicles();
      final Map<String, int> fuelTypeMap = {
        for (var ft in fuelTypes) ft.name.toLowerCase(): ft.id!
      };
      final Map<String, int> vehicleMap = {
        for (var v in vehicles) v.name.toLowerCase(): v.id!
      };

      List<FuelRecord> entries = [];
      for (final row in _previewData.skip(1)) {
        if (row.isEmpty) continue;
        try {
          final String rawDate =
              dateCol != -1 && dateCol < row.length ? row[dateCol].toString().trim() : '';
          final DateTime recordDate =
              DateTime.tryParse(rawDate) ?? DateTime.now();

          final double odometer = odoCol != -1 && odoCol < row.length
              ? double.tryParse(row[odoCol].toString()) ?? 0.0
              : 0.0;

          final String fuelTypeName = fuelTypeCol != -1 && fuelTypeCol < row.length
              ? row[fuelTypeCol].toString().trim()
              : '';
          int? fuelTypeId = fuelTypeMap[fuelTypeName.toLowerCase()];
          if (fuelTypeId == null && fuelTypes.isNotEmpty) {
            fuelTypeId = fuelTypes.first.id;
          }
          if (fuelTypeId == null) continue;

          int? recordVehicleId;
          if (hasVehicleColumn && vehicleCol < row.length) {
            final String vehicleName = row[vehicleCol].toString().trim();
            if (vehicleName.isNotEmpty && vehicleName != 'N/A') {
              if (vehicleMap.containsKey(vehicleName.toLowerCase())) {
                recordVehicleId = vehicleMap[vehicleName.toLowerCase()];
              } else {
                // Auto-create missing vehicle
                final newVehicle = Vehicle(
                  name: vehicleName,
                  type: VehicleType.carOrSedan,
                  primaryFuelTypeId: fuelTypeId,
                );
                final newId =
                    await DatabaseHelper.instance.insertVehicle(newVehicle);
                vehicleMap[vehicleName.toLowerCase()] = newId;
                recordVehicleId = newId;
              }
            } else {
              recordVehicleId = selectedVehicleId ??
                  (vehicles.isNotEmpty ? vehicles.first.id : null);
            }
          } else {
            recordVehicleId = selectedVehicleId;
          }

          if (recordVehicleId == null) {
            if (vehicles.isNotEmpty) {
              recordVehicleId = vehicles.first.id;
            } else {
              final newVehicle = Vehicle(
                name: 'Default Vehicle',
                type: VehicleType.carOrSedan,
                primaryFuelTypeId: fuelTypeId,
              );
              recordVehicleId =
                  await DatabaseHelper.instance.insertVehicle(newVehicle);
            }
          }

          final double rate = rateCol != -1 && rateCol < row.length
              ? double.tryParse(row[rateCol].toString()) ?? 0.0
              : 0.0;
          final double volume = volumeCol != -1 && volumeCol < row.length
              ? double.tryParse(row[volumeCol].toString()) ?? 0.0
              : 0.0;
          final double paidAmount = paidCol != -1 && paidCol < row.length
              ? double.tryParse(row[paidCol].toString()) ?? 0.0
              : 0.0;

          entries.add(FuelRecord(
            date: recordDate,
            odometer: odometer,
            vehicleId: recordVehicleId,
            fuelTypeId: fuelTypeId,
            rate: rate,
            volume: volume,
            paidAmount: paidAmount,
          ));
        } catch (e) {
          debugPrint('Error parsing CSV row: $e');
        }
      }

      for (var record in entries) {
        await DatabaseHelper.instance.insertFuelRecord(record);
      }

      if (!mounted) return;
      if (entries.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${entries.length} ${localizations?.dataImportedSuccessfully ?? "records imported"}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations?.csvFileEmptyOrIncorrectlyFormatted ?? "CSV file empty or incorrectly formatted")));
      }

      setState(() {
        _previewData = [];
        _filePath = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${localizations?.errorImportingData ?? 'Error: '}$e")));
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
      bottomNavigationBar: AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
