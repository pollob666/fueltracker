// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/foundation.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/database/database_helper.dart'; // Import DatabaseHelper

class StorageService {
  final dbHelper = DatabaseHelper(); // Instantiate DatabaseHelper

  Future<List<FuelRecord>> loadEntries() async {
    debugPrint('StorageService: loadEntries - Start loading entries from database...'); // DEBUG: Start loadEntries
    try {
      final records = await dbHelper.getFuelRecords();
      debugPrint('StorageService: loadEntries - Retrieved ${records.length} records from database.'); // DEBUG: Record count
      return records;
    } catch (e) {
      debugPrint('StorageService: loadEntries - Error loading from database: $e'); // DEBUG: Database load error
      return [];
    }
  }

  Future<void> saveEntries(List<FuelRecord> entries) async {
    debugPrint('StorageService: saveEntries - Start saving ${entries.length} entries to database...'); // DEBUG: Start saveEntries
    try {
      for (final record in entries) {
        debugPrint('StorageService: saveEntries - Inserting record: ${record.toMap()}'); // DEBUG: Log record being inserted (using toMap for debugging)
        await dbHelper.insertFuelRecord(record);
      }
      debugPrint('StorageService: saveEntries - Successfully saved all entries to database.'); // DEBUG: Save success
    } catch (e) {
      debugPrint('StorageService: saveEntries - Error saving to database: $e'); // DEBUG: Database save error
    }
  }
}