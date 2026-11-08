// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/models/tire.dart';
import 'package:fuel_tracker/models/tire_log.dart';
import 'package:fuel_tracker/repositories/tire_repository.dart';

final tireRepositoryProvider = Provider<TireRepository>((ref) {
  return SqliteTireRepository();
});

class TiresNotifier extends FamilyAsyncNotifier<List<Tire>, int> {
  @override
  Future<List<Tire>> build(int arg) async {
    final repo = ref.watch(tireRepositoryProvider);
    return await repo.getTiresForVehicle(arg);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(tireRepositoryProvider);
      return await repo.getTiresForVehicle(arg);
    });
  }

  Future<int> addTire(Tire tire) async {
    final repo = ref.read(tireRepositoryProvider);
    final id = await repo.insertTire(tire);
    await refresh();
    return id;
  }

  Future<void> updateTire(Tire tire) async {
    final repo = ref.read(tireRepositoryProvider);
    await repo.updateTire(tire);
    await refresh();
  }

  Future<void> deleteTire(int id) async {
    final repo = ref.read(tireRepositoryProvider);
    await repo.deleteTire(id);
    await refresh();
  }

  Future<int> logMeasurement(TireLog log) async {
    final repo = ref.read(tireRepositoryProvider);
    final id = await repo.insertTireLog(log);
    await refresh();
    ref.invalidate(latestTireLogsProvider(arg));
    return id;
  }
}

final tiresProvider = AsyncNotifierProvider.family<TiresNotifier, List<Tire>, int>(
  TiresNotifier.new,
);

final latestTireLogsProvider = FutureProvider.family<List<TireLog>, int>((ref, vehicleId) async {
  final repo = ref.watch(tireRepositoryProvider);
  return await repo.getLatestTireLogsForVehicle(vehicleId);
});

final tireLogsForTireProvider = FutureProvider.family<List<TireLog>, int>((ref, tireId) async {
  final repo = ref.watch(tireRepositoryProvider);
  return await repo.getTireLogsForTire(tireId);
});
