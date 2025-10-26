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
    final colorScheme = theme.colorScheme;

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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            children: [
                              Text(
                                localizations.runningAverageMileage,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                runningAverage.toStringAsFixed(2),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "km/l",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onPrimaryContainer),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Column(
                            children: [
                              Text(
                                localizations.lastTimeMileage,
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSecondaryContainer),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentRunningMileage.toStringAsFixed(2),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "km/l",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSecondaryContainer),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          localizations.lastRefuelDetails,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.spaceAround,
                          spacing: 16.0,
                          runSpacing: 24.0,
                          children: [
                            _buildInfoTile(
                              context,
                              label: localizations.volume,
                              value:
                                  "${records.isNotEmpty ? records.last.volume.toStringAsFixed(2) : 'N/A'} litres",
                              icon: Icons.local_gas_station,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.totalPrice,
                              value:
                                  "${records.isNotEmpty ? records.last.paidAmount.toStringAsFixed(2) : 'N/A'} BDT",
                              icon: Icons.monetization_on,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.odometer,
                              value:
                                  "${records.isNotEmpty ? records.last.odometer.toStringAsFixed(2) : 'N/A'} km",
                              icon: Icons.speed,
                            ),
                            _buildInfoTile(
                              context,
                              label: 'Fuel Type',
                              value: records.isNotEmpty
                                  ? records.last.fuelType
                                  : 'N/A',
                              icon: Icons.opacity,
                            ),
                            _buildInfoTile(
                              context,
                              label: localizations.fuelRate,
                              value:
                                  "${records.isNotEmpty ? records.last.rate.toStringAsFixed(2) : 'N/A'} BDT/litre",
                              icon: Icons.price_change,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddDataPage()));
                    _loadRecords();
                  },
                  label: Text(localizations.addFuelData),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context,
      {required String label,
      required String value,
      required IconData icon}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 140,
      child: Column(
        children: [
          Icon(icon, size: 32, color: colorScheme.secondary),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
