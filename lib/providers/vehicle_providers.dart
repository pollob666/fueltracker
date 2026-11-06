// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/repositories/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return SqliteVehicleRepository();
});

class VehiclesNotifier extends AsyncNotifier<List<Vehicle>> {
  @override
  Future<List<Vehicle>> build() async {
    final repo = ref.watch(vehicleRepositoryProvider);
    final vehicles = await repo.getVehicles();

    // Auto-initialize active vehicle if unset
    final activeId = ref.read(activeVehicleIdProvider);
    if (activeId == null && vehicles.isNotEmpty) {
      final defaultId = await repo.getDefaultVehicleId();
      final targetId = defaultId != null && vehicles.any((v) => v.id == defaultId)
          ? defaultId
          : vehicles.first.id;
      ref.read(activeVehicleIdProvider.notifier).state = targetId;
    }

    return vehicles;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(vehicleRepositoryProvider);
      return await repo.getVehicles();
    });
  }

  Future<int> addVehicle(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    final id = await repo.insertVehicle(vehicle);
    await refresh();
    return id;
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final repo = ref.read(vehicleRepositoryProvider);
    await repo.updateVehicle(vehicle);
    await refresh();
  }

  Future<void> deleteVehicle(int id, {bool cascade = true}) async {
    final repo = ref.read(vehicleRepositoryProvider);
    await repo.deleteVehicle(id, cascade: cascade);
    await refresh();
    final remaining = state.value ?? [];
    final activeId = ref.read(activeVehicleIdProvider);
    if (activeId == id) {
      ref.read(activeVehicleIdProvider.notifier).state =
          remaining.isNotEmpty ? remaining.first.id : null;
    }
  }

  Future<void> setDefaultVehicle(int id) async {
    final repo = ref.read(vehicleRepositoryProvider);
    await repo.setDefaultVehicleId(id);
    ref.read(activeVehicleIdProvider.notifier).state = id;
  }
}

final vehiclesProvider =
    AsyncNotifierProvider<VehiclesNotifier, List<Vehicle>>(VehiclesNotifier.new);

final activeVehicleIdProvider = StateProvider<int?>((ref) => null);

final activeVehicleProvider = Provider<Vehicle?>((ref) {
  final activeId = ref.watch(activeVehicleIdProvider);
  final vehiclesAsync = ref.watch(vehiclesProvider);
  return vehiclesAsync.maybeWhen(
    data: (vehicles) {
      if (activeId == null) {
        return vehicles.isNotEmpty ? vehicles.first : null;
      }
      try {
        return vehicles.firstWhere((v) => v.id == activeId);
      } catch (_) {
        return vehicles.isNotEmpty ? vehicles.first : null;
      }
    },
    orElse: () => null,
  );
});
