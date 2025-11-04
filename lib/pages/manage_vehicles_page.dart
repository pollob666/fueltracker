// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';

import 'add_vehicle_page.dart';

class ManageVehiclesPage extends StatefulWidget {
  const ManageVehiclesPage({super.key});

  @override
  State<ManageVehiclesPage> createState() => _ManageVehiclesPageState();
}

class _ManageVehiclesPageState extends State<ManageVehiclesPage> {
  final VehicleService _vehicleService = VehicleService();
  List<Vehicle> _vehicles = [];
  int? _defaultVehicleId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final vehicles = await _vehicleService.getVehicles();
    var defaultVehicleId = await _vehicleService.getDefaultVehicle();

    if (vehicles.length == 1 && defaultVehicleId == null) {
      await _vehicleService.setDefaultVehicle(vehicles.first.id!);
      defaultVehicleId = await _vehicleService.getDefaultVehicle();
    }

    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        _defaultVehicleId = defaultVehicleId;
      });
    }
  }

  Future<void> _setAsDefault(int vehicleId) async {
    await _vehicleService.setDefaultVehicle(vehicleId);
    _loadVehicles();
  }

  String _getVehicleTypeLocalization(BuildContext context, VehicleType type) {
    switch (type) {
      case VehicleType.carOrSedan:
        return AppLocalizations.of(context)!.carOrSedan;
      case VehicleType.motorcycle:
        return AppLocalizations.of(context)!.motorcycle;
      case VehicleType.scooterOrMoped:
        return AppLocalizations.of(context)!.scooterOrMoped;
      case VehicleType.suv:
        return AppLocalizations.of(context)!.suv;
      case VehicleType.pickupOrTruck:
        return AppLocalizations.of(context)!.pickupOrTruck;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.manageVehicles)),
      drawer: const MyDrawer(),
      body: ListView.builder(
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          final isDefault = vehicle.id == _defaultVehicleId;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getVehicleTypeLocalization(context, vehicle.type),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isDefault)
                        Chip(
                          label: Text(localizations.defaultVehicle),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddVehiclePage(vehicle: vehicle),
                            ),
                          );
                          _loadVehicles();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isDefault ? null : () => _setAsDefault(vehicle.id!),
                        child: Text(localizations.setAsDefault),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVehiclePage()),
          );
          _loadVehicles();
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }
}
