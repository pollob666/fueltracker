// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/utils/maintenance_calculator.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Request Android 13+ notification permissions
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  /// Cancels any scheduled refuel reminder for the given vehicle ID.
  Future<void> cancelVehicleReminder(int vehicleId) async {
    await _notificationsPlugin.cancel(id: vehicleId);
  }

  /// Evaluates and schedules a 09:00 AM notification for the vehicle on the projected low-fuel date.
  Future<void> scheduleRefuelReminder({
    required Vehicle vehicle,
    required RefuelPredictionResult prediction,
  }) async {
    if (vehicle.id == null) return;
    final int notifId = vehicle.id!;

    // Cancel prior schedule
    await _notificationsPlugin.cancel(id: notifId);

    if (!prediction.hasAnyReminderEnabled || !prediction.isCalibrated) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'refuel_reminders',
      'Refuel Reminders',
      channelDescription: 'Alerts before vehicle fuel level reaches critical reserve',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final String title = 'Low Fuel Alert: ${vehicle.name}';
    String body = 'Your vehicle is approaching low fuel reserve.';
    if (prediction.primaryRemainingFuel != null) {
      body =
          '${vehicle.name} has ~${prediction.primaryRemainingFuel!.toStringAsFixed(1)} L remaining (~${prediction.totalDte?.toStringAsFixed(0) ?? "?"} km range). Refuel soon!';
    }

    // If currently already below threshold, trigger immediate warning
    if (prediction.isAlertActive) {
      await _notificationsPlugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: details,
      );
      return;
    }

    // Schedule daily notification at configured time on projected day
    if (prediction.daysRemaining != null && prediction.daysRemaining! > 0) {
      final now = DateTime.now();
      final targetDate = now.add(Duration(days: prediction.daysRemaining!));

      final scheduledDateTime = tz.TZDateTime(
        tz.local,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        AppSettings.reminderHour,
        AppSettings.reminderMinute,
      );

      // If scheduled time today has already passed, schedule 5 minutes from now if due today
      final tz.TZDateTime effectiveSchedule =
          scheduledDateTime.isBefore(tz.TZDateTime.now(tz.local))
              ? tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5))
              : scheduledDateTime;

      await _scheduleZonedNotification(
        id: notifId,
        title: title,
        body: body,
        scheduledDate: effectiveSchedule,
        notificationDetails: details,
      );
    }
  }

  /// Generates a non-colliding notification ID for vehicle maintenance tasks.
  static int getMaintenanceNotifId(int vehicleId, int taskId) =>
      100000 + (vehicleId * 1000) + (taskId % 1000);

  /// Cancels any scheduled maintenance reminder for a task.
  Future<void> cancelMaintenanceReminder(int vehicleId, int taskId) async {
    await _notificationsPlugin.cancel(id: getMaintenanceNotifId(vehicleId, taskId));
  }

  /// Evaluates and schedules individual notifications for upcoming or overdue maintenance tasks.
  Future<void> scheduleMaintenanceReminders({
    required Vehicle vehicle,
    required List<MaintenanceTask> tasks,
    required double currentOdo,
    required double dailyKmRate,
  }) async {
    if (vehicle.id == null) return;
    final int vehicleId = vehicle.id!;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'maintenance_reminders',
      'Maintenance Reminders',
      channelDescription: 'Alerts for upcoming and overdue vehicle maintenance tasks',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final now = DateTime.now();

    for (final task in tasks) {
      if (task.id == null || !task.isEnabled) continue;
      final notifId = getMaintenanceNotifId(vehicleId, task.id!);

      // Cancel prior notification for this task
      await _notificationsPlugin.cancel(id: notifId);

      final prediction = MaintenanceCalculator.calculateTaskStatus(
        task: task,
        currentOdo: currentOdo,
        currentDate: now,
        dailyKmRate: dailyKmRate,
      );

      // 1. If currently overdue, trigger immediate alert
      if (prediction.status == MaintenanceStatus.overdue) {
        final overdueText = prediction.kmRemaining <= 0
            ? '${(-prediction.kmRemaining).toStringAsFixed(0)} km'
            : 'calendar limit exceeded';
        await _notificationsPlugin.show(
          id: notifId,
          title: 'Maintenance Overdue: ${task.title}',
          body: '${vehicle.name} is overdue for ${task.title} ($overdueText). Please service soon!',
          notificationDetails: details,
        );
        continue;
      }

      // 2. If due soon, trigger immediate warning
      if (prediction.status == MaintenanceStatus.dueSoon) {
        await _notificationsPlugin.show(
          id: notifId,
          title: 'Maintenance Due Soon: ${task.title}',
          body: '${vehicle.name} is due for ${task.title} in ~${prediction.kmRemaining.toStringAsFixed(0)} km.',
          notificationDetails: details,
        );
        continue;
      }

      // 3. Otherwise schedule notification at configured time on projected due date
      if (prediction.daysRemaining != null && prediction.daysRemaining! > 0) {
        final targetDate = now.add(Duration(days: prediction.daysRemaining!));
        final scheduledDateTime = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          AppSettings.reminderHour,
          AppSettings.reminderMinute,
        );

        final tz.TZDateTime effectiveSchedule =
            scheduledDateTime.isBefore(tz.TZDateTime.now(tz.local))
                ? tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5))
                : scheduledDateTime;

        await _scheduleZonedNotification(
          id: notifId,
          title: 'Maintenance Reminder: ${task.title}',
          body: '${vehicle.name} is projected to need ${task.title} today.',
          scheduledDate: effectiveSchedule,
          notificationDetails: details,
        );
      }
    }
  }

  /// Schedules a zoned alarm, falling back to inexact alarm if exact alarms are not permitted on Android 12+.
  Future<void> _scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Fallback to inexact mode if exact alarms not permitted on Android 12+ (API 31+)
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Reschedules reminders for all vehicles based on current settings and records.
  Future<void> rescheduleAllReminders() async {
    final vehicles = await DatabaseHelper.instance.getVehicles();
    final allRecords = await DatabaseHelper.instance.getFuelRecords();
    allRecords.sort((a, b) => a.date.compareTo(b.date));

    for (final vehicle in vehicles) {
      if (vehicle.id == null) continue;
      final vehicleRecords =
          allRecords.where((r) => r.vehicleId == vehicle.id).toList();

      // Reschedule refuel reminders
      if (vehicle.volumeReminderEnabled || vehicle.distanceReminderEnabled) {
        final prediction = MileageCalculator.calculateRefuelPrediction(
          vehicle: vehicle,
          records: vehicleRecords,
        );
        await scheduleRefuelReminder(vehicle: vehicle, prediction: prediction);
      } else {
        await cancelVehicleReminder(vehicle.id!);
      }

      // Reschedule maintenance reminders
      final tasks = await DatabaseHelper.instance.getMaintenanceTasks(vehicle.id!);
      double maxOdo = 0.0;
      if (vehicleRecords.isNotEmpty) {
        maxOdo = vehicleRecords.map((r) => r.odometer).reduce((a, b) => a > b ? a : b);
      }
      final dailyAvg = MileageCalculator.calculateDailyAverageRun(vehicleRecords);
      final rate = dailyAvg > 0 ? dailyAvg : 20.0;
      await scheduleMaintenanceReminders(
        vehicle: vehicle,
        tasks: tasks,
        currentOdo: maxOdo,
        dailyKmRate: rate,
      );
    }
  }
}
