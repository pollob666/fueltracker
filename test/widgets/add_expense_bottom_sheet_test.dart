// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/providers/non_fuel_expense_providers.dart';
import 'package:fuel_tracker/repositories/non_fuel_expense_repository.dart';
import 'package:fuel_tracker/widgets/add_expense_bottom_sheet.dart';

class MockNonFuelExpenseRepository implements NonFuelExpenseRepository {
  final List<NonFuelExpense> expenses = [];

  @override
  Future<List<NonFuelExpense>> getNonFuelExpenses({int? vehicleId}) async => expenses;

  @override
  Stream<List<NonFuelExpense>> watchNonFuelExpenses(int vehicleId) => Stream.value(expenses);

  @override
  Future<int> insertNonFuelExpense(NonFuelExpense expense) async {
    expenses.add(expense);
    return expenses.length;
  }

  @override
  Future<int> updateNonFuelExpense(NonFuelExpense expense) async => 1;

  @override
  Future<int> deleteNonFuelExpense(int id, {int? vehicleId}) async => 1;

  @override
  Future<double> getTotalNonFuelExpenses({int? vehicleId}) async => 0.0;

  @override
  void notifyChanged([int? vehicleId]) {}

  @override
  void dispose() {}
}

void main() {
  testWidgets('AddExpenseBottomSheet renders categories, validates, and saves',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    final mockRepo = MockNonFuelExpenseRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nonFuelExpenseRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AddExpenseBottomSheet.show(context, vehicleId: 1);
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open bottom sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Log Non-Fuel Expense'), findsOneWidget);

    // Verify Category Chips
    expect(find.text('🛣️ Toll / Express'), findsOneWidget);
    expect(find.text('🅿️ Parking'), findsOneWidget);
    expect(find.text('🧼 Car Wash & Detail'), findsOneWidget);

    // Select Parking
    await tester.tap(find.text('🅿️ Parking'));
    await tester.pumpAndSettle();

    // Fill form fields
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(3));

    // Amount field
    await tester.enterText(textFields.at(0), '150');
    // Odometer field
    await tester.enterText(textFields.at(1), '48250');
    // Notes field
    await tester.enterText(textFields.at(2), 'Basundhara City Parking');
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify saved in repository
    expect(mockRepo.expenses.length, 1);
    expect(mockRepo.expenses.first.category, ExpenseCategory.parking);
    expect(mockRepo.expenses.first.amount, 150.0);
    expect(mockRepo.expenses.first.odometer, 48250.0);
    expect(mockRepo.expenses.first.notes, 'Basundhara City Parking');
  });
}
