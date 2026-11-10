// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParsedResult {
  final double? odometer;
  final double? volume;
  final double? rate;
  final double? paidAmount;
  final String rawText;
  final List<String> recognizedLines;

  const OcrParsedResult({
    this.odometer,
    this.volume,
    this.rate,
    this.paidAmount,
    required this.rawText,
    this.recognizedLines = const [],
  });

  bool get hasAnyMetric =>
      odometer != null || volume != null || rate != null || paidAmount != null;
}

class OcrVisionService {
  /// Converts Bengali Unicode digits (০-৯, \u09E6-\u09EF) to standard ASCII digits (0-9).
  static String normalizeBengaliDigits(String input) {
    const int bengaliZero = 0x09E6;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if (codeUnit >= bengaliZero && codeUnit <= bengaliZero + 9) {
        buffer.writeCharCode(0x30 + (codeUnit - bengaliZero));
      } else {
        buffer.write(input[i]);
      }
    }
    return buffer.toString();
  }

  /// Parses localized numbers containing comma or period thousand/decimal separators.
  /// Handles both standard Western (1,234.56) and European/Continental (1.234,56) formats,
  /// as well as simple comma decimals (19,23) and multi-part grouping (1,25,000).
  static double? parseLocalizedNumber(
    String raw, {
    bool isIntegerMetric = false,
    bool isVolume = false,
  }) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    final hasDot = s.contains('.');
    final hasComma = s.contains(',');

    // 1. Both separators present: Determine decimal by the rightmost occurrence
    if (hasDot && hasComma) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      if (lastDot > lastComma) {
        // Standard US/UK: comma thousand separator, dot decimal (e.g. 1,234.56)
        s = s.replaceAll(',', '');
      } else {
        // European: dot thousand separator, comma decimal (e.g. 1.234,56)
        s = s.replaceAll('.', '').replaceAll(',', '.');
      }
      return double.tryParse(s);
    }

    // 2. Only comma present
    if (hasComma) {
      final parts = s.split(',');
      if (parts.length > 2) {
        // Multiple commas: e.g. 1,25,000 or 1,25,000,50
        if (parts.last.length <= 2) {
          final integerPart = parts.sublist(0, parts.length - 1).join('');
          return double.tryParse('$integerPart.${parts.last}');
        }
        s = s.replaceAll(',', '');
        return double.tryParse(s);
      }
      final afterComma = parts[1];
      if (isVolume) {
        // Fuel volume on dispensers typically has 2 or 3 decimal places (e.g. 19,23 L)
        s = '${parts[0]}.${parts[1]}';
        return double.tryParse(s);
      }
      // If 3 digits after comma and leading integer <= 3 digits, treat as thousand separator
      if (afterComma.length == 3 && !afterComma.startsWith('00') && parts[0].length <= 3) {
        s = s.replaceAll(',', '');
        return double.tryParse(s);
      }
      // If 1 or 2 digits after comma, treat as decimal separator (e.g. 120,50)
      if (afterComma.length <= 2) {
        s = '${parts[0]}.${parts[1]}';
        return double.tryParse(s);
      }
      return double.tryParse(s.replaceAll(',', ''));
    }

    // 3. Only period present
    if (hasDot) {
      final parts = s.split('.');
      if (parts.length > 2) {
        // Multiple periods: e.g. 1.25.000 or European thousand grouping
        if (parts.last.length <= 2) {
          final integerPart = parts.sublist(0, parts.length - 1).join('');
          return double.tryParse('$integerPart.${parts.last}');
        }
        s = s.replaceAll('.', '');
        return double.tryParse(s);
      }
      final afterDot = parts[1];
      // For odometer, 3 digits after dot with small prefix indicates thousand grouping (e.g. 85.400 KM)
      if (isIntegerMetric && afterDot.length == 3 && parts[0].length <= 3) {
        s = s.replaceAll('.', '');
        return double.tryParse(s);
      }
      return double.tryParse(s);
    }

    // 4. Plain integer without separators
    return double.tryParse(s);
  }

  /// Pure regex parsing engine extracting fuel and odometer metrics from raw OCR text.
  /// Normalizes Bengali numerals (০-৯) to ASCII digits and parses localized comma/period separators.
  static OcrParsedResult parseReceiptText(String text) {
    if (text.trim().isEmpty) {
      return const OcrParsedResult(rawText: '');
    }

    final normalizedText = normalizeBengaliDigits(text);
    final lines = normalizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double? parsedOdometer;
    double? parsedVolume;
    double? parsedRate;
    double? parsedPaidAmount;

    // 1. Odometer Heuristics
    final odoRegexWithKeyword = RegExp(
      r'(?:ODO(?:METER)?|TOTAL\s*KM|KILOMETER|DIST(?:ANCE)?|KM|ওডোমিটার|ওডো|দূরত্ব)\s*[:.]?\s*([0-9]{1,7}(?:[.,][0-9]{1,3})*)',
      caseSensitive: false,
    );
    final odoRegexWithUnit = RegExp(
      r'([0-9]{1,7}(?:[.,][0-9]{1,3})*)\s*(?:KM|KMS|কিমি)(?!\s*/\s*(?:L|LTR|লিটার))\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchKeyword = odoRegexWithKeyword.firstMatch(line);
      if (matchKeyword != null) {
        parsedOdometer = parseLocalizedNumber(matchKeyword.group(1)!, isIntegerMetric: true);
        if (parsedOdometer != null) break;
      }
      final matchUnit = odoRegexWithUnit.firstMatch(line);
      if (matchUnit != null) {
        parsedOdometer = parseLocalizedNumber(matchUnit.group(1)!, isIntegerMetric: true);
        if (parsedOdometer != null) break;
      }
    }

    // 2. Volume Heuristics (Litres, Liters, L, Gallons, m3, Bengali equivalents)
    final volumeRegex = RegExp(
      r'(?:VOLUME|VOL|QTY|QUANTITY|LITRES?|LITERS?|পরিমাণ|ভলিউম|লিটার)\s*[:.]?\s*([0-9]{1,5}(?:[.,][0-9]{1,3})*)',
      caseSensitive: false,
    );
    final volumeTrailingUnitRegex = RegExp(
      r'([0-9]{1,5}(?:[.,][0-9]{1,3})*)\s*(?:L|LTR|LTRS|LITRE|LITRES|GAL|M3|লিটার|লি)(?!\s*(?:/|PER|প্রতি))\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchVol = volumeRegex.firstMatch(line);
      if (matchVol != null) {
        final val = parseLocalizedNumber(matchVol.group(1)!, isVolume: true);
        if (val != null && val > 0 && val < 500) {
          parsedVolume = val;
          break;
        }
      }
      final matchTrailing = volumeTrailingUnitRegex.firstMatch(line);
      if (matchTrailing != null) {
        final val = parseLocalizedNumber(matchTrailing.group(1)!, isVolume: true);
        if (val != null && val > 0 && val < 500) {
          parsedVolume = val;
          break;
        }
      }
    }

    // 3. Rate / Unit Price Heuristics
    final rateRegex = RegExp(
      r'(?:RATE|PRICE(?:\s*/\s*L)?|UNIT\s*PRICE|PRICE\s*PER\s*LITRE|দর|মূল্য|প্রতি\s*লিটার)\s*[:.]?\s*(?:BDT|TK|RS|টাকা|\$|EUR|USD)?\s*([0-9]{1,5}(?:[.,][0-9]{1,3})*)',
      caseSensitive: false,
    );
    final rateTrailingUnitRegex = RegExp(
      r'(?:@|AT)\s*([0-9]{1,5}(?:[.,][0-9]{1,3})*)|([0-9]{1,5}(?:[.,][0-9]{1,3})*)\s*/\s*(?:L|LTR|লিটার)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchRate = rateRegex.firstMatch(line);
      if (matchRate != null) {
        final val = parseLocalizedNumber(matchRate.group(1)!);
        if (val != null && val > 0) {
          parsedRate = val;
          break;
        }
      }
      final matchAt = rateTrailingUnitRegex.firstMatch(line);
      if (matchAt != null) {
        final raw = matchAt.group(1) ?? matchAt.group(2);
        if (raw != null) {
          final val = parseLocalizedNumber(raw);
          if (val != null && val > 0) {
            parsedRate = val;
            break;
          }
        }
      }
    }

    // 4. Total Paid Amount Heuristics
    final totalRegex = RegExp(
      r'(?:TOTAL(?:\s*AMOUNT|\s*PAID)?|NET(?:\s*AMOUNT)?|PAID|GRAND\s*TOTAL|TOTAL\s*SALE|SALE|BILL|SUMME|মোট|সর্বমোট|টাকা|বিল|বিক্রয়)\s*[:.]?\s*(?:BDT|TK|RS|টাকা|\$|EUR|USD)?\s*([0-9]{1,7}(?:[.,][0-9]{1,3})*)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchTotal = totalRegex.firstMatch(line);
      if (matchTotal != null) {
        final val = parseLocalizedNumber(matchTotal.group(1)!);
        if (val != null && val > 0) {
          parsedPaidAmount = val;
          break;
        }
      }
    }

    // 5. Cross-Reconciliation & Mathematical Inferences
    if (parsedVolume != null && parsedRate != null && parsedPaidAmount == null) {
      parsedPaidAmount = (parsedVolume * parsedRate * 100).round() / 100;
    } else if (parsedPaidAmount != null && parsedRate != null && parsedRate > 0 && parsedVolume == null) {
      parsedVolume = (parsedPaidAmount / parsedRate * 100).round() / 100;
    } else if (parsedPaidAmount != null && parsedVolume != null && parsedVolume > 0 && parsedRate == null) {
      parsedRate = (parsedPaidAmount / parsedVolume * 100).round() / 100;
    }

    return OcrParsedResult(
      odometer: parsedOdometer,
      volume: parsedVolume,
      rate: parsedRate,
      paidAmount: parsedPaidAmount,
      rawText: text,
      recognizedLines: lines,
    );
  }

  /// Performs ML Kit on-device text recognition on an image file and extracts metrics.
  static Future<OcrParsedResult> processImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return parseReceiptText(recognizedText.text);
    } finally {
      await textRecognizer.close();
    }
  }
}
