// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/saved_location.dart';

class SavedLocationsPage extends StatefulWidget {
  const SavedLocationsPage({super.key});

  @override
  State<SavedLocationsPage> createState() => _SavedLocationsPageState();
}

class _SavedLocationsPageState extends State<SavedLocationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SavedLocation> _allLocations = [];
  bool _isLoading = true;
  bool _showUnnamed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final list = await DatabaseHelper.instance.getSavedLocations();
    if (mounted) {
      setState(() {
        _allLocations = list;
        _isLoading = false;
      });
    }
  }

  List<SavedLocation> _getFilteredLocations(int tabIndex) {
    List<SavedLocation> baseList = _allLocations;
    if (!_showUnnamed) {
      baseList = baseList.where((l) => l.isNamed).toList();
    }

    switch (tabIndex) {
      case 0: // All Named / Visible
        return baseList;
      case 1: // High Efficiency
        return baseList.where((l) => l.isRecommended).toList();
      case 2: // Suspect Quality
        return baseList.where((l) => l.isSuspect).toList();
      case 3: // Workshops
        return baseList
            .where((l) => l.type == 'service_shop' || l.type == 'both')
            .toList();
      default:
        return baseList;
    }
  }

  Future<void> _showAddOrEditDialog({SavedLocation? locationToEdit}) async {
    final isEditing = locationToEdit != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? (locationToEdit.isNamed ? locationToEdit.name : '') : '',
    );
    String selectedType = isEditing ? locationToEdit.type : 'fuel_station';
    double radius = isEditing ? locationToEdit.radiusMeters : 80.0;
    final latCtrl = TextEditingController(
      text: isEditing && locationToEdit.latitude != null
          ? locationToEdit.latitude!.toStringAsFixed(5)
          : '',
    );
    final lngCtrl = TextEditingController(
      text: isEditing && locationToEdit.longitude != null
          ? locationToEdit.longitude!.toStringAsFixed(5)
          : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text(
                isEditing
                    ? (locationToEdit.isNamed ? 'Edit Location' : 'Name This Location')
                    : 'Add Saved Location',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location Name',
                        hintText: 'e.g. Padma Highway Pump',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'fuel_station',
                          child: Text('⛽ Fuel Station'),
                        ),
                        DropdownMenuItem(
                          value: 'service_shop',
                          child: Text('🔧 Workshop / Garage'),
                        ),
                        DropdownMenuItem(
                          value: 'both',
                          child: Text('⛽+🔧 Both'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitude (Optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitude (Optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Proximity Radius: ${radius.toInt()}m',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: radius,
                      min: 30.0,
                      max: 200.0,
                      divisions: 17,
                      label: '${radius.toInt()}m',
                      onChanged: (val) {
                        setDlgState(() => radius = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      final double? lat = double.tryParse(latCtrl.text.trim());
      final double? lng = double.tryParse(lngCtrl.text.trim());

      if (isEditing) {
        final updated = locationToEdit.copyWith(
          name: name,
          isNamed: true,
          type: selectedType,
          latitude: lat ?? locationToEdit.latitude,
          longitude: lng ?? locationToEdit.longitude,
          radiusMeters: radius,
        );
        await DatabaseHelper.instance.updateSavedLocation(updated);
      } else {
        final newLoc = SavedLocation(
          name: name,
          isNamed: true,
          type: selectedType,
          latitude: lat,
          longitude: lng,
          radiusMeters: radius,
        );
        await DatabaseHelper.instance.insertSavedLocation(newLoc);
      }
      _loadLocations();
    }
  }

  Future<void> _deleteLocation(SavedLocation loc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
          'Delete "${loc.displayName}"? Previous records attached to this location will retain their history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && loc.id != null) {
      await DatabaseHelper.instance.deleteSavedLocation(loc.id!);
      _loadLocations();
    }
  }

  Widget _buildLocationCard(SavedLocation loc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String typeLabel = '⛽ Fuel Station';
    if (loc.type == 'service_shop') typeLabel = '🔧 Workshop';
    if (loc.type == 'both') typeLabel = '⛽+🔧 Both';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: loc.isSuspect
              ? Colors.amber.shade700
              : (loc.isRecommended ? Colors.green.shade600 : colorScheme.outlineVariant),
          width: loc.isSuspect || loc.isRecommended ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        loc.isSuspect
                            ? Icons.warning_amber_rounded
                            : (loc.isRecommended ? Icons.eco : Icons.place),
                        color: loc.isSuspect
                            ? Colors.amber.shade800
                            : (loc.isRecommended ? Colors.green.shade700 : colorScheme.primary),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: loc.isNamed ? null : Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _showAddOrEditDialog(locationToEdit: loc);
                    } else if (val == 'clear_suspect') {
                      await DatabaseHelper.instance.clearLocationSuspectFlag(loc.id!);
                      _loadLocations();
                    } else if (val == 'clear_recommended') {
                      await DatabaseHelper.instance.clearLocationRecommendedFlag(loc.id!);
                      _loadLocations();
                    } else if (val == 'delete') {
                      _deleteLocation(loc);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(loc.isNamed ? 'Edit' : 'Name Location'),
                    ),
                    if (loc.isSuspect)
                      const PopupMenuItem(
                        value: 'clear_suspect',
                        child: Text('Clear Suspect Flag'),
                      ),
                    if (loc.isRecommended)
                      const PopupMenuItem(
                        value: 'clear_recommended',
                        child: Text('Clear High-Efficiency Flag'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(typeLabel, style: const TextStyle(fontSize: 10)),
                ),
                if (loc.isSuspect)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.amber.shade100,
                    label: Text(
                      '⚠️ Suspect Quality',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                if (loc.isRecommended)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.green.shade100,
                    label: Text(
                      '🟢 High Efficiency',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                if (!loc.isNamed)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.grey.shade200,
                    label: Text(
                      'Unnamed GPS Cluster',
                      style: TextStyle(fontSize: 10, color: Colors.grey[800]),
                    ),
                  ),
              ],
            ),
            if (loc.latitude != null && loc.longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'GPS: ${loc.latitude!.toStringAsFixed(4)}°, ${loc.longitude!.toStringAsFixed(4)}° • Radius: ${loc.radiusMeters.toInt()}m',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
            if (loc.suspectReason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Warning: ${loc.suspectReason}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
            if (loc.performanceReason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Performance: ${loc.performanceReason}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.green.shade800,
                ),
              ),
            ],
            if (!loc.isNamed) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.label_outline, size: 14),
                  label: const Text('Name This Location', style: TextStyle(fontSize: 11)),
                  onPressed: () => _showAddOrEditDialog(locationToEdit: loc),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unnamedCount = _allLocations.where((l) => !l.isNamed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        actions: [
          IconButton(
            tooltip: 'Add Location',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: () => _showAddOrEditDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Named'),
            Tab(text: '🟢 High Efficiency'),
            Tab(text: '⚠️ Suspect Quality'),
            Tab(text: 'Workshops'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top control bar with "Show Unnamed Locations" toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Saved: ${_allLocations.where((l) => l.isNamed).length} locations',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Text(
                            'Show Unnamed ($unnamedCount)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: _showUnnamed,
                            onChanged: (val) {
                              setState(() {
                                _showUnnamed = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: List.generate(4, (tabIdx) {
                      final items = _getFilteredLocations(tabIdx);
                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.place_outlined, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text(
                                  'No locations in this category.',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) => _buildLocationCard(items[i]),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}
