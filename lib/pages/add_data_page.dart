import 'package:flutter/material.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/database/database_helper.dart';

class AddDataPage extends StatefulWidget {
  const AddDataPage({super.key});

  @override
  _AddDataPageState createState() => _AddDataPageState();
}

class _AddDataPageState extends State<AddDataPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _odometerController = TextEditingController();
  String _selectedFuelType = "Octane";
  final TextEditingController _rateController = TextEditingController();
  double _volume = 0;
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _volumeController.text = _volume.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _rateController.dispose();
    _volumeController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxVolume = AppSettings.maxVolume; // Maximum from settings

    return Scaffold(
      appBar: AppBar(title: Text("Add Fuel Data")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Date and time picker
                Row(
                  children: [
                    Expanded(
                      child: Text("Date & Time: ${_selectedDate.toLocal().toString().substring(0, 16)}"),
                    ),
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
                TextFormField(
                  controller: _odometerController,
                  decoration:
                  InputDecoration(labelText: "Odometer Reading (km)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter odometer reading";
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _selectedFuelType,
                  items: ["Octane", "Petrol"]
                      .map((fuel) => DropdownMenuItem(
                    value: fuel,
                    child: Text(fuel),
                  ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedFuelType = val!;
                    });
                  },
                  decoration: InputDecoration(labelText: "Fuel Type"),
                ),
                TextFormField(
                  controller: _rateController,
                  decoration:
                  InputDecoration(labelText: "Fuel Price Rate (BDT)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter fuel price rate";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                // Volume slider and input field
                Text("Total Volume (litres): ${_volume.toStringAsFixed(2)}"),
                Slider(
                  value: _volume,
                  min: 0,
                  max: maxVolume,
                  divisions: (maxVolume * 100).toInt(),
                  label: _volume.toStringAsFixed(2),
                  onChanged: (val) {
                    setState(() {
                      _volume = double.parse(val.toStringAsFixed(2));
                      _volumeController.text = _volume.toStringAsFixed(2);
                    });
                  },
                ),
                TextFormField(
                  controller: _volumeController,
                  decoration:
                  InputDecoration(labelText: "Total Volume (litres)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    double? parsed = double.tryParse(val);
                    if (parsed != null) {
                      setState(() {
                        _volume = parsed;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter total volume";
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _paidAmountController,
                  decoration:
                  InputDecoration(labelText: "Paid Amount (BDT)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Enter paid amount";
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Create a new FuelRecord and save it.
                      FuelRecord record = FuelRecord(
                        date: _selectedDate,
                        odometer: double.parse(_odometerController.text),
                        fuelType: _selectedFuelType,
                        rate: double.parse(_rateController.text),
                        volume: _volume,
                        paidAmount: double.parse(_paidAmountController.text),
                      );
                      await DatabaseHelper.instance.insertFuelRecord(record);
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Save"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
