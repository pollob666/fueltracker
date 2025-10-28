// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static double maxVolume = 100.0;
  static String storageOption = 'Local'; // Options: Local, Google Drive, Dropbox
  static String localFolderPath = '';
  static String googleDriveFolderPath = '';
  static String dropboxFolderPath = '';
  static String language = 'en';
  static String themeMode = 'system'; // 'light', 'dark', 'system'
  static String darkTheme = 'monet'; // 'monet', 'black'
  static Map<String, double> defaultFuelPrices = {};

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    maxVolume = prefs.getDouble('maxVolume') ?? 100.0;
    storageOption = prefs.getString('storageOption') ?? 'Local';
    localFolderPath = prefs.getString('localFolderPath') ?? '';
    googleDriveFolderPath = prefs.getString('googleDriveFolderPath') ?? '';
    dropboxFolderPath = prefs.getString('dropboxFolderPath') ?? '';
    language = prefs.getString('language') ?? 'en';
    themeMode = prefs.getString('themeMode') ?? 'system';
    darkTheme = prefs.getString('darkTheme') ?? 'monet';

    final defaultPricesString = prefs.getString('defaultFuelPrices');
    if (defaultPricesString != null) {
      defaultFuelPrices = Map<String, double>.from(json.decode(defaultPricesString));
    }
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('maxVolume', maxVolume);
    await prefs.setString('storageOption', storageOption);
    await prefs.setString('localFolderPath', localFolderPath);
    await prefs.setString('googleDriveFolderPath', googleDriveFolderPath);
    await prefs.setString('dropboxFolderPath', dropboxFolderPath);
    await prefs.setString('language', language);
    await prefs.setString('themeMode', themeMode);
    await prefs.setString('darkTheme', darkTheme);
    await prefs.setString('defaultFuelPrices', json.encode(defaultFuelPrices));
  }
}
