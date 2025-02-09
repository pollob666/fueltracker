import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'fuel_tracker_model.dart';
import 'data_entry_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FuelTrackerModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Fuel Tracker')),
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: const Text('All Data'),
              onTap: () => Navigator.pushNamed(context, '/all_data'),
            ),
            ListTile(
              title: const Text('Settings'),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Running Average Mileage'),
                          Text('${model.runningAverageMileage.toStringAsFixed(2)} km/L'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('Last Time Mileage'),
                          Text('${model.lastMileage.toStringAsFixed(2)} km/L'),
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
                  children: [
                    const Text('Last Refuel Volume'),
                    Text('${model.lastRefuelVolume.toStringAsFixed(2)} L'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DataEntryScreen()),
                );
              },
              child: const Text('Add New Data'),
            ),
          ],
        ),
      ),
    );
  }
}