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
import 'package:shared_preferences/shared_preferences.dart';

class AddDataPage extends StatefulWidget {
  const AddDataPage({super.key});

  @override
  State<AddDataPage> createState() => _AddDataPageState();
}

class _AddDataPageState extends State<AddDataPage> {
  final _formKey = GlobalKey<FormState>();
  final FuelTypeService _fuelTypeService = FuelTypeService();
  final VehicleService _vehicleService = VehicleService();
  final InterstitialAdService _interstitialAdService = InterstitialAdService();

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _odometerController = TextEditingController();
  int? _selectedVehicleId;
  int? _selectedFuelTypeId;
  List<Vehicle> _vehicles = [];
  List<FuelType> _allFuelTypes = [];
  List<FuelType> _availableFuelTypes = [];

  final TextEditingController _rateController = TextEditingController();
  double _volume = 0;
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _interstitialAdService.loadAd();
    _loadLastValues();
    _volumeController.text = _volume.toStringAsFixed(2);

    _rateController.addListener(_calculateVolume);
    _paidAmountController.addListener(_calculateVolume);

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final vehicles = await _vehicleService.getVehicles();
    final allFuelTypes = await _fuelTypeService.getFuelTypes();
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        _allFuelTypes = allFuelTypes;
        if (_vehicles.isNotEmpty) {
          _selectedVehicleId = _vehicles.first.id;
          _updateAvailableFuelTypes();
        }
      });
    }
  }

  void _updateAvailableFuelTypes() {
    if (_selectedVehicleId == null || _vehicles.isEmpty) return;

    final selectedVehicle = _vehicles.firstWhere((v) => v.id == _selectedVehicleId);
    final availableFuelTypes = <FuelType>{};

    final primaryFuelType = _allFuelTypes.firstWhere((ft) => ft.id == selectedVehicle.primaryFuelTypeId);
    if (primaryFuelType.category == FuelCategory.gasoline) {
      availableFuelTypes.addAll(_allFuelTypes.where((ft) => ft.category == FuelCategory.gasoline));
    } else {
      availableFuelTypes.add(primaryFuelType);
    }

    if (selectedVehicle.secondaryFuelTypeId != null) {
      final secondaryFuelType = _allFuelTypes.firstWhere((ft) => ft.id == selectedVehicle.secondaryFuelTypeId);
      if (secondaryFuelType.category == FuelCategory.gasoline) {
        availableFuelTypes.addAll(_allFuelTypes.where((ft) => ft.category == FuelCategory.gasoline));
      } else {
        availableFuelTypes.add(secondaryFuelType);
      }
    }

    setState(() {
      _availableFuelTypes = availableFuelTypes.toList();
      if (_availableFuelTypes.isNotEmpty) {
        _selectedFuelTypeId = _availableFuelTypes.first.id;
        final fuelName = _availableFuelTypes.first.name;
        _rateController.text = AppSettings.defaultFuelPrices[fuelName]?.toString() ?? '';
      }
    });
  }

  void _calculateVolume() {
    final double? rate = double.tryParse(_rateController.text);
    final double? paidAmount = double.tryParse(_paidAmountController.text);

    if (rate != null && rate > 0 && paidAmount != null && paidAmount > 0) {
      setState(() {
        _volume = paidAmount / rate;
        _volumeController.text = _volume.toStringAsFixed(2);
      });
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

  @override
  void dispose() {
    _rateController.removeListener(_calculateVolume);
    _paidAmountController.removeListener(_calculateVolume);
    _odometerController.dispose();
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
          initialTime: TimeOfDay.fromDateTime(_selectedDate), context: context);
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
    double maxVolume = AppSettings.maxVolume;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.addFuelData)),
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
                  TextFormField(
                    controller: _odometerController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.odometerReading),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterOdometerReading;
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedVehicleId,
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
                      });
                    },
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.vehicle),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedFuelTypeId,
                    items: _availableFuelTypes
                        .map((fuel) => DropdownMenuItem(
                              value: fuel.id,
                              child: Text(fuel.name),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedFuelTypeId = val!;
                        final fuelName = _availableFuelTypes.firstWhere((ft) => ft.id == val).name;
                        _rateController.text = AppSettings.defaultFuelPrices[fuelName]?.toString() ?? '';
                      });
                    },
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.fuelType),
                  ),
                  TextFormField(
                    controller: _rateController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.fuelPriceRate),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterFuelPriceRate;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                      "${AppLocalizations.of(context)!.totalVolume}: ${_volume.toStringAsFixed(2)}"),
                  Slider(
                    value: _volume,
                    min: 0,
                    max: maxVolume,
                    divisions: (maxVolume * 100).toInt(),
                    label: _volume.toStringAsFixed(2),
                    onChanged: (val) {
                      setState(() {
                        _volume = double.parse(val.toStringAsFixed(2));
                        _volumeController.text = _volume.toStringAsFixed(2);
                      });
                    },
                  ),
                  TextFormField(
                    controller: _volumeController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.totalVolume),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterPaidAmount;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _saveLastValues();
                        FuelRecord record = FuelRecord(
                          date: _selectedDate,
                          odometer: double.parse(_odometerController.text),
                          fuelTypeId: _selectedFuelTypeId!,
                          vehicleId: _selectedVehicleId!,
                          rate: double.parse(_rateController.text),
                          volume: _volume,
                          paidAmount: double.parse(_paidAmountController.text),
                        );
                        await DatabaseHelper.instance.insertFuelRecord(record);
                        _interstitialAdService.showAd();
                        final navigator = Navigator.of(context);
                        if (!mounted) return;
                        navigator.pop();
                      }
                    },
                    child: Text(AppLocalizations.of(context)!.save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
