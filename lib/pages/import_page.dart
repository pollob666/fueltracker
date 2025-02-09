import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:file_picker/file_picker.dart';

class ImportPage extends StatefulWidget {
  @override
  _ImportPageState createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _importing = false;
  String _message = "";

  Future<void> _importData() async {
    setState(() {
      _importing = true;
      _message = "";
    });
    // Let the user pick a CSV file.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<List<dynamic>> csvTable =
      const CsvToListConverter().convert(content);
      if (csvTable.length < 2) {
        setState(() {
          _importing = false;
          _message = "No data found in CSV.";
        });
        return;
      }
      // Remove header row.
      csvTable.removeAt(0);
      // Insert each row as a FuelRecord.
      for (var row in csvTable) {
        try {
          FuelRecord record = FuelRecord(
            date: DateTime.parse(row[0].toString()),
            odometer: double.parse(row[1].toString()),
            fuelType: row[2].toString(),
            rate: double.parse(row[3].toString()),
            volume: double.parse(row[4].toString()),
            paidAmount: double.parse(row[5].toString()),
          );
          await DatabaseHelper.instance.insertFuelRecord(record);
        } catch (e) {
          // Optionally handle errors for each row.
        }
      }
      setState(() {
        _importing = false;
        _message = "Data imported successfully.";
      });
    } else {
      setState(() {
        _importing = false;
        _message = "File selection canceled.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Import Data")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _importing ? null : _importData,
              child: Text("Import CSV"),
            ),
            SizedBox(height: 16),
            Text(_message),
          ],
        ),
      ),
    );
  }
}
