import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart'; // Import localization

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _exporting = false;
  String _message = "";

  Future<void> _exportData() async {
    setState(() {
      _exporting = true;
      _message = "";
    });
    List<FuelRecord> records = await DatabaseHelper.instance.getFuelRecords();

    List<List<String>> csvData = [
      [
        AppLocalizations.of(context).dateAndTime, // Localized
        AppLocalizations.of(context).odometerReading, // Localized
        AppLocalizations.of(context).fuelType, // Localized
        AppLocalizations.of(context).fuelPriceRate, // Localized
        AppLocalizations.of(context).totalVolume, // Localized
        AppLocalizations.of(context).paidAmount, // Localized
      ],
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
        _message = AppLocalizations.of(context).folderPathNotSetInSettings; // Localized
      });
      return;
    }

    String fileName = "fuel_data_${DateTime.now().millisecondsSinceEpoch}.csv";
    File file = File("$folderPath/$fileName");
    try {
      await file.writeAsString(csv);
      setState(() {
        _exporting = false;
        _message = "${AppLocalizations.of(context).dataExportedTo} $fileName"; // Localized
      });
    } catch (e) {
      setState(() {
        _exporting = false;
        _message = "${AppLocalizations.of(context).failedToExport}: $e"; // Localized
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).exportToCSV)), // Localized
      drawer: const MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _exporting ? null : _exportData,
              child: Text(AppLocalizations.of(context).exportToCSV), // Localized
            ),
            const SizedBox(height: 16),
            Text(_message), // Message is already localized in _exportData
          ],
        ),
      ),
    );
  }
}