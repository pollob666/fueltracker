import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'fuel_tracker_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<FuelTrackerModel>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Maximum Tank Capacity (L)'),
              keyboardType: TextInputType.number,
              initialValue: model.maxTankCapacity.toString(),
              onChanged: (value) => model.setMaxTankCapacity(double.parse(value)),
            ),
            const SizedBox(height: 16),
            const Text('Storage Options'),
            ListTile(
              title: const Text('Store Locally'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('Store in Google Drive'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('Store in Dropbox'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}