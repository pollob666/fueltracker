import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';

class AllDataPage extends StatefulWidget {
  @override
  _AllDataPageState createState() => _AllDataPageState();
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

  // Color rows based on paid amount vs. expected (volume * rate)
  Color getRowColor(FuelRecord record) {
    double expected = record.volume * record.rate;
    if (record.paidAmount < expected) return Colors.green[200]!;
    if (record.paidAmount > expected) return Colors.pink[200]!;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("All Data")),
      drawer: MyDrawer(),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text("Date")),
            DataColumn(label: Text("Odometer")),
            DataColumn(label: Text("Fuel Type")),
            DataColumn(label: Text("Rate")),
            DataColumn(label: Text("Volume")),
            DataColumn(label: Text("Paid Amount")),
          ],
          rows: records
              .map(
                (record) => DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                      (states) => getRowColor(record)),
              cells: [
                DataCell(Text(record.date
                    .toLocal()
                    .toString()
                    .substring(0, 16))),
                DataCell(Text(record.odometer.toStringAsFixed(2))),
                DataCell(Text(record.fuelType)),
                DataCell(Text(record.rate.toStringAsFixed(2))),
                DataCell(Text(record.volume.toStringAsFixed(2))),
                DataCell(Text(record.paidAmount.toStringAsFixed(2))),
              ],
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}
