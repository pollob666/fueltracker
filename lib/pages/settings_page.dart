// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/l10n/l10n_utils.dart';
import 'package:fuel_tracker/main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _maxVolumeController = TextEditingController();
  String _storageOption = AppSettings.storageOption;
  final TextEditingController _folderController = TextEditingController();
  Locale? _currentLocale;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _maxVolumeController.text = AppSettings.maxVolume.toString();
    _folderController.text = _getCurrentFolderPath();
    _currentLocale = L10n.all.first;
    _themeMode = AppSettings.themeMode;
  }

  String _getCurrentFolderPath() {
    if (_storageOption == 'Local') return AppSettings.localFolderPath;
    if (_storageOption == 'Google Drive') {
      return AppSettings.googleDriveFolderPath;
    }
    if (_storageOption == 'Dropbox') return AppSettings.dropboxFolderPath;
    return '';
  }

  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _folderController.text = selectedDirectory;
      });
    }
  }

  @override
  void dispose() {
    _maxVolumeController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      AppSettings.maxVolume = double.parse(_maxVolumeController.text);
      AppSettings.storageOption = _storageOption;
      if (_storageOption == 'Local') {
        AppSettings.localFolderPath = _folderController.text;
      } else if (_storageOption == 'Google Drive') {
        AppSettings.googleDriveFolderPath = _folderController.text;
      } else if (_storageOption == 'Dropbox') {
        AppSettings.dropboxFolderPath = _folderController.text;
      }
      AppSettings.themeMode = _themeMode;

      await AppSettings.saveSettings();
      MyApp.setThemeMode(context, _themeMode);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)));
    }
  }

  String _getStorageOptionLocalization(BuildContext context, String option) {
    switch (option) {
      case 'Local':
        return AppLocalizations.of(context).local;
      case 'Google Drive':
        return AppLocalizations.of(context).googleDrive;
      case 'Dropbox':
        return AppLocalizations.of(context).dropbox;
      default:
        return option;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settings)),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: _maxVolumeController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).maximumTankCapacity),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context).enterMaximumCapacity;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _storageOption,
                    items: ["Local", "Google Drive", "Dropbox"]
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(_getStorageOptionLocalization(context, option)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _storageOption = val!;
                        _folderController.text = _getCurrentFolderPath();
                      });
                    },
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context).fileStorageOption),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _folderController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).folderPath,
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _pickFolder),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<Locale>(
                    value: _currentLocale,
                    items: L10n.all
                        .map((locale) => DropdownMenuItem<Locale>(
                              value: locale,
                              child: Text(L10n.getLanguageName(locale)),
                            ))
                        .toList(),
                    onChanged: (locale) {
                      if (locale != null) {
                        setState(() {
                          _currentLocale = locale;
                          MyApp.setLocale(context, locale);
                        });
                      }
                    },
                    hint: const Text("Select Language"),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('Theme', style: theme.textTheme.titleMedium),
                    trailing: DropdownButton<ThemeMode>(
                      value: _themeMode,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                      ],
                      onChanged: (ThemeMode? themeMode) {
                        if (themeMode != null) {
                          setState(() {
                            _themeMode = themeMode!;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: Text(AppLocalizations.of(context).saveSettings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
