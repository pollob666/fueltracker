// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/add_data_page.dart';
import 'package:fuel_tracker/providers/vehicle_providers.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/utils/long_screenshot_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/widgets/refuel_timeline_card.dart';

enum HistoryDateFilter {
  all,
  thisMonth,
  lastThreeMonths,
  custom,
}

enum HistoryViewMode {
  cards,
  table,
}

class AllDataPage extends ConsumerStatefulWidget {
  const AllDataPage({super.key});

  @override
  ConsumerState<AllDataPage> createState() => _AllDataPageState();
}

class _AllDataPageState extends ConsumerState<AllDataPage> {
  final GlobalKey _screenshotKey = GlobalKey();
  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();
  final TextEditingController _searchController = TextEditingController();

  List<FuelRecord> _allRecords = [];
  Map<int, FuelType> _fuelTypeMap = {};
  Map<int, Vehicle> _vehicleMap = {};
  Map<int, SavedLocation> _locationMap = {};
  List<Vehicle> _vehicles = [];
  int? _selectedVehicleId;

  String _searchQuery = '';
  HistoryDateFilter _dateFilter = HistoryDateFilter.all;
  DateTimeRange? _customDateRange;
  int? _selectedFuelTypeId;
  DrivingCondition? _selectedCondition;
  HistoryViewMode _viewMode = HistoryViewMode.cards;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final recs = await DatabaseHelper.instance.getFuelRecords();
    final fuelTypes = await _fuelTypeService.getFuelTypes();
    final vehicles = await _vehicleService.getVehicles();
    final locations = await DatabaseHelper.instance.getSavedLocations();

    recs.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _allRecords = recs;
        _vehicles = vehicles;
        _fuelTypeMap = {for (var ft in fuelTypes) if (ft.id != null) ft.id!: ft};
        _vehicleMap = {for (var v in vehicles) if (v.id != null) v.id!: v};
        _locationMap = {for (var loc in locations) if (loc.id != null) loc.id!: loc};
        if (_vehicles.isNotEmpty) {
          final activeId = ref.read(activeVehicleIdProvider);
          if (activeId != null && _vehicles.any((v) => v.id == activeId)) {
            _selectedVehicleId = activeId;
          } else if (_selectedVehicleId == null ||
              !_vehicles.any((v) => v.id == _selectedVehicleId)) {
            _selectedVehicleId = _vehicles.first.id;
          }
        }
      });
    }
  }

  List<FuelRecord> _getFilteredRecords() {
    return _allRecords.where((record) {
      // Vehicle filter
      if (_selectedVehicleId != null && record.vehicleId != _selectedVehicleId) {
        return false;
      }

      // Fuel Type filter
      if (_selectedFuelTypeId != null && record.fuelTypeId != _selectedFuelTypeId) {
        return false;
      }

      // Driving Condition filter
      if (_selectedCondition != null && record.drivingCondition != _selectedCondition) {
        return false;
      }

      // Date Range filter
      final now = DateTime.now();
      switch (_dateFilter) {
        case HistoryDateFilter.all:
          break;
        case HistoryDateFilter.thisMonth:
          final startOfMonth = DateTime(now.year, now.month, 1);
          if (record.date.isBefore(startOfMonth)) return false;
          break;
        case HistoryDateFilter.lastThreeMonths:
          final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
          if (record.date.isBefore(threeMonthsAgo)) return false;
          break;
        case HistoryDateFilter.custom:
          if (_customDateRange != null) {
            final start = DateTime(
              _customDateRange!.start.year,
              _customDateRange!.start.month,
              _customDateRange!.start.day,
            );
            final end = DateTime(
              _customDateRange!.end.year,
              _customDateRange!.end.month,
              _customDateRange!.end.day,
              23,
              59,
              59,
            );
            if (record.date.isBefore(start) || record.date.isAfter(end)) {
              return false;
            }
          }
          break;
      }

      // Text Search Query
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final stationName = record.locationId != null
            ? _locationMap[record.locationId]?.name.toLowerCase() ?? ''
            : '';
        final fuelName = _fuelTypeMap[record.fuelTypeId]?.name.toLowerCase() ?? '';
        final odoStr = record.odometer.toStringAsFixed(1);
        final dateStr = record.date.toString().toLowerCase();

        final matches = stationName.contains(query) ||
            fuelName.contains(query) ||
            odoStr.contains(query) ||
            dateStr.contains(query);

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );

    if (picked != null) {
      setState(() {
        _dateFilter = HistoryDateFilter.custom;
        _customDateRange = picked;
      });
    }
  }

  Future<void> _showRecordActions(FuelRecord record) async {
    final localizations = AppLocalizations.of(context)!;
    final vehicleName =
        _vehicleMap[record.vehicleId]?.name ?? localizations.notAvailable;
    final fuelTypeName =
        _fuelTypeMap[record.fuelTypeId]?.name ?? localizations.notAvailable;
    final stationName = record.locationId != null
        ? _locationMap[record.locationId]?.name
        : null;
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(77),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${record.date.toLocal().toString().substring(0, 16)} — $vehicleName ($fuelTypeName)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (stationName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Station: $stationName',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Odometer: ${record.odometer.toStringAsFixed(2)} | Volume: ${record.volume.toStringAsFixed(2)} | Paid: ${record.paidAmount.toStringAsFixed(2)}${record.tripDistance != null ? ' | Trip: ${record.tripDistance!.toStringAsFixed(1)}' : ''}${record.secondaryTripDistance != null ? ' | Trip B: ${record.secondaryTripDistance!.toStringAsFixed(1)}' : ''} (${record.drivingCondition == DrivingCondition.city ? '🏙️ City' : record.drivingCondition == DrivingCondition.highway ? '🛣️ Highway' : '🔄 Mixed'})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Record'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final updated = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddDataPage(recordToEdit: record),
                    ),
                  );
                  if (updated == true) {
                    _loadInitialData();
                  }
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text(
                  'Delete Record',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(record);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(FuelRecord record) async {
    final localizations = AppLocalizations.of(context)!;
    final vehicleName =
        _vehicleMap[record.vehicleId]?.name ?? localizations.notAvailable;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fuel Record'),
        content: Text(
          'Are you sure you want to delete the record for $vehicleName on ${record.date.toLocal().toString().substring(0, 16)} (${record.odometer.toStringAsFixed(2)} km)?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null) {
      await DatabaseHelper.instance.deleteFuelRecord(record.id!);
      _loadInitialData();
    }
  }

  Widget _buildMileageCell(IntervalResult? interval, AppLocalizations localizations, ThemeData theme) {
    if (interval == null) return Text(localizations.notAvailable);
    if (interval.isMissed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(localizations.notAvailable),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              localizations.missed,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      );
    }
    if (interval.isPartial) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(localizations.notAvailable),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              localizations.partial,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      );
    }
    if (interval.mileage != null) {
      return Text(interval.mileage!.toStringAsFixed(2));
    }
    return Text(localizations.notAvailable);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredRecords = _getFilteredRecords();
    final double overallAverageMileage =
        MileageCalculator.calculateWeightedRunningAverage(filteredRecords);

    // Compute intervals
    final Map<FuelRecord, IntervalResult> resultMap = {};
    if (_selectedVehicleId != null) {
      final results = MileageCalculator.calculateIntervalResults(filteredRecords);
      for (final res in results) {
        resultMap[res.record] = res;
      }
    } else {
      final Map<int, List<FuelRecord>> byVehicle = {};
      for (final r in filteredRecords) {
        byVehicle.putIfAbsent(r.vehicleId, () => []).add(r);
      }
      for (final vRecords in byVehicle.values) {
        final results = MileageCalculator.calculateIntervalResults(vRecords);
        for (final res in results) {
          resultMap[res.record] = res;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.allData),
        actions: [
          IconButton(
            icon: const Icon(Icons.screenshot_outlined),
            tooltip: 'Long Screenshot',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Capturing screenshot...'),
                  duration: Duration(milliseconds: 700),
                ),
              );
              final success = await LongScreenshotService.captureAndShare(
                context: context,
                boundaryKey: _screenshotKey,
                fileNamePrefix: 'fueltracker_history',
                shareText: 'Fuel Tracker History',
              );
              if (!success && mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to capture screenshot')),
                );
              }
            },
          ),
          // View Mode Switcher
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SegmentedButton<HistoryViewMode>(
              segments: const [
                ButtonSegment<HistoryViewMode>(
                  value: HistoryViewMode.cards,
                  icon: Icon(Icons.view_agenda_outlined, size: 16),
                  tooltip: 'Cards View',
                ),
                ButtonSegment<HistoryViewMode>(
                  value: HistoryViewMode.table,
                  icon: Icon(Icons.table_chart_outlined, size: 16),
                  tooltip: 'Table View',
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _viewMode = newSelection.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: RepaintBoundary(
        key: _screenshotKey,
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              // Vehicle Selector
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: DropdownButtonFormField<int>(
                  key: ValueKey(_selectedVehicleId),
                  value: _selectedVehicleId,
                  items: _vehicles.map((vehicle) {
                    return DropdownMenuItem<int>(
                      value: vehicle.id,
                      child: Text(vehicle.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(activeVehicleIdProvider.notifier).state = val;
                    }
                    setState(() {
                      _selectedVehicleId = val;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: localizations.vehicle,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),

              // Search Bar & Filter Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search station, notes, odo...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),

              // Horizontal Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: Row(
                  children: [
                    _buildDateChip('All Dates', HistoryDateFilter.all),
                    const SizedBox(width: 6),
                    _buildDateChip('This Month', HistoryDateFilter.thisMonth),
                    const SizedBox(width: 6),
                    _buildDateChip('Last 3 Months', HistoryDateFilter.lastThreeMonths),
                    const SizedBox(width: 6),
                    _buildCustomDateChip(),
                    const SizedBox(width: 12),
                    // Driving Condition Filter Chips
                    _buildConditionChip('All Road', null),
                    const SizedBox(width: 6),
                    _buildConditionChip('🏙️ City', DrivingCondition.city),
                    const SizedBox(width: 6),
                    _buildConditionChip('🛣️ Highway', DrivingCondition.highway),
                    const SizedBox(width: 6),
                    _buildConditionChip('🔄 Mixed', DrivingCondition.mixed),
                  ],
                ),
              ),

              // Summary Stats Header Strip
              _buildSummaryStatsBar(filteredRecords, overallAverageMileage, theme),

              // Body: Cards Timeline vs Table
              Expanded(
                child: filteredRecords.isEmpty
                    ? _buildEmptyState(theme)
                    : _viewMode == HistoryViewMode.cards
                        ? _buildCardsTimeline(
                            filteredRecords, resultMap, overallAverageMileage)
                        : _buildClassicTable(filteredRecords, resultMap,
                            overallAverageMileage, localizations, theme),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }

  Widget _buildSummaryStatsBar(
    List<FuelRecord> records,
    double runningAvg,
    ThemeData theme,
  ) {
    if (records.isEmpty) return const SizedBox.shrink();

    final totalVolume =
        records.map((r) => r.volume).fold(0.0, (a, b) => a + b);
    final totalPaid =
        records.map((r) => r.paidAmount).fold(0.0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${records.length} records',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Total: ${totalVolume.toStringAsFixed(1)} L • ${totalPaid.toStringAsFixed(0)} ৳',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (runningAvg > 0)
            Text(
              'Avg: ${runningAvg.toStringAsFixed(2)} km/L',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardsTimeline(
    List<FuelRecord> records,
    Map<FuelRecord, IntervalResult> resultMap,
    double runningAvg,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6.0, bottom: 80.0),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final interval = resultMap[record];
        final fuelTypeName =
            _fuelTypeMap[record.fuelTypeId]?.name ?? 'Fuel';
        final vehicleName =
            _vehicleMap[record.vehicleId]?.name ?? 'Vehicle';
        final stationName = record.locationId != null
            ? _locationMap[record.locationId]?.name
            : null;

        return RefuelTimelineCard(
          record: record,
          interval: interval,
          runningAverage: runningAvg,
          fuelTypeName: fuelTypeName,
          vehicleName: vehicleName,
          stationName: stationName,
          onTap: () => _showRecordActions(record),
          onEdit: () async {
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => AddDataPage(recordToEdit: record),
              ),
            );
            if (updated == true) {
              _loadInitialData();
            }
          },
          onDelete: () => _confirmDelete(record),
        );
      },
    );
  }

  Widget _buildClassicTable(
    List<FuelRecord> records,
    Map<FuelRecord, IntervalResult> resultMap,
    double overallAverageMileage,
    AppLocalizations localizations,
    ThemeData theme,
  ) {
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
        DataCell(const Text('')),
        DataCell(const Text('')),
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
        DataCell(const Text('')),
        DataCell(Text(overallAverageMileage.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant))),
      ],
    );

    List<DataRow> dataRows = [];
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final interval = resultMap[record];
      final double? tripMileage = interval?.mileage;

      final fuelTypeName =
          _fuelTypeMap[record.fuelTypeId]?.name ?? localizations.notAvailable;
      final vehicleName =
          _vehicleMap[record.vehicleId]?.name ?? localizations.notAvailable;

      Color? rowColor;
      if (tripMileage != null && tripMileage > 0 && overallAverageMileage > 0) {
        final differencePercent =
            (tripMileage - overallAverageMileage) / overallAverageMileage;
        if (differencePercent < -0.10) {
          rowColor = theme.colorScheme.errorContainer.withAlpha(77);
        } else if (differencePercent > 0.10) {
          rowColor = theme.colorScheme.tertiaryContainer.withAlpha(77);
        }
      }

      dataRows.add(DataRow(
        color: WidgetStateProperty.all(rowColor),
        onSelectChanged: (_) => _showRecordActions(record),
        cells: [
          DataCell(Text(record.date.toLocal().toString().substring(0, 16))),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(record.odometer.toStringAsFixed(2)),
                if (record.drivingCondition != DrivingCondition.mixed) ...[
                  const SizedBox(width: 4),
                  Text(
                    record.drivingCondition == DrivingCondition.city
                        ? '🏙️'
                        : '🛣️',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          DataCell(Text(vehicleName)),
          DataCell(Text(fuelTypeName)),
          DataCell(Text(record.rate.toStringAsFixed(2))),
          DataCell(Text(record.volume.toStringAsFixed(2))),
          DataCell(Text(record.paidAmount.toStringAsFixed(2))),
          DataCell(_buildMileageCell(interval, localizations, theme)),
          DataCell(Text(overallAverageMileage.toStringAsFixed(2))),
        ],
      ));
    }

    final List<DataRow> allRows = [summaryRow, ...dataRows];

    return InteractiveViewer(
      constrained: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: DataTable(
          showCheckboxColumn: false,
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
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _dateFilter != HistoryDateFilter.all
                  ? 'No records match your filters'
                  : 'No fuel records found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _dateFilter != HistoryDateFilter.all
                  ? 'Try clearing search terms or selecting a broader date range.'
                  : 'Tap "+" to log your first fill-up!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _dateFilter != HistoryDateFilter.all) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Reset Filters'),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _dateFilter = HistoryDateFilter.all;
                    _customDateRange = null;
                    _selectedFuelTypeId = null;
                    _selectedCondition = null;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, HistoryDateFilter target) {
    final isSelected = _dateFilter == target;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _dateFilter = target;
          });
        }
      },
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
    );
  }

  Widget _buildCustomDateChip() {
    final isSelected = _dateFilter == HistoryDateFilter.custom;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ActionChip(
      label: Text(
        _customDateRange != null
            ? '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}'
            : 'Custom Date',
      ),
      avatar: const Icon(Icons.date_range, size: 14),
      onPressed: _pickCustomDateRange,
      visualDensity: VisualDensity.compact,
      backgroundColor: isSelected ? colorScheme.primaryContainer : null,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
    );
  }

  Widget _buildConditionChip(String label, DrivingCondition? target) {
    final isSelected = _selectedCondition == target;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCondition = selected ? target : null;
        });
      },
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
    );
  }
}
