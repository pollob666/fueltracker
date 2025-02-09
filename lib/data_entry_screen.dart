import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'fuel_tracker_model.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  DataEntryScreenState createState() => DataEntryScreenState(); // Changed here
}

class DataEntryScreenState extends State<DataEntryScreen> { // Changed here
  final _formKey = GlobalKey<FormState>();
  final DateTime _selectedDate = DateTime.now(); // Changed here
  double _odometerReading = 0;
  String _fuelType = 'Octane';
  double _fuelPrice = 0;
  double _fuelVolume = 0;
  double _paidAmount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Data')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Odometer Reading (km)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _odometerReading = double.parse(value),
              ),
              DropdownButtonFormField<String>(
                value: _fuelType,
                items: ['Octane', 'Petrol'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => _fuelType = value!),
                decoration: const InputDecoration(labelText: 'Fuel Type'),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Fuel Price (BDT)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _fuelPrice = double.parse(value),
              ),
              Slider(
                value: _fuelVolume,
                min: 0,
                max: Provider.of<FuelTrackerModel>(context).maxTankCapacity,
                divisions: 1000,
                label: _fuelVolume.toStringAsFixed(2),
                onChanged: (value) => setState(() => _fuelVolume = value),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Paid Amount (BDT)'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _paidAmount = double.parse(value),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Provider.of<FuelTrackerModel>(context, listen: false).addData(
                      _selectedDate,
                      _odometerReading,
                      _fuelType,
                      _fuelPrice,
                      _fuelVolume,
                      _paidAmount,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}