// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/add_vehicle_page.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';

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
    if (records.length < 2) {
      return 0;
    }
    double lastOdometer = records.last.odometer;
    double previousOdometer = records[records.length - 2].odometer;
    double previousVolume = records[records.length - 2].volume;

    if (previousVolume == 0) return 0; // Avoid division by zero

    return (lastOdometer - previousOdometer) / previousVolume;
  }

  double calculateRunningAverage(List<FuelRecord> records) {
    if (records.length < 2) {
      return 0; // Not enough data for running average
    }

    List<double> mileages = [];
    for (int i = 1; i < records.length; i++) {
      double diff = records[i].odometer - records[i - 1].odometer;
      if (records[i - 1].volume > 0) {
        double mileage = diff / records[i - 1].volume;
        mileages.add(mileage);
      }
    }

    if (mileages.isEmpty) {
      return 0;
    }

    double totalMileage = mileages.reduce((a, b) => a + b);
    return totalMileage / mileages.length;
  }

  double calculateCostPerKm(List<FuelRecord> records) {
    if (records.isEmpty) {
      return 0;
    }

    double totalCost = records.map((r) => r.paidAmount).reduce((a, b) => a + b);
    double totalDistance = records.last.odometer - records.first.odometer;

    if (totalDistance <= 0) {
      return 0;
    }

    return totalCost / totalDistance;
  }

  double calculateDailyAverageRun(List<FuelRecord> records) {
    if (records.length < 2) {
      return 0;
    }
    double totalDistance = records.last.odometer - records.first.odometer;
    int days = records.last.date.difference(records.first.date).inDays;
    if (days == 0) {
      return totalDistance;
    }
    return totalDistance / days;
  }

  double calculateDailyAverageCost(List<FuelRecord> records) {
    if (records.isEmpty) {
      return 0;
    }
    double totalCost = records.map((r) => r.paidAmount).reduce((a, b) => a + b);
    if (records.length < 2) {
      return totalCost;
    }
    int days = records.last.date.difference(records.first.date).inDays;
    if (days == 0) {
      return totalCost;
    }
    return totalCost / days;
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
                  color: valueColor,
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
                  color: valueColor,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appTitle),
        actions: [
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
                        const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const AddDataPage()));
                    _loadInitialData();
                  },
                  label: Text(localizations.addFuelData),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
