class FuelRecord {
  int? id;
  DateTime date;
  double odometer;
  String fuelType;
  double rate;
  double volume;
  double paidAmount;

  FuelRecord({
    this.id,
    required this.date,
    required this.odometer,
    required this.fuelType,
    required this.rate,
    required this.volume,
    required this.paidAmount,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'date': date.toIso8601String(),
      'odometer': odometer,
      'fuelType': fuelType,
      'rate': rate,
      'volume': volume,
      'paidAmount': paidAmount,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory FuelRecord.fromMap(Map<String, dynamic> map) {
    return FuelRecord(
      id: map['id'],
      date: DateTime.parse(map['date']),
      odometer: map['odometer'],
      fuelType: map['fuelType'],
      rate: map['rate'],
      volume: map['volume'],
      paidAmount: map['paidAmount'],
    );
  }
}
