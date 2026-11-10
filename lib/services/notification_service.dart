// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/maintenance_task.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/utils/maintenance_calculator.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String prefKeyTimezoneOffset = 'notification_last_tz_offset_minutes';
  static const String prefKeyTimezoneName = 'notification_last_tz_name';

  NotificationService._internal();

  @visibleForTesting
  NotificationService.custom(this._notificationsPlugin);

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

    // Request Android 13+ POST_NOTIFICATIONS runtime permissions
    await requestNotificationPermissions();

    // Check if timezone has changed and reschedule if necessary
    await checkTimezoneChangeAndReschedule();

    _isInitialized = true;
  }

  /// Requests notification runtime permissions for Android 13+ (POST_NOTIFICATIONS) and iOS.
  Future<bool?> requestNotificationPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission();
    }
    final iosImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      return await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return true;
  }

  /// Checks if notifications are enabled for the application.
  Future<bool> areNotificationsEnabled() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final enabled = await androidImplementation.areNotificationsEnabled();
      return enabled ?? false;
    }
    return true;
  }

  /// Checks if exact alarms can be scheduled (Android 12+ / API 31+).
  /// Google Play Developer Policy restricts USE_EXACT_ALARM to alarm clocks and timers.
  /// For vehicle reminders, SCHEDULE_EXACT_ALARM is used, which can be checked or requested.
  Future<bool> canScheduleExactAlarms() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final canSchedule =
          await androidImplementation.canScheduleExactNotifications();
      return canSchedule ?? true;
    }
    return true;
  }

  /// Requests permission to schedule exact alarms (navigates user to system settings on Android 13/14).
  Future<bool?> requestExactAlarmsPermission() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.requestExactAlarmsPermission();
    }
    return true;
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

  /// Schedules a zoned alarm, proactively checking exact alarm permission and
  /// falling back to inexact alarm if denied, unsupported, or if SecurityException occurs.
  Future<void> _scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
  }) async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    bool canScheduleExact = true;
    if (androidImplementation != null) {
      try {
        final permitted =
            await androidImplementation.canScheduleExactNotifications();
        if (permitted != null) {
          canScheduleExact = permitted;
        }
      } catch (_) {
        canScheduleExact = false;
      }
    }

    if (canScheduleExact) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        return;
      } catch (_) {
        // Fallback to inexact mode if exact alarms throw SecurityException
      }
    }

    // Inexact fallback when exact alarms are denied, revoked, or throw SecurityException
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Checks if the device timezone or UTC offset changed since the last schedule.
  /// If changed, reschedules all reminders and updates stored timezone metadata.
  Future<bool> checkTimezoneChangeAndReschedule() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int currentOffset = DateTime.now().timeZoneOffset.inMinutes;
      final String currentName = tz.local.name;

      final int? lastOffset = prefs.getInt(prefKeyTimezoneOffset);
      final String? lastName = prefs.getString(prefKeyTimezoneName);

      if (lastOffset == null || lastName == null) {
        await prefs.setInt(prefKeyTimezoneOffset, currentOffset);
        await prefs.setString(prefKeyTimezoneName, currentName);
        return false;
      }

      if (lastOffset != currentOffset || lastName != currentName) {
        // Timezone or offset changed; re-evaluate and reschedule all active reminders
        try {
          await rescheduleAllReminders();
        } catch (_) {}
        await prefs.setInt(prefKeyTimezoneOffset, currentOffset);
        await prefs.setString(prefKeyTimezoneName, currentName);
        return true;
      }
    } catch (_) {
      // Silently ignore preference IO errors
    }
    return false;
  }

  /// Reschedules reminders for all vehicles based on current settings and records.
  Future<void> rescheduleAllReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prefKeyTimezoneOffset, DateTime.now().timeZoneOffset.inMinutes);
      await prefs.setString(prefKeyTimezoneName, tz.local.name);
    } catch (_) {}

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
