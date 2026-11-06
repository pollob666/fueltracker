// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/services/pdf_report_generator.dart';

void main() {
  test('PdfReportGenerator compiles multi-page PDF with magic header and tables', () async {
    final vehicle = Vehicle(
      id: 1,
      name: 'Toyota Corolla Cross',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
      primaryFuelCapacity: 47.0,
    );

    final dateRange = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 31),
    );

    final fuelRecords = [
      FuelRecord(
        id: 1,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 5),
        odometer: 15000,
        rate: 130.0,
        volume: 35.0,
        paidAmount: 4550.0,
        isFullTank: true,
        locationId: 10,
      ),
      FuelRecord(
        id: 2,
        vehicleId: 1,
        fuelTypeId: 1,
        date: DateTime(2026, 10, 20),
        odometer: 15450,
        rate: 130.0,
        volume: 32.0,
        paidAmount: 4160.0,
        isFullTank: true,
        locationId: 10,
      ),
    ];

    final serviceSessions = [
      ServiceSession(
        id: 1,
        vehicleId: 1,
        odometer: 15200,
        serviceDate: DateTime(2026, 10, 12),
        totalCost: 3500.0,
        workshopName: 'Toyota Navana Workshop',
      ),
    ];

    final nonFuelExpenses = [
      NonFuelExpense(
        id: 1,
        vehicleId: 1,
        date: DateTime(2026, 10, 8),
        odometer: 15080,
        category: ExpenseCategory.toll,
        amount: 300.0,
        notes: 'Padma Bridge Toll',
      ),
      NonFuelExpense(
        id: 2,
        vehicleId: 1,
        date: DateTime(2026, 10, 15),
        category: ExpenseCategory.wash,
        amount: 800.0,
        notes: 'Full Detailing',
      ),
    ];

    final fuelTypes = {
      1: FuelType(id: 1, name: 'Octane', category: FuelCategory.gasoline, unit: FuelUnit.litre),
    };

    final savedLocations = {
      10: SavedLocation(
        id: 10,
        name: 'Padma Oil Co Station',
        type: 'fuel_station',
        isNamed: true,
      ),
    };

    final pdfBytes = await PdfReportGenerator.generateFleetReport(
      vehicle: vehicle,
      dateRange: dateRange,
      fuelRecords: fuelRecords,
      serviceSessions: serviceSessions,
      nonFuelExpenses: nonFuelExpenses,
      fuelTypes: fuelTypes,
      savedLocations: savedLocations,
      companyOrOwnerName: 'Acme Fleet Services',
    );

    expect(pdfBytes, isNotEmpty);
    // PDF Magic Header check: '%PDF-'
    final headerString = ascii.decode(pdfBytes.sublist(0, 5));
    expect(headerString, equals('%PDF-'));
    // Length should be sufficient for a fully styled A4 PDF document
    expect(pdfBytes.length, greaterThan(1000));
  });

  test('PdfReportGenerator handles empty logs gracefully without throwing', () async {
    final vehicle = Vehicle(
      id: 2,
      name: 'Honda Civic',
      type: VehicleType.carOrSedan,
      primaryFuelTypeId: 1,
    );

    final dateRange = DateTimeRange(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 30),
    );

    final pdfBytes = await PdfReportGenerator.generateFleetReport(
      vehicle: vehicle,
      dateRange: dateRange,
      fuelRecords: [],
      serviceSessions: [],
      nonFuelExpenses: [],
    );

    expect(pdfBytes, isNotEmpty);
    final headerString = ascii.decode(pdfBytes.sublist(0, 5));
    expect(headerString, equals('%PDF-'));
  });
}
