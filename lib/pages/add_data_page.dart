import 'package:flutter/material.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDataPage extends StatefulWidget {
  const AddDataPage({super.key});

  @override
  State<AddDataPage> createState() => _AddDataPageState();
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
    _loadLastValues();
    _volumeController.text = _volume.toStringAsFixed(2);

    _rateController.addListener(_calculateVolume);
    _paidAmountController.addListener(_calculateVolume);
  }

  void _calculateVolume() {
    final double? rate = double.tryParse(_rateController.text);
    final double? paidAmount = double.tryParse(_paidAmountController.text);

    if (rate != null && rate > 0 && paidAmount != null && paidAmount > 0) {
      setState(() {
        _volume = paidAmount / rate;
        _volumeController.text = _volume.toStringAsFixed(2);
      });
    }
  }

  Future<void> _loadLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rateController.text = prefs.getString('last_fuel_price') ?? '';
    });
  }

  Future<void> _saveLastValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_fuel_price', _rateController.text);
  }

  @override
  void dispose() {
    _rateController.removeListener(_calculateVolume);
    _paidAmountController.removeListener(_calculateVolume);
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
          initialTime: TimeOfDay.fromDateTime(_selectedDate), context: context);
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
    double maxVolume = AppSettings.maxVolume;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).addFuelData)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${AppLocalizations.of(context).dateAndTime}: ${_selectedDate.toLocal().toString().substring(0, 16)}",
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _odometerController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).odometerReading),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).enterOdometerReading; // Localized
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
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).fuelType),
                  ),
                  TextFormField(
                    controller: _rateController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).fuelPriceRate),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).enterFuelPriceRate; // Localized
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Text(
                      "${AppLocalizations.of(context).totalVolume}: ${_volume.toStringAsFixed(2)}"),
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
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).totalVolume),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).enterTotalVolume; // Localized
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _paidAmountController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).paidAmount),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).enterPaidAmount; // Localized
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _saveLastValues();
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
                    child: Text(AppLocalizations.of(context).save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
