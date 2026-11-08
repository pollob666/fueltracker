// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WebDavConfig {
  final String serverUrl;
  final String username;
  final String password;

  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  bool get isValid => serverUrl.trim().isNotEmpty && username.trim().isNotEmpty;

  String get authHeader {
    final credentials = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  Map<String, String> get defaultHeaders => {
        'Authorization': authHeader,
        'User-Agent': 'FuelTracker/3.1 (Android; Flutter)',
      };

  Map<String, dynamic> toMap() => {
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
      };

  factory WebDavConfig.fromMap(Map<String, dynamic> map) => WebDavConfig(
        serverUrl: map['serverUrl'] as String? ?? '',
        username: map['username'] as String? ?? '',
        password: map['password'] as String? ?? '',
      );
}

class WebDavFileInfo {
  final String name;
  final String href;
  final int contentLength;
  final DateTime? lastModified;

  const WebDavFileInfo({
    required this.name,
    required this.href,
    this.contentLength = 0,
    this.lastModified,
  });
}

class WebDavException implements Exception {
  final String message;
  final int? statusCode;
  const WebDavException(this.message, {this.statusCode});
  @override
  String toString() => 'WebDavException: $message (status: $statusCode)';
}

class WebDavService {
  static const String _prefKey = 'webdav_config';

  /// Loads saved WebDAV credentials from SharedPreferences.
  static Future<WebDavConfig?> loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return WebDavConfig.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Persists WebDAV credentials to SharedPreferences.
  static Future<void> saveConfig(WebDavConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(config.toMap()));
  }

  /// Clears saved WebDAV credentials.
  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// Tests connectivity and authentication to the remote WebDAV endpoint.
  static Future<bool> testConnection({
    required WebDavConfig config,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(config.serverUrl);
      final request = http.Request('PROPFIND', uri)
        ..headers.addAll(config.defaultHeaders)
        ..headers['Depth'] = '0';

      final streamedResponse = await httpClient.send(request);
      final code = streamedResponse.statusCode;
      return code == 200 || code == 207 || code == 204;
    } catch (e) {
      return false;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Uploads an encrypted backup file to the WebDAV endpoint.
  static Future<bool> uploadBackup({
    required WebDavConfig config,
    required String fileName,
    required Uint8List content,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final cleanBaseUrl = config.serverUrl.endsWith('/')
          ? config.serverUrl
          : '${config.serverUrl}/';
      final targetUri = Uri.parse('$cleanBaseUrl$fileName');

      final response = await httpClient.put(
        targetUri,
        headers: {
          ...config.defaultHeaders,
          'Content-Type': 'application/octet-stream',
        },
        body: content,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      throw WebDavException(
        'Upload failed with response: ${response.body}',
        statusCode: response.statusCode,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Lists remote `.ftbackup` files from the WebDAV endpoint.
  static Future<List<WebDavFileInfo>> listRemoteBackups({
    required WebDavConfig config,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(config.serverUrl);
      final request = http.Request('PROPFIND', uri)
        ..headers.addAll(config.defaultHeaders)
        ..headers['Depth'] = '1';

      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 207) {
        throw WebDavException(
          'Failed to query remote files',
          statusCode: response.statusCode,
        );
      }

      // Parse XML response for .ftbackup entries
      final List<WebDavFileInfo> files = [];
      final hrefMatches = RegExp(r'<[^>]*href[^>]*>([^<]+)<\/[^>]*href>', caseSensitive: false)
          .allMatches(response.body);

      for (final match in hrefMatches) {
        final href = match.group(1) ?? '';
        final segments = Uri.decodeComponent(href).split('/');
        final name = segments.where((s) => s.isNotEmpty).lastOrNull ?? '';

        if (name.endsWith('.ftbackup')) {
          files.add(WebDavFileInfo(
            name: name,
            href: href,
          ));
        }
      }

      return files;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Downloads an encrypted backup file from the WebDAV endpoint.
  static Future<Uint8List> downloadBackup({
    required WebDavConfig config,
    required String remoteFileName,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final cleanBaseUrl = config.serverUrl.endsWith('/')
          ? config.serverUrl
          : '${config.serverUrl}/';
      final targetUri = Uri.parse('$cleanBaseUrl$remoteFileName');

      final response = await httpClient.get(
        targetUri,
        headers: config.defaultHeaders,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      throw WebDavException(
        'Failed to download remote backup',
        statusCode: response.statusCode,
      );
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
