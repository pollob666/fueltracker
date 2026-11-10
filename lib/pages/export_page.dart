// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/backup_encryption_service.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/pdf_report_generator.dart';
import 'package:fuel_tracker/services/unified_backup_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/services/webdav_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
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

  // Single JSON Export State
  bool _jsonExportVehicles = true;
  bool _jsonExportRefuels = true;
  bool _jsonExportServices = true;
  bool _jsonExportLocations = true;
  bool _jsonExportExpenses = true;
  bool _jsonExportSettings = true;
  bool _jsonIncludeAttachments = true;
  bool _exportingJson = false;
  String _jsonExportProgress = '';

  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();

  // PDF Fleet & Tax Reporting State
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  DateTimeRange _pdfDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _generatingPdf = false;
  bool _exportingBackup = false;
  final TextEditingController _pdfNotesController =
      TextEditingController(text: 'Fleet & Tax Audit Report');

  @override
  void initState() {
    super.initState();
    _loadSequence();
    _loadVehicles();
  }

  @override
  void dispose() {
    _pdfNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final vehicles = await _vehicleService.getVehicles();
    final defaultId = await _vehicleService.getDefaultVehicle();
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        if (vehicles.isNotEmpty) {
          _selectedVehicle = vehicles.firstWhere(
            (v) => v.id == defaultId,
            orElse: () => vehicles.first,
          );
        }
      });
    }
  }

  Future<Uint8List?> _compilePdf() async {
    if (_selectedVehicle == null || _selectedVehicle!.id == null) return null;

    final vehicleId = _selectedVehicle!.id!;
    final dbHelper = DatabaseHelper.instance;

    final allRecords = await dbHelper.getFuelRecords();
    final fuelRecords = allRecords.where((r) => r.vehicleId == vehicleId).toList();
    final serviceSessions = await dbHelper.getServiceSessions(vehicleId);
    final nonFuelExpenses = await dbHelper.getNonFuelExpenses(vehicleId: vehicleId);
    final fuelTypesList = await _fuelTypeService.getFuelTypes();
    final fuelTypesMap = {for (final ft in fuelTypesList) if (ft.id != null) ft.id!: ft};
    final savedLocationsList = await dbHelper.getSavedLocations();
    final savedLocationsMap = {for (final sl in savedLocationsList) if (sl.id != null) sl.id!: sl};

    return await PdfReportGenerator.generateFleetReport(
      vehicle: _selectedVehicle!,
      dateRange: _pdfDateRange,
      fuelRecords: fuelRecords,
      serviceSessions: serviceSessions,
      nonFuelExpenses: nonFuelExpenses,
      fuelTypes: fuelTypesMap,
      savedLocations: savedLocationsMap,
      companyOrOwnerName: _pdfNotesController.text.trim().isEmpty
          ? 'Fleet & Tax Audit Report'
          : _pdfNotesController.text.trim(),
    );
  }

  Future<void> _previewPdfReport() async {
    if (_selectedVehicle == null) return;
    setState(() => _generatingPdf = true);
    try {
      final pdfBytes = await _compilePdf();
      if (pdfBytes != null) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Fleet_Report_${_selectedVehicle!.name.replaceAll(RegExp(r'\s+'), '_')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _sharePdfReport() async {
    if (_selectedVehicle == null) return;
    setState(() => _generatingPdf = true);
    try {
      final pdfBytes = await _compilePdf();
      if (pdfBytes != null) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Fleet_Report_${_selectedVehicle!.name.replaceAll(RegExp(r'\s+'), '_')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _pdfDateRange,
    );
    if (picked != null) {
      setState(() => _pdfDateRange = picked);
    }
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

  Future<void> _exportSingleJsonViaSaf() async {
    setState(() {
      _exportingJson = true;
      _jsonExportProgress = 'Preparing backup archive...';
    });
    try {
      if (_jsonIncludeAttachments) {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 15);
        final zipFile = File(p.join(tempDir.path, 'fueltracker_backup_$timestamp.zip'));
        await UnifiedBackupService.exportBackupZip(
          targetZipFile: zipFile,
          includeVehicles: _jsonExportVehicles,
          includeRefuelRecords: _jsonExportRefuels,
          includeServiceRecords: _jsonExportServices,
          includeSavedLocations: _jsonExportLocations,
          includeNonFuelExpenses: _jsonExportExpenses,
          includeAppSettings: _jsonExportSettings,
          includeAttachments: true,
          onProgress: (current, total, status) {
            if (mounted) setState(() => _jsonExportProgress = status);
          },
        );
        final uri = await UnifiedBackupService.saveBackupZipViaSaf(zipFile: zipFile);
        if (uri != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup archive saved successfully!')),
          );
        }
      } else {
        final payload = await UnifiedBackupService.createBackupPayload(
          includeVehicles: _jsonExportVehicles,
          includeRefuelRecords: _jsonExportRefuels,
          includeServiceRecords: _jsonExportServices,
          includeSavedLocations: _jsonExportLocations,
          includeNonFuelExpenses: _jsonExportExpenses,
          includeAppSettings: _jsonExportSettings,
          includeAttachments: false,
        );
        final jsonString = UnifiedBackupService.encodePayload(payload);
        final uri = await UnifiedBackupService.saveBackupViaSaf(jsonString: jsonString);
        if (uri != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup saved successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save backup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingJson = false;
          _jsonExportProgress = '';
        });
      }
    }
  }

  Future<void> _shareSingleJson() async {
    setState(() {
      _exportingJson = true;
      _jsonExportProgress = 'Preparing backup archive...';
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 15);
      final File exportFile;

      if (_jsonIncludeAttachments) {
        exportFile = File(p.join(tempDir.path, 'fueltracker_backup_$timestamp.zip'));
        await UnifiedBackupService.exportBackupZip(
          targetZipFile: exportFile,
          includeVehicles: _jsonExportVehicles,
          includeRefuelRecords: _jsonExportRefuels,
          includeServiceRecords: _jsonExportServices,
          includeSavedLocations: _jsonExportLocations,
          includeNonFuelExpenses: _jsonExportExpenses,
          includeAppSettings: _jsonExportSettings,
          includeAttachments: true,
          onProgress: (current, total, status) {
            if (mounted) setState(() => _jsonExportProgress = status);
          },
        );
      } else {
        final payload = await UnifiedBackupService.createBackupPayload(
          includeVehicles: _jsonExportVehicles,
          includeRefuelRecords: _jsonExportRefuels,
          includeServiceRecords: _jsonExportServices,
          includeSavedLocations: _jsonExportLocations,
          includeNonFuelExpenses: _jsonExportExpenses,
          includeAppSettings: _jsonExportSettings,
          includeAttachments: false,
        );
        final jsonString = UnifiedBackupService.encodePayload(payload);
        exportFile = File(p.join(tempDir.path, 'fueltracker_backup_$timestamp.json'));
        await exportFile.writeAsString(jsonString);
      }

      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(exportFile.path)],
          text: _jsonIncludeAttachments ? 'FuelTracker Backup Archive (.zip)' : 'FuelTracker Backup (.json)',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share backup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingJson = false;
          _jsonExportProgress = '';
        });
      }
    }
  }

  Future<void> _uploadSingleJsonToWebDav() async {
    final config = await WebDavService.loadSavedConfig();
    if (config == null) {
      _showWebDavSyncSheet();
      return;
    }

    setState(() => _exportingJson = true);
    try {
      final payload = await UnifiedBackupService.createBackupPayload(
        includeVehicles: _jsonExportVehicles,
        includeRefuelRecords: _jsonExportRefuels,
        includeServiceRecords: _jsonExportServices,
        includeSavedLocations: _jsonExportLocations,
        includeNonFuelExpenses: _jsonExportExpenses,
        includeAppSettings: _jsonExportSettings,
        includeAttachments: _jsonIncludeAttachments,
      );
      final jsonString = UnifiedBackupService.encodePayload(payload);
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 15);
      final fileName = 'fueltracker_backup_$timestamp.json';

      final success = await WebDavService.uploadBackup(
        config: config,
        fileName: fileName,
        content: Uint8List.fromList(utf8.encode(jsonString)),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Uploaded backup to WebDAV!' : 'WebDAV upload failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WebDAV upload error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingJson = false);
    }
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

  Future<void> _showEncryptedExportDialog() async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool includeAttachments = true;
    bool obscurePassword = true;

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 22),
                  SizedBox(width: 8),
                  Text('Create Encrypted Backup'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your data is protected with AES-256-GCM and PBKDF2 key derivation (600,000 rounds). Choose a strong master password.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Master Password',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, size: 20),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include photo attachments (receipts, odometers)', style: TextStyle(fontSize: 13)),
                      value: includeAttachments,
                      onChanged: (val) => setDialogState(() => includeAttachments = val ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final pass = passwordController.text;
                    final conf = confirmController.text;
                    if (pass.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password cannot be empty.')),
                      );
                      return;
                    }
                    if (pass != conf) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match.')),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Encrypt & Export'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldExport == true) {
      final password = passwordController.text;
      setState(() => _exportingBackup = true);
      try {
        final backupFile = await BackupEncryptionService.createEncryptedBackupFile(
          password: password,
          includeAttachments: includeAttachments,
        );
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(backupFile.path)],
            subject: 'FuelTracker Encrypted Backup',
            text: 'FuelTracker encrypted backup created on ${DateTime.now()}',
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup creation failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _exportingBackup = false);
      }
    }
  }

  Future<void> _restoreFromFile(File file) async {
    Uint8List fileBytes;
    try {
      fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        throw const BackupCorruptHeaderException('The selected backup file is empty.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read backup file: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final enteredPassword = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.key, size: 22),
                  SizedBox(width: 8),
                  Text('Enter Master Password'),
                ],
              ),
              content: TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Master Password',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, size: 20),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(passwordController.text),
                  child: const Text('Decrypt'),
                ),
              ],
            );
          },
        );
      },
    );

    if (enteredPassword == null || enteredPassword.isEmpty) return;

    Map<String, dynamic> payload;
    try {
      payload = await BackupEncryptionService.decryptBackup(
        backup: fileBytes,
        password: enteredPassword,
      );
    } on BackupAuthenticationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } on BackupDecryptionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decryption error: $e')),
        );
      }
      return;
    }

    final summary = BackupEncryptionService.getPayloadSummary(payload);
    if (!mounted) return;

    final restoreChoice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Backup Verified'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Archive contains verified records:',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('• ${summary['vehicles']} vehicles'),
              Text('• ${summary['fuelRecords']} fuel records'),
              Text('• ${summary['serviceSessions']} maintenance sessions'),
              Text('• ${summary['nonFuelExpenses']} non-fuel expenses'),
              Text('• ${summary['savedLocations']} saved locations'),
              Text('• ${summary['attachments']} photo attachments'),
              const SizedBox(height: 14),
              const Text('Select restoration strategy:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('merge'),
              child: const Text('Merge with Existing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop('replace'),
              child: const Text('Replace All Data'),
            ),
          ],
        );
      },
    );

    if (restoreChoice == null) return;
    final replaceExisting = restoreChoice == 'replace';

    setState(() => _exportingBackup = true);
    try {
      await BackupEncryptionService.restoreFromDecryptedPayload(
        payload: payload,
        replaceExisting: replaceExisting,
      );
      await _loadVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replaceExisting
                  ? 'All data successfully restored from backup.'
                  : 'Backup data successfully merged.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingBackup = false);
    }
  }

  Future<void> _showEncryptedImportDialog() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ftbackup', 'json'],
    );
    if (file == null || file.path == null) {
      return;
    }

    final localFile = File(file.path!);
    await _restoreFromFile(localFile);
  }

  Future<void> _showWebDavSyncSheet() async {
    final savedConfig = await WebDavService.loadSavedConfig();
    final urlController = TextEditingController(text: savedConfig?.serverUrl ?? '');
    final userController = TextEditingController(text: savedConfig?.username ?? '');
    final passController = TextEditingController(text: savedConfig?.password ?? '');

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        bool isConnecting = false;
        bool obscurePassword = true;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.cloud_sync, color: colorScheme.onSecondaryContainer, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WebDAV & Nextcloud Sync', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Sync client-side encrypted backups to private cloud', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        labelText: 'WebDAV Server URL',
                        hintText: 'https://cloud.example.com/remote.php/dav/files/user/FuelTracker/',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: userController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'App Password / Password',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off, size: 20),
                          onPressed: () => setSheetState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    if (isConnecting)
                      const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.wifi_tethering, size: 16),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Test Connection'),
                                  ),
                                  onPressed: () async {
                                    final config = WebDavConfig(
                                      serverUrl: urlController.text.trim(),
                                      username: userController.text.trim(),
                                      password: passController.text,
                                    );
                                    if (!config.isValid) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter server URL and username.')),
                                      );
                                      return;
                                    }
                                    setSheetState(() => isConnecting = true);
                                    try {
                                      final ok = await WebDavService.testConnection(config: config);
                                      await WebDavService.saveConfig(config);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'Connected successfully!' : 'Connection returned non-207 status.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Connection failed: $e')),
                                        );
                                      }
                                    } finally {
                                      setSheetState(() => isConnecting = false);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.cloud_upload, size: 16),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Upload Backup'),
                                  ),
                                  onPressed: () async {
                                    final config = WebDavConfig(
                                      serverUrl: urlController.text.trim(),
                                      username: userController.text.trim(),
                                      password: passController.text,
                                    );
                                    if (!config.isValid) return;
                                    await WebDavService.saveConfig(config);

                                    if (!context.mounted) return;
                                    final passwordController = TextEditingController();
                                    final masterPass = await showDialog<String>(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text('Master Encryption Password'),
                                        content: TextField(
                                          controller: passwordController,
                                          obscureText: true,
                                          autofocus: true,
                                          decoration: const InputDecoration(labelText: 'Password'),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(dialogCtx).pop(null),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(dialogCtx).pop(passwordController.text),
                                            child: const Text('Encrypt & Upload'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (masterPass == null || masterPass.isEmpty) return;

                                    setSheetState(() => isConnecting = true);
                                    try {
                                      final backupFile = await BackupEncryptionService.createEncryptedBackupFile(
                                        password: masterPass,
                                      );
                                      final fileName = p.basename(backupFile.path);
                                      final bytes = await backupFile.readAsBytes();
                                      final ok = await WebDavService.uploadBackup(
                                        config: config,
                                        fileName: fileName,
                                        content: bytes,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(ok ? 'Backup uploaded to WebDAV: $fileName' : 'Upload failed.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Upload error: $e')),
                                        );
                                      }
                                    } finally {
                                      setSheetState(() => isConnecting = false);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cloud_download, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('List & Download Remote Backups'),
                              ),
                              onPressed: () async {
                                final config = WebDavConfig(
                                  serverUrl: urlController.text.trim(),
                                  username: userController.text.trim(),
                                  password: passController.text,
                                );
                                if (!config.isValid) return;
                                setSheetState(() => isConnecting = true);
                                List<WebDavFileInfo> files = [];
                                try {
                                  files = await WebDavService.listRemoteBackups(config: config);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to list backups: $e')),
                                    );
                                  }
                                } finally {
                                  setSheetState(() => isConnecting = false);
                                }

                                if (!context.mounted || files.isEmpty) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No .ftbackup files found on server.')),
                                    );
                                  }
                                  return;
                                }

                                final chosen = await showDialog<WebDavFileInfo>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Select Remote Backup'),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: files.length,
                                        itemBuilder: (ctx, i) {
                                          final f = files[i];
                                          return ListTile(
                                            leading: const Icon(Icons.shield),
                                            title: Text(f.name, style: const TextStyle(fontSize: 12)),
                                            onTap: () => Navigator.of(dCtx).pop(f),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );

                                if (chosen == null || !context.mounted) return;

                                setSheetState(() => isConnecting = true);
                                try {
                                  final downloadedBytes = await WebDavService.downloadBackup(
                                    config: config,
                                    remoteFileName: chosen.name,
                                  );
                                  final tempDir = await getTemporaryDirectory();
                                  final localFile = File(p.join(tempDir.path, chosen.name));
                                  await localFile.writeAsBytes(downloadedBytes);

                                  if (context.mounted) {
                                    Navigator.of(context).pop(); // close bottom sheet
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Downloaded ${chosen.name}. Restoring...')),
                                    );
                                    await _restoreFromFile(localFile);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Download failed: $e')),
                                    );
                                  }
                                } finally {
                                  setSheetState(() => isConnecting = false);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);

    if (localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dateFormatter = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: Text(localizations.export)),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Unified Single JSON Data Backup Section (Primary)
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.cloud_sync, color: colorScheme.onPrimaryContainer, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Unified Data Backup',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Single JSON',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Save directly to Google Drive, Dropbox, or Device via Android SAF',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Select Content to Include (Defaults to All):', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Vehicles & Fuel Types'),
                        value: _jsonExportVehicles,
                        onChanged: (v) => setState(() => _jsonExportVehicles = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Refueling Logs'),
                        value: _jsonExportRefuels,
                        onChanged: (v) => setState(() => _jsonExportRefuels = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Service & Maintenance Records'),
                        value: _jsonExportServices,
                        onChanged: (v) => setState(() => _jsonExportServices = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Saved GPS Locations'),
                        value: _jsonExportLocations,
                        onChanged: (v) => setState(() => _jsonExportLocations = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Non-Fuel Expenses'),
                        value: _jsonExportExpenses,
                        onChanged: (v) => setState(() => _jsonExportExpenses = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('App Settings & Preferences'),
                        value: _jsonExportSettings,
                        onChanged: (v) => setState(() => _jsonExportSettings = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: const Text('Include Photo Attachments (Streamed ZIP)'),
                        subtitle: const Text('Streamed entries without Base64 memory overhead'),
                        value: _jsonIncludeAttachments,
                        onChanged: (v) => setState(() => _jsonIncludeAttachments = v ?? true),
                      ),
                      const SizedBox(height: 12),
                      if (_exportingJson)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                if (_jsonExportProgress.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _jsonExportProgress,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _exportSingleJsonViaSaf,
                            icon: const Icon(Icons.file_download, size: 18),
                            label: const Text('Save to Phone / Cloud (Drive, Dropbox, Files)'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _shareSingleJson,
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text('Share File'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _uploadSingleJsonToWebDav,
                                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                                label: const Text('WebDAV Upload'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Legacy CSV & Spreadsheet Exports Accordion
              Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text('Legacy & Spreadsheet Exports (CSV / Tables)'),
                    subtitle: const Text('Export individual CSV files for Excel & spreadsheets'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              dense: true,
                              title: Text(localizations.exportRefuelingData),
                              value: _exportRefuelingData,
                              onChanged: (value) => setState(() => _exportRefuelingData = value!),
                            ),
                            CheckboxListTile(
                              dense: true,
                              title: Text(localizations.exportServiceHistory),
                              value: _exportServiceHistory,
                              onChanged: (value) => setState(() => _exportServiceHistory = value!),
                            ),
                            CheckboxListTile(
                              dense: true,
                              title: const Text('Export Saved Locations'),
                              value: _exportSavedLocations,
                              onChanged: (value) => setState(() => _exportSavedLocations = value!),
                            ),
                            CheckboxListTile(
                              dense: true,
                              title: Text(localizations.exportAppSettings),
                              value: _exportAppSettings,
                              onChanged: (value) => setState(() => _exportAppSettings = value!),
                            ),
                            CheckboxListTile(
                              dense: true,
                              title: Text(localizations.exportVehicleInformation),
                              value: _exportVehicleInformation,
                              onChanged: (value) => setState(() => _exportVehicleInformation = value!),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _exporting ? null : _exportData,
                              icon: const Icon(Icons.table_chart, size: 18),
                              label: const Text('Export Selected CSVs'),
                            ),
                            if (_message.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(_message, style: theme.textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Printable PDF Tax & Fleet Reports Card
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.picture_as_pdf, color: colorScheme.onPrimaryContainer, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Printable Tax & Fleet PDF',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Audit-ready expense & mileage reports for write-offs',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Vehicle Selection (if multiple)
                      if (_vehicles.isNotEmpty) ...[
                        Text('Select Vehicle', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Vehicle>(
                              isExpanded: true,
                              value: _selectedVehicle,
                              items: _vehicles.map((v) {
                                return DropdownMenuItem(
                                  value: v,
                                  child: Text('${v.name} (${v.type.name.toUpperCase()})'),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedVehicle = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Date Range Selection
                      Text('Reporting Date Range', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDateRange,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${dateFormatter.format(_pdfDateRange.start)} – ${dateFormatter.format(_pdfDateRange.end)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.edit_calendar, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Date Presets
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Last 30 Days', style: TextStyle(fontSize: 11)),
                            selected: _pdfDateRange.duration.inDays == 30,
                            onSelected: (_) {
                              setState(() {
                                _pdfDateRange = DateTimeRange(
                                  start: DateTime.now().subtract(const Duration(days: 30)),
                                  end: DateTime.now(),
                                );
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('This Month', style: TextStyle(fontSize: 11)),
                            selected: false,
                            onSelected: (_) {
                              final now = DateTime.now();
                              setState(() {
                                _pdfDateRange = DateTimeRange(
                                  start: DateTime(now.year, now.month, 1),
                                  end: now,
                                );
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('All Time', style: TextStyle(fontSize: 11)),
                            selected: false,
                            onSelected: (_) {
                              setState(() {
                                _pdfDateRange = DateTimeRange(
                                  start: DateTime(2000, 1, 1),
                                  end: DateTime.now().add(const Duration(days: 1)),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Custom Note / Title
                      TextField(
                        controller: _pdfNotesController,
                        decoration: InputDecoration(
                          labelText: 'Report Header / Auditor Note',
                          hintText: 'e.g. Tax Year 2026 Fleet Log',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 18),

                      // Action Buttons
                      if (_generatingPdf)
                        const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _previewPdfReport,
                                icon: const Icon(Icons.print, size: 16),
                                label: const Text('Preview & Print'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _sharePdfReport,
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text('Share PDF'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Client-Side Encrypted Backup & Cloud Sync Card
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.shield_outlined, color: colorScheme.onTertiaryContainer, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Encrypted Vault & Cloud Sync',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'AES-256 client-side encrypted .ftbackup & WebDAV',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Full-fidelity zero-knowledge backups protected with PBKDF2 (600,000 rounds) and AES-256-GCM. Includes vehicle records, service logs, receipts, and odometer photos.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 18),
                      if (_exportingBackup)
                        const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _showEncryptedExportDialog,
                                icon: const Icon(Icons.lock, size: 16),
                                label: const Text('Export .ftbackup'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showEncryptedImportDialog,
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Restore File'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                          ),
                          onPressed: _showWebDavSyncSheet,
                          icon: const Icon(Icons.cloud_sync, size: 18),
                          label: const Text('WebDAV / Nextcloud Sync Settings'),
                        ),
                      ],
                    ],
                  ),
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
