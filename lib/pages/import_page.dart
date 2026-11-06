// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/service_session.dart';
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
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (file != null && file.path != null) {
      setState(() {
        _filePath = file.path!;
      });
      await _previewFile();
    }
  }

  Future<void> _previewFile() async {
    if (_filePath == null) return;

    try {
      final file = File(_filePath!);
      final content = await file.readAsString();

      List<List<dynamic>> csvTable = Csv().decode(content);

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

    // Check if imported CSV is service records
    if (_findColumnIndex(headers, ['Task', 'task', 'Workshop', 'workshop', 'Brand / Spec', 'brand']) != -1) {
      await _importServiceData(headers);
      return;
    }

    // Check if imported CSV is saved locations
    if (_findColumnIndex(headers, ['RadiusMeters', 'IsSuspectFuel', 'IsRecommendedFuel', 'radiusMeters']) != -1) {
      await _importSavedLocationsData(headers);
      return;
    }

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
    int fullTankCol = _findColumnIndex(headers, [
      'Full Tank', 'fullTank', 'isFullTank', 'FullTank',
      'সম্পূর্ণ ট্যাঙ্ক',
      if (localizations != null) localizations.fullTank,
    ]);
    int missedCol = _findColumnIndex(headers, [
      'Missed Previous', 'missedPrevious', 'missed', 'Missed',
      'আগের রিফুয়েল বাদ পড়েছে', 'বাদ পড়েছে',
      if (localizations != null) localizations.missedPrevious,
    ]);
    int tripDistCol = _findColumnIndex(headers, [
      'Trip Distance', 'tripDistance', 'TripDistance', 'Trip',
      'ট্রিপ দূরত্ব',
      if (localizations != null) localizations.tripDistance,
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
            if (vehicles.isNotEmpty && vehicles.first.id != null) {
              recordVehicleId = vehicles.first.id!;
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

          bool isFullTank = true;
          if (fullTankCol != -1 && fullTankCol < row.length) {
            final val = row[fullTankCol].toString().trim().toLowerCase();
            if (val == 'false' || val == '0' || val == 'no' || val == 'না') {
              isFullTank = false;
            }
          }

          bool missedPrevious = false;
          if (missedCol != -1 && missedCol < row.length) {
            final val = row[missedCol].toString().trim().toLowerCase();
            if (val == 'true' || val == '1' || val == 'yes' || val == 'হ্যাঁ') {
              missedPrevious = true;
            }
          }

          double? tripDistance;
          if (tripDistCol != -1 && tripDistCol < row.length) {
            final val = row[tripDistCol].toString().trim();
            if (val.isNotEmpty && val != 'N/A' && val != 'null') {
              tripDistance = double.tryParse(val);
            }
          }

          entries.add(FuelRecord(
            date: recordDate,
            odometer: odometer,
            vehicleId: recordVehicleId,
            fuelTypeId: fuelTypeId,
            rate: rate,
            volume: volume,
            paidAmount: paidAmount,
            isFullTank: isFullTank,
            missedPrevious: missedPrevious,
            tripDistance: tripDistance,
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

  Future<void> _importServiceData(List<String> headers) async {
    int dateCol = _findColumnIndex(headers, ['Date', 'date', 'DateTime']);
    int odoCol = _findColumnIndex(headers, ['Odometer', 'odometer']);
    int vehicleCol = _findColumnIndex(headers, ['Vehicle', 'vehicle']);
    int workshopCol = _findColumnIndex(headers, ['Workshop', 'workshop', 'mechanic']);
    int totalCostCol = _findColumnIndex(headers, ['Total Cost', 'totalCost', 'Cost', 'cost']);
    int taskCol = _findColumnIndex(headers, ['Task', 'task', 'Task Title', 'taskTitle']);
    int brandCol = _findColumnIndex(headers, ['Brand / Spec', 'brandOrSpec', 'Brand', 'brand', 'spec']);
    int itemCostCol = _findColumnIndex(headers, ['Item Cost', 'itemCost']);
    int notesCol = _findColumnIndex(headers, ['Notes', 'notes', 'comment']);

    final vehicles = await _vehicleService.getVehicles();
    final vehicleMap = {for (var v in vehicles) v.name.toLowerCase(): v};

    int importedCount = 0;
    final Map<String, List<List<dynamic>>> sessionGroups = {};

    for (int i = 1; i < _previewData.length; i++) {
      final row = _previewData[i];
      if (row.isEmpty) continue;
      final dateStr = (dateCol != -1 && dateCol < row.length) ? row[dateCol].toString().trim() : '';
      final odoStr = (odoCol != -1 && odoCol < row.length) ? row[odoCol].toString().trim() : '';
      final vName = (vehicleCol != -1 && vehicleCol < row.length) ? row[vehicleCol].toString().trim() : '';
      final key = '$vName|$dateStr|$odoStr';
      sessionGroups.putIfAbsent(key, () => []).add(row);
    }

    for (final entry in sessionGroups.entries) {
      final rows = entry.value;
      final firstRow = rows.first;
      final dateStr = (dateCol != -1 && dateCol < firstRow.length) ? firstRow[dateCol].toString().trim() : '';
      final odoStr = (odoCol != -1 && odoCol < firstRow.length) ? firstRow[odoCol].toString().trim() : '';
      final vName = (vehicleCol != -1 && vehicleCol < firstRow.length) ? firstRow[vehicleCol].toString().trim().toLowerCase() : '';
      final workshop = (workshopCol != -1 && workshopCol < firstRow.length) ? firstRow[workshopCol].toString().trim() : null;
      final totalCostStr = (totalCostCol != -1 && totalCostCol < firstRow.length) ? firstRow[totalCostCol].toString().trim() : null;
      final notes = (notesCol != -1 && notesCol < firstRow.length) ? firstRow[notesCol].toString().trim() : null;

      final vehicle = vehicleMap[vName] ?? (vehicles.isNotEmpty ? vehicles.first : null);
      if (vehicle == null || vehicle.id == null) continue;

      final serviceDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      final odo = double.tryParse(odoStr) ?? 0.0;
      final totalCost = double.tryParse(totalCostStr ?? '');

      final vehicleTasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicle.id!);
      final taskMap = {for (var t in vehicleTasks) t.title.toLowerCase(): t};

      final List<ServiceSessionItem> items = [];
      for (final r in rows) {
        final taskTitle = (taskCol != -1 && taskCol < r.length) ? r[taskCol].toString().trim() : '';
        if (taskTitle.isEmpty) continue;

        var task = taskMap[taskTitle.toLowerCase()];
        if (task == null) {
          final newTask = MaintenanceTask(
            vehicleId: vehicle.id!,
            title: taskTitle,
            intervalKm: 5000.0,
            lastServiceOdo: odo,
            lastServiceDate: serviceDate,
          );
          final taskId = await DatabaseHelper.instance.insertMaintenanceTask(newTask);
          task = newTask.copyWith(id: taskId);
          taskMap[taskTitle.toLowerCase()] = task;
        }

        final brand = (brandCol != -1 && brandCol < r.length && r[brandCol].toString().trim().isNotEmpty)
            ? r[brandCol].toString().trim()
            : null;
        final itemCost = (itemCostCol != -1 && itemCostCol < r.length)
            ? double.tryParse(r[itemCostCol].toString().trim())
            : null;

        items.add(ServiceSessionItem(
          taskId: task.id!,
          brandOrSpec: brand,
          cost: itemCost,
        ));
      }

      final session = ServiceSession(
        vehicleId: vehicle.id!,
        odometer: odo,
        serviceDate: serviceDate,
        totalCost: totalCost,
        workshopName: (workshop != null && workshop.isNotEmpty) ? workshop : null,
        notes: (notes != null && notes.isNotEmpty) ? notes : null,
        items: items,
      );

      await DatabaseHelper.instance.insertServiceSession(session);
      importedCount++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $importedCount service visit(s) successfully.')),
    );
    Navigator.pop(context);
  }

  Future<void> _importSavedLocationsData(List<String> headers) async {
    final nameCol = _findColumnIndex(headers, ['Name', 'name', 'Location']);
    final isNamedCol = _findColumnIndex(headers, ['IsNamed', 'isNamed']);
    final typeCol = _findColumnIndex(headers, ['Type', 'type', 'Category']);
    final latCol = _findColumnIndex(headers, ['Latitude', 'latitude', 'lat']);
    final lngCol = _findColumnIndex(headers, ['Longitude', 'longitude', 'lng']);
    final radiusCol = _findColumnIndex(headers, ['RadiusMeters', 'radiusMeters', 'radius']);
    final suspectFuelCol = _findColumnIndex(headers, ['IsSuspectFuel', 'isSuspectFuel']);
    final suspectServiceCol = _findColumnIndex(headers, ['IsSuspectServiceOrParts', 'isSuspectServiceOrParts']);
    final suspectReasonCol = _findColumnIndex(headers, ['SuspectReason', 'suspectReason']);
    final recFuelCol = _findColumnIndex(headers, ['IsRecommendedFuel', 'isRecommendedFuel']);
    final recServiceCol = _findColumnIndex(headers, ['IsRecommendedServiceOrParts', 'isRecommendedServiceOrParts']);
    final perfReasonCol = _findColumnIndex(headers, ['PerformanceReason', 'performanceReason']);

    int count = 0;
    for (int i = 1; i < _previewData.length; i++) {
      final row = _previewData[i];
      if (row.isEmpty) continue;
      try {
        final name = nameCol != -1 && nameCol < row.length ? row[nameCol].toString().trim() : 'Saved Location';
        final isNamed = isNamedCol != -1 && isNamedCol < row.length ? (row[isNamedCol].toString().toLowerCase() == 'true' || row[isNamedCol].toString() == '1') : true;
        final type = typeCol != -1 && typeCol < row.length ? row[typeCol].toString().trim() : 'fuel_station';
        final lat = latCol != -1 && latCol < row.length ? double.tryParse(row[latCol].toString()) : null;
        final lng = lngCol != -1 && lngCol < row.length ? double.tryParse(row[lngCol].toString()) : null;
        final radius = radiusCol != -1 && radiusCol < row.length ? (double.tryParse(row[radiusCol].toString()) ?? 80.0) : 80.0;
        final isSuspectFuel = suspectFuelCol != -1 && suspectFuelCol < row.length ? (row[suspectFuelCol].toString().toLowerCase() == 'true' || row[suspectFuelCol].toString() == '1') : false;
        final isSuspectService = suspectServiceCol != -1 && suspectServiceCol < row.length ? (row[suspectServiceCol].toString().toLowerCase() == 'true' || row[suspectServiceCol].toString() == '1') : false;
        final suspectReason = suspectReasonCol != -1 && suspectReasonCol < row.length && row[suspectReasonCol].toString().isNotEmpty ? row[suspectReasonCol].toString() : null;
        final isRecFuel = recFuelCol != -1 && recFuelCol < row.length ? (row[recFuelCol].toString().toLowerCase() == 'true' || row[recFuelCol].toString() == '1') : false;
        final isRecService = recServiceCol != -1 && recServiceCol < row.length ? (row[recServiceCol].toString().toLowerCase() == 'true' || row[recServiceCol].toString() == '1') : false;
        final perfReason = perfReasonCol != -1 && perfReasonCol < row.length && row[perfReasonCol].toString().isNotEmpty ? row[perfReasonCol].toString() : null;

        final loc = SavedLocation(
          name: name,
          isNamed: isNamed,
          type: type,
          latitude: lat,
          longitude: lng,
          radiusMeters: radius,
          isSuspectFuel: isSuspectFuel,
          isSuspectServiceOrParts: isSuspectService,
          suspectReason: suspectReason,
          isRecommendedFuel: isRecFuel,
          isRecommendedServiceOrParts: isRecService,
          performanceReason: perfReason,
        );
        await DatabaseHelper.instance.insertSavedLocation(loc);
        count++;
      } catch (e) {
        debugPrint('Error importing location row: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count saved locations imported successfully.')),
    );
    setState(() {
      _previewData = [];
      _filePath = null;
    });
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
