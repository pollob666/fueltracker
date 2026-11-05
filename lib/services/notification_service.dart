// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
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

      await _notificationsPlugin.zonedSchedule(
        id: notifId,
        title: title,
        body: body,
        scheduledDate: effectiveSchedule,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
      if (!vehicle.volumeReminderEnabled && !vehicle.distanceReminderEnabled) {
        await cancelVehicleReminder(vehicle.id!);
        continue;
      }
      final vehicleRecords =
          allRecords.where((r) => r.vehicleId == vehicle.id).toList();
      final prediction =
          MileageCalculator.calculateRefuelPrediction(
        vehicle: vehicle,
        records: vehicleRecords,
      );
      await scheduleRefuelReminder(vehicle: vehicle, prediction: prediction);
    }
  }
}
