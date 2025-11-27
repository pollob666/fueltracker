// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
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

  List<FuelType> _fuelTypes = [];

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
    }
    _loadFuelTypes();
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
      body: Padding(
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
                  onSaved: (value) => _secondaryFuelCapacity = value!.isEmpty ? null : double.tryParse(value),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      final vehicle = Vehicle(
                        id: widget.vehicle?.id,
                        name: _name,
                        type: _vehicleType,
                        primaryFuelTypeId: _primaryFuelTypeId!,
                        primaryFuelCapacity: _primaryFuelCapacity,
                        secondaryFuelTypeId: _secondaryFuelTypeId,
                        secondaryFuelCapacity: _secondaryFuelCapacity,
                      );
                      final navigator = Navigator.of(context);
                      if (widget.vehicle == null) {
                        await DatabaseHelper.instance.insertVehicle(vehicle);
                      } else {
                        await DatabaseHelper.instance.updateVehicle(vehicle);
                      }

                      if (mounted) {
                        navigator.pop();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: theme.textTheme.titleLarge,
                  ),
                  child: Text(localizations.save),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
