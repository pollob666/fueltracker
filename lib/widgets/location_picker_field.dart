// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/services/location_service.dart';

class LocationPickerField extends StatefulWidget {
  final String type; // 'fuel_station' or 'service_shop'
  final SavedLocation? initialLocation;
  final ValueChanged<SavedLocation?> onLocationChanged;
  final ValueChanged<Position?>? onGpsPositionChanged;

  const LocationPickerField({
    super.key,
    required this.type,
    this.initialLocation,
    required this.onLocationChanged,
    this.onGpsPositionChanged,
  });

  @override
  State<LocationPickerField> createState() => LocationPickerFieldState();
}

class LocationPickerFieldState extends State<LocationPickerField> {
  SavedLocation? _selectedLocation;
  Position? _currentPosition;
  bool _isGpsScanning = false;
  List<SavedLocation> _availableLocations = [];
  bool _dismissedWarning = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _loadLocations();
    _autoDetectGps();
  }

  Future<void> _loadLocations() async {
    final list = await DatabaseHelper.instance.getSavedLocations(
      type: widget.type,
      onlyNamed: true,
    );
    if (mounted) {
      setState(() {
        _availableLocations = list;
      });
    }
  }

  Future<void> _autoDetectGps() async {
    final permission = await LocationService.instance.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      await scanGps(silent: true);
    }
  }

  Future<void> scanGps({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      _isGpsScanning = true;
    });

    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _isGpsScanning = false;
      _currentPosition = pos;
    });

    if (pos != null) {
      widget.onGpsPositionChanged?.call(pos);
      final nearby = await LocationService.instance.findNearbyLocations(
        latitude: pos.latitude,
        longitude: pos.longitude,
        type: widget.type,
      );

      if (!mounted) return;

      if (nearby.length > 1) {
        // Multi-station conflict: ask user to disambiguate
        _showDisambiguationSheet(nearby);
      } else if (nearby.length == 1) {
        _selectLocation(nearby.first);
      } else {
        // No saved station in range: auto-create an unnamed cluster spot
        final cluster = await LocationService.instance.getOrCreateCluster(
          latitude: pos.latitude,
          longitude: pos.longitude,
          type: widget.type,
        );
        if (mounted) {
          _selectLocation(cluster);
        }
      }
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS unavailable or permission not granted.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _selectLocation(SavedLocation? location) {
    setState(() {
      _selectedLocation = location;
      _dismissedWarning = false;
    });
    widget.onLocationChanged(location);
  }

  void _showDisambiguationSheet(List<SavedLocation> candidates) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.near_me, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Multiple Locations Detected Nearby',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirm which station you are currently visiting:',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 12),
                ...candidates.map((loc) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: loc.isSuspect
                            ? Colors.amber.shade700
                            : (loc.isRecommended ? Colors.green : Colors.grey.shade300),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        loc.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        loc.isSuspect
                            ? '⚠️ Flagged for suspect quality'
                            : (loc.isRecommended ? '🟢 High Efficiency' : 'Saved location'),
                        style: TextStyle(
                          fontSize: 11,
                          color: loc.isSuspect
                              ? Colors.amber.shade900
                              : (loc.isRecommended ? Colors.green.shade800 : Colors.grey[700]),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectLocation(loc);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptNameLocation() async {
    final nameCtrl = TextEditingController(
      text: _selectedLocation?.isNamed == true ? _selectedLocation!.name : '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            _selectedLocation?.isNamed == true ? 'Edit Location Name' : 'Name This Location',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Give this spot a name for future auto-detection:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Location / Station Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Name'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      if (_selectedLocation != null) {
        final updated = _selectedLocation!.copyWith(
          name: name,
          isNamed: true,
        );
        await DatabaseHelper.instance.updateSavedLocation(updated);
        _selectLocation(updated);
      } else if (_currentPosition != null) {
        final newLoc = await LocationService.instance.getOrCreateCluster(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          type: widget.type,
          customName: name,
        );
        _selectLocation(newLoc);
      } else {
        final newLoc = SavedLocation(
          name: name,
          isNamed: true,
          type: widget.type,
          radiusMeters: 80.0,
        );
        final id = await DatabaseHelper.instance.insertSavedLocation(newLoc);
        newLoc.id = id;
        _selectLocation(newLoc);
      }
      _loadLocations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuspect = (_selectedLocation?.isSuspect ?? false) && !_dismissedWarning;
    final isRecommended = _selectedLocation?.isRecommended ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Suspect warning banner
        if (isSuspect)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suspect Quality Warning',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedLocation!.suspectReason ??
                            'Mileage dropped significantly after visiting this location.',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _dismissedWarning = true;
                              });
                            },
                            child: const Text(
                              'Dismiss',
                              style: TextStyle(
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () async {
                              await DatabaseHelper.instance.clearLocationSuspectFlag(_selectedLocation!.id!);
                              final refreshed = await DatabaseHelper.instance.getSavedLocationById(_selectedLocation!.id!);
                              _selectLocation(refreshed);
                            },
                            child: const Text(
                              'Clear Flag',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // High efficiency banner
        if (isRecommended)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade600),
            ),
            child: Row(
              children: [
                Icon(Icons.eco, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLocation!.performanceReason ??
                        'High-efficiency station recognized (+15% mileage boost recorded).',
                    style: TextStyle(color: Colors.green.shade800, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

        // Input Selector Bar
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showLocationSelectionDialog(),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.type == 'service_shop' ? 'Workshop / Shop' : 'Fuel Station',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    prefixIcon: Icon(
                      widget.type == 'service_shop' ? Icons.build : Icons.local_gas_station,
                      size: 20,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLocation?.displayName ?? 'Select or detect station...',
                          style: TextStyle(
                            fontSize: 13,
                            color: _selectedLocation == null ? Colors.grey[600] : null,
                            fontWeight: _selectedLocation?.isNamed == true ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedLocation?.isSuspect ?? false)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '⚠️ Suspect',
                            style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (_selectedLocation?.isRecommended ?? false)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🟢 Best',
                            style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // GPS Scan Button
            IconButton.filledTonal(
              tooltip: 'Detect GPS Location',
              onPressed: _isGpsScanning ? null : () => scanGps(silent: false),
              icon: _isGpsScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 20),
            ),
            const SizedBox(width: 4),
            // Name / Edit button
            IconButton.outlined(
              tooltip: _selectedLocation?.isNamed == true ? 'Rename Location' : 'Name Location',
              onPressed: _promptNameLocation,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  void _showLocationSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(widget.type == 'service_shop' ? 'Select Workshop' : 'Select Fuel Station'),
          content: SizedBox(
            width: double.maxFinite,
            child: _availableLocations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No named locations saved yet. Tap Detect GPS or Name Location.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableLocations.length,
                    itemBuilder: (context, index) {
                      final loc = _availableLocations[index];
                      return ListTile(
                        leading: Icon(
                          loc.isSuspect
                              ? Icons.warning_amber_rounded
                              : (loc.isRecommended ? Icons.eco : Icons.place),
                          color: loc.isSuspect
                              ? Colors.amber.shade800
                              : (loc.isRecommended ? Colors.green : Colors.blue),
                        ),
                        title: Text(loc.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: loc.isSuspect
                            ? const Text('⚠️ Suspect quality', style: TextStyle(color: Colors.amber, fontSize: 11))
                            : (loc.isRecommended
                                ? const Text('🟢 High efficiency', style: TextStyle(color: Colors.green, fontSize: 11))
                                : null),
                        onTap: () {
                          Navigator.pop(ctx);
                          _selectLocation(loc);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _selectLocation(null);
              },
              child: const Text('Clear Selection'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New'),
              onPressed: () {
                Navigator.pop(ctx);
                _promptNameLocation();
              },
            ),
          ],
        );
      },
    );
  }
}
