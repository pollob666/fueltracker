
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:version/version.dart';

class VersionService {
  static const String _repo = 'pollob666/fueltracker';
  static const String _releasesUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const String _keySkippedVersion = 'skipped_update_version';

  static bool isDismissedForSession = false;

  Future<bool> isVersionSkipped(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySkippedVersion) == version;
  }

  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySkippedVersion, version);
  }

  void dismissForSession() {
    isDismissedForSession = true;
  }

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
    return 'v${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<bool> get isUpdateAvailable async {
    final latest = await latestVersion;
    if (latest == null) {
      return false;
    }
    final current = await currentVersion;

    try {
      // Use the version package to parse and compare versions
      final latestVersion = Version.parse(latest.replaceFirst('v', ''));
      final currentVersion = Version.parse(current.replaceFirst('v', ''));
      return latestVersion > currentVersion;
    } catch (e) {
      // Fallback to simple string comparison in case of parsing errors
      return latest != current;
    }
  }
}
