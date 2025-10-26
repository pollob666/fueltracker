import 'package:flutter/material.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'add_data_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
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

  double calculateCurrentRunningMileage(List<FuelRecord> records) {
    if (records.length < 2) {
      return 0;
    }
    double lastOdometer = records.last.odometer;
    double previousOdometer = records[records.length - 2].odometer;
    double previousVolume = records[records.length - 2].volume;

    if (previousVolume == 0) return 0; // Avoid division by zero

    return (lastOdometer - previousOdometer) / previousVolume;
  }

  double calculateRunningAverage(List<FuelRecord> records) {
    if (records.length < 2) {
      return 0; // Not enough data for running average
    }

    List<double> mileages = [];
    for (int i = 1; i < records.length; i++) {
      double diff = records[i].odometer - records[i - 1].odometer;
      if (records[i - 1].volume > 0) {
        double mileage = diff / records[i - 1].volume;
        mileages.add(mileage);
      }
    }

    if (mileages.isEmpty) {
      return 0;
    }

    double totalMileage = mileages.reduce((a, b) => a + b);
    return totalMileage / mileages.length;
  }

  @override
  Widget build(BuildContext context) {
    double currentRunningMileage = calculateCurrentRunningMileage(records);
    double runningAverage = calculateRunningAverage(records);
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Padding(
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
                              style: theme.textTheme.headlineSmall,
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
                              "${currentRunningMileage.toStringAsFixed(2)} km/l",
                              style: theme.textTheme.headlineSmall,
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.lastRefuelDetails,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(localizations.volume),
                          Text("${records.isNotEmpty ? records.last.volume.toStringAsFixed(2) : 'N/A'} litres"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(localizations.totalPrice),
                          Text("${records.isNotEmpty ? records.last.paidAmount.toStringAsFixed(2) : 'N/A'} BDT"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(localizations.odometer),
                          Text("${records.isNotEmpty ? records.last.odometer.toStringAsFixed(2) : 'N/A'} km"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fuel Type'),
                          Text(records.isNotEmpty ? records.last.fuelType : 'N/A'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(localizations.fuelRate),
                          Text("${records.isNotEmpty ? records.last.rate.toStringAsFixed(2) : 'N/A'} BDT/litre"),
                        ],
                      ),
                    ],
                  ),
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
      ),
    );
  }
}
