import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_bn.dart';
import 'l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel Consumption Tracker'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @allData.
  ///
  /// In en, this message translates to:
  /// **'All Data'**
  String get allData;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addFuelData.
  ///
  /// In en, this message translates to:
  /// **'Add Fuel Data'**
  String get addFuelData;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @odometerReading.
  ///
  /// In en, this message translates to:
  /// **'Odometer Reading (km)'**
  String get odometerReading;

  /// No description provided for @fuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel Type'**
  String get fuelType;

  /// No description provided for @fuelPriceRate.
  ///
  /// In en, this message translates to:
  /// **'Fuel Price Rate (BDT)'**
  String get fuelPriceRate;

  /// No description provided for @totalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total Volume (litres)'**
  String get totalVolume;

  /// No description provided for @paidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid Amount (BDT)'**
  String get paidAmount;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @runningAverageMileage.
  ///
  /// In en, this message translates to:
  /// **'Running Average Mileage'**
  String get runningAverageMileage;

  /// No description provided for @lastTimeMileage.
  ///
  /// In en, this message translates to:
  /// **'Current Running Mileage'**
  String get lastTimeMileage;

  /// No description provided for @lastRefuelVolume.
  ///
  /// In en, this message translates to:
  /// **'Last Refuel Volume'**
  String get lastRefuelVolume;

  /// No description provided for @exportToCSV.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get exportToCSV;

  /// No description provided for @folderPath.
  ///
  /// In en, this message translates to:
  /// **'Folder Path'**
  String get folderPath;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @maximumTankCapacity.
  ///
  /// In en, this message translates to:
  /// **'Maximum Tank Capacity (litres)'**
  String get maximumTankCapacity;

  /// No description provided for @selectCSVFile.
  ///
  /// In en, this message translates to:
  /// **'Select CSV File'**
  String get selectCSVFile;

  /// No description provided for @selectedFile.
  ///
  /// In en, this message translates to:
  /// **'Selected File'**
  String get selectedFile;

  /// No description provided for @noDataPreviewAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Data Preview Available'**
  String get noDataPreviewAvailable;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @dataImportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Data Imported Successfully!'**
  String get dataImportedSuccessfully;

  /// No description provided for @errorImportingData.
  ///
  /// In en, this message translates to:
  /// **'Error importing data: '**
  String get errorImportingData;

  /// No description provided for @errorReadingCSVFile.
  ///
  /// In en, this message translates to:
  /// **'Error reading CSV file: '**
  String get errorReadingCSVFile;

  /// No description provided for @csvFileEmptyOrIncorrectlyFormatted.
  ///
  /// In en, this message translates to:
  /// **'CSV file is empty or incorrectly formatted.'**
  String get csvFileEmptyOrIncorrectlyFormatted;

  /// No description provided for @dataExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Data exported to '**
  String get dataExportedTo;

  /// No description provided for @failedToExport.
  ///
  /// In en, this message translates to:
  /// **'Failed to export: '**
  String get failedToExport;

  /// No description provided for @folderPathNotSetInSettings.
  ///
  /// In en, this message translates to:
  /// **'Folder path not set in settings.'**
  String get folderPathNotSetInSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get settingsSaved;

  /// No description provided for @enterOdometerReading.
  ///
  /// In en, this message translates to:
  /// **'Enter odometer reading'**
  String get enterOdometerReading;

  /// No description provided for @enterFuelPriceRate.
  ///
  /// In en, this message translates to:
  /// **'Enter fuel price rate'**
  String get enterFuelPriceRate;

  /// No description provided for @enterTotalVolume.
  ///
  /// In en, this message translates to:
  /// **'Enter total volume'**
  String get enterTotalVolume;

  /// No description provided for @enterPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter paid amount'**
  String get enterPaidAmount;

  /// No description provided for @enterMaximumCapacity.
  ///
  /// In en, this message translates to:
  /// **'Enter maximum capacity'**
  String get enterMaximumCapacity;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @googleDrive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get googleDrive;

  /// No description provided for @dropbox.
  ///
  /// In en, this message translates to:
  /// **'Dropbox'**
  String get dropbox;

  /// No description provided for @fileStorageOption.
  ///
  /// In en, this message translates to:
  /// **'File Storage Option'**
  String get fileStorageOption;

  /// No description provided for @actualBill.
  ///
  /// In en, this message translates to:
  /// **'Actual Bill'**
  String get actualBill;

  /// No description provided for @savings.
  ///
  /// In en, this message translates to:
  /// **'Savings/Loss'**
  String get savings;

  /// No description provided for @averageMileage.
  ///
  /// In en, this message translates to:
  /// **'Average Mileage'**
  String get averageMileage;

  /// No description provided for @lastRefuelDetails.
  ///
  /// In en, this message translates to:
  /// **'Last Refuel Details'**
  String get lastRefuelDetails;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume:'**
  String get volume;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price:'**
  String get totalPrice;

  /// No description provided for @odometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer:'**
  String get odometer;

  /// No description provided for @fuelRate.
  ///
  /// In en, this message translates to:
  /// **'Fuel Rate:'**
  String get fuelRate;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @costEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Cost-Efficiency'**
  String get costEfficiency;

  /// No description provided for @costPerKm.
  ///
  /// In en, this message translates to:
  /// **'Cost per km'**
  String get costPerKm;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @exportRefuelingData.
  ///
  /// In en, this message translates to:
  /// **'Export Refueling Data'**
  String get exportRefuelingData;

  /// No description provided for @exportAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Export App Settings'**
  String get exportAppSettings;

  /// No description provided for @exportVehicleInformation.
  ///
  /// In en, this message translates to:
  /// **'Export Vehicle Information'**
  String get exportVehicleInformation;

  /// No description provided for @selectDataToExport.
  ///
  /// In en, this message translates to:
  /// **'Select data to export:'**
  String get selectDataToExport;

  /// No description provided for @manageVehicles.
  ///
  /// In en, this message translates to:
  /// **'Manage Vehicles'**
  String get manageVehicles;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add Vehicle'**
  String get addVehicle;

  /// No description provided for @vehicleName.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Name'**
  String get vehicleName;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @primaryFuelType.
  ///
  /// In en, this message translates to:
  /// **'Primary Fuel Type'**
  String get primaryFuelType;

  /// No description provided for @primaryFuelCapacity.
  ///
  /// In en, this message translates to:
  /// **'Primary Fuel Capacity'**
  String get primaryFuelCapacity;

  /// No description provided for @secondaryFuelType.
  ///
  /// In en, this message translates to:
  /// **'Secondary Fuel Type'**
  String get secondaryFuelType;

  /// No description provided for @secondaryFuelCapacity.
  ///
  /// In en, this message translates to:
  /// **'Secondary Fuel Capacity'**
  String get secondaryFuelCapacity;

  /// No description provided for @carOrSedan.
  ///
  /// In en, this message translates to:
  /// **'Car/Sedan'**
  String get carOrSedan;

  /// No description provided for @motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get motorcycle;

  /// No description provided for @scooterOrMoped.
  ///
  /// In en, this message translates to:
  /// **'Scooter/Moped'**
  String get scooterOrMoped;

  /// No description provided for @suv.
  ///
  /// In en, this message translates to:
  /// **'SUV'**
  String get suv;

  /// No description provided for @pickupOrTruck.
  ///
  /// In en, this message translates to:
  /// **'Pick-up/Truck'**
  String get pickupOrTruck;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get setAsDefault;

  /// No description provided for @defaultVehicle.
  ///
  /// In en, this message translates to:
  /// **'Default Vehicle'**
  String get defaultVehicle;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vehicle'**
  String get editVehicle;

  /// No description provided for @noVehiclesMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome! Add your first vehicle to get started.'**
  String get noVehiclesMessage;

  /// No description provided for @defaultFuelPrices.
  ///
  /// In en, this message translates to:
  /// **'Default Fuel Prices'**
  String get defaultFuelPrices;

  /// No description provided for @importToVehicle.
  ///
  /// In en, this message translates to:
  /// **'Import to Vehicle'**
  String get importToVehicle;

  /// No description provided for @pleaseSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Please select a vehicle to import the data into.'**
  String get pleaseSelectVehicle;

  /// No description provided for @noVehiclesFound.
  ///
  /// In en, this message translates to:
  /// **'No vehicles found. Please add a vehicle first.'**
  String get noVehiclesFound;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @welcomeToFuelTracker.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fuel Tracker!'**
  String get welcomeToFuelTracker;

  /// No description provided for @addFirstVehiclePrompt.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start by adding your first vehicle. It only takes a moment!'**
  String get addFirstVehiclePrompt;

  /// No description provided for @dailyAverages.
  ///
  /// In en, this message translates to:
  /// **'Daily Averages'**
  String get dailyAverages;

  /// No description provided for @dailyAverageRun.
  ///
  /// In en, this message translates to:
  /// **'Daily Average Run'**
  String get dailyAverageRun;

  /// No description provided for @dailyAverageCost.
  ///
  /// In en, this message translates to:
  /// **'Daily Average Cost'**
  String get dailyAverageCost;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
