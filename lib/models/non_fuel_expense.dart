// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

enum ExpenseCategory {
  toll,
  parking,
  wash,
  insurance,
  tax,
  fine,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.toll:
        return 'Toll / Express';
      case ExpenseCategory.parking:
        return 'Parking';
      case ExpenseCategory.wash:
        return 'Car Wash & Detail';
      case ExpenseCategory.insurance:
        return 'Insurance';
      case ExpenseCategory.tax:
        return 'Road Tax / Token';
      case ExpenseCategory.fine:
        return 'Traffic Fine';
      case ExpenseCategory.other:
        return 'Other Expense';
    }
  }

  String get iconEmoji {
    switch (this) {
      case ExpenseCategory.toll:
        return '🛣️';
      case ExpenseCategory.parking:
        return '🅿️';
      case ExpenseCategory.wash:
        return '🧼';
      case ExpenseCategory.insurance:
        return '🛡️';
      case ExpenseCategory.tax:
        return '📜';
      case ExpenseCategory.fine:
        return '🚨';
      case ExpenseCategory.other:
        return '📦';
    }
  }
}

class NonFuelExpense {
  final int? id;
  final int vehicleId;
  final DateTime date;
  final double? odometer;
  final ExpenseCategory category;
  final double amount;
  final String currencyCode;
  final String? notes;
  final String? receiptImagePath;

  const NonFuelExpense({
    this.id,
    required this.vehicleId,
    required this.date,
    this.odometer,
    required this.category,
    required this.amount,
    this.currencyCode = 'BDT',
    this.notes,
    this.receiptImagePath,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'vehicleId': vehicleId,
      'date': date.toIso8601String(),
      'odometer': odometer,
      'category': category.name,
      'amount': amount,
      'currencyCode': currencyCode,
      'notes': notes,
      'receiptImagePath': receiptImagePath,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory NonFuelExpense.fromMap(Map<String, dynamic> map) {
    return NonFuelExpense(
      id: map['id'] as int?,
      vehicleId: map['vehicleId'] as int,
      date: DateTime.parse(map['date'] as String),
      odometer: (map['odometer'] as num?)?.toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ExpenseCategory.other,
      ),
      amount: (map['amount'] as num).toDouble(),
      currencyCode: (map['currencyCode'] as String?) ?? 'BDT',
      notes: map['notes'] as String?,
      receiptImagePath: map['receiptImagePath'] as String?,
    );
  }

  NonFuelExpense copyWith({
    int? id,
    int? vehicleId,
    DateTime? date,
    double? odometer,
    ExpenseCategory? category,
    double? amount,
    String? currencyCode,
    String? notes,
    String? receiptImagePath,
  }) {
    return NonFuelExpense(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      notes: notes ?? this.notes,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
    );
  }
}
