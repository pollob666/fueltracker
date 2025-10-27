// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';

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
    switch (type) {
      case VehicleType.carOrSedan:
        return AppLocalizations.of(context).carOrSedan;
      case VehicleType.motorcycle:
        return AppLocalizations.of(context).motorcycle;
      case VehicleType.scooterOrMoped:
        return AppLocalizations.of(context).scooterOrMoped;
      case VehicleType.suv:
        return AppLocalizations.of(context).suv;
      case VehicleType.pickupOrTruck:
        return AppLocalizations.of(context).pickupOrTruck;
      default:
        return type.toString().split('.').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

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
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(labelText: localizations.vehicleName),
                  onSaved: (value) => _name = value!,
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                DropdownButtonFormField<VehicleType>(
                  value: _vehicleType,
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
                  value: _primaryFuelTypeId,
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
                  value: _secondaryFuelTypeId,
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
                      if (widget.vehicle == null) {
                        await DatabaseHelper.instance.insertVehicle(vehicle);
                      } else {
                        await DatabaseHelper.instance.updateVehicle(vehicle);
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  child: Text(localizations.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
