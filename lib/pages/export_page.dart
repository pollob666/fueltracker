// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _exporting = false;
  String _message = "";
  bool _exportRefuelingData = true;
  bool _exportServiceHistory = true;
  bool _exportSavedLocations = false;
  bool _exportAppSettings = false;
  bool _exportVehicleInformation = false;
  int _sequence = 1;

  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();

  @override
  void initState() {
    super.initState();
    _loadSequence();
  }

  Future<void> _loadSequence() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sequence = prefs.getInt('export_sequence') ?? 1;
    });
  }

  Future<void> _incrementSequence() async {
    final prefs = await SharedPreferences.getInstance();
    _sequence++;
    await prefs.setInt('export_sequence', _sequence);
    setState(() {});
  }

  String _getFormattedFileName(String prefix) {
    final now = DateTime.now();
    final dateFormatter = DateFormat('yyyyMMddTHHmm');
    final formattedDate = dateFormatter.format(now);
    return '${prefix}_${formattedDate}_$_sequence';
  }

  Future<void> _exportData() async {
    final localizations = AppLocalizations.of(context);
    if (!mounted || localizations == null) return;

    setState(() {
      _exporting = true;
      _message = "";
    });

    if (!_exportRefuelingData &&
        !_exportServiceHistory &&
        !_exportSavedLocations &&
        !_exportAppSettings &&
        !_exportVehicleInformation) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
      });
      return;
    }

    final localFolderPath = AppSettings.localFolderPath;
    final bool isScopedStorage = localFolderPath.isEmpty;
    final String exportFolder = isScopedStorage
        ? (await getTemporaryDirectory()).path
        : localFolderPath;

    final dir = Directory(exportFolder);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final List<File> createdFiles = [];

    if (_exportRefuelingData) {
      final file = await _exportRefuelingDataAsCsv(exportFolder);
      if (file != null) createdFiles.add(file);
    }
    if (_exportServiceHistory) {
      final file = await _exportServiceHistoryAsCsv(exportFolder);
      if (file != null) createdFiles.add(file);
    }
    if (_exportSavedLocations) {
      final file = await _exportSavedLocationsAsCsv(exportFolder);
      if (file != null) createdFiles.add(file);
    }
    if (_exportAppSettings) {
      final file = await _exportAppSettingsAsJson(exportFolder);
      if (file != null) createdFiles.add(file);
    }
    if (_exportVehicleInformation) {
      final file = await _exportVehicleInformationAsCsv(exportFolder);
      if (file != null) createdFiles.add(file);
    }

    if (createdFiles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _message = localizations.failedToExport;
      });
      return;
    }

    if (isScopedStorage) {
      if (!mounted) return;
      final xFiles = createdFiles.map((f) => XFile(f.path)).toList();
      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          files: xFiles,
          text: localizations.shareExport,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      await _incrementSequence();
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _message = localizations.exportSuccessful;
      });
    } else {
      await _incrementSequence();
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _message = "${localizations.dataExportedTo} $localFolderPath";
      });
    }
  }

  Future<File?> _exportRefuelingDataAsCsv(String folderPath) async {
    try {
      List<FuelRecord> records = await DatabaseHelper.instance.getFuelRecords();
      final fuelTypes = await _fuelTypeService.getFuelTypes();
      final vehicles = await _vehicleService.getVehicles();
      final savedLocations = await DatabaseHelper.instance.getSavedLocations();
      final fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};
      final vehicleMap = {for (var v in vehicles) v.id!: v};
      final locationMap = {for (var loc in savedLocations) loc.id!: loc};

      List<List<String>> csvData = [
        [
          'Date',
          'Odometer',
          'Vehicle',
          'Fuel Type',
          'Price Rate',
          'Volume',
          'Paid Amount',
          'Full Tank',
          'Missed Previous',
          'Trip Distance',
          'Secondary Trip Distance',
          'Driving Condition',
          'Location Name',
          'Latitude',
          'Longitude',
        ],
        ...records.map((r) => [
              r.date.toIso8601String(),
              r.odometer.toStringAsFixed(2),
              vehicleMap[r.vehicleId]?.name ?? 'N/A',
              fuelTypeMap[r.fuelTypeId]?.name ?? 'N/A',
              r.rate.toStringAsFixed(2),
              r.volume.toStringAsFixed(2),
              r.paidAmount.toStringAsFixed(2),
              r.isFullTank.toString(),
              r.missedPrevious.toString(),
              r.tripDistance?.toStringAsFixed(2) ?? '',
              r.secondaryTripDistance?.toStringAsFixed(2) ?? '',
              r.drivingCondition.name,
              r.locationId != null
                  ? (locationMap[r.locationId]?.displayName ?? '')
                  : '',
              r.latitude?.toString() ?? '',
              r.longitude?.toString() ?? '',
            ])
      ];

      String csv = Csv().encode(csvData);
      String fileName = "${_getFormattedFileName('refuel_records')}.csv";
      File file = File("$folderPath/$fileName");

      await file.writeAsString(csv);
      return file;
    } catch (e) {
      debugPrint("Failed to export refueling data: $e");
      return null;
    }
  }

  Future<File?> _exportAppSettingsAsJson(String folderPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'maxVolume': prefs.getDouble('maxVolume'),
        'storageOption': prefs.getString('storageOption'),
        'localFolderPath': prefs.getString('localFolderPath'),
        'googleDriveFolderPath': prefs.getString('googleDriveFolderPath'),
        'dropboxFolderPath': prefs.getString('dropboxFolderPath'),
        'themeMode': prefs.getString('themeMode'),
        'darkTheme': prefs.getString('darkTheme'),
        'language': prefs.getString('language'),
        'defaultFuelPrices':
            jsonDecode(prefs.getString('defaultFuelPrices') ?? '{}'),
      };

      String json = jsonEncode(settings);
      String fileName = "${_getFormattedFileName('app_settings')}.json";
      File file = File("$folderPath/$fileName");

      await file.writeAsString(json);
      return file;
    } catch (e) {
      debugPrint("Failed to export app settings: $e");
      return null;
    }
  }

  Future<File?> _exportVehicleInformationAsCsv(String folderPath) async {
    try {
      List<Vehicle> vehicles = await _vehicleService.getVehicles();
      final fuelTypes = await _fuelTypeService.getFuelTypes();
      final fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};

      List<List<String>> csvData = [
        [
          'ID',
          'Name',
          'Type',
          'Primary Fuel Type',
          'Primary Fuel Capacity',
          'Secondary Fuel Type',
          'Secondary Fuel Capacity',
        ],
        ...vehicles.map((v) => [
              v.id.toString(),
              v.name,
              v.type.toString(),
              fuelTypeMap[v.primaryFuelTypeId]?.name ?? 'N/A',
              v.primaryFuelCapacity?.toString() ?? 'N/A',
              fuelTypeMap[v.secondaryFuelTypeId]?.name ?? 'N/A',
              v.secondaryFuelCapacity?.toString() ?? 'N/A',
            ])
      ];

      String csv = Csv().encode(csvData);
      String fileName = "${_getFormattedFileName('vehicle_information')}.csv";
      File file = File("$folderPath/$fileName");

      await file.writeAsString(csv);
      return file;
    } catch (e) {
      debugPrint("Failed to export vehicle information: $e");
      return null;
    }
  }

  Future<File?> _exportServiceHistoryAsCsv(String folderPath) async {
    try {
      final vehicles = await _vehicleService.getVehicles();
      final vehicleMap = {for (var v in vehicles) v.id!: v};

      final List<List<String>> csvData = [
        [
          'Date',
          'Odometer',
          'Vehicle',
          'Workshop',
          'Total Cost',
          'Task',
          'Brand / Spec',
          'Item Cost',
          'Notes',
        ],
      ];

      for (final v in vehicles) {
        if (v.id == null) continue;
        final sessions = await DatabaseHelper.instance.getServiceSessions(v.id!);
        for (final session in sessions) {
          final dateStr = session.serviceDate.toIso8601String();
          final odoStr = session.odometer.toStringAsFixed(2);
          final vehicleName = vehicleMap[session.vehicleId]?.name ?? 'N/A';
          final workshop = session.workshopName ?? '';
          final totalCost = session.totalCost != null
              ? session.totalCost!.toStringAsFixed(2)
              : '';
          final notes = session.notes ?? '';

          if (session.items.isNotEmpty) {
            for (final item in session.items) {
              final taskTitle = item.taskTitle ?? 'Task #${item.taskId}';
              final brand = item.brandOrSpec ?? '';
              final itemCost = item.cost != null ? item.cost!.toStringAsFixed(2) : '';
              csvData.add([
                dateStr,
                odoStr,
                vehicleName,
                workshop,
                totalCost,
                taskTitle,
                brand,
                itemCost,
                notes,
              ]);
            }
          } else {
            csvData.add([
              dateStr,
              odoStr,
              vehicleName,
              workshop,
              totalCost,
              '',
              '',
              '',
              notes,
            ]);
          }
        }
      }

      String csv = Csv().encode(csvData);
      String fileName = "${_getFormattedFileName('service_records')}.csv";
      File file = File("$folderPath/$fileName");

      await file.writeAsString(csv);
      return file;
    } catch (e) {
      debugPrint("Failed to export service history: $e");
      return null;
    }
  }

  Future<File?> _exportSavedLocationsAsCsv(String folderPath) async {
    try {
      final locations = await DatabaseHelper.instance.getSavedLocations();
      List<List<String>> csvData = [
        [
          'ID',
          'Name',
          'IsNamed',
          'Type',
          'Latitude',
          'Longitude',
          'RadiusMeters',
          'IsSuspectFuel',
          'IsSuspectServiceOrParts',
          'SuspectReason',
          'IsRecommendedFuel',
          'IsRecommendedServiceOrParts',
          'PerformanceReason',
        ],
        ...locations.map((l) => [
              l.id?.toString() ?? '',
              l.name,
              l.isNamed.toString(),
              l.type,
              l.latitude?.toString() ?? '',
              l.longitude?.toString() ?? '',
              l.radiusMeters.toString(),
              l.isSuspectFuel.toString(),
              l.isSuspectServiceOrParts.toString(),
              l.suspectReason ?? '',
              l.isRecommendedFuel.toString(),
              l.isRecommendedServiceOrParts.toString(),
              l.performanceReason ?? '',
            ])
      ];

      String csv = Csv().encode(csvData);
      String fileName = "${_getFormattedFileName('saved_locations')}.csv";
      File file = File("$folderPath/$fileName");

      await file.writeAsString(csv);
      return file;
    } catch (e) {
      debugPrint("Failed to export saved locations: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    if (localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(localizations.export)),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localizations.selectDataToExport,
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(localizations.exportRefuelingData),
                value: _exportRefuelingData,
                onChanged: (value) {
                  setState(() {
                    _exportRefuelingData = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: Text(localizations.exportServiceHistory),
                value: _exportServiceHistory,
                onChanged: (value) {
                  setState(() {
                    _exportServiceHistory = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Export Saved Locations'),
                value: _exportSavedLocations,
                onChanged: (value) {
                  setState(() {
                    _exportSavedLocations = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: Text(localizations.exportAppSettings),
                value: _exportAppSettings,
                onChanged: (value) {
                  setState(() {
                    _exportAppSettings = value!;
                  });
                },
              ),
              CheckboxListTile(
                title: Text(localizations.exportVehicleInformation),
                value: _exportVehicleInformation,
                onChanged: (value) {
                  setState(() {
                    _exportVehicleInformation = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _exporting ? null : _exportData,
                  child: Text(localizations.export),
                ),
              ),
              const SizedBox(height: 16),
              Text(_message, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
