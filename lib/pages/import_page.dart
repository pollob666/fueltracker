import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
// import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
// import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/services/storage_service.dart';

class ImportPage extends StatefulWidget {
  @override
  _ImportPageState createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<List<dynamic>> _previewData = [];
  String? _filePath;
  final StorageService _storageService = StorageService(); // Correct instantiation

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv']
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
      });
      print('File Path Selected: $_filePath'); // ADD THIS LINE
      _previewFile();
    }
  }

  Future<void> _previewFile() async {
    if (_filePath == null) return;

    try {
      final file = File(_filePath!);
      print('Attempting to read file: $_filePath');
      final content = await file.readAsString();
      print('File content read successfully. Content preview (first 100 chars):\n${content.substring(0, content.length > 100 ? 100 : content.length)}');

      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n', // Explicitly set end-of-line character to newline
      ).convert(content);

      if (csvTable.isNotEmpty) {
        setState(() {
          _previewData = csvTable;
        });
        print('CSV data parsed and _previewData updated. Row count: ${_previewData.length}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSV file is empty or incorrectly formatted.'))
        );
      }
    } catch (e) {
      print('Error reading CSV file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading CSV file: $e'))
      );
    }
  }

  Future<void> _importData() async {
    if (_previewData.isEmpty) return;

    try {
      List<FuelRecord> entries = _previewData.skip(1).map((row) {
        print('Processing row: $row'); // DEBUG: Print each row being processed
        try {
          return FuelRecord(
            date: DateTime.parse(row[0]),
            odometer: double.tryParse(row[1].toString()) ?? 0,
            fuelType: row[2].toString(),
            rate: double.tryParse(row[3].toString()) ?? 0.0,
            volume: double.tryParse(row[4].toString()) ?? 0.0,
            paidAmount: double.tryParse(row[5].toString()) ?? 0.0,
          );
        } catch (e) {
          print('Error parsing row: $row - Error: $e'); // DEBUG: Print row and parsing error
          return null; // Or throw error, or handle as appropriate for your app - returning null will filter out invalid entries below
        }
      }).whereType<FuelRecord>().toList(); // Use whereType to filter out nulls if you return null in case of error

      print('Entries created. Count: ${entries.length}'); // DEBUG: Print the number of entries created
      // Print the first entry to inspect its data
      if (entries.isNotEmpty) {
        print('First Entry Date: ${entries.first.date}, Odometer: ${entries.first.odometer}, FuelType: ${entries.first.fuelType}, Rate: ${entries.first.rate}, Volume: ${entries.first.volume}, PaidAmount: ${entries.first.paidAmount}');
      }


      await _storageService.saveEntries(entries);
      print('StorageService.saveEntries called successfully.'); // DEBUG: Check if saveEntries is reached

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data Imported Successfully!'))
      );

      setState(() {
        _previewData = [];
        _filePath = null;
      });
    } catch (e) {
      print('Error in _importData (outer try-catch): $e'); // DEBUG: Catch any errors in _importData itself
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing data: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import Data')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickFile,
            child: Text('Select CSV File'),
          ),
          if (_filePath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Selected File: $_filePath', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          Expanded(
            child: _previewData.isNotEmpty
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Odometer')),
                  DataColumn(label: Text('Fuel Type')),
                  DataColumn(label: Text('Rate (BDT)')),
                  DataColumn(label: Text('Volume (L)')),
                  DataColumn(label: Text('Amount (BDT)')),
                ],
                rows: _previewData.skip(1).map((row) {
                  return DataRow(cells: row.map((cell) => DataCell(Text(cell.toString()))).toList());
                }).toList(),
              ),
            )
                : Center(child: Text('No Data Preview Available')),
          ),
          if (_previewData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _importData,
                child: Text('Import Data'),
              ),
            ),
        ],
      ),
    );
  }
}