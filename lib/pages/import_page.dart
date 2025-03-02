import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/services/storage_service.dart';
import 'package:fuel_tracker/l10n/l10n.dart'; // Import localization

class ImportPage extends StatefulWidget {
  const ImportPage({super.key}); // Added key parameter

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  List<List<dynamic>> _previewData = [];
  String? _filePath;
  final StorageService _storageService = StorageService();

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path!;
      });
      _previewFile();
    }
  }

  Future<void> _previewFile() async {
    if (_filePath == null) return;

    try {
      final file = File(_filePath!);
      final content = await file.readAsString();

      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
      ).convert(content);

      if (csvTable.isNotEmpty) {
        setState(() {
          _previewData = csvTable;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).csvFileEmptyOrIncorrectlyFormatted))); // Localized
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context).errorReadingCSVFile}: $e"))); // Localized
    }
  }

  Future<void> _importData() async {
    if (_previewData.isEmpty) return;

    try {
      List<FuelRecord> entries = _previewData.skip(1).map((row) {
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
          return null;
        }
      }).whereType<FuelRecord>().toList();

      await _storageService.saveEntries(entries);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).dataImportedSuccessfully))); // Localized

      setState(() {
        _previewData = [];
        _filePath = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context).errorImportingData}: $e"))); // Localized
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).import)), // Localized
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickFile,
            child: Text(AppLocalizations.of(context).selectCSVFile), // Localized
          ),
          if (_filePath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                  '${AppLocalizations.of(context).selectedFile}: $_filePath',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)), // Localized
            ),
          Expanded(
            child: _previewData.isNotEmpty
                ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(
                      AppLocalizations.of(context).dateAndTime)), // Localized
                  DataColumn(label: Text(
                      AppLocalizations.of(context).odometerReading)), // Localized
                  DataColumn(label: Text(
                      AppLocalizations.of(context).fuelType)), // Localized
                  DataColumn(label: Text(
                      AppLocalizations.of(context).fuelPriceRate)), // Localized
                  DataColumn(label: Text(
                      AppLocalizations.of(context).totalVolume)), // Localized
                  DataColumn(label: Text(
                      AppLocalizations.of(context).paidAmount)), // Localized
                ],
                rows: _previewData.skip(1).map((row) {
                  return DataRow(cells: row
                      .map((cell) => DataCell(Text(cell.toString())))
                      .toList());
                }).toList(),
              ),
            )
                : Center(
                child: Text(AppLocalizations.of(context)
                    .noDataPreviewAvailable)), // Localized
          ),
          if (_previewData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: _importData,
                child: Text(AppLocalizations.of(context).importData), // Localized
              ),
            ),
        ],
      ),
    );
  }
}