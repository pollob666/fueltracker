// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/utils/unit_converter.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';

class AddVehiclePage extends StatefulWidget {
  final Vehicle? vehicle;

  const AddVehiclePage({super.key, this.vehicle});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final FuelTypeService _fuelTypeService = FuelTypeService();

  String _name = '';
  VehicleType _vehicleType = VehicleType.carOrSedan;
  int? _primaryFuelTypeId;
  double? _primaryFuelCapacity;
  int? _secondaryFuelTypeId;
  double? _secondaryFuelCapacity;
  TripMeterMode _tripMeterMode = TripMeterMode.none;
  bool _isDualFuel = false;
  bool _volumeReminderEnabled = false;
  double _volumeReminderValue = 3.0;
  bool _distanceReminderEnabled = false;
  double _distanceReminderValue = 50.0;

  // Tier 3: Powertrain & International Preferences
  PowertrainType _powertrainType = PowertrainType.ice;
  double? _batteryCapacityKwh;
  DistanceUnit _distanceUnit = DistanceUnit.km;
  FuelVolumeUnit _fuelVolumeUnit = FuelVolumeUnit.litre;
  ConsumptionUnit _consumptionUnit = ConsumptionUnit.kmPerLitre;
  String _baseCurrency = 'BDT';

  List<FuelType> _fuelTypes = [];
  List<MaintenanceTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _name = widget.vehicle!.name;
      _vehicleType = widget.vehicle!.type;
      _primaryFuelTypeId = widget.vehicle!.primaryFuelTypeId;
      _primaryFuelCapacity = widget.vehicle!.primaryFuelCapacity;
      _secondaryFuelTypeId = widget.vehicle!.secondaryFuelTypeId;
      _secondaryFuelCapacity = widget.vehicle!.secondaryFuelCapacity;
      _tripMeterMode = widget.vehicle!.tripMeterMode;
      _isDualFuel = widget.vehicle!.isDualFuel;
      _volumeReminderEnabled = widget.vehicle!.volumeReminderEnabled;
      _volumeReminderValue = widget.vehicle!.volumeReminderValue;
      _distanceReminderEnabled = widget.vehicle!.distanceReminderEnabled;
      _distanceReminderValue = widget.vehicle!.distanceReminderValue;
      _powertrainType = widget.vehicle!.powertrainType;
      _batteryCapacityKwh = widget.vehicle!.batteryCapacityKwh;
      _distanceUnit = widget.vehicle!.distanceUnit;
      _fuelVolumeUnit = widget.vehicle!.fuelVolumeUnit;
      _consumptionUnit = widget.vehicle!.consumptionUnit;
      _baseCurrency = widget.vehicle!.baseCurrency;
      _loadTasks(widget.vehicle!.id!);
    } else {
      _distanceUnit = DistanceUnit.fromString(AppSettings.defaultDistanceUnit);
      _fuelVolumeUnit = FuelVolumeUnit.fromString(AppSettings.defaultFuelVolumeUnit);
      _consumptionUnit = ConsumptionUnit.fromString(AppSettings.defaultConsumptionUnit);
      _baseCurrency = AppSettings.defaultBaseCurrency;
      _initDefaultTasks();
    }
    _loadFuelTypes();
  }

  void _initDefaultTasks() {
    _tasks = [
      MaintenanceTask(
        vehicleId: 0,
        taskKey: 'engine_oil',
        title: 'Engine Oil Change',
        intervalKm: 3000.0,
        intervalMonths: 3,
        lastServiceOdo: 0.0,
        lastServiceDate: DateTime.now(),
        reminderBufferKm: 100.0,
        isEnabled: false,
      ),
      MaintenanceTask(
        vehicleId: 0,
        taskKey: 'oil_filter',
        title: 'Engine Oil Filter',
        intervalKm: 6000.0,
        intervalMonths: 6,
        lastServiceOdo: 0.0,
        lastServiceDate: DateTime.now(),
        reminderBufferKm: 100.0,
        isEnabled: false,
      ),
      MaintenanceTask(
        vehicleId: 0,
        taskKey: 'air_filter',
        title: 'Air Filter Clean / Replace',
        intervalKm: 4000.0,
        intervalMonths: 6,
        lastServiceOdo: 0.0,
        lastServiceDate: DateTime.now(),
        reminderBufferKm: 100.0,
        isEnabled: false,
      ),
      MaintenanceTask(
        vehicleId: 0,
        taskKey: 'general_servicing',
        title: 'General Servicing',
        intervalKm: 5000.0,
        intervalMonths: 6,
        lastServiceOdo: 0.0,
        lastServiceDate: DateTime.now(),
        reminderBufferKm: 150.0,
        isEnabled: false,
      ),
    ];
  }

  Future<void> _loadTasks(int vehicleId) async {
    final tasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicleId);
    if (mounted) {
      setState(() {
        if (tasks.isNotEmpty) {
          _tasks = tasks;
        } else {
          _initDefaultTasks();
        }
      });
    }
  }

  String _getTaskLocalizedTitle(BuildContext context, MaintenanceTask task) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return task.title;
    switch (task.taskKey) {
      case 'engine_oil':
        return l10n.engineOilChange;
      case 'oil_filter':
        return l10n.oilFilterReplacement;
      case 'air_filter':
        return l10n.airFilterClean;
      case 'general_servicing':
        return l10n.generalServicing;
      default:
        return task.title;
    }
  }

  Future<void> _openAddCustomTaskDialog() async {
    final localizations = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    final kmController = TextEditingController(text: '5000');
    final monthsController = TextEditingController(text: '6');
    final bufferController = TextEditingController(text: '100');

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.addCustomTask),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: localizations.taskTitle,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kmController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: localizations.intervalKm,
                  suffixText: 'km',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: monthsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: localizations.intervalMonths,
                  suffixText: 'months',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bufferController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: localizations.reminderBuffer,
                  suffixText: 'km',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  double.tryParse(kmController.text) != null) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(localizations.save),
          ),
        ],
      ),
    );

    if (added == true && mounted) {
      setState(() {
        _tasks.add(MaintenanceTask(
          vehicleId: widget.vehicle?.id ?? 0,
          title: titleController.text.trim(),
          intervalKm: double.tryParse(kmController.text) ?? 5000.0,
          intervalMonths: int.tryParse(monthsController.text),
          lastServiceOdo: 0.0,
          lastServiceDate: DateTime.now(),
          reminderBufferKm: double.tryParse(bufferController.text) ?? 100.0,
          isEnabled: true,
        ));
      });
    }
  }

  Future<void> _loadFuelTypes() async {
    final fuelTypes = await _fuelTypeService.getFuelTypes();
    if (mounted) {
      setState(() {
        _fuelTypes = fuelTypes;
        if (widget.vehicle == null && _fuelTypes.isNotEmpty) {
          _primaryFuelTypeId = _fuelTypes.first.id;
        }
      });
    }
  }

  String _getVehicleTypeLocalization(BuildContext context, VehicleType type) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return type.toString().split('.').last;
    }
    switch (type) {
      case VehicleType.carOrSedan:
        return localizations.carOrSedan;
      case VehicleType.motorcycle:
        return localizations.motorcycle;
      case VehicleType.scooterOrMoped:
        return localizations.scooterOrMoped;
      case VehicleType.suv:
        return localizations.suv;
      case VehicleType.pickupOrTruck:
        return localizations.pickupOrTruck;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (localizations == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.vehicle == null
              ? localizations.addVehicle
              : localizations.editVehicle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
              children: [
                if (widget.vehicle == null)
                  Card(
                    elevation: 4.0,
                    color: theme.colorScheme.surfaceContainerHighest,
                    margin: const EdgeInsets.symmetric(vertical: 20.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_filled, size: 80, color: theme.colorScheme.primary),
                          const SizedBox(height: 24),
                          Text(
                            localizations.welcomeToFuelTracker,
                            style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            localizations.addFirstVehiclePrompt,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(labelText: localizations.vehicleName),
                  onSaved: (value) => _name = value!,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                DropdownButtonFormField<VehicleType>(
                  initialValue: _vehicleType,
                  items: VehicleType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_getVehicleTypeLocalization(context, type)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _vehicleType = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: localizations.vehicleType),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Powertrain & Motor',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PowertrainType>(
                  value: _powertrainType,
                  decoration: const InputDecoration(labelText: 'Powertrain Type'),
                  items: PowertrainType.values.map((pt) => DropdownMenuItem(
                    value: pt,
                    child: Text('${pt.code} - ${pt.label}'),
                  )).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _powertrainType = val;
                      if (_powertrainType == PowertrainType.bev) {
                        _isDualFuel = false;
                        _consumptionUnit = ConsumptionUnit.kmPerKwh;
                        _fuelVolumeUnit = FuelVolumeUnit.kwh;
                        final elec = _fuelTypes.where((ft) => ft.category == FuelCategory.electricity).firstOrNull;
                        if (elec != null) _primaryFuelTypeId = elec.id;
                      } else if (_powertrainType == PowertrainType.ice) {
                        if (_consumptionUnit == ConsumptionUnit.kmPerKwh || _consumptionUnit == ConsumptionUnit.kwhPer100Km) {
                          _consumptionUnit = ConsumptionUnit.kmPerLitre;
                          _fuelVolumeUnit = FuelVolumeUnit.litre;
                        }
                      }
                    });
                  },
                ),
                if (_powertrainType == PowertrainType.bev || _powertrainType == PowertrainType.phev) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _batteryCapacityKwh?.toString(),
                    decoration: const InputDecoration(labelText: 'Battery Capacity (kWh)', suffixText: 'kWh'),
                    keyboardType: TextInputType.number,
                    onSaved: (val) => _batteryCapacityKwh = val == null || val.isEmpty ? null : double.tryParse(val),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.supportedFuelTypes,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.local_gas_station_outlined),
                        label: Text(localizations.singleFuel),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.electric_bolt_outlined),
                        label: Text(localizations.dualFuel),
                      ),
                    ],
                    selected: {_isDualFuel},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _isDualFuel = newSelection.first;
                        if (!_isDualFuel) {
                          _secondaryFuelTypeId = null;
                          _secondaryFuelCapacity = null;
                        } else if (_secondaryFuelTypeId == null && _fuelTypes.length > 1) {
                          _secondaryFuelTypeId = _fuelTypes.firstWhere(
                            (ft) => ft.id != _primaryFuelTypeId,
                            orElse: () => _fuelTypes.last,
                          ).id;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _primaryFuelTypeId,
                  items: _fuelTypes
                      .map((fuel) => DropdownMenuItem(
                            value: fuel.id,
                            child: Text(fuel.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _primaryFuelTypeId = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: localizations.primaryFuelType),
                ),
                TextFormField(
                  initialValue: _primaryFuelCapacity?.toString(),
                  decoration: InputDecoration(labelText: localizations.primaryFuelCapacity),
                  keyboardType: TextInputType.number,
                  onSaved: (value) =>
                      _primaryFuelCapacity = value!.isEmpty ? null : double.tryParse(value),
                ),
                if (_isDualFuel) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _secondaryFuelTypeId,
                    items: _fuelTypes
                        .map((fuel) => DropdownMenuItem(
                              value: fuel.id,
                              child: Text(fuel.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _secondaryFuelTypeId = value;
                      });
                    },
                    decoration: InputDecoration(labelText: localizations.secondaryFuelType),
                  ),
                  TextFormField(
                    initialValue: _secondaryFuelCapacity?.toString(),
                    decoration: InputDecoration(labelText: localizations.secondaryFuelCapacity),
                    keyboardType: TextInputType.number,
                    onSaved: (value) =>
                        _secondaryFuelCapacity = value!.isEmpty ? null : double.tryParse(value),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.tripMeterMode,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.tripMeterModeSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<TripMeterMode>(
                    segments: [
                      ButtonSegment(
                        value: TripMeterMode.none,
                        icon: const Icon(Icons.block),
                        label: Text(localizations.tripModeNone),
                      ),
                      ButtonSegment(
                        value: TripMeterMode.single,
                        icon: const Icon(Icons.looks_one_outlined),
                        label: Text(localizations.tripModeSingle),
                      ),
                      ButtonSegment(
                        value: TripMeterMode.dual,
                        icon: const Icon(Icons.looks_two_outlined),
                        label: Text(localizations.tripModeDual),
                      ),
                    ],
                    selected: {_tripMeterMode},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _tripMeterMode = newSelection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ExpansionTile(
                    title: const Text('Units & Base Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${_distanceUnit.symbol} • ${_consumptionUnit.symbol} • $_baseCurrency',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      DropdownButtonFormField<DistanceUnit>(
                        value: _distanceUnit,
                        decoration: const InputDecoration(labelText: 'Distance Unit'),
                        items: DistanceUnit.values.map((u) => DropdownMenuItem(
                          value: u,
                          child: Text('${u.label} (${u.symbol})'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _distanceUnit = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ConsumptionUnit>(
                        value: _consumptionUnit,
                        decoration: const InputDecoration(labelText: 'Efficiency / Consumption Metric'),
                        items: ConsumptionUnit.values.map((u) => DropdownMenuItem(
                          value: u,
                          child: Text('${u.label} (${u.symbol})'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _consumptionUnit = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<FuelVolumeUnit>(
                        value: _fuelVolumeUnit,
                        decoration: const InputDecoration(labelText: 'Fuel Volume Unit'),
                        items: FuelVolumeUnit.values.map((u) => DropdownMenuItem(
                          value: u,
                          child: Text('${u.label} (${u.symbol})'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _fuelVolumeUnit = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _baseCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Base Currency Code',
                          hintText: 'e.g. BDT, USD, EUR, GBP, INR, CAD',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (val) => _baseCurrency = val,
                        onSaved: (val) => _baseCurrency = (val == null || val.trim().isEmpty) ? 'BDT' : val.trim().toUpperCase(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    localizations.refuelReminders,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(localizations.volumeReminderTitle, style: theme.textTheme.titleSmall),
                          subtitle: Text(localizations.volumeReminderSubtitle),
                          value: _volumeReminderEnabled,
                          onChanged: (val) {
                            setState(() {
                              _volumeReminderEnabled = val;
                            });
                          },
                        ),
                        if (_volumeReminderEnabled) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final double maxCap = _primaryFuelCapacity ?? 50.0;
                              final double effectiveMax = maxCap > 0.8 ? maxCap : 50.0;
                              final double clampedVal = _volumeReminderValue.clamp(0.8, effectiveMax);
                              final double pct = (clampedVal / effectiveMax) * 100.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        localizations.volumeThresholdLabel,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      Text(
                                        '${clampedVal.toStringAsFixed(1)} L (${pct.toStringAsFixed(1)}%)',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: clampedVal,
                                    min: 0.8,
                                    max: effectiveMax,
                                    divisions: ((effectiveMax - 0.8) * 10).toInt().clamp(1, 200),
                                    onChanged: (val) {
                                      setState(() {
                                        _volumeReminderValue = double.parse(val.toStringAsFixed(1));
                                      });
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(localizations.distanceReminderTitle, style: theme.textTheme.titleSmall),
                          subtitle: Text(localizations.distanceReminderSubtitle),
                          value: _distanceReminderEnabled,
                          onChanged: (val) {
                            setState(() {
                              _distanceReminderEnabled = val;
                            });
                          },
                        ),
                        if (_distanceReminderEnabled) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                localizations.distanceThresholdLabel,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '${_distanceReminderValue.toInt()} km',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _distanceReminderValue.clamp(15.0, 200.0),
                            min: 15.0,
                            max: 200.0,
                            divisions: 37,
                            onChanged: (val) {
                              setState(() {
                                _distanceReminderValue = val.roundToDouble();
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                localizations.maintenanceReminders,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(localizations.addCustomTask),
                              onPressed: _openAddCustomTaskDialog,
                            ),
                          ],
                        ),
                        Text(
                          localizations.enableMaintenanceRemindersSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._tasks.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          return Card(
                            elevation: 0,
                            color: theme.colorScheme.surface,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: task.isEnabled
                                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                    : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(
                                            _getTaskLocalizedTitle(context, task),
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${task.intervalKm.toStringAsFixed(0)} km${task.intervalMonths != null ? " • ${task.intervalMonths} mos" : ""}',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          value: task.isEnabled,
                                          onChanged: (val) {
                                            setState(() {
                                              task.isEnabled = val;
                                            });
                                          },
                                        ),
                                      ),
                                      if (task.taskKey == null)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          color: theme.colorScheme.error,
                                          onPressed: () {
                                            setState(() {
                                              _tasks.removeAt(index);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                  if (task.isEnabled) ...[
                                    const Divider(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: TextFormField(
                                            initialValue: task.intervalKm.toStringAsFixed(0),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: localizations.intervalKm,
                                              suffixText: 'km',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              final d = double.tryParse(val);
                                              if (d != null && d > 0) {
                                                task.intervalKm = d;
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            initialValue: task.intervalMonths?.toString() ?? '',
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: localizations.intervalMonths,
                                              suffixText: 'm',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              task.intervalMonths = int.tryParse(val);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            initialValue: task.reminderBufferKm.toStringAsFixed(0),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: localizations.reminderBuffer,
                                              suffixText: 'km',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              final d = double.tryParse(val);
                                              if (d != null && d >= 0) {
                                                task.reminderBufferKm = d;
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submitVehicle,
                  child: Text(
                    localizations.save,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            if (AppSettings.adsEnabled) const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Future<void> _submitVehicle() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please correct the errors in the form.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    final vehicle = Vehicle(
      id: widget.vehicle?.id,
      name: _name,
      type: _vehicleType,
      primaryFuelTypeId: _primaryFuelTypeId!,
      primaryFuelCapacity: _primaryFuelCapacity,
      secondaryFuelTypeId: _isDualFuel ? _secondaryFuelTypeId : null,
      secondaryFuelCapacity: _isDualFuel ? _secondaryFuelCapacity : null,
      tripMeterMode: _tripMeterMode,
      volumeReminderEnabled: _volumeReminderEnabled,
      volumeReminderValue: _volumeReminderValue,
      distanceReminderEnabled: _distanceReminderEnabled,
      distanceReminderValue: _distanceReminderValue,
      powertrainType: _powertrainType,
      batteryCapacityKwh: _batteryCapacityKwh,
      distanceUnit: _distanceUnit,
      fuelVolumeUnit: _fuelVolumeUnit,
      consumptionUnit: _consumptionUnit,
      baseCurrency: _baseCurrency.trim().isEmpty ? 'BDT' : _baseCurrency.trim().toUpperCase(),
    );
    final navigator = Navigator.of(context);
    if (widget.vehicle == null) {
      final id = await DatabaseHelper.instance.insertVehicle(vehicle);
      vehicle.id = id;
      final seededTasks = await DatabaseHelper.instance.getMaintenanceTasks(id);
      for (final userTask in _tasks) {
        if (userTask.taskKey != null) {
          final match = seededTasks.firstWhere((t) => t.taskKey == userTask.taskKey, orElse: () => userTask);
          if (match.id != null) {
            await DatabaseHelper.instance.updateMaintenanceTask(
              userTask.copyWith(id: match.id, vehicleId: id),
            );
          }
        } else {
          await DatabaseHelper.instance.insertMaintenanceTask(userTask.copyWith(vehicleId: id));
        }
      }
    } else {
      await DatabaseHelper.instance.updateVehicle(vehicle);
      for (final userTask in _tasks) {
        if (userTask.id != null) {
          await DatabaseHelper.instance.updateMaintenanceTask(userTask);
        } else {
          await DatabaseHelper.instance.insertMaintenanceTask(userTask.copyWith(vehicleId: vehicle.id!));
        }
      }
    }

    final allRecords = await DatabaseHelper.instance.getFuelRecords();
    final vehicleRecords =
        allRecords.where((r) => r.vehicleId == vehicle.id).toList();
    final prediction = MileageCalculator.calculateRefuelPrediction(
      vehicle: vehicle,
      records: vehicleRecords,
    );
    await NotificationService.instance.scheduleRefuelReminder(
      vehicle: vehicle,
      prediction: prediction,
    );

    double maxOdo = 0.0;
    if (vehicleRecords.isNotEmpty) {
      maxOdo = vehicleRecords.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
    }
    final dailyAvg = MileageCalculator.calculateDailyAverageRun(vehicleRecords);
    final double rate = (dailyAvg > 0) ? dailyAvg : 20.0;
    final updatedTasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicle.id!);
    await NotificationService.instance.scheduleMaintenanceReminders(
      vehicle: vehicle,
      tasks: updatedTasks,
      currentOdo: maxOdo,
      dailyKmRate: rate,
    );

    if (mounted) {
      navigator.pop();
    }
  }
}
