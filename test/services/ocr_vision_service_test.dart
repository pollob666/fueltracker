// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/ocr_vision_service.dart';

void main() {
  group('OcrVisionService Bengali Digit Normalization', () {
    test('normalizes all Bengali numerals (০-৯) to ASCII digits (0-9)', () {
      const bengaliDigits = '০১২৩৪৫৬৭৮৯';
      expect(OcrVisionService.normalizeBengaliDigits(bengaliDigits), equals('0123456789'));
    });

    test('preserves ASCII characters, punctuation, and mixed text unchanged', () {
      const mixed = 'ওডোমিটার: ১২৫০০ কিমি (ODO: 12500 km) - দর: ১৩০.৫০ টাকা';
      final normalized = OcrVisionService.normalizeBengaliDigits(mixed);
      expect(normalized, equals('ওডোমিটার: 12500 কিমি (ODO: 12500 km) - দর: 130.50 টাকা'));
    });
  });

  group('OcrVisionService Localized Number Parsing', () {
    test('parses Western formats with comma thousand and dot decimal', () {
      expect(OcrVisionService.parseLocalizedNumber('1,234.56'), equals(1234.56));
      expect(OcrVisionService.parseLocalizedNumber('45,210'), equals(45210.0));
    });

    test('parses Continental/European formats with dot thousand and comma decimal', () {
      expect(OcrVisionService.parseLocalizedNumber('1.234,56'), equals(1234.56));
      expect(OcrVisionService.parseLocalizedNumber('35,50', isVolume: true), equals(35.50));
      expect(OcrVisionService.parseLocalizedNumber('85.400', isIntegerMetric: true), equals(85400.0));
    });

    test('parses South Asian grouping formats with multiple commas', () {
      expect(OcrVisionService.parseLocalizedNumber('1,25,000'), equals(125000.0));
      expect(OcrVisionService.parseLocalizedNumber('1,25,000.50'), equals(125000.50));
    });
  });

  group('OcrVisionService Table-Driven Synthetic Receipt Tests', () {
    // Note: These tests verify the regex parsing engine on controlled synthetic samples.
    // They do not claim accuracy on arbitrary real-world receipts.
    final testCases = <Map<String, dynamic>>[
      {
        'title': 'Case 1: Standard English/Western receipt',
        'raw': '''
SHELL GAS STATION
DATE: 2026-10-15
ODO: 45,210 KM
VOLUME: 19.23 L
RATE: 130.00 / L
TOTAL: 2,500.00 BDT
''',
        'odo': 45210.0,
        'vol': 19.23,
        'rate': 130.0,
        'total': 2500.0,
      },
      {
        'title': 'Case 2: European format (dot thousand separator, comma decimal)',
        'raw': '''
TOTAL ENERGIES BERLIN
KM: 85.400
VOL: 35,50 LTR
PREIS: 1,85 / L
SUMME: 65,68 EUR
''',
        'odo': 85400.0,
        'vol': 35.5,
        'rate': 1.85,
        'total': 65.68,
      },
      {
        'title': 'Case 3: Full Bengali script with Bengali digits and Bengali keywords',
        'raw': '''
যমুনা অটোমোবাইলস ফিলিং
ওডোমিটার: ৪৫,২১০ কিমি
পরিমাণ: ৩২.৫০ লিটার
দর: ১৩০.০০ টাকা
মোট: ৪,২২৫.০০ টাকা
''',
        'odo': 45210.0,
        'vol': 32.5,
        'rate': 130.0,
        'total': 4225.0,
      },
      {
        'title': 'Case 4: Bengali digits with English keywords and BDT currency',
        'raw': '''
PADMA OIL COMPANY
ODO: ৫২,১০০ KM
VOLUME: ২০.০০ L
RATE: ১২৫.০০
TOTAL: ২,৫০০.০০ BDT
''',
        'odo': 52100.0,
        'vol': 20.0,
        'rate': 125.0,
        'total': 2500.0,
      },
      {
        'title': 'Case 5: Comma-decimal volume and rate with plain integer total',
        'raw': '''
CALTEX REFUEL
TOTAL KM: 125000
QTY: 40,00 L
PRICE: 120,50
SALE: 4820
''',
        'odo': 125000.0,
        'vol': 40.0,
        'rate': 120.5,
        'total': 4820.0,
      },
      {
        'title': 'Case 6: South Asian grouping with Bengali numerals and distance keyword',
        'raw': '''
মেঘনা পেট্রোলিয়াম
দূরত্ব: ১,২৫,০০০ কিমি
পরিমাণ: ৫০.০০ লিটার
দর: ১৩০.০০ টাকা
মোট: ৬,৫০০.০০ টাকা
''',
        'odo': 125000.0,
        'vol': 50.0,
        'rate': 130.0,
        'total': 6500.0,
      },
      {
        'title': 'Case 7: Dispenser LCD format with comma decimal and Bengali numerals',
        'raw': '''
বিক্রয়: ৩,৭৫০.০০ টাকা
পরিমাণ: ৩০,০০ লিটার
দর: ১২৫,০০ টাকা
''',
        'odo': null,
        'vol': 30.0,
        'rate': 125.0,
        'total': 3750.0,
      },
      {
        'title': 'Case 8: Odometer with comma decimal and mathematically inferred total',
        'raw': '''
HIGHWAY REFUEL
DISTANCE: 12850,5 KM
LITRES: 25,00
RATE: 140,00
''',
        'odo': 12850.5,
        'vol': 25.0,
        'rate': 140.0,
        'total': 3500.0,
      },
      {
        'title': 'Case 9: Trailing unit formats in Bengali script',
        'raw': '''
সিলেট ফিলিং স্টেশন
ওডো: ৯৮,৫০০ কিমি
৪০.০০ লিটার
১৩৫.০০ / লিটার
মোট বিল: ৫,৪০০.০০ টাকা
''',
        'odo': 98500.0,
        'vol': 40.0,
        'rate': 135.0,
        'total': 5400.0,
      },
      {
        'title': 'Case 10: Mixed Bengali numerals, decimal comma, and inferred volume',
        'raw': '''
সোনারগাঁও সিএনজি অ্যান্ড পেট্রোল
ওডোমিটার: ৬৪,৩২০ কিমি
দর: ১২০,০০ টাকা
মোট: ৩,৬০০,০০ টাকা
''',
        'odo': 64320.0,
        'vol': 30.0,
        'rate': 120.0,
        'total': 3600.0,
      },
    ];

    for (final testCase in testCases) {
      test('correctly parses ${testCase['title']}', () {
        final result = OcrVisionService.parseReceiptText(testCase['raw'] as String);

        if (testCase['odo'] != null) {
          expect(result.odometer, equals(testCase['odo']), reason: 'Odometer mismatch in ${testCase['title']}');
        }
        if (testCase['vol'] != null) {
          expect(result.volume, equals(testCase['vol']), reason: 'Volume mismatch in ${testCase['title']}');
        }
        if (testCase['rate'] != null) {
          expect(result.rate, equals(testCase['rate']), reason: 'Rate mismatch in ${testCase['title']}');
        }
        if (testCase['total'] != null) {
          expect(result.paidAmount, equals(testCase['total']), reason: 'Total paid mismatch in ${testCase['title']}');
        }
      });
    }
  });

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
