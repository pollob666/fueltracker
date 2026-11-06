// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/services/interstitial_ad_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/location_picker_field.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDataPage extends StatefulWidget {
  final FuelRecord? recordToEdit;

  const AddDataPage({super.key, this.recordToEdit});

  @override
  State<AddDataPage> createState() => _AddDataPageState();
}

class _AddDataPageState extends State<AddDataPage> {
  final _formKey = GlobalKey<FormState>();
  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();
  final InterstitialAdService _interstitialAdService = InterstitialAdService();

  bool get _isEditing => widget.recordToEdit != null;

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _tripDistanceController = TextEditingController();
  final TextEditingController _secondaryTripDistanceController = TextEditingController();
  DrivingCondition _drivingCondition = DrivingCondition.mixed;
  double? _previousOdometer;
  int? _selectedVehicleId;
  int? _selectedFuelTypeId;
  List<Vehicle> _vehicles = [];
  List<FuelType> _allFuelTypes = [];
  List<FuelType> _availableFuelTypes = [];

  final TextEditingController _rateController = TextEditingController();
  double _volume = 0;
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  bool _isUpdating = false;
  bool _isFullTank = true;
  bool _missedPrevious = false;
  SavedLocation? _selectedLocation;
  Position? _capturedPosition;

  Vehicle? get _selectedVehicle {
    if (_selectedVehicleId == null || _vehicles.isEmpty) return null;
    try {
      return _vehicles.firstWhere((v) => v.id == _selectedVehicleId);
    } catch (_) {
      return null;
    }
  }

  bool get _isBiFuelVehicle => _selectedVehicle?.secondaryFuelTypeId != null;
  bool get _hasTripMeter =>
      (_selectedVehicle?.tripMeterMode != null &&
          _selectedVehicle!.tripMeterMode != TripMeterMode.none) ||
      _isBiFuelVehicle;
  bool get _hasDualTrip =>
      _selectedVehicle?.tripMeterMode == TripMeterMode.dual;

  @override
  void initState() {
    super.initState();
    if (AppSettings.adsEnabled && !_isEditing) {
      _interstitialAdService.loadAd();
    }
    if (_isEditing) {
      final rec = widget.recordToEdit!;
      _selectedDate = rec.date;
      _odometerController.text = rec.odometer.toStringAsFixed(2);
      if (rec.tripDistance != null) {
        _tripDistanceController.text = rec.tripDistance!.toStringAsFixed(2);
      }
      if (rec.secondaryTripDistance != null) {
        _secondaryTripDistanceController.text =
            rec.secondaryTripDistance!.toStringAsFixed(2);
      }
      _drivingCondition = rec.drivingCondition;
      _rateController.text = rec.rate.toStringAsFixed(2);
      _volume = rec.volume;
      _volumeController.text = rec.volume.toStringAsFixed(2);
      _paidAmountController.text = rec.paidAmount.toStringAsFixed(2);
      _isFullTank = rec.isFullTank;
      _missedPrevious = rec.missedPrevious;
      _selectedVehicleId = rec.vehicleId;
      _selectedFuelTypeId = rec.fuelTypeId;
      if (rec.locationId != null) {
        DatabaseHelper.instance.getSavedLocationById(rec.locationId!).then((loc) {
          if (mounted) setState(() => _selectedLocation = loc);
        });
      }
    } else {
      _loadLastValues();
      _volumeController.text = _volume.toStringAsFixed(2);
    }

    _rateController.addListener(_onRateOrPaidAmountChanged);
    _paidAmountController.addListener(_onRateOrPaidAmountChanged);
    _volumeController.addListener(_onVolumeChanged);
    _odometerController.addListener(_onOdoOrTripChanged);
    _tripDistanceController.addListener(_onOdoOrTripChanged);

    _loadInitialData();
  }

  Widget? _buildDiscrepancyChip(BuildContext context) {
    if (_previousOdometer == null) return null;
    final enteredOdo = double.tryParse(_odometerController.text);
    final enteredTrip = double.tryParse(_tripDistanceController.text);
    if (enteredOdo == null || enteredTrip == null) return null;
    if (enteredOdo <= _previousOdometer!) return null;

    final deltaOdo = enteredOdo - _previousOdometer!;
    final diff = (deltaOdo - enteredTrip).abs();
    if (diff > 1.0) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: ActionChip(
          avatar: Icon(Icons.warning_amber_rounded,
              size: 18, color: theme.colorScheme.error),
          backgroundColor:
              theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          label: Text(
            AppLocalizations.of(context)!.odometerTripMismatch(
              deltaOdo.toStringAsFixed(1),
              enteredTrip.toStringAsFixed(1),
            ),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          onPressed: () {
            final syncedOdo = _previousOdometer! + enteredTrip;
            _odometerController.text = syncedOdo.toStringAsFixed(2);
          },
        ),
      );
    }
    return null;
  }

  void _onOdoOrTripChanged() {
    setState(() {});
  }

  Future<void> _updatePreviousOdometer() async {
    if (_selectedVehicleId == null) return;
    final allRecords = await DatabaseHelper.instance.getFuelRecords();
    final vehicleRecords = allRecords
        .where((r) =>
            r.vehicleId == _selectedVehicleId &&
            (!_isEditing || r.id != widget.recordToEdit!.id))
        .toList();
    if (vehicleRecords.isNotEmpty) {
      vehicleRecords.sort((a, b) => a.date.compareTo(b.date));
      if (mounted) {
        setState(() {
          _previousOdometer = vehicleRecords.last.odometer;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _previousOdometer = null;
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    final vehicles = await _vehicleService.getVehicles();
    final allFuelTypes = await _fuelTypeService.getFuelTypes();
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        _allFuelTypes = allFuelTypes;
        if (!_isEditing && _vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first.id;
          _updateAvailableFuelTypes();
        } else if (_isEditing) {
          _updateAvailableFuelTypes(preserveSelectedFuelType: true);
        }
      });
      _updatePreviousOdometer();
    }
  }

  void _updateAvailableFuelTypes({bool preserveSelectedFuelType = false}) {
    if (_selectedVehicleId == null || _vehicles.isEmpty) return;

    final selectedVehicle =
        _vehicles.firstWhere((v) => v.id == _selectedVehicleId);
    final availableFuelTypes = <FuelType>{};

    final primaryFuelType = _allFuelTypes
        .firstWhere((ft) => ft.id == selectedVehicle.primaryFuelTypeId);
    if (primaryFuelType.category == FuelCategory.gasoline) {
      availableFuelTypes.addAll(
          _allFuelTypes.where((ft) => ft.category == FuelCategory.gasoline));
    } else {
      availableFuelTypes.add(primaryFuelType);
    }

    if (selectedVehicle.secondaryFuelTypeId != null) {
      final secondaryFuelType = _allFuelTypes.firstWhere(
          (ft) => ft.id == selectedVehicle.secondaryFuelTypeId);
      if (secondaryFuelType.category == FuelCategory.gasoline) {
        availableFuelTypes.addAll(
            _allFuelTypes.where((ft) => ft.category == FuelCategory.gasoline));
      } else {
        availableFuelTypes.add(secondaryFuelType);
      }
    }

    setState(() {
      _availableFuelTypes = availableFuelTypes.toList();
      if (_availableFuelTypes.isNotEmpty) {
        if (!preserveSelectedFuelType ||
            _selectedFuelTypeId == null ||
            !_availableFuelTypes.any((ft) => ft.id == _selectedFuelTypeId)) {
          _selectedFuelTypeId = _availableFuelTypes.first.id;
          final fuelName = _availableFuelTypes.first.name;
          _rateController.text =
              AppSettings.defaultFuelPrices[fuelName]?.toString() ?? '';
        }
      }
    });
  }

  void _onRateOrPaidAmountChanged() {
    if (_isUpdating) return;
    final double? rate = double.tryParse(_rateController.text);
    final double? paidAmount = double.tryParse(_paidAmountController.text);

    if (rate != null && rate > 0 && paidAmount != null && paidAmount > 0) {
      _isUpdating = true;
      _volume = paidAmount / rate;
      _volumeController.text = _volume.toStringAsFixed(2);
      _isUpdating = false;
      setState(() {});
    }
  }

  void _onVolumeChanged() {
    if (_isUpdating) return;
    final double? vol = double.tryParse(_volumeController.text);
    final double? rate = double.tryParse(_rateController.text);

    if (vol != null && vol >= 0) {
      _volume = vol;
      if (rate != null && rate > 0) {
        _isUpdating = true;
        _paidAmountController.text = (vol * rate).toStringAsFixed(2);
        _isUpdating = false;
      }
      setState(() {});
    }
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _rateController.text = prefs.getString('last_fuel_price') ?? '';
      });
    }
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_fuel_price', _rateController.text);
  }

  Future<void> _rescheduleReminderForVehicle(int vehicleId) async {
    final vehicles = await _vehicleService.getVehicles();
    final vehicle = vehicles.where((v) => v.id == vehicleId).firstOrNull;
    if (vehicle != null) {
      final allRecords = await DatabaseHelper.instance.getFuelRecords();
      final vehicleRecords =
          allRecords.where((r) => r.vehicleId == vehicleId).toList();
      final prediction = MileageCalculator.calculateRefuelPrediction(
        vehicle: vehicle,
        records: vehicleRecords,
      );
      await NotificationService.instance.scheduleRefuelReminder(
        vehicle: vehicle,
        prediction: prediction,
      );

      final tasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicleId);
      double maxOdo = 0.0;
      if (vehicleRecords.isNotEmpty) {
        maxOdo = vehicleRecords.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
      }
      final dailyAvg = MileageCalculator.calculateDailyAverageRun(vehicleRecords);
      final rate = dailyAvg > 0 ? dailyAvg : 20.0;
      await NotificationService.instance.scheduleMaintenanceReminders(
        vehicle: vehicle,
        tasks: tasks,
        currentOdo: maxOdo,
        dailyKmRate: rate,
      );
    }
  }

  @override
  void dispose() {
    _rateController.removeListener(_onRateOrPaidAmountChanged);
    _paidAmountController.removeListener(_onRateOrPaidAmountChanged);
    _volumeController.removeListener(_onVolumeChanged);
    _odometerController.removeListener(_onOdoOrTripChanged);
    _tripDistanceController.removeListener(_onOdoOrTripChanged);
    _odometerController.dispose();
    _tripDistanceController.dispose();
    _secondaryTripDistanceController.dispose();
    _rateController.dispose();
    _volumeController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (!mounted) return;
      TimeOfDay? time = await showTimePicker(
          initialTime: TimeOfDay.fromDateTime(_selectedDate),
          context: context);
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxVolume =
        AppSettings.maxVolume > 0 ? AppSettings.maxVolume : 100.0;
    final double clampedSliderValue = _volume.clamp(0.0, maxVolume);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Edit Fuel Record'
            : AppLocalizations.of(context)!.addFuelData),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${AppLocalizations.of(context)!.dateAndTime}: ${_selectedDate.toLocal().toString().substring(0, 16)}",
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedVehicleId != null &&
                            _vehicles.any((v) => v.id == _selectedVehicleId)
                        ? _selectedVehicleId
                        : null,
                    items: _vehicles
                        .map((vehicle) => DropdownMenuItem(
                              value: vehicle.id,
                              child: Text(vehicle.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedVehicleId = val!;
                        _updateAvailableFuelTypes();
                        _updatePreviousOdometer();
                      });
                    },
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.vehicle),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedFuelTypeId != null &&
                            _availableFuelTypes
                                .any((ft) => ft.id == _selectedFuelTypeId)
                        ? _selectedFuelTypeId
                        : null,
                    items: _availableFuelTypes
                        .map((fuel) => DropdownMenuItem(
                              value: fuel.id,
                              child: Text(fuel.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedFuelTypeId = val!;
                        final fuelName = _availableFuelTypes
                            .firstWhere((ft) => ft.id == val)
                            .name;
                        _rateController.text =
                            AppSettings.defaultFuelPrices[fuelName]
                                    ?.toString() ??
                                '';
                      });
                    },
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.fuelType),
                  ),
                  const SizedBox(height: 12),
                  LocationPickerField(
                    type: 'fuel_station',
                    initialLocation: _selectedLocation,
                    onLocationChanged: (loc) {
                      _selectedLocation = loc;
                    },
                    onGpsPositionChanged: (pos) {
                      _capturedPosition = pos;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _odometerController,
                    decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)!.odometerReading),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!
                            .enterOdometerReading;
                      }
                      return null;
                    },
                  ),
                  if (_hasTripMeter) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tripDistanceController,
                      decoration: InputDecoration(
                        labelText: _hasDualTrip
                            ? AppLocalizations.of(context)!.tripA
                            : AppLocalizations.of(context)!.tripDistance,
                        hintText:
                            AppLocalizations.of(context)!.enterTripDistance,
                        suffixIcon: _previousOdometer != null
                            ? IconButton(
                                icon: const Icon(Icons.sync),
                                tooltip: _tripDistanceController.text.isNotEmpty
                                    ? AppLocalizations.of(context)!
                                        .syncOdometerTooltip(
                                        _previousOdometer!.toStringAsFixed(1),
                                        _tripDistanceController.text,
                                      )
                                    : AppLocalizations.of(context)!
                                        .syncOdometer,
                                onPressed: () {
                                  final trip = double.tryParse(
                                      _tripDistanceController.text);
                                  final odo = double.tryParse(
                                      _odometerController.text);
                                  if (trip != null && trip > 0) {
                                    final synced = _previousOdometer! + trip;
                                    _odometerController.text =
                                        synced.toStringAsFixed(2);
                                  } else if (odo != null &&
                                      odo > _previousOdometer!) {
                                    final calculatedTrip =
                                        odo - _previousOdometer!;
                                    _tripDistanceController.text =
                                        calculatedTrip.toStringAsFixed(2);
                                  }
                                },
                              )
                            : null,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (_hasDualTrip) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _secondaryTripDistanceController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.tripB,
                          hintText: AppLocalizations.of(context)!.tripB,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ],
                    if (_buildDiscrepancyChip(context) != null)
                      _buildDiscrepancyChip(context)!,
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context)!.drivingCondition,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          avatar: const Text('🔄'),
                          label: Text(AppLocalizations.of(context)!.mixed),
                          selected: _drivingCondition == DrivingCondition.mixed,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _drivingCondition = DrivingCondition.mixed;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Text('🏙️'),
                          label: Text(AppLocalizations.of(context)!.city),
                          selected: _drivingCondition == DrivingCondition.city,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _drivingCondition = DrivingCondition.city;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          avatar: const Text('🛣️'),
                          label: Text(AppLocalizations.of(context)!.highway),
                          selected:
                              _drivingCondition == DrivingCondition.highway,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _drivingCondition = DrivingCondition.highway;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateController,
                    decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)!.fuelPriceRate),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!
                            .enterFuelPriceRate;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                      "${AppLocalizations.of(context)!.totalVolume}: ${_volume.toStringAsFixed(2)}"),
                  Slider(
                    value: clampedSliderValue,
                    min: 0,
                    max: maxVolume,
                    divisions: (maxVolume * 100).toInt() > 0
                        ? (maxVolume * 100).toInt()
                        : 100,
                    label: clampedSliderValue.toStringAsFixed(2),
                    onChanged: (val) {
                      final parsedVal = double.parse(val.toStringAsFixed(2));
                      setState(() {
                        _volume = parsedVal;
                        _isUpdating = true;
                        _volumeController.text = _volume.toStringAsFixed(2);
                        final double? rate = double.tryParse(_rateController.text);
                        if (rate != null && rate > 0) {
                          _paidAmountController.text =
                              (_volume * rate).toStringAsFixed(2);
                        }
                        _isUpdating = false;
                      });
                    },
                  ),
                  TextFormField(
                    controller: _volumeController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.totalVolume),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterTotalVolume;
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _paidAmountController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.paidAmount),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterPaidAmount;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.fullTank),
                    subtitle:
                        Text(AppLocalizations.of(context)!.fullTankSubtitle),
                    value: _isFullTank,
                    onChanged: (val) {
                      setState(() {
                        _isFullTank = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.missedPrevious),
                    subtitle: Text(
                        AppLocalizations.of(context)!.missedPreviousSubtitle),
                    value: _missedPrevious,
                    onChanged: (val) {
                      setState(() {
                        _missedPrevious = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final double enteredOdometer =
                            double.parse(_odometerController.text);
                        final double finalVolume =
                            double.tryParse(_volumeController.text) ?? _volume;
                        final double? tripDist =
                            _tripDistanceController.text.isNotEmpty
                                ? double.tryParse(_tripDistanceController.text)
                                : null;
                        final double? secTripDist =
                            _secondaryTripDistanceController.text.isNotEmpty
                                ? double.tryParse(
                                    _secondaryTripDistanceController.text)
                                : null;

                        if (_isEditing) {
                          final allRecords =
                              await DatabaseHelper.instance.getFuelRecords();
                          final otherVehicleRecords = allRecords
                              .where((r) =>
                                  r.vehicleId == _selectedVehicleId &&
                                  r.id != widget.recordToEdit!.id)
                              .toList();
                          otherVehicleRecords
                              .sort((a, b) => a.date.compareTo(b.date));

                          final prevRecords = otherVehicleRecords
                              .where((r) => r.date.isBefore(_selectedDate))
                              .toList();
                          final nextRecords = otherVehicleRecords
                              .where((r) => r.date.isAfter(_selectedDate))
                              .toList();

                          final double? prevOdo = prevRecords.isNotEmpty
                              ? prevRecords.last.odometer
                              : null;
                          final double? nextOdo = nextRecords.isNotEmpty
                              ? nextRecords.first.odometer
                              : null;

                          String? warningMessage;
                          if (prevOdo != null && enteredOdometer < prevOdo) {
                            warningMessage =
                                'Entered odometer (${enteredOdometer.toStringAsFixed(2)}) is lower than previous record (${prevOdo.toStringAsFixed(2)}). Continue?';
                          } else if (nextOdo != null &&
                              enteredOdometer > nextOdo) {
                            warningMessage =
                                'Entered odometer (${enteredOdometer.toStringAsFixed(2)}) is higher than subsequent record (${nextOdo.toStringAsFixed(2)}). Continue?';
                          }

                          if (warningMessage != null) {
                            if (!context.mounted) return;
                            final bool? proceed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(AppLocalizations.of(ctx)!
                                    .odometerWarningTitle),
                                content: Text(warningMessage!),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child:
                                        Text(AppLocalizations.of(ctx)!.cancel),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child:
                                        Text(AppLocalizations.of(ctx)!.confirm),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }

                          final updatedRecord = widget.recordToEdit!.copyWith(
                            date: _selectedDate,
                            odometer: enteredOdometer,
                            fuelTypeId: _selectedFuelTypeId!,
                            vehicleId: _selectedVehicleId!,
                            rate: double.parse(_rateController.text),
                            volume: finalVolume,
                            paidAmount:
                                double.parse(_paidAmountController.text),
                            isFullTank: _isFullTank,
                            missedPrevious: _missedPrevious,
                            tripDistance: tripDist,
                            secondaryTripDistance: secTripDist,
                            drivingCondition: _drivingCondition,
                            locationId: _selectedLocation?.id,
                            latitude: _capturedPosition?.latitude ?? _selectedLocation?.latitude,
                            longitude: _capturedPosition?.longitude ?? _selectedLocation?.longitude,
                          );

                          await DatabaseHelper.instance
                              .updateFuelRecord(updatedRecord);
                          await _rescheduleReminderForVehicle(_selectedVehicleId!);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } else {
                          final allRecords =
                              await DatabaseHelper.instance.getFuelRecords();
                          final vehicleRecords = allRecords
                              .where((r) => r.vehicleId == _selectedVehicleId)
                              .toList();
                          if (vehicleRecords.isNotEmpty) {
                            vehicleRecords
                                .sort((a, b) => a.date.compareTo(b.date));
                            final latestOdometer = vehicleRecords.last.odometer;
                            if (enteredOdometer <= latestOdometer) {
                              if (!context.mounted) return;
                              final bool? proceed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(AppLocalizations.of(ctx)!
                                      .odometerWarningTitle),
                                  content: Text(AppLocalizations.of(ctx)!
                                      .odometerWarningMessage(
                                    enteredOdometer.toStringAsFixed(2),
                                    latestOdometer.toStringAsFixed(2),
                                  )),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child:
                                          Text(AppLocalizations.of(ctx)!.cancel),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child:
                                          Text(AppLocalizations.of(ctx)!.confirm),
                                    ),
                                  ],
                                ),
                              );
                              if (proceed != true) return;
                            }
                          }

                          await _saveLastValues();
                          FuelRecord record = FuelRecord(
                            date: _selectedDate,
                            odometer: enteredOdometer,
                            fuelTypeId: _selectedFuelTypeId!,
                            vehicleId: _selectedVehicleId!,
                            rate: double.parse(_rateController.text),
                            volume: finalVolume,
                            paidAmount:
                                double.parse(_paidAmountController.text),
                            isFullTank: _isFullTank,
                            missedPrevious: _missedPrevious,
                            tripDistance: tripDist,
                            secondaryTripDistance: secTripDist,
                            drivingCondition: _drivingCondition,
                            locationId: _selectedLocation?.id,
                            latitude: _capturedPosition?.latitude ?? _selectedLocation?.latitude,
                            longitude: _capturedPosition?.longitude ?? _selectedLocation?.longitude,
                          );
                          await DatabaseHelper.instance.insertFuelRecord(record);
                          await _rescheduleReminderForVehicle(_selectedVehicleId!);
                          if (AppSettings.adsEnabled) {
                            _interstitialAdService.showAd();
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        }
                      }
                    },
                    child: Text(_isEditing
                        ? 'Update'
                        : AppLocalizations.of(context)!.save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
