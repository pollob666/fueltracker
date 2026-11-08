// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

class HomeWidgetService {
  static const String appGroupId = 'group.com.pollob666.fueltracker';
  static const String androidWidgetProvider = 'RefuelGlanceWidgetProvider';

  /// Updates home screen glance widget with latest vehicle and fuel telemetry.
  static Future<void> updateGlanceWidget({
    required Vehicle vehicle,
    required List<FuelRecord> fuelRecords,
  }) async {
    try {
      final sortedRecords = MileageCalculator.sortChronological(fuelRecords);
      final lastRecord = sortedRecords.isNotEmpty ? sortedRecords.last : null;

      final prediction = MileageCalculator.calculateRefuelPrediction(
        vehicle: vehicle,
        records: sortedRecords,
      );
      final remainingFuel = prediction.primaryRemainingFuel;
      final dte = prediction.totalDte ?? prediction.primaryDte;

      final dteText = dte != null ? '${dte.toStringAsFixed(0)} km' : '-- km';
      final remainingFuelText = remainingFuel != null ? '${remainingFuel.toStringAsFixed(1)} L' : '-- L';
      final odoText = lastRecord != null ? '${lastRecord.odometer.toStringAsFixed(0)} km' : '-- km';
      final dateText = lastRecord != null ? DateFormat.MMMd().format(lastRecord.date) : 'No Records';

      await HomeWidget.saveWidgetData<String>('widget_vehicle_name', vehicle.name);
      await HomeWidget.saveWidgetData<String>('widget_remaining_fuel', remainingFuelText);
      await HomeWidget.saveWidgetData<String>('widget_dte_text', dteText);
      await HomeWidget.saveWidgetData<String>('widget_last_odo', odoText);
      await HomeWidget.saveWidgetData<String>('widget_last_date', dateText);

      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );
    } catch (e) {
      debugPrint('Failed to update glance widget: $e');
    }
  }
}
