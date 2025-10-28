// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/models/fuel_type.dart';
import 'package:fuel_tracker/services/fuel_type_service.dart';
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
  late String _currentThemeSetting;
  final FuelTypeService _fuelTypeService = FuelTypeService();
  List<FuelType> _fuelTypes = [];
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _maxVolumeController.text = AppSettings.maxVolume.toString();
    _folderController.text = _getCurrentFolderPath();
    _currentLocale = Locale(AppSettings.language);
    _setCurrentThemeSetting();
    _loadFuelTypes();
  }

  void _setCurrentThemeSetting() {
    if (AppSettings.themeMode == 'light') {
      _currentThemeSetting = 'light';
    } else if (AppSettings.themeMode == 'system') {
      _currentThemeSetting = 'system';
    } else { // dark
      if (AppSettings.darkTheme == 'monet') {
        _currentThemeSetting = 'monet';
      } else { // black
        _currentThemeSetting = 'black';
      }
    }
  }

  Future<void> _loadFuelTypes() async {
    _fuelTypes = await _fuelTypeService.getFuelTypes();
    for (var ft in _fuelTypes) {
      _priceControllers[ft.name] = TextEditingController(
        text: AppSettings.defaultFuelPrices[ft.name]?.toString() ?? '',
      );
    }
    setState(() {});
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
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
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
      AppSettings.language = _currentLocale!.languageCode;

      switch (_currentThemeSetting) {
        case 'light':
          AppSettings.themeMode = 'light';
          break;
        case 'system':
          AppSettings.themeMode = 'system';
          break;
        case 'monet':
          AppSettings.themeMode = 'dark';
          AppSettings.darkTheme = 'monet';
          break;
        case 'black':
          AppSettings.themeMode = 'dark';
          AppSettings.darkTheme = 'black';
          break;
      }

      _priceControllers.forEach((name, controller) {
        final price = double.tryParse(controller.text);
        if (price != null) {
          AppSettings.defaultFuelPrices[name] = price;
        }
      });

      await AppSettings.saveSettings();
      if (mounted) {
        MyApp.setLocale(context, _currentLocale!);
        MyApp.setThemeMode(context, AppSettings.themeMode);
        MyApp.setDarkTheme(context, AppSettings.darkTheme);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.settingsSaved)));
      }
    }
  }

  String _getStorageOptionLocalization(BuildContext context, String option) {
    switch (option) {
      case 'Local':
        return AppLocalizations.of(context)!.local;
      case 'Google Drive':
        return AppLocalizations.of(context)!.googleDrive;
      case 'Dropbox':
        return AppLocalizations.of(context)!.dropbox;
      default:
        return option;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _maxVolumeController,
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!
                            .maximumTankCapacity),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!
                            .enterMaximumCapacity;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _storageOption,
                    items: ["Local", "Google Drive", "Dropbox"]
                        .map((option) => DropdownMenuItem(
                              value: option,
                              child: Text(_getStorageOptionLocalization(
                                  context, option)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _storageOption = val!;
                        _folderController.text = _getCurrentFolderPath();
                      });
                    },
                    decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!
                            .fileStorageOption),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _folderController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.folderPath,
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _pickFolder),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<Locale>(
                    value: _currentLocale,
                    items: AppLocalizations.supportedLocales
                        .map((locale) => DropdownMenuItem<Locale>(
                              value: locale,
                              child: Text(
                                  L10n.getLanguageName(locale.languageCode)),
                            ))
                        .toList(),
                    onChanged: (locale) {
                      if (locale != null) {
                        setState(() {
                          _currentLocale = locale;
                        });
                      }
                    },
                    hint: const Text("Select Language"),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('Theme', style: theme.textTheme.titleMedium),
                    trailing: DropdownButton<String>(
                      value: _currentThemeSetting,
                      items: const [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: 'light',
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: 'monet',
                          child: Text('Monet (Dark)'),
                        ),
                        DropdownMenuItem(
                          value: 'black',
                          child: Text('Black'),
                        ),
                      ],
                      onChanged: (String? newTheme) {
                        if (newTheme != null) {
                          setState(() {
                            _currentThemeSetting = newTheme;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.defaultFuelPrices,
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ..._fuelTypes.map((ft) {
                    return TextFormField(
                      controller: _priceControllers[ft.name],
                      decoration: InputDecoration(labelText: ft.name),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    );
                  }),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: Text(AppLocalizations.of(context)!.saveSettings),
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
