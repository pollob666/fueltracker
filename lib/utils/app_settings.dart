import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static double maxVolume = 100.0;
  static String storageOption = 'Local'; // Options: Local, Google Drive, Dropbox
  static String localFolderPath = '';
  static String googleDriveFolderPath = '';
  static String dropboxFolderPath = '';
  static ThemeMode themeMode = ThemeMode.system;

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    maxVolume = prefs.getDouble('maxVolume') ?? 100.0;
    storageOption = prefs.getString('storageOption') ?? 'Local';
    localFolderPath = prefs.getString('localFolderPath') ?? '';
    googleDriveFolderPath = prefs.getString('googleDriveFolderPath') ?? '';
    dropboxFolderPath = prefs.getString('dropboxFolderPath') ?? '';
    final theme = prefs.getString('themeMode');
    if (theme == 'light') {
      themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('maxVolume', maxVolume);
    await prefs.setString('storageOption', storageOption);
    await prefs.setString('localFolderPath', localFolderPath);
    await prefs.setString('googleDriveFolderPath', googleDriveFolderPath);
    await prefs.setString('dropboxFolderPath', dropboxFolderPath);
    await prefs.setString('themeMode', themeMode.toString().split('.').last);
  }
}
