import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart'; // Import localization

class AllDataPage extends StatefulWidget {
  const AllDataPage({super.key});

  @override
  State<AllDataPage> createState() => _AllDataPageState();
}

class _AllDataPageState extends State<AllDataPage> {
  List<FuelRecord> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    List<FuelRecord> recs = await DatabaseHelper.instance.getFuelRecords();
    setState(() {
      records = recs;
    });
  }

  Color getRowColor(FuelRecord record) {
    double expected = record.volume * record.rate;
    if (record.paidAmount < expected) return Colors.green[200]!;
    if (record.paidAmount > expected) return Colors.pink[200]!;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context); // Get the localizations

    return Scaffold(
      appBar: AppBar(title: Text(localizations.allData)), // Use localizations
      drawer: const MyDrawer(),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text(localizations.dateAndTime)), // Use localizations
            DataColumn(label: Text(localizations.odometerReading)), // Use localizations
            DataColumn(label: Text(localizations.fuelType)), // Use localizations
            DataColumn(label: Text(localizations.fuelPriceRate)), // Use localizations
            DataColumn(label: Text(localizations.totalVolume)), // Use localizations
            DataColumn(label: Text(localizations.paidAmount)), // Use localizations
          ],
          rows: records.map((record) => DataRow(
            color: WidgetStateProperty.resolveWith<Color?>(
                    (states) => getRowColor(record)),
            cells: [
              DataCell(Text(record.date.toLocal().toString().substring(0, 16))),
              DataCell(Text(record.odometer.toStringAsFixed(2))),
              DataCell(Text(record.fuelType)),
              DataCell(Text(record.rate.toStringAsFixed(2))),
              DataCell(Text(record.volume.toStringAsFixed(2))),
              DataCell(Text(record.paidAmount.toStringAsFixed(2))),
            ],
          )).toList(),
        ),
      ),
    );
  }
}