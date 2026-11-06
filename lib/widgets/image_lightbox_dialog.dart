// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter/material.dart';

class ImageLightboxDialog extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback? onDelete;

  const ImageLightboxDialog({
    super.key,
    required this.imagePath,
    this.title = 'Attachment Preview',
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required String imagePath,
    String title = 'Attachment Preview',
    VoidCallback? onDelete,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => ImageLightboxDialog(
        imagePath: imagePath,
        title: title,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete Attachment',
                          onPressed: () {
                            Navigator.of(context).pop();
                            onDelete!();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Zoomable Image Area
            Expanded(
              child: Center(
                child: file.existsSync()
                    ? InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text(
                              'Unable to load image file',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Attachment file not found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
