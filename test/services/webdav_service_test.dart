// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/services/webdav_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('WebDavService Unit Tests', () {
    const config = WebDavConfig(
      serverUrl: 'https://cloud.example.com/remote.php/dav/files/user/FuelTracker/',
      username: 'testuser',
      password: 'testpassword123',
    );

    test('generates valid Basic Auth header', () {
      expect(config.authHeader, startsWith('Basic '));
      final decoded = utf8.decode(base64Decode(config.authHeader.replaceFirst('Basic ', '')));
      expect(decoded, equals('testuser:testpassword123'));
    });

    test('testConnection returns true for status 207 Multi-Status', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('PROPFIND'));
        expect(request.headers['Authorization'], equals(config.authHeader));
        return http.Response('', 207);
      });

      final isSuccess = await WebDavService.testConnection(
        config: config,
        client: mockClient,
      );
      expect(isSuccess, isTrue);
    });

    test('uploadBackup sends PUT request with payload bytes', () async {
      final dummyPayload = Uint8List.fromList([1, 2, 3, 4, 5]);

      final mockClient = MockClient((request) async {
        expect(request.method, equals('PUT'));
        expect(request.url.path, endsWith('/backup_20261108.ftbackup'));
        expect(request.bodyBytes, equals(dummyPayload));
        return http.Response('', 201);
      });

      final uploaded = await WebDavService.uploadBackup(
        config: config,
        fileName: 'backup_20261108.ftbackup',
        content: dummyPayload,
        client: mockClient,
      );
      expect(uploaded, isTrue);
    });

    test('listRemoteBackups parses XML PROPFIND response for .ftbackup files', () async {
      const xmlResponse = '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/remote.php/dav/files/user/FuelTracker/</d:href>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/FuelTracker/backup_20261001.ftbackup</d:href>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/FuelTracker/backup_20261015.ftbackup</d:href>
  </d:response>
  <d:response>
    <d:href>/remote.php/dav/files/user/FuelTracker/notes.txt</d:href>
  </d:response>
</d:multistatus>''';

      final mockClient = MockClient((request) async {
        expect(request.method, equals('PROPFIND'));
        return http.Response(xmlResponse, 207);
      });

      final files = await WebDavService.listRemoteBackups(
        config: config,
        client: mockClient,
      );

      expect(files.length, equals(2));
      expect(files[0].name, equals('backup_20261001.ftbackup'));
      expect(files[1].name, equals('backup_20261015.ftbackup'));
    });

    test('downloadBackup returns remote file bytes', () async {
      final remoteBytes = utf8.encode('{"format":"ftbackup"}');

      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.path, endsWith('/backup_target.ftbackup'));
        return http.Response.bytes(remoteBytes, 200);
      });

      final downloaded = await WebDavService.downloadBackup(
        config: config,
        remoteFileName: 'backup_target.ftbackup',
        client: mockClient,
      );

      expect(downloaded, equals(remoteBytes));
    });
  });
}
