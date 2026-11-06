// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();
  factory LocationService() => instance;

  Future<bool> isLocationEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Error checking location service status: $e');
      return false;
    }
  }

  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return LocationPermission.denied;
    }
  }

  Future<Position?> getCurrentPosition({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final serviceEnabled = await isLocationEnabled();
      if (!serviceEnabled) return null;

      var permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } catch (e) {
      debugPrint('Error obtaining current GPS position: $e');
      return null;
    }
  }

  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  Future<List<SavedLocation>> findNearbyLocations({
    required double latitude,
    required double longitude,
    String? type,
  }) async {
    final allLocations = await DatabaseHelper.instance.getSavedLocations(type: type);
    final List<MapEntry<SavedLocation, double>> matches = [];

    for (final loc in allLocations) {
      if (loc.latitude != null && loc.longitude != null) {
        final dist = calculateDistance(
          latitude,
          longitude,
          loc.latitude!,
          loc.longitude!,
        );
        if (dist <= loc.radiusMeters) {
          matches.add(MapEntry(loc, dist));
        }
      }
    }

    matches.sort((a, b) => a.value.compareTo(b.value));
    return matches.map((e) => e.key).toList();
  }

  Future<SavedLocation> getOrCreateCluster({
    required double latitude,
    required double longitude,
    required String type,
    String? customName,
  }) async {
    final nearby = await findNearbyLocations(
      latitude: latitude,
      longitude: longitude,
      type: type,
    );

    if (nearby.isNotEmpty) {
      final closest = nearby.first;
      if (customName != null && customName.trim().isNotEmpty && !closest.isNamed) {
        final updated = closest.copyWith(
          name: customName.trim(),
          isNamed: true,
        );
        await DatabaseHelper.instance.updateSavedLocation(updated);
        return updated;
      }
      return closest;
    }

    final hasCustomName = customName != null && customName.trim().isNotEmpty;
    final fallbackName = hasCustomName
        ? customName.trim()
        : 'Unnamed Spot (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';

    final newLoc = SavedLocation(
      name: fallbackName,
      isNamed: hasCustomName,
      type: type,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: 80.0,
      createdAt: DateTime.now(),
    );

    final id = await DatabaseHelper.instance.insertSavedLocation(newLoc);
    newLoc.id = id;
    return newLoc;
  }

  Future<List<AnomalyAttributionItem>> findAttributionCandidates({
    required int vehicleId,
    required MileageAnomalyResult anomaly,
  }) async {
    final List<AnomalyAttributionItem> candidates = [];

    // 1. Candidate Fuel Station (from baselineRecord or currentRecord)
    final targetRecord = anomaly.baselineRecord ?? anomaly.currentRecord;
    if (targetRecord.locationId != null) {
      final loc = await DatabaseHelper.instance.getSavedLocationById(targetRecord.locationId!);
      if (loc != null) {
        candidates.add(AnomalyAttributionItem(
          locationId: loc.id,
          title: 'Fuel Station: ${loc.displayName}',
          subtitle: 'Supplied fuel consumed during this interval (${targetRecord.volume.toStringAsFixed(1)}L filled at ${targetRecord.odometer.toStringAsFixed(0)} km)',
          isFuel: true,
          isSelected: true,
        ));
      }
    }

    // 2. Candidate Workshop / Services (sessions between baseline and current)
    final db = await DatabaseHelper.instance.database;
    final double lowerOdo = (anomaly.baselineRecord?.odometer ?? (anomaly.currentRecord.odometer - 500.0)) - 50.0;
    final double upperOdo = anomaly.currentRecord.odometer + 1.0;

    final sessionRows = await db.query(
      'service_sessions',
      where: 'vehicleId = ? AND odometer >= ? AND odometer <= ?',
      whereArgs: [vehicleId, lowerOdo, upperOdo],
      orderBy: 'odometer DESC',
    );

    for (final s in sessionRows) {
      final int sId = s['id'] as int;
      final int? locId = s['locationId'] as int?;
      String workshopName = s['workshopName'] as String? ?? '';
      if (locId != null) {
        final loc = await DatabaseHelper.instance.getSavedLocationById(locId);
        if (loc != null) {
          workshopName = loc.displayName;
        }
      }
      if (workshopName.isEmpty) workshopName = 'Recent Workshop Service';

      final items = await db.rawQuery('''
        SELECT i.*, t.title as taskTitle FROM service_session_items i
        JOIN maintenance_tasks t ON i.taskId = t.id
        WHERE i.sessionId = ?
      ''', [sId]);

      final itemSpecs = items.map((i) {
        final title = i['taskTitle'] ?? 'Service Task';
        final brand = i['brandOrSpec'] as String?;
        return brand != null && brand.isNotEmpty ? '$title ($brand)' : '$title';
      }).join(', ');

      candidates.add(AnomalyAttributionItem(
        locationId: locId,
        title: 'Service: $workshopName',
        subtitle:
            'Logged at ${(s['odometer'] as num).toDouble().toStringAsFixed(0)} km${itemSpecs.isNotEmpty ? ' • $itemSpecs' : ''}',
        isService: true,
        isSelected: candidates.isEmpty,
      ));
    }

    return candidates;
  }
}

class AnomalyAttributionItem {
  final int? locationId;
  final String title;
  final String subtitle;
  final bool isFuel;
  final bool isService;
  bool isSelected;

  AnomalyAttributionItem({
    this.locationId,
    required this.title,
    required this.subtitle,
    this.isFuel = false,
    this.isService = false,
    this.isSelected = false,
  });
}
