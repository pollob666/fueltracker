import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';

void main() {
  group('FuelRecord model', () {
    test('serializes to and from map with new fields', () {
      final record = FuelRecord(
        id: 1,
        date: DateTime(2026, 1, 15, 10, 30),
        odometer: 15420.0,
        fuelTypeId: 1,
        vehicleId: 2,
        rate: 118.3,
        volume: 35.5,
        paidAmount: 4200.0,
        isFullTank: false,
        missedPrevious: true,
        tripDistance: 250.5,
      );

      final map = record.toMap();
      expect(map['id'], 1);
      expect(map['date'], record.date.toIso8601String());
      expect(map['odometer'], 15420.0);
      expect(map['fuelTypeId'], 1);
      expect(map['vehicleId'], 2);
      expect(map['rate'], 118.3);
      expect(map['volume'], 35.5);
      expect(map['paidAmount'], 4200.0);
      expect(map['isFullTank'], 0);
      expect(map['missedPrevious'], 1);
      expect(map['tripDistance'], 250.5);

      final fromMap = FuelRecord.fromMap(map);
      expect(fromMap.id, record.id);
      expect(fromMap.vehicleId, record.vehicleId);
      expect(fromMap.fuelTypeId, record.fuelTypeId);
      expect(fromMap.volume, record.volume);
      expect(fromMap.rate, record.rate);
      expect(fromMap.odometer, record.odometer);
      expect(fromMap.paidAmount, record.paidAmount);
      expect(fromMap.date, record.date);
      expect(fromMap.isFullTank, false);
      expect(fromMap.missedPrevious, true);
      expect(fromMap.tripDistance, 250.5);
    });

    test('handles legacy map without new fields gracefully', () {
      final legacyMap = <String, dynamic>{
        'id': 10,
        'date': '2026-01-01T00:00:00.000',
        'odometer': 5000.0,
        'fuelTypeId': 1,
        'vehicleId': 1,
        'rate': 75.0,
        'volume': 40.0,
        'paidAmount': 3000.0,
      };

      final record = FuelRecord.fromMap(legacyMap);
      expect(record.isFullTank, true); // legacy default
      expect(record.missedPrevious, false); // legacy default
      expect(record.tripDistance, isNull);
    });

    test('serializes to and from json', () {
      final record = FuelRecord(
        id: 1,
        date: DateTime(2026, 1, 15, 10, 30),
        odometer: 15420.0,
        fuelTypeId: 1,
        vehicleId: 2,
        rate: 118.3,
        volume: 35.5,
        paidAmount: 4200.0,
        isFullTank: true,
        missedPrevious: false,
        tripDistance: 100.0,
      );

      final json = record.toJson();
      expect(json['dateTime'], record.date.toIso8601String());
      expect(json['isFullTank'], true);
      expect(json['missedPrevious'], false);
      expect(json['tripDistance'], 100.0);

      final fromJson = FuelRecord.fromJson(json);
      expect(fromJson.date, record.date);
      expect(fromJson.isFullTank, true);
      expect(fromJson.missedPrevious, false);
      expect(fromJson.tripDistance, 100.0);
    });

    test('copyWith updates fields correctly', () {
      final record = FuelRecord(
        id: 1,
        date: DateTime(2026, 1, 1),
        odometer: 1000.0,
        fuelTypeId: 1,
        vehicleId: 1,
        rate: 75.0,
        volume: 20.0,
        paidAmount: 1500.0,
      );

      final updated = record.copyWith(
        isFullTank: false,
        missedPrevious: true,
        tripDistance: 80.0,
      );

      expect(updated.id, record.id);
      expect(updated.isFullTank, false);
      expect(updated.missedPrevious, true);
      expect(updated.tripDistance, 80.0);
    });
  });
}
