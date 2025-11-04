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

    String folderPath = AppSettings.localFolderPath;
    if (folderPath.isEmpty) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _message = localizations.folderPathNotSetInSettings;
      });
      return;
    }

    List<String> messages = [];

    if (_exportRefuelingData) {
      messages.add(await _exportRefuelingDataAsCsv(folderPath, localizations));
    }
    if (_exportAppSettings) {
      messages.add(await _exportAppSettingsAsJson(folderPath, localizations));
    }
    if (_exportVehicleInformation) {
      messages.add(await _exportVehicleInformationAsCsv(folderPath, localizations));
    }

    if (messages.any((m) => m.contains(localizations.dataExportedTo))) {
      await _incrementSequence();
    }

    if (!mounted) return;
    setState(() {
      _exporting = false;
      _message = messages.join('\n');
    });
  }

  Future<String> _exportRefuelingDataAsCsv(
      String folderPath, AppLocalizations localizations) async {
    List<FuelRecord> records = await DatabaseHelper.instance.getFuelRecords();
    final fuelTypes = await _fuelTypeService.getFuelTypes();
    final vehicles = await _vehicleService.getVehicles();
    final fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};
    final vehicleMap = {for (var v in vehicles) v.id!: v};

    List<List<String>> csvData = [
      [
        localizations.dateAndTime,
        localizations.odometerReading,
        localizations.vehicle,
        localizations.fuelType,
        localizations.fuelPriceRate,
        localizations.totalVolume,
        localizations.paidAmount,
      ],
      ...records.map((r) => [
            r.date.toIso8601String(),
            r.odometer.toStringAsFixed(2),
            vehicleMap[r.vehicleId]?.name ?? 'N/A',
            fuelTypeMap[r.fuelTypeId]?.name ?? 'N/A',
            r.rate.toStringAsFixed(2),
            r.volume.toStringAsFixed(2),
            r.paidAmount.toStringAsFixed(2),
          ])
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    String fileName = "${_getFormattedFileName('refuel_records')}.csv";
    File file = File("$folderPath/$fileName");

    try {
      await file.writeAsString(csv);
      return "${localizations.dataExportedTo} $fileName";
    } catch (e) {
      return "${localizations.failedToExport} $fileName: $e";
    }
  }

  Future<String> _exportAppSettingsAsJson(
      String folderPath, AppLocalizations localizations) async {
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

    try {
      await file.writeAsString(json);
      return "${localizations.dataExportedTo} $fileName";
    } catch (e) {
      return "${localizations.failedToExport} $fileName: $e";
    }
  }

  Future<String> _exportVehicleInformationAsCsv(
      String folderPath, AppLocalizations localizations) async {
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

    String csv = const ListToCsvConverter().convert(csvData);
    String fileName = "${_getFormattedFileName('vehicle_information')}.csv";
    File file = File("$folderPath/$fileName");

    try {
      await file.writeAsString(csv);
      return "${localizations.dataExportedTo} $fileName";
    } catch (e) {
      return "${localizations.failedToExport} $fileName: $e";
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
      bottomNavigationBar: const BannerAdWidget(),
    );
  }
}
