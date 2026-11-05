// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/add_vehicle_page.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/services/version_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_data_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();
  final VersionService _versionService = VersionService();

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
    _checkForUpdates();
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

  @override
  Widget build(BuildContext context) {
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
                SizedBox(
                  width: double.infinity,
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
}
