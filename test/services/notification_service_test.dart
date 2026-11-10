// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class FakeNotificationsPlugin extends Fake implements FlutterLocalNotificationsPlugin {
  bool zonedScheduleCalled = false;
  AndroidScheduleMode? lastScheduleMode;
  bool shouldThrowOnExact = false;

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    AndroidScheduleMode? androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    zonedScheduleCalled = true;
    lastScheduleMode = androidScheduleMode;
    if (shouldThrowOnExact && androidScheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
      throw Exception('SecurityException: Exact alarms not permitted');
    }
  }

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() {
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  group('NotificationService Timezone Change Detection', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes and records current timezone offset on first run without rescheduling', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final changed = await service.checkTimezoneChangeAndReschedule();
      expect(changed, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotificationService.prefKeyTimezoneOffset), equals(DateTime.now().timeZoneOffset.inMinutes));
      expect(prefs.getString(NotificationService.prefKeyTimezoneName), equals(tz.local.name));
    });

    test('returns false when timezone offset and name match stored values', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final currentOffset = DateTime.now().timeZoneOffset.inMinutes;
      final currentName = tz.local.name;
      SharedPreferences.setMockInitialValues({
        NotificationService.prefKeyTimezoneOffset: currentOffset,
        NotificationService.prefKeyTimezoneName: currentName,
      });

      final changed = await service.checkTimezoneChangeAndReschedule();
      expect(changed, isFalse);
    });

    test('detects timezone offset change when stored offset differs', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final differentOffset = DateTime.now().timeZoneOffset.inMinutes + 120;
      SharedPreferences.setMockInitialValues({
        NotificationService.prefKeyTimezoneOffset: differentOffset,
        NotificationService.prefKeyTimezoneName: tz.local.name,
      });

      final changed = await service.checkTimezoneChangeAndReschedule();
      expect(changed, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NotificationService.prefKeyTimezoneOffset), equals(DateTime.now().timeZoneOffset.inMinutes));
    });
  });

  group('NotificationService Permissions & Inexact Fallback', () {
    test('areNotificationsEnabled defaults gracefully when platform implementation is null', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final enabled = await service.areNotificationsEnabled();
      expect(enabled, isTrue);
    });

    test('canScheduleExactAlarms defaults gracefully when platform implementation is null', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final canSchedule = await service.canScheduleExactAlarms();
      expect(canSchedule, isTrue);
    });

    test('requestNotificationPermissions returns default when platform implementation is null', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final result = await service.requestNotificationPermissions();
      expect(result, isTrue);
    });

    test('requestExactAlarmsPermission returns default when platform implementation is null', () async {
      final fakePlugin = FakeNotificationsPlugin();
      final service = NotificationService.custom(fakePlugin);

      final result = await service.requestExactAlarmsPermission();
      expect(result, isTrue);
    });
  });
}
