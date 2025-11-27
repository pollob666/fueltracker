
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static const String _repo = 'pollob666/fueltracker';
  static const String _releasesUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  Future<String?> get latestVersion async {
    try {
      final response = await http.get(Uri.parse(_releasesUrl));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['tag_name'];
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  Future<String> get currentVersion async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'v\${packageInfo.version}+\${packageInfo.buildNumber}';
  }

  Future<bool> get isUpdateAvailable async {
    final latest = await latestVersion;
    if (latest == null) {
      return false;
    }
    final current = await currentVersion;
    return latest != current;
  }
}
