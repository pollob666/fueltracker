import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'add_data_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

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

  double calculateLastMileage(List<FuelRecord> records) {
    if (records.length < 2) {
      return 0;
    }
    double lastOdometer = records.last.odometer;
    double previousOdometer = records[records.length - 2].odometer;
    // double previousVolume = records[records.length - 2].volume;
    //fixed the calculation to use latest volume
    double lastVolume = records.last.volume;

    if (lastVolume == 0) return 0; // Avoid division by zero

    return (lastOdometer - previousOdometer) / lastVolume;
  }

  double calculateRunningAverage(List<FuelRecord> records) {
    if (records.length < 3) {
      return 0; // Not enough data for running average
    }

    List<double> mileages = [];
    for (int i = 1; i < records.length; i++) {
      double diff = records[i].odometer - records[i - 1].odometer;
      double mileage = diff / records[i].volume;
      mileages.add(mileage);
    }

    double runningAverage = mileages[0]; // Initialize with the first mileage

    for (int i = 1; i < mileages.length; i++) {
      runningAverage = (runningAverage + mileages[i]) / 2;
    }
    return runningAverage;
  }

  @override
  Widget build(BuildContext context) {
    double lastMileage = calculateLastMileage(records);
    double runningAverage = calculateRunningAverage(records);
    double lastRefuelVolume = records.isNotEmpty ? records.last.volume : 0;

    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.appTitle)),
      drawer: const MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(localizations.runningAverageMileage),
                          const SizedBox(height: 8),
                          Text(
                            "${runningAverage.toStringAsFixed(2)} km/l",
                            style: const TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(localizations.lastTimeMileage),
                          const SizedBox(height: 8),
                          Text(
                            "${lastMileage.toStringAsFixed(2)} km/l",
                            style: const TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(localizations.lastRefuelVolume),
                subtitle: Text("${lastRefuelVolume.toStringAsFixed(2)} litres"),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddDataPage()));
                _loadRecords();
              },
              child: Text(localizations.addFuelData),
            ),
          ],
        ),
      ),
    );
  }
}