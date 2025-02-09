import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'add_data_page.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<FuelRecord> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    var recs = await DatabaseHelper.instance.getFuelRecords();
    setState(() {
      records = recs;
    });
  }

  @override
  Widget build(BuildContext context) {
    double lastMileage = 0;
    double runningAverage = 0;
    if (records.length >= 2) {
      List<double> mileages = [];
      for (int i = 1; i < records.length; i++) {
        double diff = records[i].odometer - records[i - 1].odometer;
        double mileage = diff / records[i].volume;
        mileages.add(mileage);
      }
      lastMileage = mileages.last;
      runningAverage = mileages.reduce((a, b) => a + b) / mileages.length;
    }

    double lastRefuelVolume = records.isNotEmpty ? records.last.volume : 0;

    return Scaffold(
      appBar: AppBar(title: Text("Fuel Consumption Tracker")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Two side-by-side cards: running average and last mileage
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("Running Average Mileage"),
                          SizedBox(height: 8),
                          Text(
                            runningAverage.toStringAsFixed(2) + " km/l",
                            style: TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("Last Time Mileage"),
                          SizedBox(height: 8),
                          Text(
                            lastMileage.toStringAsFixed(2) + " km/l",
                            style: TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Card showing last refuel volume
            Card(
              child: ListTile(
                title: Text("Last Refuel Volume"),
                subtitle:
                Text(lastRefuelVolume.toStringAsFixed(2) + " litres"),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AddDataPage()));
                _loadRecords(); // Refresh after adding new record.
              },
              child: Text("Add New Data"),
            ),
          ],
        ),
      ),
    );
  }
}
