import 'package:flutter/material.dart';

class FuelTrackerModel with ChangeNotifier {
  final List<Map<String, dynamic>> _data = [];
  double _runningAverageMileage = 0;
  double _lastMileage = 0;
  double _lastRefuelVolume = 0;
  double _maxTankCapacity = 50;

  List<Map<String, dynamic>> get data => _data;
  double get runningAverageMileage => _runningAverageMileage;
  double get lastMileage => _lastMileage;
  double get lastRefuelVolume => _lastRefuelVolume;
  double get maxTankCapacity => _maxTankCapacity;

  void addData(DateTime date, double odometerReading, String fuelType, double fuelPrice, double fuelVolume, double paidAmount) {
    if (_data.isNotEmpty) {
      final previousOdometer = _data.last['odometerReading'];
      _lastMileage = (odometerReading - previousOdometer) / fuelVolume;
      _runningAverageMileage = (_runningAverageMileage + _lastMileage) / 2;
    }

    _lastRefuelVolume = fuelVolume;

    _data.add({
      'date': date,
      'odometerReading': odometerReading,
      'fuelType': fuelType,
      'fuelPrice': fuelPrice,
      'fuelVolume': fuelVolume,
      'paidAmount': paidAmount,
    });

    notifyListeners();
  }

  void setMaxTankCapacity(double capacity) {
    _maxTankCapacity = capacity;
    notifyListeners();
  }
}