// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/ocr_vision_service.dart';

void main() {
  group('OcrVisionService Heuristic Parsing Tests', () {
    test('parses standard fuel dispenser LCD text', () {
      const dispenserText = '''
        PADMA OIL COMPANY LTD
        SALE: 2500.00 BDT
        VOLUME: 19.23 L
        RATE: 130.00 / L
        THANK YOU
      ''';

      final result = OcrVisionService.parseReceiptText(dispenserText);

      expect(result.paidAmount, equals(2500.00));
      expect(result.volume, equals(19.23));
      expect(result.rate, equals(130.00));
      expect(result.hasAnyMetric, isTrue);
    });

    test('parses receipt with unit trailing formats and ODO keyword', () {
      const receiptText = '''
        DHANMONDI PETROL PUMP
        DATE: 2026-10-15 14:30
        ODO: 45210 KM
        OCTANE
        QTY: 32.50 LTR
        PRICE: 130.00
        TOTAL: 4225.00
      ''';

      final result = OcrVisionService.parseReceiptText(receiptText);

      expect(result.odometer, equals(45210.0));
      expect(result.volume, equals(32.50));
      expect(result.rate, equals(130.00));
      expect(result.paidAmount, equals(4225.00));
    });

    test('infers missing total amount when volume and rate are present', () {
      const partialText = '''
        PETROL STATION
        VOLUME: 20.00 L
        RATE: 125.00
      ''';

      final result = OcrVisionService.parseReceiptText(partialText);

      expect(result.volume, equals(20.0));
      expect(result.rate, equals(125.0));
      expect(result.paidAmount, equals(2500.00));
    });

    test('infers missing volume when total amount and rate are present', () {
      const partialText = '''
        TOTAL: 3900.00 BDT
        RATE: 130.00
      ''';

      final result = OcrVisionService.parseReceiptText(partialText);

      expect(result.paidAmount, equals(3900.00));
      expect(result.rate, equals(130.00));
      expect(result.volume, equals(30.0));
    });

    test('parses odometer cluster display text', () {
      const odoText = '''
        AVG 14.2 km/L
        TOTAL KM 12850.5
        ECO MODE
      ''';

      final result = OcrVisionService.parseReceiptText(odoText);

      expect(result.odometer, equals(12850.5));
    });

    test('handles empty and noisy text gracefully without throwing', () {
      final emptyResult = OcrVisionService.parseReceiptText('');
      expect(emptyResult.hasAnyMetric, isFalse);

      final noisyResult = OcrVisionService.parseReceiptText('WELCOME TO THE CITY RESTAURANT\nHAVE A NICE DAY');
      expect(noisyResult.hasAnyMetric, isFalse);
    });
  });
}
