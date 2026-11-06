// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/pages/add_data_page.dart';
import 'package:fuel_tracker/pages/add_vehicle_page.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/utils/maintenance_calculator.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/widgets/location_picker_field.dart';

class MaintenancePage extends StatefulWidget {
  final int? initialVehicleId;
  final int? openLogForTaskId;

  const MaintenancePage({
    super.key,
    this.initialVehicleId,
    this.openLogForTaskId,
  });

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with SingleTickerProviderStateMixin {
  final VehicleService _vehicleService = VehicleService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  late TabController _tabController;
  List<Vehicle> _vehicles = [];
  int? _selectedVehicleId;
  List<MaintenanceTask> _tasks = [];
  List<ServiceSession> _serviceSessions = [];
  RefuelPredictionResult? _refuelPrediction;
  double _currentOdo = 0.0;
  double _dailyKmRate = 20.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final vehicles = await _vehicleService.getVehicles();
    final defaultId = await _vehicleService.getDefaultVehicle();

    int? activeId = widget.initialVehicleId ?? defaultId;
    if (activeId == null && vehicles.isNotEmpty) {
      activeId = vehicles.first.id;
    } else if (activeId != null && !vehicles.any((v) => v.id == activeId)) {
      activeId = vehicles.isNotEmpty ? vehicles.first.id : null;
    }

    _vehicles = vehicles;
    _selectedVehicleId = activeId;

    if (_selectedVehicleId != null) {
      await _loadTasksForVehicle(_selectedVehicleId!);
      if (widget.openLogForTaskId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openLogServiceDialog(preSelectedTaskId: widget.openLogForTaskId);
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasksForVehicle(int vehicleId) async {
    final allRecords = await _dbHelper.getFuelRecords();
    final vehicleRecs = allRecords.where((r) => r.vehicleId == vehicleId).toList();
    vehicleRecs.sort((a, b) => a.date.compareTo(b.date));

    double maxOdo = 0.0;
    if (vehicleRecs.isNotEmpty) {
      maxOdo = vehicleRecs.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
    }

    final dailyAvg = MileageCalculator.calculateDailyAverageRun(vehicleRecs);
    final double rate = (dailyAvg > 0) ? dailyAvg : 20.0;

    final tasks = await _dbHelper.getMaintenanceTasks(vehicleId);
    final sessions = await _dbHelper.getServiceSessions(vehicleId);

    RefuelPredictionResult? refuelPred;
    final currentVeh = _vehicles.where((v) => v.id == vehicleId).firstOrNull;
    if (currentVeh != null && (currentVeh.volumeReminderEnabled || currentVeh.distanceReminderEnabled)) {
      refuelPred = MileageCalculator.calculateRefuelPrediction(
        vehicle: currentVeh,
        records: vehicleRecs,
      );
    }

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _serviceSessions = sessions;
        _refuelPrediction = refuelPred;
        _currentOdo = maxOdo;
        _dailyKmRate = rate;
        _isLoading = false;
      });
    }
  }

  String _getTaskLocalizedTitle(BuildContext context, MaintenanceTask task) {
    final l10n = AppLocalizations.of(context)!;
    switch (task.taskKey) {
      case 'engine_oil':
        return l10n.engineOilChange;
      case 'oil_filter':
        return l10n.oilFilterReplacement;
      case 'air_filter':
        return l10n.airFilterClean;
      case 'general_servicing':
        return l10n.generalServicing;
      default:
        return task.title;
    }
  }

  Future<void> _quickDone(MaintenanceTask task) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final odoController = TextEditingController(
      text: _currentOdo > 0 ? _currentOdo.toStringAsFixed(0) : task.lastServiceOdo.toStringAsFixed(0),
    );
    DateTime selectedDate = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.confirmQuickDone),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.confirmQuickDoneMsg(_getTaskLocalizedTitle(context, task)),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: odoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.lastServiceOdometer,
                        suffixText: 'km',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.lastServiceDate),
                      subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: Text(l10n.quickDone),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final newOdo = double.tryParse(odoController.text) ?? _currentOdo;
      await _dbHelper.quickResetMaintenanceTask(task.id!, newOdo, selectedDate);
      if (_selectedVehicleId != null) {
        await _loadTasksForVehicle(_selectedVehicleId!);
        final currentVehicle = _vehicles.firstWhere((v) => v.id == _selectedVehicleId);
        await NotificationService.instance.scheduleMaintenanceReminders(
          vehicle: currentVehicle,
          tasks: _tasks,
          currentOdo: _currentOdo,
          dailyKmRate: _dailyKmRate,
        );
      }
    }
  }

  Future<void> _openLogServiceDialog({
    ServiceSession? sessionToEdit,
    int? preSelectedTaskId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = sessionToEdit != null;

    final odoController = TextEditingController(
      text: isEditing
          ? sessionToEdit.odometer.toStringAsFixed(0)
          : (_currentOdo > 0 ? _currentOdo.toStringAsFixed(0) : ''),
    );
    final workshopController = TextEditingController(
      text: isEditing ? (sessionToEdit.workshopName ?? '') : '',
    );
    final costController = TextEditingController(
      text: isEditing && sessionToEdit.totalCost != null
          ? sessionToEdit.totalCost!.toStringAsFixed(2)
          : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? (sessionToEdit.notes ?? '') : '',
    );
    DateTime serviceDate = isEditing ? sessionToEdit.serviceDate : DateTime.now();

    SavedLocation? selectedLocation;
    if (isEditing && sessionToEdit.locationId != null) {
      selectedLocation = await _dbHelper.getSavedLocationById(sessionToEdit.locationId!);
    }

    final Set<int> selectedTaskIds = {};
    final Map<int, TextEditingController> brandControllers = {};
    final Map<int, TextEditingController> itemCostControllers = {};

    if (isEditing) {
      for (final item in sessionToEdit.items) {
        selectedTaskIds.add(item.taskId);
        brandControllers[item.taskId] = TextEditingController(text: item.brandOrSpec ?? '');
        itemCostControllers[item.taskId] = TextEditingController(
          text: item.cost != null ? item.cost!.toStringAsFixed(2) : '',
        );
      }
    } else {
      if (preSelectedTaskId != null) {
        selectedTaskIds.add(preSelectedTaskId);
      }
      for (final t in _tasks) {
        if (t.id != null) {
          final pred = MaintenanceCalculator.calculateTaskStatus(
            task: t,
            currentOdo: _currentOdo,
            currentDate: serviceDate,
            dailyKmRate: _dailyKmRate,
          );
          if (pred.status != MaintenanceStatus.healthy) {
            selectedTaskIds.add(t.id!);
          }
        }
      }
      if (selectedTaskIds.isEmpty && _tasks.isNotEmpty && _tasks.first.id != null) {
        selectedTaskIds.add(_tasks.first.id!);
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit_note_outlined : Icons.assignment_turned_in_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(isEditing ? l10n.editServiceVisit : l10n.logServiceVisit),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: odoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.lastServiceOdometer,
                                suffixText: 'km',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: costController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: l10n.serviceCost,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LocationPickerField(
                        type: 'service_shop',
                        initialLocation: selectedLocation,
                        onLocationChanged: (loc) {
                          selectedLocation = loc;
                          if (loc != null) {
                            workshopController.text = loc.displayName;
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.lastServiceDate),
                        subtitle: Text(DateFormat.yMMMd().format(serviceDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_month),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: serviceDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => serviceDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.tasksCompleted,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Column(
                          children: _tasks.map((task) {
                            final taskId = task.id;
                            final isChecked = taskId != null && selectedTaskIds.contains(taskId);
                            return Column(
                              children: [
                                CheckboxListTile(
                                  title: Text(
                                    _getTaskLocalizedTitle(context, task),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  value: isChecked,
                                  dense: true,
                                  onChanged: (val) {
                                    if (taskId == null) return;
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedTaskIds.add(taskId);
                                        brandControllers.putIfAbsent(taskId, () => TextEditingController());
                                        itemCostControllers.putIfAbsent(taskId, () => TextEditingController());
                                      } else {
                                        selectedTaskIds.remove(taskId);
                                      }
                                    });
                                  },
                                ),
                                if (isChecked)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 10.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: brandControllers.putIfAbsent(
                                              taskId,
                                              () => TextEditingController(),
                                            ),
                                            decoration: InputDecoration(
                                              labelText: l10n.brandOrSpec,
                                              hintText: l10n.brandOrSpecHint,
                                              isDense: true,
                                              border: const OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: itemCostControllers.putIfAbsent(
                                              taskId,
                                              () => TextEditingController(),
                                            ),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              labelText: l10n.itemCost,
                                              suffixText: 'BDT',
                                              isDense: true,
                                              border: const OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: InputDecoration(
                          labelText: l10n.notes,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (selectedTaskIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.selectAtLeastOneTask)),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: Text(l10n.saveServiceVisit),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted && _selectedVehicleId != null) {
      final double serviceOdo = double.tryParse(odoController.text) ?? _currentOdo;
      final double? totalCost = double.tryParse(costController.text);
      final String? workshop = workshopController.text.trim().isNotEmpty
          ? workshopController.text.trim()
          : null;
      final String? notes = notesController.text.trim().isNotEmpty
          ? notesController.text.trim()
          : null;

      final items = selectedTaskIds.map((taskId) {
        final brandText = brandControllers[taskId]?.text.trim();
        final costVal = double.tryParse(itemCostControllers[taskId]?.text.trim() ?? '');
        return ServiceSessionItem(
          taskId: taskId,
          brandOrSpec: (brandText != null && brandText.isNotEmpty) ? brandText : null,
          cost: costVal,
        );
      }).toList();

      final session = ServiceSession(
        id: sessionToEdit?.id,
        vehicleId: _selectedVehicleId!,
        odometer: serviceOdo,
        serviceDate: serviceDate,
        totalCost: totalCost,
        workshopName: selectedLocation?.displayName ?? workshop,
        locationId: selectedLocation?.id ?? sessionToEdit?.locationId,
        latitude: selectedLocation?.latitude,
        longitude: selectedLocation?.longitude,
        notes: notes,
        items: items,
      );

      if (isEditing) {
        await _dbHelper.updateServiceSession(session);
      } else {
        await _dbHelper.insertServiceSession(session);
      }

      await _loadTasksForVehicle(_selectedVehicleId!);

      final currentVehicle = _vehicles.firstWhere((v) => v.id == _selectedVehicleId);
      await NotificationService.instance.scheduleMaintenanceReminders(
        vehicle: currentVehicle,
        tasks: _tasks,
        currentOdo: _currentOdo,
        dailyKmRate: _dailyKmRate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? l10n.serviceVisitUpdated : l10n.serviceVisitLogged)),
        );
      }
    }
  }

  Future<void> _showSessionBottomSheet(ServiceSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().format(session.serviceDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.serviceVisitDetails,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${session.odometer.toStringAsFixed(0)} km',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: theme.textTheme.bodyMedium),
                    if (session.workshopName != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.workshopName!,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (session.totalCost != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.serviceCost}: ${session.totalCost!.toStringAsFixed(2)} BDT',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    session.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.tasksCompleted,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: session.items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, idx) {
                      final item = session.items[idx];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle_outline, size: 18),
                        title: Text(item.taskTitle ?? 'Task #${item.taskId}'),
                        subtitle: item.brandOrSpec != null ? Text(item.brandOrSpec!) : null,
                        trailing: item.cost != null
                            ? Text(
                                '${item.cost!.toStringAsFixed(2)} BDT',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                        onPressed: () {
                          Navigator.pop(bottomSheetCtx);
                          _deleteSession(session);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.deleteServiceVisit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(bottomSheetCtx);
                          _openLogServiceDialog(sessionToEdit: session);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.editServiceVisit),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSession(ServiceSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteServiceVisit),
        content: Text(l10n.confirmDeleteServiceVisitMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && session.id != null) {
      await _dbHelper.deleteServiceSession(session.id!);
      if (_selectedVehicleId != null) {
        await _loadTasksForVehicle(_selectedVehicleId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.serviceVisitDeleted)),
        );
      }
    }
  }

  Future<void> _openTaskDialog({MaintenanceTask? taskToEdit}) async {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = taskToEdit != null;

    final titleController = TextEditingController(
      text: isEditing ? _getTaskLocalizedTitle(context, taskToEdit) : '',
    );
    final kmController = TextEditingController(
      text: isEditing ? taskToEdit.intervalKm.toStringAsFixed(0) : '4000',
    );
    final monthsController = TextEditingController(
      text: isEditing && taskToEdit.intervalMonths != null
          ? taskToEdit.intervalMonths.toString()
          : '6',
    );
    final bufferController = TextEditingController(
      text: isEditing ? taskToEdit.reminderBufferKm.toStringAsFixed(0) : '100',
    );
    final odoController = TextEditingController(
      text: isEditing
          ? taskToEdit.lastServiceOdo.toStringAsFixed(0)
          : (_currentOdo > 0 ? _currentOdo.toStringAsFixed(0) : '0'),
    );
    DateTime serviceDate = isEditing ? taskToEdit.lastServiceDate : DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? l10n.editTask : l10n.addTask),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: l10n.taskTitle,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.intervalDistance,
                        suffixText: 'km',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: monthsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.intervalMonths,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bufferController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.reminderBuffer,
                        suffixText: 'km',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: odoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.lastServiceOdometer,
                        suffixText: 'km',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.lastServiceDate),
                      subtitle: Text(DateFormat.yMMMd().format(serviceDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: serviceDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => serviceDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty ||
                        double.tryParse(kmController.text) == null) {
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      final double intervalKm = double.tryParse(kmController.text) ?? 4000.0;
      final int? intervalMonths = int.tryParse(monthsController.text);
      final double reminderBuffer = double.tryParse(bufferController.text) ?? 100.0;
      final double lastOdo = double.tryParse(odoController.text) ?? _currentOdo;

      if (isEditing) {
        final updated = taskToEdit.copyWith(
          title: titleController.text.trim(),
          intervalKm: intervalKm,
          intervalMonths: intervalMonths,
          reminderBufferKm: reminderBuffer,
          lastServiceOdo: lastOdo,
          lastServiceDate: serviceDate,
        );
        await _dbHelper.updateMaintenanceTask(updated);
      } else {
        final newTask = MaintenanceTask(
          vehicleId: _selectedVehicleId!,
          title: titleController.text.trim(),
          intervalKm: intervalKm,
          intervalMonths: intervalMonths,
          reminderBufferKm: reminderBuffer,
          lastServiceOdo: lastOdo,
          lastServiceDate: serviceDate,
        );
        await _dbHelper.insertMaintenanceTask(newTask);
      }

      if (_selectedVehicleId != null) {
        await _loadTasksForVehicle(_selectedVehicleId!);
      }
    }
  }

  Future<void> _deleteTask(MaintenanceTask task) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteTask),
        content: Text(l10n.confirmDeleteTaskMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && task.id != null) {
      await _dbHelper.deleteMaintenanceTask(task.id!);
      if (_selectedVehicleId != null) {
        await _loadTasksForVehicle(_selectedVehicleId!);
      }
    }
  }

  Future<void> _quickDoneRefuel(Vehicle vehicle) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.markQuickDone),
        content: const Text('Mark tank as filled to reset countdown?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final record = FuelRecord(
        odometer: _currentOdo,
        date: DateTime.now(),
        rate: 0.0,
        volume: vehicle.primaryFuelCapacity ?? 10.0,
        paidAmount: 0.0,
        fuelTypeId: vehicle.primaryFuelTypeId,
        vehicleId: vehicle.id!,
        isFullTank: true,
        missedPrevious: false,
        drivingCondition: DrivingCondition.mixed,
      );
      await _dbHelper.insertFuelRecord(record);
      if (_selectedVehicleId != null) {
        await _loadTasksForVehicle(_selectedVehicleId!);
      }
    }
  }

  Widget _buildFuelCountdownCard(
    BuildContext context,
    Vehicle vehicle,
    RefuelPredictionResult prediction,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;

    if (!prediction.isCalibrated) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_gas_station_outlined, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    localizations.refuelReminders,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                localizations.refuelCalibrationPrompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isAlert = prediction.isAlertActive;
    final statusColor = isAlert ? colorScheme.error : colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: isAlert
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isAlert ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_gas_station, size: 20, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            localizations.refuelReminders,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localizations.refuelRemainingCountdown(
                          prediction.primaryRemainingFuel?.toStringAsFixed(1) ?? '?',
                          prediction.totalDte?.toStringAsFixed(0) ?? '?',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isAlert ? colorScheme.errorContainer : colorScheme.secondaryContainer,
                  label: Text(
                    isAlert
                        ? localizations.statusOverdue
                        : (prediction.daysRemaining != null
                            ? localizations.projectedRefuelIn(prediction.daysRemaining!)
                            : localizations.statusHealthy),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isAlert ? colorScheme.onErrorContainer : colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: LinearProgressIndicator(
                value: ((prediction.primaryFuelPercentage ?? 0.0) / 100.0).clamp(0.0, 1.0),
                minHeight: 8.0,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _quickDoneRefuel(vehicle),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(localizations.markQuickDone),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddDataPage()),
                      );
                      if (_selectedVehicleId != null) {
                        _loadTasksForVehicle(_selectedVehicleId!);
                      }
                    },
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.local_gas_station, size: 16),
                    label: Text(localizations.doItNow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, TaskPredictionResult prediction) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (prediction.status) {
      case MaintenanceStatus.overdue:
        bg = theme.colorScheme.errorContainer;
        fg = theme.colorScheme.onErrorContainer;
        icon = Icons.error_outline;
        final overdueKm = (-prediction.kmRemaining).toStringAsFixed(0);
        label = '${l10n.statusOverdue}: ${l10n.kmOverdue(overdueKm)}';
        break;
      case MaintenanceStatus.dueSoon:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        icon = Icons.warning_amber_rounded;
        final kmLeft = prediction.kmRemaining.toStringAsFixed(0);
        label = '${l10n.statusDueSoon}: ${l10n.kmRemaining(kmLeft)}';
        break;
      case MaintenanceStatus.healthy:
        bg = theme.colorScheme.secondaryContainer;
        fg = theme.colorScheme.onSecondaryContainer;
        icon = Icons.check_circle_outline;
        final kmLeft = prediction.kmRemaining.toStringAsFixed(0);
        label = '${l10n.statusHealthy}: ${l10n.kmRemaining(kmLeft)}';
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: fg),
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getProgressColor(BuildContext context, MaintenanceStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case MaintenanceStatus.overdue:
        return theme.colorScheme.error;
      case MaintenanceStatus.dueSoon:
        return Colors.amber.shade700;
      case MaintenanceStatus.healthy:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.maintenance),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_turned_in_outlined),
            tooltip: l10n.logServiceVisit,
            onPressed: _selectedVehicleId != null ? _openLogServiceDialog : null,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addTask,
            onPressed: _selectedVehicleId != null ? () => _openTaskDialog() : null,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.build_outlined, size: 20),
              text: l10n.tasksAndReminders,
            ),
            Tab(
              icon: const Icon(Icons.history, size: 20),
              text: l10n.serviceHistory,
            ),
          ],
        ),
      ),
      drawer: const MyDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Vehicle Selector Header Card
                  if (_vehicles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedVehicleId,
                                    isExpanded: true,
                                    items: _vehicles.map((v) {
                                      return DropdownMenuItem<int>(
                                        value: v.id,
                                        child: Text(
                                          v.name,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (id) {
                                      if (id != null && id != _selectedVehicleId) {
                                        setState(() {
                                          _selectedVehicleId = id;
                                        });
                                        _loadTasksForVehicle(id);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(
                                  '${_currentOdo.toStringAsFixed(0)} km',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // TabBarView: Tasks vs Service History
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Unified Tasks & Reminders
                        () {
                          final enabledTasks = _tasks.where((t) => t.isEnabled).toList();
                          final currentVeh = _vehicles.where((v) => v.id == _selectedVehicleId).firstOrNull;
                          final hasFuel = _refuelPrediction != null && currentVeh != null;
                          final totalCards = (hasFuel ? 1 : 0) + enabledTasks.length;

                          if (totalCards == 0) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.notifications_off_outlined,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.noActiveReminders,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (currentVeh != null)
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.tune),
                                        label: Text(l10n.configureReminders),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AddVehiclePage(vehicle: currentVeh),
                                            ),
                                          );
                                          await _loadInitialData();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            itemCount: totalCards,
                            itemBuilder: (context, index) {
                              if (hasFuel && index == 0) {
                                return _buildFuelCountdownCard(context, currentVeh, _refuelPrediction!);
                              }
                              final taskIndex = hasFuel ? index - 1 : index;
                              final task = enabledTasks[taskIndex];
                              final prediction = MaintenanceCalculator.calculateTaskStatus(
                                task: task,
                                currentOdo: _currentOdo,
                                currentDate: DateTime.now(),
                                dailyKmRate: _dailyKmRate,
                              );

                              final title = _getTaskLocalizedTitle(context, task);
                              final intervalText = task.intervalMonths != null
                                  ? 'Every ${task.intervalKm.toStringAsFixed(0)} km or ${task.intervalMonths} mos'
                                  : 'Every ${task.intervalKm.toStringAsFixed(0)} km';

                              final lastDateStr = DateFormat.yMMMd().format(task.lastServiceDate);
                              final lastDoneText = l10n.lastDoneOn(
                                task.lastServiceOdo.toStringAsFixed(0),
                                lastDateStr,
                              );
                              final targetText = l10n.targetAt(prediction.targetOdo.toStringAsFixed(0));

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                  side: BorderSide(
                                    color: prediction.status == MaintenanceStatus.overdue
                                        ? theme.colorScheme.error.withValues(alpha: 0.5)
                                        : (prediction.status == MaintenanceStatus.dueSoon
                                            ? Colors.amber.shade600
                                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                                    width: prediction.status != MaintenanceStatus.healthy ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header: Title & Actions
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  intervalText,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 20),
                                            onSelected: (action) {
                                              if (action == 'edit') {
                                                _openTaskDialog(taskToEdit: task);
                                              } else if (action == 'delete') {
                                                _deleteTask(task);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text(l10n.edit),
                                              ),
                                              if (task.taskKey == null)
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                    l10n.delete,
                                                    style: TextStyle(
                                                      color: theme.colorScheme.error,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Status Chip & Action Buttons
                                      SizedBox(
                                        width: double.infinity,
                                        child: Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8.0,
                                          runSpacing: 8.0,
                                          children: [
                                            _buildStatusChip(context, prediction),
                                            Wrap(
                                              spacing: 6.0,
                                              runSpacing: 4.0,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () => _quickDone(task),
                                                  style: OutlinedButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8.0,
                                                      vertical: 4.0,
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.check, size: 14),
                                                  label: Text(l10n.markQuickDone, style: const TextStyle(fontSize: 12)),
                                                ),
                                                FilledButton.tonalIcon(
                                                  onPressed: () => _openLogServiceDialog(preSelectedTaskId: task.id),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8.0,
                                                      vertical: 4.0,
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.build_outlined, size: 14),
                                                  label: Text(l10n.doItNow, style: const TextStyle(fontSize: 12)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Progress Bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: LinearProgressIndicator(
                                          value: prediction.progressFraction.clamp(0.0, 1.0),
                                          minHeight: 8.0,
                                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _getProgressColor(context, prediction.status),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // Footnote: Last Service & Target
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastDoneText,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            targetText,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }(),

                        // Tab 2: Service History List
                        _serviceSessions.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(
                                    l10n.noServiceHistory,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                itemCount: _serviceSessions.length,
                                itemBuilder: (context, index) {
                                  final session = _serviceSessions[index];
                                  final dateStr = DateFormat.yMMMd().format(session.serviceDate);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                      side: BorderSide(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16.0),
                                      onTap: () => _showSessionBottomSheet(session),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.event_available_outlined,
                                                      size: 20,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      dateStr,
                                                      style: theme.textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Chip(
                                                      label: Text(
                                                        '${session.odometer.toStringAsFixed(0)} km',
                                                        style: theme.textTheme.labelMedium
                                                            ?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      visualDensity: VisualDensity.compact,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.more_vert,
                                                      size: 18,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            if (session.workshopName != null ||
                                                session.totalCost != null) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (session.workshopName != null)
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.storefront_outlined,
                                                            size: 16,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Flexible(
                                                            child: Text(
                                                              session.workshopName!,
                                                              style: theme
                                                                  .textTheme.bodySmall
                                                                  ?.copyWith(
                                                                color: theme.colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                              overflow: TextOverflow
                                                                  .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (session.totalCost != null)
                                                    Text(
                                                      '${session.totalCost!.toStringAsFixed(2)} BDT',
                                                      style: theme
                                                          .textTheme.bodyMedium
                                                          ?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                        color:
                                                            theme.colorScheme.primary,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                            if (session.items.isNotEmpty) ...[
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 6.0,
                                                runSpacing: 4.0,
                                                children: session.items.map((item) {
                                                  final label = item.brandOrSpec != null &&
                                                          item.brandOrSpec!.isNotEmpty
                                                      ? '${item.taskTitle ?? 'Task'}: ${item.brandOrSpec}'
                                                      : (item.taskTitle ??
                                                          'Task #${item.taskId}');
                                                  return Chip(
                                                    avatar: const Icon(Icons.check,
                                                        size: 14),
                                                    label: Text(label),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    side: BorderSide.none,
                                                    backgroundColor: theme.colorScheme
                                                        .surfaceContainerHighest,
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          if (session.notes != null &&
                                              session.notes!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              session.notes!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                fontStyle: FontStyle.italic,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: AppSettings.adsEnabled ? const BannerAdWidget() : const SizedBox(),
    );
  }
}
