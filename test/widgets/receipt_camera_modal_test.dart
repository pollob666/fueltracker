// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/widgets/image_lightbox_dialog.dart';
import 'package:fuel_tracker/widgets/receipt_camera_modal.dart';

void main() {
  testWidgets('ReceiptCameraModal renders options for camera and gallery',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReceiptCameraModal(
            title: 'Scan Receipt or Meter',
            prefix: 'receipt',
          ),
        ),
      ),
    );

    expect(find.text('Scan Receipt or Meter'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(
      find.text(
        'Capture a photo of the dispenser LCD, meter gauge, or receipt to auto-fill form values.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ImageLightboxDialog renders title, close button, and missing image placeholder',
      (WidgetTester tester) async {
    bool deleteCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageLightboxDialog(
            imagePath: '/non/existent/path.jpg',
            title: 'Receipt Preview',
            onDelete: () => deleteCalled = true,
          ),
        ),
      ),
    );

    expect(find.text('Receipt Preview'), findsOneWidget);
    expect(find.text('Attachment file not found'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deleteCalled, isTrue);
  });
}
