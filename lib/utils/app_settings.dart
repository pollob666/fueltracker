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
  static bool adsEnabled = false;
  static int reminderHour = 9;
  static int reminderMinute = 0;
  static Map<String, double> defaultFuelPrices = {};

  // Automated Background Backup Settings
  static bool autoBackupEnabled = false;
  static int autoBackupFrequencyDays = 3;
  static bool autoBackupWifiOnly = true;
  static bool autoBackupWebDavUpload = false;

  // International Units & Default Currency Fallbacks
  static String defaultDistanceUnit = 'km';
  static String defaultFuelVolumeUnit = 'litre';
  static String defaultConsumptionUnit = 'kmPerLitre';
  static String defaultBaseCurrency = 'BDT';

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
    adsEnabled = prefs.getBool('adsEnabled') ?? false;
    reminderHour = prefs.getInt('reminderHour') ?? 9;
    reminderMinute = prefs.getInt('reminderMinute') ?? 0;
    autoBackupEnabled = prefs.getBool('autoBackupEnabled') ?? false;
    autoBackupFrequencyDays = prefs.getInt('autoBackupFrequencyDays') ?? 3;
    autoBackupWifiOnly = prefs.getBool('autoBackupWifiOnly') ?? true;
    autoBackupWebDavUpload = prefs.getBool('autoBackupWebDavUpload') ?? false;
    defaultDistanceUnit = prefs.getString('defaultDistanceUnit') ?? 'km';
    defaultFuelVolumeUnit = prefs.getString('defaultFuelVolumeUnit') ?? 'litre';
    defaultConsumptionUnit = prefs.getString('defaultConsumptionUnit') ?? 'kmPerLitre';
    defaultBaseCurrency = prefs.getString('defaultBaseCurrency') ?? 'BDT';

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
    await prefs.setBool('adsEnabled', adsEnabled);
    await prefs.setInt('reminderHour', reminderHour);
    await prefs.setInt('reminderMinute', reminderMinute);
    await prefs.setBool('autoBackupEnabled', autoBackupEnabled);
    await prefs.setInt('autoBackupFrequencyDays', autoBackupFrequencyDays);
    await prefs.setBool('autoBackupWifiOnly', autoBackupWifiOnly);
    await prefs.setBool('autoBackupWebDavUpload', autoBackupWebDavUpload);
    await prefs.setString('defaultDistanceUnit', defaultDistanceUnit);
    await prefs.setString('defaultFuelVolumeUnit', defaultFuelVolumeUnit);
    await prefs.setString('defaultConsumptionUnit', defaultConsumptionUnit);
    await prefs.setString('defaultBaseCurrency', defaultBaseCurrency);
    await prefs.setString('defaultFuelPrices', json.encode(defaultFuelPrices));
  }

  static Map<String, dynamic> toMap() => {
        'maxVolume': maxVolume,
        'storageOption': storageOption,
        'localFolderPath': localFolderPath,
        'googleDriveFolderPath': googleDriveFolderPath,
        'dropboxFolderPath': dropboxFolderPath,
        'language': language,
        'themeMode': themeMode,
        'darkTheme': darkTheme,
        'adsEnabled': adsEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'autoBackupEnabled': autoBackupEnabled,
        'autoBackupFrequencyDays': autoBackupFrequencyDays,
        'autoBackupWifiOnly': autoBackupWifiOnly,
        'autoBackupWebDavUpload': autoBackupWebDavUpload,
        'defaultDistanceUnit': defaultDistanceUnit,
        'defaultFuelVolumeUnit': defaultFuelVolumeUnit,
        'defaultConsumptionUnit': defaultConsumptionUnit,
        'defaultBaseCurrency': defaultBaseCurrency,
        'defaultFuelPrices': defaultFuelPrices,
      };

  static Future<void> fromMap(Map<String, dynamic> map) async {
    if (map['maxVolume'] != null) maxVolume = (map['maxVolume'] as num).toDouble();
    if (map['storageOption'] != null) storageOption = map['storageOption'] as String;
    if (map['localFolderPath'] != null) localFolderPath = map['localFolderPath'] as String;
    if (map['googleDriveFolderPath'] != null) googleDriveFolderPath = map['googleDriveFolderPath'] as String;
    if (map['dropboxFolderPath'] != null) dropboxFolderPath = map['dropboxFolderPath'] as String;
    if (map['language'] != null) language = map['language'] as String;
    if (map['themeMode'] != null) themeMode = map['themeMode'] as String;
    if (map['darkTheme'] != null) darkTheme = map['darkTheme'] as String;
    if (map['adsEnabled'] != null) adsEnabled = map['adsEnabled'] as bool;
    if (map['reminderHour'] != null) reminderHour = map['reminderHour'] as int;
    if (map['reminderMinute'] != null) reminderMinute = map['reminderMinute'] as int;
    if (map['autoBackupEnabled'] != null) autoBackupEnabled = map['autoBackupEnabled'] as bool;
    if (map['autoBackupFrequencyDays'] != null) autoBackupFrequencyDays = map['autoBackupFrequencyDays'] as int;
    if (map['autoBackupWifiOnly'] != null) autoBackupWifiOnly = map['autoBackupWifiOnly'] as bool;
    if (map['autoBackupWebDavUpload'] != null) autoBackupWebDavUpload = map['autoBackupWebDavUpload'] as bool;
    if (map['defaultDistanceUnit'] != null) defaultDistanceUnit = map['defaultDistanceUnit'] as String;
    if (map['defaultFuelVolumeUnit'] != null) defaultFuelVolumeUnit = map['defaultFuelVolumeUnit'] as String;
    if (map['defaultConsumptionUnit'] != null) defaultConsumptionUnit = map['defaultConsumptionUnit'] as String;
    if (map['defaultBaseCurrency'] != null) defaultBaseCurrency = map['defaultBaseCurrency'] as String;
    if (map['defaultFuelPrices'] != null) {
      defaultFuelPrices = Map<String, double>.from(
        (map['defaultFuelPrices'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      );
    }
    await saveSettings();
  }
}
