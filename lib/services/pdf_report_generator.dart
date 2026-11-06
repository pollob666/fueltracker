// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/models/non_fuel_expense.dart';
import 'package:fuel_tracker/models/saved_location.dart';
import 'package:fuel_tracker/models/service_session.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/mileage_calculator.dart';

class PdfReportGenerator {
  /// Builds a high-resolution, multi-page printable PDF fleet and tax expense report.
  static Future<Uint8List> generateFleetReport({
    required Vehicle vehicle,
    required DateTimeRange dateRange,
    required List<FuelRecord> fuelRecords,
    required List<ServiceSession> serviceSessions,
    required List<NonFuelExpense> nonFuelExpenses,
    Map<int, FuelType> fuelTypes = const {},
    Map<int, SavedLocation> savedLocations = const {},
    String companyOrOwnerName = 'Fleet & Tax Audit Report',
    String currencyCode = 'BDT',
  }) async {
    final pdf = pw.Document(
      title: 'Vehicle Expense Report - ${vehicle.name}',
      author: 'Fuel Tracker',
    );

    final dateFormatter = DateFormat('yyyy-MM-dd');
    final currencyFormatter = NumberFormat('#,##0.00');
    final intFormatter = NumberFormat('#,##0');

    // 1. Filter and sort fuel records chronologically
    final filteredFuelRecords = fuelRecords.where((r) {
      return !r.date.isBefore(dateRange.start) &&
          !r.date.isAfter(dateRange.end.add(const Duration(days: 1)));
    }).toList();
    final sortedFuelRecords = MileageCalculator.sortChronological(filteredFuelRecords);

    // Calculate fuel interval metrics
    final intervalResults = MileageCalculator.calculateIntervalResults(sortedFuelRecords);
    final intervalMap = <int, IntervalResult>{};
    for (final inv in intervalResults) {
      if (inv.record.id != null) {
        intervalMap[inv.record.id!] = inv;
      }
    }

    // Odometer span and fuel totals
    double minOdometer = sortedFuelRecords.isNotEmpty ? sortedFuelRecords.first.odometer : 0.0;
    double maxOdometer = sortedFuelRecords.isNotEmpty ? sortedFuelRecords.last.odometer : 0.0;
    double totalOdometerDelta = maxOdometer > minOdometer ? maxOdometer - minOdometer : 0.0;

    double totalFuelVolume = 0.0;
    double totalFuelSpend = 0.0;
    for (final r in sortedFuelRecords) {
      totalFuelVolume += r.volume;
      totalFuelSpend += r.paidAmount;
    }
    final weightedMileage = MileageCalculator.calculateWeightedRunningAverage(sortedFuelRecords);

    // 2. Filter service sessions
    final filteredService = serviceSessions.where((s) {
      return !s.serviceDate.isBefore(dateRange.start) &&
          !s.serviceDate.isAfter(dateRange.end.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));

    double totalServiceSpend = 0.0;
    for (final s in filteredService) {
      totalServiceSpend += (s.totalCost ?? 0.0);
    }

    // 3. Filter non-fuel expenses
    final filteredExpenses = nonFuelExpenses.where((e) {
      return !e.date.isBefore(dateRange.start) &&
          !e.date.isAfter(dateRange.end.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    double totalNonFuelSpend = 0.0;
    for (final e in filteredExpenses) {
      totalNonFuelSpend += e.amount;
    }

    // 4. Grand Totals (TCO)
    final grandTotalSpend = totalFuelSpend + totalServiceSpend + totalNonFuelSpend;
    final allInclusiveCostPerKm = totalOdometerDelta > 0
        ? grandTotalSpend / totalOdometerDelta
        : 0.0;

    // Primary Brand Colors
    const primaryColor = PdfColor.fromInt(0xFF1E3A8A); // Deep Navy Blue
    const secondaryColor = PdfColor.fromInt(0xFF0D9488); // Teal
    const headerBgColor = PdfColor.fromInt(0xFFF1F5F9); // Light Slate
    const altRowColor = PdfColor.fromInt(0xFFF8FAFC);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'VEHICLE EXPENSE & TAX AUDIT REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        companyOrOwnerName,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Period: ${dateFormatter.format(dateRange.start)} to ${dateFormatter.format(dateRange.end)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Generated: ${dateFormatter.format(DateTime.now())}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: primaryColor),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Fuel Tracker System | Confidential Audit Document',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Vehicle & Reporting Overview Card
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: headerBgColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Vehicle Profile',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          vehicle.name,
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text(
                          'Type: ${vehicle.type.name.toUpperCase()}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Odometer Span',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Start: ${intFormatter.format(minOdometer)} km',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'End: ${intFormatter.format(maxOdometer)} km',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Distance: ${intFormatter.format(totalOdometerDelta)} km',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Activity Count',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Refuels: ${sortedFuelRecords.length}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Service Visits: ${filteredService.length}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Expenses: ${filteredExpenses.length}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 2. Financial & Efficiency KPI Summary Grid
            pw.Text(
              'FINANCIAL & OPERATIONAL SUMMARY (TCO)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: altRowColor),
                  children: [
                    _buildKpiCell('Total Fuel Volume', '${currencyFormatter.format(totalFuelVolume)} L'),
                    _buildKpiCell('Running Mileage', weightedMileage > 0 ? '${weightedMileage.toStringAsFixed(2)} km/L' : 'N/A'),
                    _buildKpiCell('Total Fuel Spend', '$currencyCode ${currencyFormatter.format(totalFuelSpend)}'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildKpiCell('Maintenance Spend', '$currencyCode ${currencyFormatter.format(totalServiceSpend)}'),
                    _buildKpiCell('Non-Fuel Expenses', '$currencyCode ${currencyFormatter.format(totalNonFuelSpend)}'),
                    _buildKpiCell(
                      'Total Spend (TCO)',
                      '$currencyCode ${currencyFormatter.format(grandTotalSpend)}',
                      isBold: true,
                      color: primaryColor,
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: altRowColor),
                  children: [
                    _buildKpiCell('Total Distance', '${intFormatter.format(totalOdometerDelta)} km'),
                    _buildKpiCell(
                      'All-Inclusive Cost / km',
                      allInclusiveCostPerKm > 0 ? '$currencyCode ${allInclusiveCostPerKm.toStringAsFixed(2)}/km' : 'N/A',
                      isBold: true,
                      color: secondaryColor,
                    ),
                    _buildKpiCell(
                      'Fuel Cost / km',
                      totalOdometerDelta > 0 ? '$currencyCode ${(totalFuelSpend / totalOdometerDelta).toStringAsFixed(2)}/km' : 'N/A',
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // 3. Itemized Refueling Activity
            pw.Text(
              '1. ITEMIZED REFUELING LOG',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),
            if (sortedFuelRecords.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text('No refueling records in selected period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: [
                  'Date',
                  'Odometer (km)',
                  'Delta (km)',
                  'Station / Location',
                  'Fuel',
                  'Volume (L)',
                  'Rate ($currencyCode)',
                  'Paid ($currencyCode)',
                ],
                data: sortedFuelRecords.map((r) {
                  final inv = r.id != null ? intervalMap[r.id!] : null;
                  final locationName = r.locationId != null
                      ? savedLocations[r.locationId]?.name ?? 'Station #${r.locationId}'
                      : 'Unknown';
                  final fuelTypeName = fuelTypes[r.fuelTypeId]?.name ?? 'Fuel #${r.fuelTypeId}';
                  final deltaStr = inv != null && inv.distance > 0 ? intFormatter.format(inv.distance) : '-';

                  return [
                    dateFormatter.format(r.date),
                    intFormatter.format(r.odometer),
                    deltaStr,
                    locationName,
                    fuelTypeName,
                    r.volume.toStringAsFixed(2),
                    r.rate.toStringAsFixed(2),
                    currencyFormatter.format(r.paidAmount),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: primaryColor),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: const pw.BoxDecoration(color: altRowColor),
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                },
              ),
            pw.SizedBox(height: 16),

            // 4. Itemized Maintenance & Service Visits
            if (filteredService.isNotEmpty) ...[
              pw.Text(
                '2. MAINTENANCE & SERVICE LOG',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Date',
                  'Odometer (km)',
                  'Workshop / Location',
                  'Details / Notes',
                  'Cost ($currencyCode)',
                ],
                data: filteredService.map((s) {
                  final locationName = s.workshopName ??
                      (s.locationId != null ? savedLocations[s.locationId]?.name ?? 'Workshop' : 'General');
                  final costStr = s.totalCost != null ? currencyFormatter.format(s.totalCost!) : '0.00';

                  return [
                    dateFormatter.format(s.serviceDate),
                    intFormatter.format(s.odometer),
                    locationName,
                    s.workshopName ?? 'Periodic Maintenance',
                    costStr,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: secondaryColor),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: const pw.BoxDecoration(color: altRowColor),
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 16),
            ],

            // 5. Itemized Non-Fuel Expenses
            if (filteredExpenses.isNotEmpty) ...[
              pw.Text(
                '3. AUXILIARY NON-FUEL EXPENSES LOG',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Date',
                  'Category',
                  'Odometer (km)',
                  'Notes / Description',
                  'Amount ($currencyCode)',
                ],
                data: filteredExpenses.map((e) {
                  return [
                    dateFormatter.format(e.date),
                    e.category.displayName,
                    e.odometer != null ? intFormatter.format(e.odometer!) : '-',
                    e.notes ?? '-',
                    currencyFormatter.format(e.amount),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: const pw.BoxDecoration(color: altRowColor),
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 24),
            ],

            // 6. Signature & Verification Sign-Off Block
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VERIFICATION & AUDIT SIGN-OFF',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'I hereby certify that the refueling, maintenance, and operating expenses itemized above were accurately incurred in the operation of the designated vehicle for the stated period.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 180,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700, width: 0.8)),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('Driver / Vehicle Custodian', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('Date: ____________________', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 180,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey700, width: 0.8)),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('Fleet Manager / Tax Auditor', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text('Date: ____________________', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildKpiCell(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
