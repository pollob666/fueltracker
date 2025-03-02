// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(
      _current != null,
      'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
            ? locale.languageCode
            : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `Fuel Consumption Tracker`
  String get appTitle {
    return Intl.message(
      'Fuel Consumption Tracker',
      name: 'appTitle',
      desc: '',
      args: [],
    );
  }

  /// `Dashboard`
  String get dashboard {
    return Intl.message('Dashboard', name: 'dashboard', desc: '', args: []);
  }

  /// `All Data`
  String get allData {
    return Intl.message('All Data', name: 'allData', desc: '', args: []);
  }

  /// `Import`
  String get import {
    return Intl.message('Import', name: 'import', desc: '', args: []);
  }

  /// `Export`
  String get export {
    return Intl.message('Export', name: 'export', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Add Fuel Data`
  String get addFuelData {
    return Intl.message(
      'Add Fuel Data',
      name: 'addFuelData',
      desc: '',
      args: [],
    );
  }

  /// `Date & Time`
  String get dateAndTime {
    return Intl.message('Date & Time', name: 'dateAndTime', desc: '', args: []);
  }

  /// `Odometer Reading (km)`
  String get odometerReading {
    return Intl.message(
      'Odometer Reading (km)',
      name: 'odometerReading',
      desc: '',
      args: [],
    );
  }

  /// `Fuel Type`
  String get fuelType {
    return Intl.message('Fuel Type', name: 'fuelType', desc: '', args: []);
  }

  /// `Fuel Price Rate (BDT)`
  String get fuelPriceRate {
    return Intl.message(
      'Fuel Price Rate (BDT)',
      name: 'fuelPriceRate',
      desc: '',
      args: [],
    );
  }

  /// `Total Volume (litres)`
  String get totalVolume {
    return Intl.message(
      'Total Volume (litres)',
      name: 'totalVolume',
      desc: '',
      args: [],
    );
  }

  /// `Paid Amount (BDT)`
  String get paidAmount {
    return Intl.message(
      'Paid Amount (BDT)',
      name: 'paidAmount',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Running Average Mileage`
  String get runningAverageMileage {
    return Intl.message(
      'Running Average Mileage',
      name: 'runningAverageMileage',
      desc: '',
      args: [],
    );
  }

  /// `Last Time Mileage`
  String get lastTimeMileage {
    return Intl.message(
      'Last Time Mileage',
      name: 'lastTimeMileage',
      desc: '',
      args: [],
    );
  }

  /// `Last Refuel Volume`
  String get lastRefuelVolume {
    return Intl.message(
      'Last Refuel Volume',
      name: 'lastRefuelVolume',
      desc: '',
      args: [],
    );
  }

  /// `Export to CSV`
  String get exportToCSV {
    return Intl.message(
      'Export to CSV',
      name: 'exportToCSV',
      desc: '',
      args: [],
    );
  }

  /// `Folder Path`
  String get folderPath {
    return Intl.message('Folder Path', name: 'folderPath', desc: '', args: []);
  }

  /// `Save Settings`
  String get saveSettings {
    return Intl.message(
      'Save Settings',
      name: 'saveSettings',
      desc: '',
      args: [],
    );
  }

  /// `Maximum Tank Capacity (litres)`
  String get maximumTankCapacity {
    return Intl.message(
      'Maximum Tank Capacity (litres)',
      name: 'maximumTankCapacity',
      desc: '',
      args: [],
    );
  }

  /// `Select CSV File`
  String get selectCSVFile {
    return Intl.message(
      'Select CSV File',
      name: 'selectCSVFile',
      desc: '',
      args: [],
    );
  }

  /// `Selected File`
  String get selectedFile {
    return Intl.message(
      'Selected File',
      name: 'selectedFile',
      desc: '',
      args: [],
    );
  }

  /// `No Data Preview Available`
  String get noDataPreviewAvailable {
    return Intl.message(
      'No Data Preview Available',
      name: 'noDataPreviewAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Import Data`
  String get importData {
    return Intl.message('Import Data', name: 'importData', desc: '', args: []);
  }

  /// `Data Imported Successfully!`
  String get dataImportedSuccessfully {
    return Intl.message(
      'Data Imported Successfully!',
      name: 'dataImportedSuccessfully',
      desc: '',
      args: [],
    );
  }

  /// `Error importing data: `
  String get errorImportingData {
    return Intl.message(
      'Error importing data: ',
      name: 'errorImportingData',
      desc: '',
      args: [],
    );
  }

  /// `Error reading CSV file: `
  String get errorReadingCSVFile {
    return Intl.message(
      'Error reading CSV file: ',
      name: 'errorReadingCSVFile',
      desc: '',
      args: [],
    );
  }

  /// `CSV file is empty or incorrectly formatted.`
  String get csvFileEmptyOrIncorrectlyFormatted {
    return Intl.message(
      'CSV file is empty or incorrectly formatted.',
      name: 'csvFileEmptyOrIncorrectlyFormatted',
      desc: '',
      args: [],
    );
  }

  /// `Data exported to `
  String get dataExportedTo {
    return Intl.message(
      'Data exported to ',
      name: 'dataExportedTo',
      desc: '',
      args: [],
    );
  }

  /// `Failed to export: `
  String get failedToExport {
    return Intl.message(
      'Failed to export: ',
      name: 'failedToExport',
      desc: '',
      args: [],
    );
  }

  /// `Folder path not set in settings.`
  String get folderPathNotSetInSettings {
    return Intl.message(
      'Folder path not set in settings.',
      name: 'folderPathNotSetInSettings',
      desc: '',
      args: [],
    );
  }

  /// `Settings saved.`
  String get settingsSaved {
    return Intl.message(
      'Settings saved.',
      name: 'settingsSaved',
      desc: '',
      args: [],
    );
  }

  /// `Enter odometer reading`
  String get enterOdometerReading {
    return Intl.message(
      'Enter odometer reading',
      name: 'enterOdometerReading',
      desc: '',
      args: [],
    );
  }

  /// `Enter fuel price rate`
  String get enterFuelPriceRate {
    return Intl.message(
      'Enter fuel price rate',
      name: 'enterFuelPriceRate',
      desc: '',
      args: [],
    );
  }

  /// `Enter total volume`
  String get enterTotalVolume {
    return Intl.message(
      'Enter total volume',
      name: 'enterTotalVolume',
      desc: '',
      args: [],
    );
  }

  /// `Enter paid amount`
  String get enterPaidAmount {
    return Intl.message(
      'Enter paid amount',
      name: 'enterPaidAmount',
      desc: '',
      args: [],
    );
  }

  /// `Enter maximum capacity`
  String get enterMaximumCapacity {
    return Intl.message(
      'Enter maximum capacity',
      name: 'enterMaximumCapacity',
      desc: '',
      args: [],
    );
  }

  /// `Local`
  String get local {
    return Intl.message('Local', name: 'local', desc: '', args: []);
  }

  /// `Google Drive`
  String get googleDrive {
    return Intl.message(
      'Google Drive',
      name: 'googleDrive',
      desc: '',
      args: [],
    );
  }

  /// `Dropbox`
  String get dropbox {
    return Intl.message('Dropbox', name: 'dropbox', desc: '', args: []);
  }

  /// `File Storage Option`
  String get fileStorageOption {
    return Intl.message(
      'File Storage Option',
      name: 'fileStorageOption',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'bn'),
      Locale.fromSubtags(languageCode: 'messages'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
