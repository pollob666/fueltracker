// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/tire.dart';
import 'package:fuel_tracker/models/tire_log.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';
import 'package:fuel_tracker/utils/tire_calculator.dart';
import 'package:fuel_tracker/utils/unit_converter.dart';

void main() {
  group('Tier 3: International Units & UnitConverter Tests', () {
    test('Distance conversion between Kilometers and Miles', () {
      const double km = 100.0;
      final double miles = UnitConverter.kmToDisplay(km, DistanceUnit.mi);
      expect(miles, closeTo(62.1371, 0.001));

      final double backToKm = UnitConverter.displayToKm(miles, DistanceUnit.mi);
      expect(backToKm, closeTo(100.0, 0.001));
    });

    test('Volume conversion between Litres, Gallons, and kWh', () {
      const double litres = 50.0;
      final double galUs = UnitConverter.litreToDisplayVolume(litres, FuelVolumeUnit.gallonUs);
      expect(galUs, closeTo(13.2086, 0.001));

      final double galUk = UnitConverter.litreToDisplayVolume(litres, FuelVolumeUnit.gallonUk);
      expect(galUk, closeTo(10.9985, 0.001));

      final double backToL = UnitConverter.displayVolumeToLitres(galUs, FuelVolumeUnit.gallonUs);
      expect(backToL, closeTo(50.0, 0.001));
    });

    test('Fuel economy conversion across standards', () {
      const double kmPerLitre = 15.0; // 15 km/l

      // L/100km = 100 / 15 = 6.67
      final double? lPer100 = UnitConverter.convertConsumption(
        kmPerLitre,
        ConsumptionUnit.litrePer100Km,
      );
      expect(lPer100, closeTo(6.6667, 0.01));

      // MPG US = 15 * 2.35215 = 35.28
      final double? mpgUs = UnitConverter.convertConsumption(
        kmPerLitre,
        ConsumptionUnit.mpgUs,
      );
      expect(mpgUs, closeTo(35.28, 0.05));

      // MPG UK = 15 * 2.82481 = 42.37
      final double? mpgUk = UnitConverter.convertConsumption(
        kmPerLitre,
        ConsumptionUnit.mpgUk,
      );
      expect(mpgUk, closeTo(42.37, 0.05));
    });

    test('UnitFormatter outputs consistent localized strings', () {
      expect(UnitFormatter.formatDistance(12500.5, DistanceUnit.km), equals('12500.5 km'));
      expect(UnitFormatter.formatDistance(12500.5, DistanceUnit.mi), equals('7767.5 mi'));
      expect(UnitFormatter.formatEconomy(14.85, ConsumptionUnit.kmPerLitre), equals('14.85 km/L'));
      expect(UnitFormatter.formatCurrency(450.50, 'USD'), equals('450.50 USD'));
    });
  });

  group('Tier 3: Alternative Powertrains & EV Attributes', () {
    test('Vehicle model correctly identifies EV and Hybrid architectures', () {
      final ice = Vehicle(
        name: 'Sedan ICE',
        type: VehicleType.carOrSedan,
        primaryFuelTypeId: 1,
        powertrainType: PowertrainType.ice,
      );
      expect(ice.isElectric, isFalse);
      expect(ice.hasElectricMotor, isFalse);

      final hybrid = Vehicle(
        name: 'Prius Hybrid',
        type: VehicleType.carOrSedan,
        primaryFuelTypeId: 1,
        powertrainType: PowertrainType.hybrid,
      );
      expect(hybrid.isElectric, isFalse);
      expect(hybrid.hasElectricMotor, isTrue);

      final phev = Vehicle(
        name: 'Outlander PHEV',
        type: VehicleType.suv,
        primaryFuelTypeId: 1,
        powertrainType: PowertrainType.phev,
        batteryCapacityKwh: 13.8,
      );
      expect(phev.isElectric, isFalse);
      expect(phev.hasElectricMotor, isTrue);

      final bev = Vehicle(
        name: 'Tesla Model 3',
        type: VehicleType.carOrSedan,
        primaryFuelTypeId: 2,
        powertrainType: PowertrainType.bev,
        batteryCapacityKwh: 60.0,
      );
      expect(bev.isElectric, isTrue);
      expect(bev.hasElectricMotor, isTrue);
    });

    test('Electricity fuel category results in 0.0 kg direct tailpipe CO2', () {
      final electricFuelType = FuelType(
        id: 10,
        name: 'Electricity',
        category: FuelCategory.electricity,
        unit: FuelUnit.kwh,
      );

      final records = [
        FuelRecord(
          date: DateTime(2026, 1, 1),
          odometer: 1000.0,
          fuelTypeId: 10,
          vehicleId: 1,
          rate: 12.0,
          volume: 40.0, // 40 kWh
          paidAmount: 480.0,
        ),
      ];

      final co2Result = MileageCalculator.calculateCarbonFootprint(
        records,
        fuelTypeMap: {10: electricFuelType},
      );
      expect(co2Result.totalCo2Kg, equals(0.0));
    });
  });

  group('Tier 3: Multi-Currency & Exchange Rate Normalization', () {
    test('FuelRecord basePaidAmount applies exchangeRateToBase correctly', () {
      // 100 USD refuel at exchange rate of 120.0 BDT/USD
      final recordForeign = FuelRecord(
        date: DateTime(2026, 2, 1),
        odometer: 5000.0,
        fuelTypeId: 1,
        vehicleId: 1,
        rate: 3.50,
        volume: 28.57,
        paidAmount: 100.0,
        currencyCode: 'USD',
        exchangeRateToBase: 120.0,
      );
      expect(recordForeign.basePaidAmount, equals(12000.0));

      // Domestic refuel with 1.0 rate
      final recordDomestic = FuelRecord(
        date: DateTime(2026, 2, 2),
        odometer: 5500.0,
        fuelTypeId: 1,
        vehicleId: 1,
        rate: 130.0,
        volume: 30.0,
        paidAmount: 3900.0,
        currencyCode: 'BDT',
        exchangeRateToBase: 1.0,
      );
      expect(recordDomestic.basePaidAmount, equals(3900.0));
    });

    test('MileageCalculator running cost per km utilizes basePaidAmount', () {
      final records = [
        FuelRecord(
          date: DateTime(2026, 1, 1),
          odometer: 1000.0,
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 1.0,
          volume: 20.0,
          paidAmount: 100.0,
          exchangeRateToBase: 120.0, // base = 12,000
        ),
        FuelRecord(
          date: DateTime(2026, 1, 10),
          odometer: 1500.0, // delta = 500 km
          fuelTypeId: 1,
          vehicleId: 1,
          rate: 1.0,
          volume: 25.0,
          paidAmount: 3000.0,
          exchangeRateToBase: 1.0, // base = 3,000
        ),
      ];

      // Post-baseline cost = 3000 base. Delta distance = 500 km.
      // Running cost per km = 3000 / 500 = 6.0 (CRIT-03 fix)
      final costPerKm = MileageCalculator.calculateCostPerKm(records);
      expect(costPerKm, equals(6.0));
    });
  });

  group('Tier 3: Tire Wear & Lifecycle Engine Tests', () {
    test('calculateWearRatePer1000Km computes mm per 1,000 km correctly', () {
      // 8.0mm initial down to 6.0mm after 20,000 km
      // (8.0 - 6.0) / 20000 * 1000 = 2.0 / 20 = 0.10 mm / 1000 km
      final rate = TireCalculator.calculateWearRatePer1000Km(
        initialDepthMm: 8.0,
        currentDepthMm: 6.0,
        deltaKm: 20000.0,
      );
      expect(rate, closeTo(0.10, 0.001));
    });

    test('estimateRemainingDistanceKm projects remaining distance until legal threshold', () {
      // Current depth: 4.0mm, Legal min: 1.6mm -> 2.4mm remaining
      // Wear rate: 0.10 mm / 1000 km -> 2.4 / 0.10 * 1000 = 24,000 km remaining
      final remainingKm = TireCalculator.estimateRemainingDistanceKm(
        currentDepthMm: 4.0,
        wearRatePer1000Km: 0.10,
      );
      expect(remainingKm, closeTo(24000.0, 1.0));
    });

    test('isRotationDue flags rotation after threshold exceeded', () {
      expect(
        TireCalculator.isRotationDue(
          currentOdometer: 25000.0,
          lastRotationOdometer: 14000.0, // 11,000 km (> 10,000 km)
          intervalKm: 10000.0,
        ),
        isTrue,
      );

      expect(
        TireCalculator.isRotationDue(
          currentOdometer: 20000.0,
          lastRotationOdometer: 14000.0, // 6,000 km (< 10,000 km)
          intervalKm: 10000.0,
        ),
        isFalse,
      );
    });

    test('Tire model toMap and fromMap serialization roundtrip', () {
      final now = DateTime.now();
      final tire = Tire(
        id: 1,
        vehicleId: 42,
        brand: 'Michelin',
        model: 'Pilot Sport 4',
        size: '225/45 R17',
        dotCode: 'DOT4223',
        installedOdo: 15000.0,
        installedDate: now,
        initialTreadDepthMm: 8.2,
        currentTreadDepthMm: 6.5,
        isArchived: false,
      );

      final map = tire.toMap();
      final restored = Tire.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.vehicleId, equals(42));
      expect(restored.brand, equals('Michelin'));
      expect(restored.model, equals('Pilot Sport 4'));
      expect(restored.size, equals('225/45 R17'));
      expect(restored.dotCode, equals('DOT4223'));
      expect(restored.initialTreadDepthMm, equals(8.2));
      expect(restored.currentTreadDepthMm, equals(6.5));
    });

    test('TireLog model toMap and fromMap serialization roundtrip', () {
      final now = DateTime.now();
      final log = TireLog(
        id: 5,
        tireId: 1,
        date: now,
        odometer: 25000.0,
        position: 'FL',
        treadDepthMm: 5.8,
        notes: 'Rotated front to rear',
      );

      final map = log.toMap();
      final restored = TireLog.fromMap(map);

      expect(restored.id, equals(5));
      expect(restored.tireId, equals(1));
      expect(restored.position, equals('FL'));
      expect(restored.treadDepthMm, equals(5.8));
      expect(restored.notes, equals('Rotated front to rear'));
    });
  });
}
