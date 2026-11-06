// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:fuel_tracker/services/ocr_vision_service.dart';

class OcrModalResult {
  final String imagePath;
  final OcrParsedResult ocrResult;

  const OcrModalResult({
    required this.imagePath,
    required this.ocrResult,
  });
}

class ReceiptCameraModal extends StatefulWidget {
  final String title;
  final String prefix;

  const ReceiptCameraModal({
    super.key,
    this.title = 'Scan Receipt or Meter',
    this.prefix = 'receipt',
  });

  static Future<OcrModalResult?> show(
    BuildContext context, {
    String title = 'Scan Receipt or Meter',
    String prefix = 'receipt',
  }) {
    return showModalBottomSheet<OcrModalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptCameraModal(title: title, prefix: prefix),
    );
  }

  @override
  State<ReceiptCameraModal> createState() => _ReceiptCameraModalState();
}

class _ReceiptCameraModalState extends State<ReceiptCameraModal> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String? _capturedPath;
  OcrParsedResult? _ocrResult;
  String? _errorMessage;

  Future<void> _captureOrPick(ImageSource source) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Persist to scoped attachments directory
      final savedPath = await AttachmentService.saveAttachment(
        picked.path,
        prefix: widget.prefix,
      );

      // Run on-device OCR
      final ocr = await OcrVisionService.processImage(savedPath);

      setState(() {
        _capturedPath = savedPath;
        _ocrResult = ocr;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error capturing image: $e';
        _isProcessing = false;
      });
    }
  }

  void _applyAllAndClose() {
    if (_capturedPath != null && _ocrResult != null) {
      Navigator.of(context).pop(OcrModalResult(
        imagePath: _capturedPath!,
        ocrResult: _ocrResult!,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Icon(Icons.document_scanner, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing image with OCR vision...'),
                ],
              ),
            )
          else if (_capturedPath != null && _ocrResult != null) ...[
            // Image Preview + OCR Results
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_capturedPath!),
                    width: 90,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected Values',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (!_ocrResult!.hasAnyMetric)
                        Text(
                          'No clear numbers detected. You can still keep the photo attachment.',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        )
                      else ...[
                        if (_ocrResult!.odometer != null)
                          _buildDetectedBadge('Odometer', '${_ocrResult!.odometer!.toStringAsFixed(0)} km'),
                        if (_ocrResult!.volume != null)
                          _buildDetectedBadge('Volume', '${_ocrResult!.volume!.toStringAsFixed(2)} L'),
                        if (_ocrResult!.rate != null)
                          _buildDetectedBadge('Rate', '${_ocrResult!.rate!.toStringAsFixed(2)}'),
                        if (_ocrResult!.paidAmount != null)
                          _buildDetectedBadge('Paid Amount', '${_ocrResult!.paidAmount!.toStringAsFixed(2)}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            FilledButton.icon(
              onPressed: _applyAllAndClose,
              icon: const Icon(Icons.check),
              label: const Text('Apply Detected Values to Form'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _capturedPath = null;
                  _ocrResult = null;
                });
              },
              child: const Text('Retake Photo'),
            ),
          ] else ...[
            // Selection Options
            Text(
              'Capture a photo of the dispenser LCD, meter gauge, or receipt to auto-fill form values.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _captureOrPick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _captureOrPick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetectedBadge(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
