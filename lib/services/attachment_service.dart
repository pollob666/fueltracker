// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AttachmentService {
  /// Returns the base directory for persistently scoped attachments.
  static Future<String> getAttachmentsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Copies an image file into the application's scoped attachment storage.
  static Future<String> saveAttachment(String sourcePath, {String prefix = 'attach'}) async {
    final folder = await getAttachmentsDirectory();
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destination = p.join(folder, filename);
    await File(sourcePath).copy(destination);
    return destination;
  }

  /// Deletes an attachment from scoped storage if it exists.
  static Future<bool> deleteAttachment(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Checks whether an attachment file exists.
  static Future<bool> attachmentExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    return await File(filePath).exists();
  }
}
