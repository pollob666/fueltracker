// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:fuel_tracker/providers/non_fuel_expense_providers.dart';
import 'package:fuel_tracker/providers/vehicle_providers.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/unified_backup_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? _filePath;
  String? _fileName;
  int _fileSizeBytes = 0;

  // Single JSON / ZIP State
  bool _isJsonBackup = false;
  bool _isZipBackup = false;
  String _progressStatus = '';
  BackupValidationSummary? _validationSummary;
  Map<String, dynamic>? _jsonPayload;
  final Set<ImportCategory> _selectedCategories = {
    ImportCategory.vehicles,
    ImportCategory.fuelRecords,
    ImportCategory.serviceRecords,
    ImportCategory.savedLocations,
    ImportCategory.nonFuelExpenses,
    ImportCategory.appSettings,
    ImportCategory.attachments,
  };
  ConflictResolutionStrategy _conflictStrategy = ConflictResolutionStrategy.overwriteExisting;
  bool _importing = false;

  // Legacy CSV Preview State
  List<List<dynamic>> _previewData = [];

  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();

  Future<void> _pickFile() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv', 'zip'],
      dialogTitle: 'Select FuelTracker Backup or CSV',
    );

    if (file != null && file.path != null) {
      final f = File(file.path!);
      final size = await f.length();
      setState(() {
        _filePath = file.path!;
        _fileName = p.basename(file.path!);
        _fileSizeBytes = size;
      });
      await _processPickedFile();
    }
  }

  Future<void> _processPickedFile() async {
    if (_filePath == null) return;

    try {
      final file = File(_filePath!);
      final lower = _filePath!.toLowerCase();

      if (lower.endsWith('.zip')) {
        await _handleZipFile(file);
      } else if (lower.endsWith('.json')) {
        final content = await file.readAsString();
        _handleJsonContent(content);
      } else {
        final content = await file.readAsString();
        _handleCsvContent(content);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading file: $e')),
      );
    }
  }

  Future<void> _handleZipFile(File file) async {
    try {
      final summary = await UnifiedBackupService.validateBackupArchive(file);
      if (summary.isValid) {
        setState(() {
          _isJsonBackup = true;
          _isZipBackup = true;
          _validationSummary = summary;
          _jsonPayload = null;
          _previewData = [];
        });
      } else {
        setState(() {
          _isJsonBackup = false;
          _isZipBackup = false;
          _validationSummary = null;
          _jsonPayload = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(summary.errorMessage ?? 'Invalid ZIP backup.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isJsonBackup = false;
        _isZipBackup = false;
        _validationSummary = null;
        _jsonPayload = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read ZIP backup: $e')),
        );
      }
    }
  }

  void _handleJsonContent(String content) {
    final summary = UnifiedBackupService.validateBackupPayload(content);
    if (summary.isValid) {
      setState(() {
        _isJsonBackup = true;
        _isZipBackup = false;
        _validationSummary = summary;
        _jsonPayload = jsonDecode(content) as Map<String, dynamic>;
        _previewData = [];
      });
    } else {
      setState(() {
        _isJsonBackup = false;
        _isZipBackup = false;
        _validationSummary = null;
        _jsonPayload = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(summary.errorMessage ?? 'Invalid JSON backup.')),
        );
      }
    }
  }

  void _handleCsvContent(String content) {
    try {
      List<List<dynamic>> csvTable = Csv().decode(content);
      if (csvTable.isNotEmpty) {
        setState(() {
          _isJsonBackup = false;
          _isZipBackup = false;
          _validationSummary = null;
          _jsonPayload = null;
          _previewData = csvTable;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.csvFileEmptyOrIncorrectlyFormatted)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context)!.errorReadingCSVFile}$e")),
      );
    }
  }

  Future<void> _startJsonImport() async {
    if (!_isZipBackup && _jsonPayload == null) return;

    setState(() {
      _importing = true;
      _progressStatus = 'Preparing import...';
    });

    try {
      final ImportExecutionResult result;
      if (_isZipBackup) {
        result = await UnifiedBackupService.executeImportFromArchive(
          archiveFile: File(_filePath!),
          selectedCategories: _selectedCategories,
          conflictStrategy: _conflictStrategy,
          onProgress: (current, total, status) {
            if (mounted) {
              setState(() => _progressStatus = status);
            }
          },
        );
      } else {
        result = await UnifiedBackupService.executeImport(
          payload: _jsonPayload!,
          selectedCategories: _selectedCategories,
          conflictStrategy: _conflictStrategy,
        );
      }

      if (!mounted) return;

      if (result.success) {
        ref.invalidate(vehiclesProvider);
        ref.invalidate(activeVehicleProvider);
        ref.invalidate(fuelRecordsProvider);
        ref.invalidate(nonFuelExpenseRepositoryProvider);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
            title: const Text('Import Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.importedVehicles > 0)
                  Text('• Vehicles: ${result.importedVehicles}'),
                if (result.importedRefuels > 0)
                  Text('• Refueling Records: ${result.importedRefuels}'),
                if (result.importedServices > 0)
                  Text('• Service Visits: ${result.importedServices}'),
                if (result.importedLocations > 0)
                  Text('• Saved Locations: ${result.importedLocations}'),
                if (result.importedExpenses > 0)
                  Text('• Non-Fuel Expenses: ${result.importedExpenses}'),
                if (result.importedSettings)
                  const Text('• App Settings Restored'),
                if (result.importedAttachments > 0)
                  Text('• Attachments Restored: ${result.importedAttachments}'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${result.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // --- Legacy CSV Parsing & Importing Logic ---

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

  Future<void> _importLegacyCsvData() async {
    if (_previewData.length < 2) return;

    final localizations = AppLocalizations.of(context);
    final headers = _previewData.first.map((e) => e.toString().trim()).toList();

    if (_findColumnIndex(headers, ['Task', 'task', 'Workshop', 'workshop', 'Brand / Spec', 'brand']) != -1) {
      await _importServiceData(headers);
      return;
    }

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
    int secTripCol = _findColumnIndex(headers, [
      'Secondary Trip Distance', 'secondaryTripDistance', 'Trip B', 'TripB', 'Trip 2',
    ]);
    int conditionCol = _findColumnIndex(headers, [
      'Driving Condition', 'drivingCondition', 'Condition', 'driving_condition',
    ]);
    int locationCol = _findColumnIndex(headers, [
      'Location Name', 'Location', 'location', 'Station', 'station',
    ]);

    if (dateCol == -1 || odoCol == -1 || vehicleCol == -1 || fuelTypeCol == -1 ||
        rateCol == -1 || volumeCol == -1 || paidCol == -1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV file lacks required refueling columns.')),
      );
      return;
    }

    final vehicles = await _vehicleService.getVehicles();
    final fuelTypes = await _fuelTypeService.getFuelTypes();
    final vehicleMap = {for (var v in vehicles) v.name.toLowerCase(): v};
    final fuelTypeMap = {for (var ft in fuelTypes) ft.name.toLowerCase(): ft};

    int importedCount = 0;
    for (int i = 1; i < _previewData.length; i++) {
      final r = _previewData[i];
      if (r.isEmpty) continue;

      final dateStr = r[dateCol].toString().trim();
      final odoStr = r[odoCol].toString().trim();
      final vehicleStr = r[vehicleCol].toString().trim();
      final fuelTypeStr = r[fuelTypeCol].toString().trim();
      final rateStr = r[rateCol].toString().trim();
      final volumeStr = r[volumeCol].toString().trim();
      final paidStr = r[paidCol].toString().trim();

      DateTime? date = DateTime.tryParse(dateStr);
      double? odo = double.tryParse(odoStr);
      double? rate = double.tryParse(rateStr);
      double? volume = double.tryParse(volumeStr);
      double? paid = double.tryParse(paidStr);

      if (date == null || odo == null || rate == null || volume == null || paid == null) {
        continue;
      }

      var vehicle = vehicleMap[vehicleStr.toLowerCase()];
      if (vehicle == null) {
        var defaultFuelType = fuelTypeMap[fuelTypeStr.toLowerCase()];
        if (defaultFuelType == null) {
          final newFuelType = FuelType(name: fuelTypeStr, category: FuelCategory.gasoline, unit: FuelUnit.litre);
          final newFuelTypeId = await DatabaseHelper.instance.insertFuelType(newFuelType);
          defaultFuelType = newFuelType.copyWith(id: newFuelTypeId);
          fuelTypeMap[fuelTypeStr.toLowerCase()] = defaultFuelType;
        }

        final newVehicle = Vehicle(
          name: vehicleStr,
          type: VehicleType.carOrSedan,
          primaryFuelTypeId: defaultFuelType.id!,
        );
        final newVehicleId = await DatabaseHelper.instance.insertVehicle(newVehicle);
        vehicle = newVehicle.copyWith(id: newVehicleId);
        vehicleMap[vehicleStr.toLowerCase()] = vehicle;
      }

      var fuelType = fuelTypeMap[fuelTypeStr.toLowerCase()];
      if (fuelType == null) {
        final newFuelType = FuelType(name: fuelTypeStr, category: FuelCategory.gasoline, unit: FuelUnit.litre);
        final newFuelTypeId = await DatabaseHelper.instance.insertFuelType(newFuelType);
        fuelType = newFuelType.copyWith(id: newFuelTypeId);
        fuelTypeMap[fuelTypeStr.toLowerCase()] = fuelType;
      }

      bool isFull = fullTankCol != -1 && fullTankCol < r.length &&
          (r[fullTankCol].toString().toLowerCase() == 'true' || r[fullTankCol].toString() == '1');
      bool isMissed = missedCol != -1 && missedCol < r.length &&
          (r[missedCol].toString().toLowerCase() == 'true' || r[missedCol].toString() == '1');
      double? tripDist = tripDistCol != -1 && tripDistCol < r.length ? double.tryParse(r[tripDistCol].toString()) : null;
      double? secTrip = secTripCol != -1 && secTripCol < r.length ? double.tryParse(r[secTripCol].toString()) : null;

      DrivingCondition cond = DrivingCondition.mixed;
      if (conditionCol != -1 && conditionCol < r.length) {
        final cStr = r[conditionCol].toString().trim().toLowerCase();
        if (cStr == 'city') cond = DrivingCondition.city;
        if (cStr == 'highway') cond = DrivingCondition.highway;
      }

      int? locId;
      if (locationCol != -1 && locationCol < r.length && r[locationCol].toString().trim().isNotEmpty) {
        final locName = r[locationCol].toString().trim();
        final existingLocs = await DatabaseHelper.instance.getSavedLocations();
        final match = existingLocs.where((l) => l.name.toLowerCase() == locName.toLowerCase()).firstOrNull;
        if (match != null) {
          locId = match.id;
        } else {
          final newLoc = SavedLocation(
            name: locName,
            isNamed: true,
            type: 'fuel_station',
          );
          locId = await DatabaseHelper.instance.insertSavedLocation(newLoc);
        }
      }

      final record = FuelRecord(
        vehicleId: vehicle.id!,
        date: date,
        odometer: odo,
        fuelTypeId: fuelType.id!,
        rate: rate,
        volume: volume,
        paidAmount: paid,
        isFullTank: isFull,
        missedPrevious: isMissed,
        tripDistance: tripDist,
        secondaryTripDistance: secTrip,
        drivingCondition: cond,
        locationId: locId,
      );

      await DatabaseHelper.instance.insertFuelRecord(record);
      importedCount++;
    }

    if (!mounted) return;
    ref.invalidate(fuelRecordsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported $importedCount records.')),
    );
    Navigator.pop(context);
  }

  Future<void> _importServiceData(List<String> headers) async {
    final vehicles = await _vehicleService.getVehicles();
    final vehicleMap = {for (var v in vehicles) v.name.toLowerCase(): v};

    final dateCol = _findColumnIndex(headers, ['Date', 'date', 'DateTime']);
    final odoCol = _findColumnIndex(headers, ['Odometer', 'odometer']);
    final vehicleCol = _findColumnIndex(headers, ['Vehicle', 'vehicle']);
    final workshopCol = _findColumnIndex(headers, ['Workshop', 'workshop']);
    final totalCostCol = _findColumnIndex(headers, ['Total Cost', 'totalCost']);
    final notesCol = _findColumnIndex(headers, ['Notes', 'notes']);

    int importedCount = 0;
    for (int i = 1; i < _previewData.length; i++) {
      final r = _previewData[i];
      if (r.isEmpty) continue;

      final dateStr = dateCol != -1 && dateCol < r.length ? r[dateCol].toString().trim() : '';
      final odoStr = odoCol != -1 && odoCol < r.length ? r[odoCol].toString().trim() : '';
      final vehicleStr = vehicleCol != -1 && vehicleCol < r.length ? r[vehicleCol].toString().trim() : '';
      final workshop = workshopCol != -1 && workshopCol < r.length ? r[workshopCol].toString().trim() : null;
      final totalCost = totalCostCol != -1 && totalCostCol < r.length ? double.tryParse(r[totalCostCol].toString().trim()) : null;
      final notes = notesCol != -1 && notesCol < r.length ? r[notesCol].toString().trim() : null;

      final serviceDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      final odo = double.tryParse(odoStr) ?? 0.0;

      var vehicle = vehicleMap[vehicleStr.toLowerCase()];
      if (vehicle == null && vehicles.isNotEmpty) {
        vehicle = vehicles.first;
      }
      if (vehicle == null) continue;

      final session = ServiceSession(
        vehicleId: vehicle.id!,
        odometer: odo,
        serviceDate: serviceDate,
        totalCost: totalCost,
        workshopName: workshop,
        notes: notes,
        items: [],
      );

      await DatabaseHelper.instance.insertServiceSession(session);
      importedCount++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $importedCount service visits.')),
    );
    Navigator.pop(context);
  }

  Future<void> _importSavedLocationsData(List<String> headers) async {
    final nameCol = _findColumnIndex(headers, ['Name', 'name', 'Location']);
    final latCol = _findColumnIndex(headers, ['Latitude', 'latitude', 'lat']);
    final lngCol = _findColumnIndex(headers, ['Longitude', 'longitude', 'lng']);

    int count = 0;
    for (int i = 1; i < _previewData.length; i++) {
      final row = _previewData[i];
      if (row.isEmpty) continue;
      final name = nameCol != -1 && nameCol < row.length ? row[nameCol].toString().trim() : 'Location';
      final lat = latCol != -1 && latCol < row.length ? double.tryParse(row[latCol].toString()) : null;
      final lng = lngCol != -1 && lngCol < row.length ? double.tryParse(row[lngCol].toString()) : null;

      final loc = SavedLocation(
        name: name,
        isNamed: true,
        type: 'fuel_station',
        latitude: lat,
        longitude: lng,
      );
      await DatabaseHelper.instance.insertSavedLocation(loc);
      count++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count saved locations imported.')),
    );
    Navigator.pop(context);
  }

  List<DataColumn> _getColumns() {
    if (_previewData.isEmpty) return [];
    return _previewData.first
        .map((cell) => DataColumn(label: Text(cell.toString())))
        .toList();
  }

  // --- Widgets for Redesigned Single JSON UI ---

  Widget _buildSummaryCategoryTile({
    required BuildContext context,
    required ImportCategory category,
    required String title,
    required String subtitle,
    required bool isPresent,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategories.contains(category);

    return Opacity(
      opacity: isPresent ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected && isPresent
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          color: isSelected && isPresent
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected && isPresent,
              onChanged: isPresent
                  ? (val) {
                      setState(() {
                        if (val == true) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    }
                  : null,
            ),
            Icon(icon, size: 22, color: isPresent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (isPresent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Valid', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            else
              Text('None', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;
    final dateFormatter = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: Text(localizations.import)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action / File Picker Button
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.file_open, color: colorScheme.onPrimaryContainer, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fileName != null ? _fileName! : 'Select Backup File',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _filePath != null
                                  ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB • ${_isJsonBackup ? "Unified JSON" : "CSV File"}'
                                  : 'Supports Single JSON backups & legacy CSVs',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: _importing ? null : _pickFile,
                        child: Text(_filePath != null ? 'Change' : 'Browse'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CASE 1: Single JSON Backup Validation Summary
              if (_isJsonBackup && _validationSummary != null) ...[
                Row(
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Detected Content Summary',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_validationSummary!.exportTimestamp != null)
                      Text(
                        dateFormatter.format(_validationSummary!.exportTimestamp!.toLocal()),
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select categories to import. Overlapping data can be overwritten or merged.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),

                // Category summary cards
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.vehicles,
                  title: 'Vehicles, Fuel Types & Tires',
                  subtitle: _validationSummary!.vehicleCount > 0
                      ? '${_validationSummary!.vehicleCount} vehicles: ${_validationSummary!.vehicleNames.join(', ')}${_validationSummary!.tireCount > 0 ? ' (${_validationSummary!.tireCount} tires)' : ''}'
                      : 'No vehicle records in backup',
                  isPresent: _validationSummary!.vehicleCount > 0,
                  icon: Icons.directions_car_outlined,
                ),
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.fuelRecords,
                  title: 'Refueling Logs',
                  subtitle: _validationSummary!.refuelCount > 0
                      ? '${_validationSummary!.refuelCount} fuel logs ready for import'
                      : 'No refueling logs in backup',
                  isPresent: _validationSummary!.refuelCount > 0,
                  icon: Icons.local_gas_station_outlined,
                ),
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.serviceRecords,
                  title: 'Service & Maintenance',
                  subtitle: _validationSummary!.serviceSessionCount > 0
                      ? '${_validationSummary!.serviceSessionCount} visits, ${_validationSummary!.serviceItemCount} line items'
                      : 'No service records in backup',
                  isPresent: _validationSummary!.serviceSessionCount > 0,
                  icon: Icons.build_outlined,
                ),
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.savedLocations,
                  title: 'Saved GPS Locations',
                  subtitle: _validationSummary!.locationCount > 0
                      ? '${_validationSummary!.locationCount} fuel stations & workshops'
                      : 'No saved locations in backup',
                  isPresent: _validationSummary!.locationCount > 0,
                  icon: Icons.place_outlined,
                ),
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.nonFuelExpenses,
                  title: 'Non-Fuel Expenses',
                  subtitle: _validationSummary!.expenseCount > 0
                      ? '${_validationSummary!.expenseCount} entries (Tolls, Parking, Insurance)'
                      : 'No non-fuel expenses in backup',
                  isPresent: _validationSummary!.expenseCount > 0,
                  icon: Icons.receipt_long_outlined,
                ),
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.appSettings,
                  title: 'App Settings & Preferences',
                  subtitle: _validationSummary!.hasAppSettings
                      ? 'Validated, ready for import'
                      : 'No app settings in backup',
                  isPresent: _validationSummary!.hasAppSettings,
                  icon: Icons.settings_outlined,
                ),
                _buildSummaryCategoryTile(
                  context: context,
                  category: ImportCategory.attachments,
                  title: 'Photo Attachments (Base64)',
                  subtitle: _validationSummary!.attachmentCount > 0
                      ? '${_validationSummary!.attachmentCount} photos embedded in backup'
                      : 'No photo attachments in backup',
                  isPresent: _validationSummary!.attachmentCount > 0,
                  icon: Icons.photo_camera_outlined,
                ),
                const SizedBox(height: 16),

                // Conflict Resolution Strategy Card
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Overlapping Data Strategy',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose how to handle records with matching IDs:',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<ConflictResolutionStrategy>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Overwrite Existing (Default)'),
                          subtitle: const Text('Updates existing rows from backup. Ideal for restoring.'),
                          value: ConflictResolutionStrategy.overwriteExisting,
                          groupValue: _conflictStrategy,
                          onChanged: (val) {
                            if (val != null) setState(() => _conflictStrategy = val);
                          },
                        ),
                        RadioListTile<ConflictResolutionStrategy>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Skip Existing (Only New)'),
                          subtitle: const Text('Keeps current data intact and adds only new entries.'),
                          value: ConflictResolutionStrategy.skipExisting,
                          groupValue: _conflictStrategy,
                          onChanged: (val) {
                            if (val != null) setState(() => _conflictStrategy = val);
                          },
                        ),
                        RadioListTile<ConflictResolutionStrategy>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Copy / Merge All'),
                          subtitle: const Text('Assigns new IDs to incoming rows, preserving duplicates.'),
                          value: ConflictResolutionStrategy.copyMergeAll,
                          groupValue: _conflictStrategy,
                          onChanged: (val) {
                            if (val != null) setState(() => _conflictStrategy = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Import Button
                if (_importing)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (_progressStatus.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _progressStatus,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selectedCategories.isEmpty ? null : _startJsonImport,
                      icon: const Icon(Icons.file_download_done),
                      label: Text('Start Import (${_selectedCategories.length} Categories Selected)'),
                    ),
                  ),
              ] else if (_previewData.length > 1) ...[
                // CASE 2: Legacy CSV Table Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Legacy CSV file detected. Showing tabular preview.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _getColumns(),
                    rows: _previewData.skip(1).take(10).map((row) {
                      return DataRow(
                        cells: row.map((cell) => DataCell(Text(cell.toString()))).toList(),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _importLegacyCsvData,
                    child: Text(localizations.importData),
                  ),
                ),
              ] else if (_filePath == null) ...[
                // CASE 3: Empty State Illustration
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 64, color: colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No Backup Selected',
                          style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick a single JSON backup file from Google Drive, Dropbox, or Device Storage',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
