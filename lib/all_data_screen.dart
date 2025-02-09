import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'fuel_tracker_model.dart';

class AllDataScreen extends StatelessWidget {
  const AllDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FuelTrackerModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('All Data')),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Odometer')),
            DataColumn(label: Text('Fuel Type')),
            DataColumn(label: Text('Price (BDT)')),
            DataColumn(label: Text('Volume (L)')),
            DataColumn(label: Text('Paid (BDT)')),
          ],
          rows: model.data.map((entry) {
            final paidAmount = entry['paidAmount'];
            final expectedAmount = entry['fuelPrice'] * entry['fuelVolume'];
            final color = paidAmount < expectedAmount
                ? Colors.green
                : paidAmount > expectedAmount
                ? Colors.pink
                : Colors.white;

            return DataRow(
              color: WidgetStateProperty.all(color),
              cells: [
                DataCell(Text(entry['date'].toString())),
                DataCell(Text(entry['odometerReading'].toString())),
                DataCell(Text(entry['fuelType'])),
                DataCell(Text(entry['fuelPrice'].toString())),
                DataCell(Text(entry['fuelVolume'].toString())),
                DataCell(Text(entry['paidAmount'].toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}