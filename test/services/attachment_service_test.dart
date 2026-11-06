// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/attachment_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final Directory tempDir;
  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ft_attachments_test');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AttachmentService saves, verifies existence, and deletes scoped files', () async {
    // 1. Create a dummy source file
    final sourceFile = File('${tempDir.path}/test_source.jpg');
    await sourceFile.writeAsString('fake_image_bytes');

    // 2. Save attachment
    final savedPath = await AttachmentService.saveAttachment(sourceFile.path, prefix: 'receipt');
    expect(savedPath, contains('receipt_'));
    expect(await AttachmentService.attachmentExists(savedPath), isTrue);

    // 3. Delete attachment
    final deleted = await AttachmentService.deleteAttachment(savedPath);
    expect(deleted, isTrue);
    expect(await AttachmentService.attachmentExists(savedPath), isFalse);

    // 4. Deleting non-existent attachment returns false
    final deletedAgain = await AttachmentService.deleteAttachment(savedPath);
    expect(deletedAgain, isFalse);
  });
}
