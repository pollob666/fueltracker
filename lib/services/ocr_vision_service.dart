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
  /// Pure regex parsing engine extracting fuel and odometer metrics from raw OCR text.
  static OcrParsedResult parseReceiptText(String text) {
    if (text.trim().isEmpty) {
      return const OcrParsedResult(rawText: '');
    }

    final lines = text
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
      r'(?:ODO(?:METER)?|TOTAL\s*KM|KILOMETER|DIST(?:ANCE)?)\s*[:.]?\s*([0-9]{3,7}(?:\.[0-9])?)',
      caseSensitive: false,
    );
    final odoRegexWithUnit = RegExp(
      r'([0-9]{3,7}(?:\.[0-9])?)\s*(?:KM|KMS)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchKeyword = odoRegexWithKeyword.firstMatch(line);
      if (matchKeyword != null) {
        parsedOdometer = double.tryParse(matchKeyword.group(1)!.replaceAll(',', ''));
        if (parsedOdometer != null) break;
      }
      final matchUnit = odoRegexWithUnit.firstMatch(line);
      if (matchUnit != null) {
        parsedOdometer = double.tryParse(matchUnit.group(1)!.replaceAll(',', ''));
        if (parsedOdometer != null) break;
      }
    }

    // 2. Volume Heuristics (Litres, Liters, L, Gallons, m3)
    final volumeRegex = RegExp(
      r'(?:VOLUME|VOL|QTY|QUANTITY|LITRES?|LITERS?)\s*[:.]?\s*([0-9]{1,4}(?:[.,][0-9]{1,3})?)',
      caseSensitive: false,
    );
    final volumeTrailingUnitRegex = RegExp(
      r'([0-9]{1,4}[.,][0-9]{1,3})\s*(?:L|LTR|LTRS|LITRE|LITRES|GAL|M3)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchVol = volumeRegex.firstMatch(line);
      if (matchVol != null) {
        final val = double.tryParse(matchVol.group(1)!.replaceAll(',', '.'));
        if (val != null && val > 0 && val < 500) {
          parsedVolume = val;
          break;
        }
      }
      final matchTrailing = volumeTrailingUnitRegex.firstMatch(line);
      if (matchTrailing != null) {
        final val = double.tryParse(matchTrailing.group(1)!.replaceAll(',', '.'));
        if (val != null && val > 0 && val < 500) {
          parsedVolume = val;
          break;
        }
      }
    }

    // 3. Rate / Unit Price Heuristics
    final rateRegex = RegExp(
      r'(?:RATE|PRICE(?:\s*/\s*L)?|UNIT\s*PRICE|PRICE\s*PER\s*LITRE)\s*[:.]?\s*(?:BDT|TK|RS|\$)?\s*([0-9]{1,4}(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final rateTrailingUnitRegex = RegExp(
      r'(?:@|AT)\s*([0-9]{1,4}(?:[.,][0-9]{1,2})?)|([0-9]{2,4}[.,][0-9]{2})\s*/\s*(?:L|LTR)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchRate = rateRegex.firstMatch(line);
      if (matchRate != null) {
        final val = double.tryParse(matchRate.group(1)!.replaceAll(',', '.'));
        if (val != null && val > 0) {
          parsedRate = val;
          break;
        }
      }
      final matchAt = rateTrailingUnitRegex.firstMatch(line);
      if (matchAt != null) {
        final raw = matchAt.group(1) ?? matchAt.group(2);
        if (raw != null) {
          final val = double.tryParse(raw.replaceAll(',', '.'));
          if (val != null && val > 0) {
            parsedRate = val;
            break;
          }
        }
      }
    }

    // 4. Total Paid Amount Heuristics
    final totalRegex = RegExp(
      r'(?:TOTAL(?:\s*AMOUNT|\s*PAID)?|NET(?:\s*AMOUNT)?|PAID|GRAND\s*TOTAL|TOTAL\s*SALE|SALE|BILL)\s*[:.]?\s*(?:BDT|TK|RS|\$)?\s*([0-9]{1,6}(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matchTotal = totalRegex.firstMatch(line);
      if (matchTotal != null) {
        final val = double.tryParse(matchTotal.group(1)!.replaceAll(',', '.'));
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
