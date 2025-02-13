import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  _ExportPageState createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _exporting = false;
  String _message = "";

  Future<void> _exportData() async {
    setState(() {
      _exporting = true;
      _message = "";
    });
    List<FuelRecord> records =
    await DatabaseHelper.instance.getFuelRecords();
    // Create CSV data
    List<List<String>> csvData = [
      ["Date", "Odometer", "Fuel Type", "Rate", "Volume", "Paid Amount"],
      ...records.map((r) => [
        r.date.toIso8601String(),
        r.odometer.toStringAsFixed(2),
        r.fuelType,
        r.rate.toStringAsFixed(2),
        r.volume.toStringAsFixed(2),
        r.paidAmount.toStringAsFixed(2),
      ])
    ];

    String csv = const ListToCsvConverter().convert(csvData);

    // Get folder path based on current settings.
    String folderPath = "";
    if (AppSettings.storageOption == 'Local') {
      folderPath = AppSettings.localFolderPath;
    } else if (AppSettings.storageOption == 'Google Drive') {
      folderPath = AppSettings.googleDriveFolderPath;
    } else if (AppSettings.storageOption == 'Dropbox') {
      folderPath = AppSettings.dropboxFolderPath;
    }

    if (folderPath.isEmpty) {
      setState(() {
        _exporting = false;
        _message = "Folder path not set in settings.";
      });
      return;
    }

    // Create a file name with timestamp.
    String fileName =
        "fuel_data_${DateTime.now().millisecondsSinceEpoch}.csv";
    File file = File("$folderPath/$fileName");
    try {
      await file.writeAsString(csv);
      setState(() {
        _exporting = false;
        _message = "Data exported to $fileName";
      });
    } catch (e) {
      setState(() {
        _exporting = false;
        _message = "Failed to export: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Export Data")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _exporting ? null : _exportData,
              child: Text("Export to CSV"),
            ),
            SizedBox(height: 16),
            Text(_message),
          ],
        ),
      ),
    );
  }
}
