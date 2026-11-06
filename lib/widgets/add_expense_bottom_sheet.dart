// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/providers/non_fuel_expense_providers.dart';
import 'package:intl/intl.dart';

class AddExpenseBottomSheet extends ConsumerStatefulWidget {
  final int vehicleId;
  final NonFuelExpense? expenseToEdit;

  const AddExpenseBottomSheet({
    super.key,
    required this.vehicleId,
    this.expenseToEdit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int vehicleId,
    NonFuelExpense? expenseToEdit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddExpenseBottomSheet(
        vehicleId: vehicleId,
        expenseToEdit: expenseToEdit,
      ),
    );
  }

  @override
  ConsumerState<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends ConsumerState<AddExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();

  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _selectedCategory = e.category;
      _selectedDate = e.date;
      _amountController.text = e.amount.toStringAsFixed(2);
      if (e.odometer != null) {
        _odometerController.text = e.odometer!.toStringAsFixed(1);
      }
      if (e.notes != null) {
        _notesController.text = e.notes!;
      }
    } else {
      _selectedCategory = ExpenseCategory.toll;
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    final odo = double.tryParse(_odometerController.text.trim());
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    setState(() {
      _isSaving = true;
    });

    final repo = ref.read(nonFuelExpenseRepositoryProvider);

    try {
      if (widget.expenseToEdit != null) {
        final updated = widget.expenseToEdit!.copyWith(
          category: _selectedCategory,
          amount: amount,
          date: _selectedDate,
          odometer: odo,
          notes: notes,
        );
        await repo.updateNonFuelExpense(updated);
      } else {
        final newExpense = NonFuelExpense(
          vehicleId: widget.vehicleId,
          date: _selectedDate,
          category: _selectedCategory,
          amount: amount,
          odometer: odo,
          notes: notes,
        );
        await repo.insertNonFuelExpense(newExpense);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.expenseToEdit != null ? 'Edit Expense' : 'Log Non-Fuel Expense',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category Selector Chips
              Text(
                'Expense Category',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ExpenseCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text('${cat.iconEmoji} ${cat.displayName}'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Amount & Odometer row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Amount (BDT) *',
                        prefixIcon: Icon(Icons.monetization_on_outlined, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter amount';
                        final numVal = double.tryParse(val.trim());
                        if (numVal == null || numVal <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _odometerController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Odometer (km)',
                        prefixIcon: Icon(Icons.speed_outlined, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Notes / Location
              TextFormField(
                controller: _notesController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Notes / Location (e.g. Padma Bridge Toll)',
                  prefixIcon: Icon(Icons.notes_outlined, size: 20),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Save Button
              ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.expenseToEdit != null ? 'Update Expense' : 'Save Expense'),
                onPressed: _isSaving ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
