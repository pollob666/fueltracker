// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:intl/intl.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/add_vehicle_page.dart';
import 'package:fuel_tracker/pages/maintenance_page.dart';
import 'package:fuel_tracker/pages/analytics_page.dart';
import 'package:fuel_tracker/widgets/add_expense_bottom_sheet.dart';
import 'package:fuel_tracker/services/app_shortcuts_service.dart';
import 'package:fuel_tracker/services/home_widget_service.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/maintenance_calculator.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/services/version_service.dart';
import 'package:fuel_tracker/widgets/anomaly_diagnostic_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_data_page.dart';
import 'settings_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();
  final VersionService _versionService = VersionService();

  List<FuelRecord> _allRecords = [];
  List<FuelRecord> _filteredRecords = [];
  Map<int, FuelType> _fuelTypeMap = {};
  Map<int, Vehicle> _vehicleMap = {};
  List<Vehicle> _vehicles = [];
  int? _selectedVehicleId;
  List<MapEntry<MaintenanceTask, TaskPredictionResult>> _dueMaintenanceTasks = [];
  double? _estimatedServiceCost;
  bool _isAnomalyDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkForUpdates();
    AppShortcutsService.instance.initialize(
      onShortcut: (shortcutType) {
        if (!mounted) return;
        switch (shortcutType) {
          case 'action_add_refuel':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddDataPage()),
            );
            break;
          case 'action_add_service':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MaintenancePage()),
            );
            break;
          case 'action_analytics':
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AnalyticsPage()),
            );
            break;
        }
      },
    );
  }

  Future<void> _checkForUpdates() async {
    if (VersionService.isDismissedForSession) {
      return;
    }
    final isUpdateAvailable = await _versionService.isUpdateAvailable;
    if (isUpdateAvailable) {
      final latestVersion = await _versionService.latestVersion;
      if (latestVersion == null) {
        return;
      }
      final isSkipped = await _versionService.isVersionSkipped(latestVersion);
      if (isSkipped) {
        return;
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n?.updateAvailableTitle ?? 'Update Available'),
            content: Text(
              l10n?.updateAvailableMessage(latestVersion) ??
                  'Update available: $latestVersion',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _versionService.skipVersion(latestVersion);
                  _versionService.dismissForSession();
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text(l10n?.skipVersionButton ?? 'Skip this version'),
              ),
              TextButton(
                onPressed: () {
                  _versionService.dismissForSession();
                  Navigator.of(dialogContext).pop();
                },
                child: Text(l10n?.laterButton ?? 'Later'),
              ),
              FilledButton(
                onPressed: () {
                  _versionService.dismissForSession();
                  Navigator.of(dialogContext).pop();
                  launchUrl(Uri.parse('https://github.com/pollob666/fueltracker/releases/latest'));
                },
                child: Text(l10n?.updateButton ?? 'Update'),
              ),
            ],
          ),
        ).then((_) {
          _versionService.dismissForSession();
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    var recs = await DatabaseHelper.instance.getFuelRecords();
    var fuelTypes = await _fuelTypeService.getFuelTypes();
    var vehicles = await _vehicleService.getVehicles();
    var defaultVehicleId = await _vehicleService.getDefaultVehicle();

    recs.sort((a, b) => a.date.compareTo(b.date));

    if (mounted) {
      setState(() {
        _allRecords = recs;
        _fuelTypeMap = {for (var ft in fuelTypes) ft.id!: ft};
        _vehicles = vehicles;
        _vehicleMap = {for (var v in vehicles) v.id!: v};

        if (vehicles.isNotEmpty) {
          _selectedVehicleId = defaultVehicleId ?? vehicles.first.id;
          _filterRecords();
        } else {
          _filteredRecords = [];
        }
      });
    }
  }

  void _filterRecords() {
    if (_selectedVehicleId == null) {
      setState(() {
        _filteredRecords = [];
      });
      return;
    }
    setState(() {
      _filteredRecords = _allRecords.where((r) => r.vehicleId == _selectedVehicleId).toList();
    });

    final vehicle = _vehicleMap[_selectedVehicleId];
    if (vehicle != null) {
      HomeWidgetService.updateGlanceWidget(
        vehicle: vehicle,
        fuelRecords: _filteredRecords,
      );
      if (vehicle.volumeReminderEnabled || vehicle.distanceReminderEnabled) {
        final prediction = MileageCalculator.calculateRefuelPrediction(
          vehicle: vehicle,
          records: _filteredRecords,
        );
        NotificationService.instance.scheduleRefuelReminder(
          vehicle: vehicle,
          prediction: prediction,
        );
      }
      _checkMaintenanceStatus(vehicle);
    }
  }

  Future<void> _checkMaintenanceStatus(Vehicle vehicle) async {
    if (vehicle.id == null) return;
    final tasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicle.id!);
    final estCost = await DatabaseHelper.instance.getEstimatedServiceCost(vehicle.id!);
    double maxOdo = 0.0;
    if (_filteredRecords.isNotEmpty) {
      maxOdo = _filteredRecords.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
    }
    final dailyAvg = MileageCalculator.calculateDailyAverageRun(_filteredRecords);
    final rate = dailyAvg > 0 ? dailyAvg : 20.0;

    final List<MapEntry<MaintenanceTask, TaskPredictionResult>> dueItems = [];
    final now = DateTime.now();

    for (final task in tasks) {
      if (!task.isEnabled) continue;
      final pred = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: maxOdo,
        currentDate: now,
        dailyKmRate: rate,
      );
      if (pred.status != MaintenanceStatus.healthy) {
        dueItems.add(MapEntry(task, pred));
      }
    }

    if (mounted) {
      setState(() {
        _dueMaintenanceTasks = dueItems;
        _estimatedServiceCost = estCost;
      });
    }
  }

  Future<void> _quickDoneRefuel(Vehicle vehicle) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.markDone),
        content: const Text('Mark tank as filled to reset reminder countdown?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      double maxOdo = 0.0;
      if (_filteredRecords.isNotEmpty) {
        maxOdo = _filteredRecords.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
      }
      final record = FuelRecord(
        odometer: maxOdo,
        date: DateTime.now(),
        rate: 0.0,
        volume: vehicle.primaryFuelCapacity ?? 10.0,
        paidAmount: 0.0,
        fuelTypeId: vehicle.primaryFuelTypeId,
        vehicleId: vehicle.id!,
        isFullTank: true,
        missedPrevious: false,
        drivingCondition: DrivingCondition.mixed,
      );
      await DatabaseHelper.instance.insertFuelRecord(record);
      _loadInitialData();
    }
  }

  Future<void> _quickDoneMaintenance(MaintenanceTask task, Vehicle vehicle) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.markDone),
        content: Text('Mark "${task.title}" as completed? Next reminder cycle will be scheduled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      double maxOdo = 0.0;
      if (_filteredRecords.isNotEmpty) {
        maxOdo = _filteredRecords.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
      }
      await DatabaseHelper.instance.quickResetMaintenanceTask(
        task.id!,
        maxOdo,
        DateTime.now(),
      );
      final tasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicle.id!);
      final dailyAvg = MileageCalculator.calculateDailyAverageRun(_filteredRecords);
      final rate = dailyAvg > 0 ? dailyAvg : 20.0;
      await NotificationService.instance.scheduleMaintenanceReminders(
        vehicle: vehicle,
        tasks: tasks,
        currentOdo: maxOdo,
        dailyKmRate: rate,
      );
      _checkMaintenanceStatus(vehicle);
    }
  }

  double calculateCurrentRunningMileage(List<FuelRecord> records) {
    return MileageCalculator.calculateLastIntervalMileage(records);
  }

  double calculateRunningAverage(List<FuelRecord> records) {
    return MileageCalculator.calculateWeightedRunningAverage(records);
  }

  double calculateCostPerKm(List<FuelRecord> records) {
    return MileageCalculator.calculateCostPerKm(records);
  }

  double calculateDailyAverageRun(List<FuelRecord> records) {
    return MileageCalculator.calculateDailyAverageRun(records);
  }

  double calculateDailyAverageCost(List<FuelRecord> records) {
    return MileageCalculator.calculateDailyAverageCost(records);
  }

  String _formatRecency(BuildContext context, DateTime recordDate) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return '';
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(recordDate.year, recordDate.month, recordDate.day);
    final diffDays = nowDate.difference(targetDate).inDays;

    if (diffDays <= 0) {
      return l10n.today;
    } else if (diffDays == 1) {
      return l10n.yesterday;
    } else {
      return l10n.daysAgo(diffDays);
    }
  }

  Widget _buildMileageCard(BuildContext context, String title, double value, String unit,
      Color backgroundColor, Color onBackgroundColor, Color valueColor) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(color: onBackgroundColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: onBackgroundColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: theme.textTheme.bodyLarge?.copyWith(color: onBackgroundColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostCard(BuildContext context, String title, double value, String unit,
      Color backgroundColor, Color onBackgroundColor, Color valueColor) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(color: onBackgroundColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: onBackgroundColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unit,
                style: theme.textTheme.bodyLarge?.copyWith(color: onBackgroundColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefuelReminderCard(
    BuildContext context,
    Vehicle vehicle,
    RefuelPredictionResult prediction,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;

    if (!prediction.isCalibrated) {
      return Card(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.hourglass_empty_rounded,
                  size: 32, color: colorScheme.secondary),
              const SizedBox(height: 8),
              Text(
                localizations.refuelReminders,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizations.refuelCalibrationPrompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final bool isAlert = prediction.isAlertActive;
    final cardBgColor = isAlert
        ? colorScheme.errorContainer.withValues(alpha: 0.7)
        : colorScheme.surfaceContainerHighest;
    final cardBorderColor =
        isAlert ? colorScheme.error : colorScheme.outlineVariant;

    return Card(
      elevation: isAlert ? 3.0 : 1.0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cardBorderColor,
          width: isAlert ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isAlert
                          ? Icons.warning_amber_rounded
                          : Icons.local_gas_station_outlined,
                      color: isAlert ? colorScheme.error : colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAlert
                          ? localizations.lowFuelWarning
                          : localizations.refuelReminders,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAlert
                            ? colorScheme.onErrorContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (prediction.daysRemaining != null)
                  Text(
                    localizations.projectedRefuelIn(prediction.daysRemaining!),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isAlert
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (prediction.primaryRemainingFuel != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: isAlert
                            ? colorScheme.surface.withValues(alpha: 0.7)
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: prediction.isVolumeTriggered
                              ? colorScheme.error
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.primaryFuelEstimate(
                              prediction.primaryRemainingFuel!
                                  .toStringAsFixed(1),
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: prediction.isVolumeTriggered
                                  ? colorScheme.error
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prediction.isVolumeTriggered
                                ? '≤ ${prediction.volumeThreshold.toStringAsFixed(1)} L'
                                : '${prediction.primaryFuelPercentage?.toStringAsFixed(0) ?? 0}% Full',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: prediction.isVolumeTriggered
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: prediction.isVolumeTriggered
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (prediction.totalDte != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: isAlert
                            ? colorScheme.surface.withValues(alpha: 0.7)
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: prediction.isDistanceTriggered
                              ? colorScheme.error
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.combinedRangeEstimate(
                              prediction.totalDte!.toStringAsFixed(0),
                            ),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: prediction.isDistanceTriggered
                                  ? colorScheme.error
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prediction.isDistanceTriggered
                                ? '≤ ${prediction.distanceThreshold.toInt()} km'
                                : 'Threshold: ${prediction.distanceThreshold.toInt()} km',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: prediction.isDistanceTriggered
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: prediction.isDistanceTriggered
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (prediction.primaryFuelPercentage ?? 0.0) / 100.0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: isAlert ? colorScheme.error : colorScheme.primary,
                minHeight: 6,
              ),
            ),
            if (isAlert) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      ),
                      icon: const Icon(Icons.local_gas_station, size: 18),
                      label: Text(localizations.doIt),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddDataPage()),
                        );
                        _loadInitialData();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onErrorContainer,
                        side: BorderSide(color: colorScheme.error),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(localizations.markDone),
                      onPressed: () => _quickDoneRefuel(vehicle),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMileageAnomalyCard(
    BuildContext context,
    Vehicle vehicle,
    MileageAnomalyResult anomaly,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDrop = anomaly.isDrop;
    final cardBgColor = isDrop
        ? colorScheme.errorContainer.withValues(alpha: 0.7)
        : Colors.green.shade50;
    final cardBorderColor = isDrop ? colorScheme.error : Colors.green.shade600;
    final accentColor = isDrop ? colorScheme.error : Colors.green.shade700;
    final onCardColor = isDrop ? colorScheme.onErrorContainer : Colors.green.shade900;
    final title = isDrop
        ? 'Mileage Drop Anomaly Detected'
        : 'Mileage Boost Detected';
    final pctStr =
        '${anomaly.percentageChange >= 0 ? '+' : ''}${anomaly.percentageChange.toStringAsFixed(1)}%';

    return Card(
      elevation: 2.0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cardBorderColor,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isDrop ? Icons.warning_amber_rounded : Icons.eco,
                      color: accentColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onCardColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pctStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Latest interval yielded ${anomaly.intervalMileage.toStringAsFixed(1)} km/L vs ${anomaly.runningAverage.toStringAsFixed(1)} km/L rolling avg ($pctStr).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onCardColor.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAnomalyDismissed = true;
                    });
                  },
                  child: Text(
                    'Dismiss',
                    style: TextStyle(color: onCardColor),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(isDrop ? Icons.search : Icons.star, size: 16),
                  label: Text(isDrop ? 'Diagnose & Attribute' : 'Mark Location Green'),
                  onPressed: () {
                    AnomalyDiagnosticDialog.show(
                      context: context,
                      vehicleId: vehicle.id!,
                      anomaly: anomaly,
                      onResolved: () {
                        setState(() {
                          _isAnomalyDismissed = true;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedVehicleId != null) {
      ref.listen(fuelRecordsProvider(_selectedVehicleId!), (previous, next) {
        if (previous != null) {
          _loadInitialData();
        }
      });
    }

    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_vehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.appTitle)),
        drawer: const MyDrawer(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4.0,
              color: theme.colorScheme.surfaceContainerHighest,
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_filled, size: 80, color: theme.colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      localizations.welcomeToFuelTracker,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations.addFirstVehiclePrompt,
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddVehiclePage()),
                        );
                        _loadInitialData();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        textStyle: theme.textTheme.titleLarge,
                      ),
                      child: Text(localizations.addVehicle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final lastRecord = _filteredRecords.isNotEmpty ? _filteredRecords.last : null;
    final fuelTypeName = lastRecord != null
        ? _fuelTypeMap[lastRecord.fuelTypeId]?.name ?? localizations.notAvailable
        : localizations.notAvailable;
    final vehicleName = lastRecord != null
        ? _vehicleMap[lastRecord.vehicleId]?.name ?? localizations.notAvailable
        : localizations.notAvailable;

    List<Widget> mileageCards = [];
    List<Widget> costCards = [];
    final selectedVehicle = _selectedVehicleId != null ? _vehicleMap[_selectedVehicleId] : null;

    RefuelPredictionResult? prediction;
    if (selectedVehicle != null &&
        (selectedVehicle.volumeReminderEnabled ||
            selectedVehicle.distanceReminderEnabled)) {
      prediction = MileageCalculator.calculateRefuelPrediction(
        vehicle: selectedVehicle,
        records: _filteredRecords,
      );
    }
    final anomaly = MileageCalculator.checkMileageAnomaly(_filteredRecords);

    if (selectedVehicle != null) {
      final primaryFuelType = _fuelTypeMap[selectedVehicle.primaryFuelTypeId];
      if (primaryFuelType != null) {
        final records = _filteredRecords.where((r) => r.fuelTypeId == primaryFuelType.id).toList();
        final unit = primaryFuelType.unit == FuelUnit.cubicMeter ? 'km/m³' : 'km/l';
        mileageCards.add(Row(
          children: [
            _buildMileageCard(
                context,
                '${primaryFuelType.name} ${localizations.runningAverageMileage}',
                calculateRunningAverage(records),
                unit,
                colorScheme.primaryContainer,
                colorScheme.onPrimaryContainer,
                colorScheme.primary),
            const SizedBox(width: 16),
            _buildMileageCard(
                context,
                '${primaryFuelType.name} ${localizations.lastTimeMileage}',
                calculateCurrentRunningMileage(records),
                unit,
                colorScheme.secondaryContainer,
                colorScheme.onSecondaryContainer,
                colorScheme.secondary),
          ],
        ));

        final cityMileage = MileageCalculator.calculateConditionAverage(records, DrivingCondition.city);
        final highwayMileage = MileageCalculator.calculateConditionAverage(records, DrivingCondition.highway);

        if (cityMileage > 0 || highwayMileage > 0) {
          mileageCards.add(const SizedBox(height: 8));
          mileageCards.add(Row(
            children: [
              if (cityMileage > 0)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🏙️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.cityMileage,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${cityMileage.toStringAsFixed(1)} $unit',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (cityMileage > 0 && highwayMileage > 0)
                const SizedBox(width: 12),
              if (highwayMileage > 0)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🛣️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.highwayMileage,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${highwayMileage.toStringAsFixed(1)} $unit',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ));
        }

        costCards.add(_buildCostCard(
            context,
            '${primaryFuelType.name} ${localizations.costPerKm}',
            calculateCostPerKm(records),
            'BDT/km',
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
            colorScheme.primary));
      }

      final secondaryFuelType = _fuelTypeMap[selectedVehicle.secondaryFuelTypeId];
      if (secondaryFuelType != null) {
        final records = _filteredRecords.where((r) => r.fuelTypeId == secondaryFuelType.id).toList();
        if (records.isNotEmpty) {
          final unit = secondaryFuelType.unit == FuelUnit.cubicMeter ? 'km/m³' : 'km/l';
          mileageCards.add(const SizedBox(height: 16));
          mileageCards.add(Row(
            children: [
              _buildMileageCard(
                  context,
                  '${secondaryFuelType.name} ${localizations.runningAverageMileage}',
                  calculateRunningAverage(records),
                  unit,
                  colorScheme.tertiaryContainer,
                  colorScheme.onTertiaryContainer,
                  colorScheme.tertiary),
              const SizedBox(width: 16),
              _buildMileageCard(
                  context,
                  '${secondaryFuelType.name} ${localizations.lastTimeMileage}',
                  calculateCurrentRunningMileage(records),
                  unit,
                  colorScheme.errorContainer,
                  colorScheme.onErrorContainer,
                  colorScheme.error),
            ],
          ));

          final secCityMileage = MileageCalculator.calculateConditionAverage(records, DrivingCondition.city);
          final secHighwayMileage = MileageCalculator.calculateConditionAverage(records, DrivingCondition.highway);

          if (secCityMileage > 0 || secHighwayMileage > 0) {
            mileageCards.add(const SizedBox(height: 8));
            mileageCards.add(Row(
              children: [
                if (secCityMileage > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🏙️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.cityMileage,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${secCityMileage.toStringAsFixed(1)} $unit',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (secCityMileage > 0 && secHighwayMileage > 0)
                  const SizedBox(width: 12),
                if (secHighwayMileage > 0)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🛣️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.highwayMileage,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${secHighwayMileage.toStringAsFixed(1)} $unit',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ));
          }

          costCards.add(const SizedBox(width: 16));
          costCards.add(_buildCostCard(
              context,
              '${secondaryFuelType.name} ${localizations.costPerKm}',
              calculateCostPerKm(records),
              'BDT/km',
              colorScheme.tertiaryContainer,
              colorScheme.onTertiaryContainer,
              colorScheme.tertiary));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const AddDataPage()));
              _loadInitialData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(builder: (context) => const AddDataPage()));
                          _loadInitialData();
                        },
                        label: Text(localizations.addFuelData),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    if (_selectedVehicleId != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        onPressed: () {
                          AddExpenseBottomSheet.show(context, vehicleId: _selectedVehicleId!);
                        },
                        label: const Text('Expense'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 1.0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.insights, color: colorScheme.onPrimaryContainer, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visual Analytics & Trends',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Price trends, station efficiency & carbon footprint',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...mileageCards,
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          localizations.dailyAverages,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildCostCard(
                              context,
                              localizations.dailyAverageRun,
                              calculateDailyAverageRun(_filteredRecords),
                              'km/day',
                              colorScheme.secondaryContainer,
                              colorScheme.onSecondaryContainer,
                              colorScheme.secondary,
                            ),
                            const SizedBox(width: 16),
                            _buildCostCard(
                              context,
                              localizations.dailyAverageCost,
                              calculateDailyAverageCost(_filteredRecords),
                              'BDT/day',
                              colorScheme.errorContainer,
                              colorScheme.onErrorContainer,
                              colorScheme.error,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (anomaly != null && anomaly.hasAnomaly && !_isAnomalyDismissed && selectedVehicle != null) ...[
                  _buildMileageAnomalyCard(context, selectedVehicle, anomaly),
                  const SizedBox(height: 24),
                ],
                if (prediction != null && selectedVehicle != null && prediction.isAlertActive) ...[
                  _buildRefuelReminderCard(context, selectedVehicle, prediction),
                  const SizedBox(height: 24),
                ],
                if (_dueMaintenanceTasks.isNotEmpty && selectedVehicle != null) ...[
                  _buildMaintenanceWarningBanner(context, selectedVehicle),
                  const SizedBox(height: 24),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          localizations.costEfficiency,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: costCards,
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          localizations.lastRefuelDetails,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        if (lastRecord != null) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final avgCadence =
                                  MileageCalculator.calculateAverageRefuelCadence(_filteredRecords);
                              final now = DateTime.now();
                              final diffDays = DateTime(now.year, now.month, now.day)
                                  .difference(DateTime(
                                      lastRecord.date.year, lastRecord.date.month, lastRecord.date.day))
                                  .inDays;
                              final isCadenceExceeded =
                                  avgCadence > 0 && diffDays > (avgCadence * 1.5);

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 16, color: colorScheme.secondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat.yMMMd(Localizations.localeOf(context).toString())
                                        .format(lastRecord.date),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCadenceExceeded
                                          ? colorScheme.errorContainer
                                          : colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatRecency(context, lastRecord.date),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: isCadenceExceeded
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.spaceAround,
                          spacing: 16.0,
                          runSpacing: 24.0,
                          children: [
                            _buildInfoTile(
                              context,
                              label: localizations.vehicle,
                              value: vehicleName,
                              icon: Icons.directions_car,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.volume,
                              value:
                                  '${lastRecord != null ? lastRecord.volume.toStringAsFixed(2) : localizations.notAvailable} litres',
                              icon: Icons.local_gas_station,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.totalPrice,
                              value:
                                  '${lastRecord != null ? lastRecord.paidAmount.toStringAsFixed(2) : localizations.notAvailable} BDT',
                              icon: Icons.monetization_on,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.odometer,
                              value:
                                  '${lastRecord != null ? lastRecord.odometer.toStringAsFixed(2) : localizations.notAvailable} km',
                              icon: Icons.speed,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.fuelType,
                              value: fuelTypeName,
                              icon: Icons.opacity,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.fuelRate,
                              value:
                                  '${lastRecord != null ? lastRecord.rate.toStringAsFixed(2) : localizations.notAvailable} BDT/litre',
                              icon: Icons.price_change,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _buildInfoTile(BuildContext context,
      {required String label, required String value, required IconData icon}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Icon(icon, size: 32, color: colorScheme.secondary),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceWarningBanner(BuildContext context, Vehicle vehicle) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasOverdue = _dueMaintenanceTasks.any(
        (e) => e.value.status == MaintenanceStatus.overdue);

    final bgColor = hasOverdue
        ? theme.colorScheme.errorContainer
        : Colors.amber.shade100;
    final fgColor = hasOverdue
        ? theme.colorScheme.onErrorContainer
        : Colors.amber.shade900;
    final borderColor = hasOverdue
        ? theme.colorScheme.error.withValues(alpha: 0.5)
        : Colors.amber.shade600;

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasOverdue ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: fgColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizations.maintenanceWarningTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: fgColor,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MaintenancePage(
                          initialVehicleId: vehicle.id,
                        ),
                      ),
                    ).then((_) => _filterRecords());
                  },
                  child: Text(localizations.viewMaintenance),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.itemsDueOrOverdue(_dueMaintenanceTasks.length),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: fgColor,
                  ),
                ),
                if (_estimatedServiceCost != null && _estimatedServiceCost! > 0)
                  Text(
                    localizations.estimatedCost('~${_estimatedServiceCost!.toStringAsFixed(0)} BDT'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._dueMaintenanceTasks.take(3).map((entry) {
              final task = entry.key;
              final pred = entry.value;
              final isOverdue = pred.status == MaintenanceStatus.overdue;
              final detailText = isOverdue
                  ? (pred.kmRemaining <= 0
                      ? localizations.kmOverdue((-pred.kmRemaining).toStringAsFixed(0))
                      : 'time limit passed')
                  : localizations.kmRemaining(pred.kmRemaining.toStringAsFixed(0));

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: borderColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isOverdue ? Icons.error_outline : Icons.warning_amber_rounded,
                          size: 16,
                          color: fgColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: fgColor,
                            ),
                          ),
                        ),
                        Text(
                          detailText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: fgColor,
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: fgColor,
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                            icon: const Icon(Icons.check, size: 14),
                            label: Text(localizations.markDone, style: const TextStyle(fontSize: 12)),
                            onPressed: () => _quickDoneMaintenance(task, vehicle),
                          ),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.surface,
                              foregroundColor: fgColor,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                            icon: const Icon(Icons.build_outlined, size: 14),
                            label: Text(localizations.doIt, style: const TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MaintenancePage(
                                    initialVehicleId: vehicle.id,
                                    openLogForTaskId: task.id,
                                  ),
                                ),
                              ).then((_) => _filterRecords());
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
