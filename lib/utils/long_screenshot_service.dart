// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LongScreenshotService {
  LongScreenshotService._();

  /// Captures the widget subtree under [boundaryKey] as a high-resolution PNG image
  /// and opens the system share dialog.
  static Future<bool> captureAndShare({
    required BuildContext context,
    required GlobalKey boundaryKey,
    String fileNamePrefix = 'fueltracker_screenshot',
    String? shareText,
    double pixelRatio = 2.0,
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('LongScreenshotService: RenderRepaintBoundary not found.');
        return false;
      }

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('LongScreenshotService: Failed to convert image to PNG bytes.');
        return false;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/${fileNamePrefix}_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      if (!context.mounted) return true;

      final box = context.findRenderObject() as RenderBox?;
      final Rect? sharePositionOrigin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'image/png')],
          text: shareText ?? 'Fuel Tracker Long Screenshot',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      return true;
    } catch (e, stack) {
      debugPrint('LongScreenshotService error: $e\n$stack');
      return false;
    }
  }
}
