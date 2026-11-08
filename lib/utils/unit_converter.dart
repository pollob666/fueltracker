// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

enum DistanceUnit {
  km('km', 'Kilometers'),
  mi('mi', 'Miles');

  final String symbol;
  final String label;
  const DistanceUnit(this.symbol, this.label);

  static DistanceUnit fromString(String? val) {
    if (val == null) return DistanceUnit.km;
    return DistanceUnit.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.symbol.toLowerCase() == val.toLowerCase(),
      orElse: () => DistanceUnit.km,
    );
  }
}

enum FuelVolumeUnit {
  litre('L', 'Litre'),
  gallonUs('gal (US)', 'Gallon (US)'),
  gallonUk('gal (UK)', 'Gallon (UK)'),
  cubicMeter('m³', 'Cubic Meter'),
  gge('GGE', 'Gasoline Gallon Equiv'),
  kwh('kWh', 'Kilowatt-hour');

  final String symbol;
  final String label;
  const FuelVolumeUnit(this.symbol, this.label);

  static FuelVolumeUnit fromString(String? val) {
    if (val == null) return FuelVolumeUnit.litre;
    return FuelVolumeUnit.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() ||
             e.symbol.toLowerCase() == val.toLowerCase() ||
             (val.toLowerCase() == 'gallon' && e == FuelVolumeUnit.gallonUs),
      orElse: () => FuelVolumeUnit.litre,
    );
  }
}

enum ConsumptionUnit {
  kmPerLitre('km/L', 'Kilometers per Litre'),
  litrePer100Km('L/100km', 'Litres per 100 km'),
  mpgUs('MPG (US)', 'Miles per Gallon (US)'),
  mpgUk('MPG (UK)', 'Miles per Gallon (UK)'),
  kmPerKwh('km/kWh', 'Kilometers per kWh'),
  kwhPer100Km('kWh/100km', 'kWh per 100 km');

  final String symbol;
  final String label;
  const ConsumptionUnit(this.symbol, this.label);

  static ConsumptionUnit fromString(String? val) {
    if (val == null) return ConsumptionUnit.kmPerLitre;
    return ConsumptionUnit.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.symbol.toLowerCase() == val.toLowerCase(),
      orElse: () => ConsumptionUnit.kmPerLitre,
    );
  }
}

enum PowertrainType {
  ice('ICE', 'Internal Combustion'),
  bev('BEV', 'Battery Electric'),
  phev('PHEV', 'Plug-in Hybrid'),
  hybrid('HEV', 'Hybrid Electric');

  final String code;
  final String label;
  const PowertrainType(this.code, this.label);

  static PowertrainType fromString(String? val) {
    if (val == null) return PowertrainType.ice;
    return PowertrainType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.code.toLowerCase() == val.toLowerCase(),
      orElse: () => PowertrainType.ice,
    );
  }
}

class UnitConverter {
  static const double kmToMiles = 0.62137119;
  static const double milesToKm = 1.609344;

  static const double litreToGallonUs = 0.264172052;
  static const double gallonUsToLitre = 3.785411784;

  static const double litreToGallonUk = 0.219969248;
  static const double gallonUkToLitre = 4.54609;

  // km/L to MPG (US): (km/L) * 2.35214583
  static const double kmPerLToMpgUs = 2.35214583;
  // km/L to MPG (UK): (km/L) * 2.82480936
  static const double kmPerLToMpgUk = 2.82480936;

  /// Convert distance from kilometers to target display unit.
  static double kmToDisplay(double km, DistanceUnit targetUnit) {
    if (targetUnit == DistanceUnit.mi) {
      return km * kmToMiles;
    }
    return km;
  }

  /// Convert user-entered distance in targetUnit to canonical storage kilometers.
  static double displayToKm(double displayDistance, DistanceUnit fromUnit) {
    if (fromUnit == DistanceUnit.mi) {
      return displayDistance * milesToKm;
    }
    return displayDistance;
  }

  /// Convert standard km/L efficiency into target consumption unit.
  /// If kmPerL <= 0, returns null or 0.0.
  static double? convertConsumption(double? kmPerL, ConsumptionUnit targetUnit) {
    if (kmPerL == null || kmPerL <= 0) return null;

    switch (targetUnit) {
      case ConsumptionUnit.kmPerLitre:
      case ConsumptionUnit.kmPerKwh:
        return kmPerL;
      case ConsumptionUnit.litrePer100Km:
      case ConsumptionUnit.kwhPer100Km:
        return 100.0 / kmPerL;
      case ConsumptionUnit.mpgUs:
        return kmPerL * kmPerLToMpgUs;
      case ConsumptionUnit.mpgUk:
        return kmPerL * kmPerLToMpgUk;
    }
  }

  /// Convert volume in Litres to target display volume unit.
  static double litreToDisplayVolume(double litres, FuelVolumeUnit targetUnit) {
    switch (targetUnit) {
      case FuelVolumeUnit.litre:
      case FuelVolumeUnit.cubicMeter:
      case FuelVolumeUnit.kwh:
      case FuelVolumeUnit.gge:
        return litres;
      case FuelVolumeUnit.gallonUs:
        return litres * litreToGallonUs;
      case FuelVolumeUnit.gallonUk:
        return litres * litreToGallonUk;
    }
  }

  /// Convert display volume to Litres for normalized storage/accounting.
  static double displayVolumeToLitres(double volume, FuelVolumeUnit fromUnit) {
    switch (fromUnit) {
      case FuelVolumeUnit.litre:
      case FuelVolumeUnit.cubicMeter:
      case FuelVolumeUnit.kwh:
      case FuelVolumeUnit.gge:
        return volume;
      case FuelVolumeUnit.gallonUs:
        return volume * gallonUsToLitre;
      case FuelVolumeUnit.gallonUk:
        return volume * gallonUkToLitre;
    }
  }
}

class UnitFormatter {
  /// Format a distance in km according to vehicle DistanceUnit.
  static String formatDistance(double km, DistanceUnit unit, {int decimals = 1}) {
    final val = UnitConverter.kmToDisplay(km, unit);
    return '${val.toStringAsFixed(decimals)} ${unit.symbol}';
  }

  /// Format an efficiency value (provided in km/L or km/kWh) into the target ConsumptionUnit.
  static String formatEconomy(double? kmPerL, ConsumptionUnit unit, {int decimals = 2}) {
    if (kmPerL == null || kmPerL <= 0) return 'N/A';
    final val = UnitConverter.convertConsumption(kmPerL, unit);
    if (val == null) return 'N/A';
    return '${val.toStringAsFixed(decimals)} ${unit.symbol}';
  }

  /// Format a monetary amount with currency code or symbol.
  static String formatCurrency(double amount, String currencyCode, {int decimals = 2}) {
    return '${amount.toStringAsFixed(decimals)} $currencyCode';
  }
}
