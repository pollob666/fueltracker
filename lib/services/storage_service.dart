import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/database/database_helper.dart'; // Import DatabaseHelper

class StorageService {
  final dbHelper = DatabaseHelper(); // Instantiate DatabaseHelper

  Future<List<FuelRecord>> loadEntries() async {
    print('StorageService: loadEntries - Start loading entries from database...'); // DEBUG: Start loadEntries
    try {
      final records = await dbHelper.getFuelRecords();
      print('StorageService: loadEntries - Retrieved ${records.length} records from database.'); // DEBUG: Record count
      return records;
    } catch (e) {
      print('StorageService: loadEntries - Error loading from database: $e'); // DEBUG: Database load error
      return [];
    }
  }

  Future<void> saveEntries(List<FuelRecord> entries) async {
    print('StorageService: saveEntries - Start saving ${entries.length} entries to database...'); // DEBUG: Start saveEntries
    try {
      for (final record in entries) {
        print('StorageService: saveEntries - Inserting record: ${record.toMap()}'); // DEBUG: Log record being inserted (using toMap for debugging)
        await dbHelper.insertFuelRecord(record);
      }
      print('StorageService: saveEntries - Successfully saved all entries to database.'); // DEBUG: Save success
    } catch (e) {
      print('StorageService: saveEntries - Error saving to database: $e'); // DEBUG: Database save error
    }
  }
}