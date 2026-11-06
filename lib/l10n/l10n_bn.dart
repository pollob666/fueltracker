// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get fuelRecords => 'জ্বালানির রেকর্ড';

  @override
  String get dateAndTime => 'তারিখ ও সময়';

  @override
  String get odometerReading => 'ওডোমিটার রিডিং';

  @override
  String get fuelPriceRate => 'জ্বালানির মূল্য/দর';

  @override
  String get totalVolume => 'মোট পরিমাণ';

  @override
  String get paidAmount => 'প্রদত্ত পরিমাণ';

  @override
  String get averageMileage => 'গড় মাইলেজ';

  @override
  String get noDataFound =>
      'কোনো ডেটা পাওয়া যায়নি। অনুগ্রহ করে কিছু জ্বালানির রেকর্ড যোগ করুন।';

  @override
  String get addRecord => 'রেকর্ড যোগ করুন';

  @override
  String get allData => 'সমস্ত ডেটা';

  @override
  String get settings => 'সেটিংস';

  @override
  String get notAvailable => 'প্রযোজ্য নয়';

  @override
  String get vehicle => 'যানবাহন';

  @override
  String get fuelType => 'জ্বালানির ধরন';

  @override
  String get runningAverage => 'চলমান গড়';

  @override
  String get runningAverageMileage => 'চলমান গড় মাইলেজ';

  @override
  String get appTitle => 'জ্বালানি খরচ ট্র্যাকার';

  @override
  String get dashboard => 'ড্যাশবোর্ড';

  @override
  String get import => 'ইম্পোর্ট';

  @override
  String get export => 'এক্সপোর্ট';

  @override
  String get addFuelData => 'জ্বালানি ডেটা যোগ করুন';

  @override
  String get save => 'সেভ করুন';

  @override
  String get lastTimeMileage => 'বর্তমান মাইলেজ';

  @override
  String get lastRefuelVolume => 'শেষ রিফুয়েল ভলিউম';

  @override
  String get exportToCSV => 'সিএসভি-তে এক্সপোর্ট করুন';

  @override
  String get folderPath => 'ফোল্ডারের পাথ';

  @override
  String get saveSettings => 'সেটিংস সেভ করুন';

  @override
  String get maximumTankCapacity => 'ট্যাঙ্কের সর্বোচ্চ ধারন ক্ষমতা (লিটার)';

  @override
  String get selectCSVFile => 'সিএসভি ফাইল নির্বাচন করুন';

  @override
  String get selectedFile => 'নির্বাচিত ফাইল';

  @override
  String get noDataPreviewAvailable => 'কোনও ডেটা প্রিভিউ পাওয়া যায় নি';

  @override
  String get importData => 'ডেটা ইম্পোর্ট করুন';

  @override
  String get dataImportedSuccessfully => 'ডেটা সফলভাবে ইম্পোর্ট করা হয়েছে!';

  @override
  String get errorImportingData => 'ডেটা ইম্পোর্ট করতে সমস্যা: ';

  @override
  String get errorReadingCSVFile => 'সিএসভি ফাইল পড়তে সমস্যা: ';

  @override
  String get csvFileEmptyOrIncorrectlyFormatted =>
      'সিএসভি ফাইলটি খালি বা ভুলভাবে ফর্ম্যাট করা হয়েছে।';

  @override
  String get dataExportedTo => 'ডেটা এখানে এক্সপোর্ট করা হয়েছে ';

  @override
  String get failedToExport => 'এক্সপোর্ট করতে ব্যর্থ: ';

  @override
  String get folderPathNotSetInSettings => 'সেটিংস-এ ফোল্ডারের পথ সেট করা নেই।';

  @override
  String get settingsSaved => 'সেটিংস সংরক্ষিত হয়েছে।';

  @override
  String get enterOdometerReading => 'ওডোমিটার রিডিং টাইপ করুন';

  @override
  String get enterFuelPriceRate => 'জ্বালানির দামের হার টাইপ করুন';

  @override
  String get enterTotalVolume => 'মোট ভলিউম টাইপ করুন';

  @override
  String get enterPaidAmount => 'পরিশোধিত পরিমাণ টাইপ করুন';

  @override
  String get enterMaximumCapacity => 'সর্বোচ্চ ক্ষমতা টাইপ করুন';

  @override
  String get local => 'লোকাল স্টোরেজ';

  @override
  String get googleDrive => 'Google Drive';

  @override
  String get dropbox => 'Dropbox';

  @override
  String get fileStorageOption => 'ফাইল স্টোরেজ অপশন';

  @override
  String get actualBill => 'বিল';

  @override
  String get savings => 'বেচেছে (টাকা)';

  @override
  String get lastRefuelDetails => 'শেষ রিফুয়েলের বিবরণ';

  @override
  String get volume => 'ভলিউম:';

  @override
  String get totalPrice => 'মোট মূল্য:';

  @override
  String get odometer => 'ওডোমিটার:';

  @override
  String get fuelRate => 'জ্বালানির দাম:';

  @override
  String get summary => 'সারসংক্ষেপ';

  @override
  String get costEfficiency => 'খরচ-কার্যকারিতা';

  @override
  String get costPerKm => 'প্রতি কিলোমিটারে খরচ';

  @override
  String get comingSoon => 'শীঘ্রই আসছে';

  @override
  String get exportRefuelingData => 'রিফুয়েলিং ডেটা এক্সপোর্ট করুন';

  @override
  String get exportAppSettings => 'অ্যাপ সেটিংস এক্সপোর্ট করুন';

  @override
  String get exportVehicleInformation => 'গাড়ির তথ্য এক্সপোর্ট করুন';

  @override
  String get selectDataToExport => 'এক্সপোর্ট করার জন্য ডেটা নির্বাচন করুন:';

  @override
  String get manageVehicles => 'যানবাহন পরিচালনা';

  @override
  String get addVehicle => 'যানবাহন যোগ করুন';

  @override
  String get vehicleName => 'যানের নাম';

  @override
  String get vehicleType => 'যানের প্রকার';

  @override
  String get primaryFuelType => 'প্রাথমিক জ্বালানির প্রকার';

  @override
  String get primaryFuelCapacity => 'প্রাথমিক জ্বালানির ধারণক্ষমতা';

  @override
  String get secondaryFuelType => 'মাধ্যমিক জ্বালানির প্রকার';

  @override
  String get secondaryFuelCapacity => 'মাধ্যমিক জ্বালানির ধারণক্ষমতা';

  @override
  String get carOrSedan => 'কার/সেডান';

  @override
  String get motorcycle => 'মোটরসাইকেল';

  @override
  String get scooterOrMoped => 'স্কুটার/ভেসপা/মপেড';

  @override
  String get suv => 'এসইউভি/জিপ গাড়ি';

  @override
  String get pickupOrTruck => 'পিকাপ/ট্রাক';

  @override
  String get edit => 'সম্পাদনা';

  @override
  String get setAsDefault => 'ডিফল্ট হিসাবে সেট করুন';

  @override
  String get defaultVehicle => 'ডিফল্ট যানবাহন';

  @override
  String get editVehicle => 'যানবাহন সম্পাদনা';

  @override
  String get noVehiclesMessage =>
      'স্বাগতম! শুরু করতে আপনার প্রথম যান যোগ করুন।';

  @override
  String get defaultFuelPrices => 'ডিফল্ট জ্বালানির দাম';

  @override
  String get importToVehicle => 'গাড়িতে ডেটা ইম্পোর্ট করুন';

  @override
  String get pleaseSelectVehicle =>
      'ডেটা ইম্পোর্ট করার জন্য একটি গাড়ি নির্বাচন করুন।';

  @override
  String get noVehiclesFound =>
      'কোনও যানবাহন পাওয়া যায়নি। অনুগ্রহ করে প্রথমে একটি গাড়ি যোগ করুন।';

  @override
  String get cancel => 'বাতিল';

  @override
  String get ok => 'ঠিক আছে';

  @override
  String get welcomeToFuelTracker => 'ফুয়েল ট্র্যাকারে স্বাগতম!';

  @override
  String get addFirstVehiclePrompt =>
      'চলুন আপনার প্রথম যানটি যোগ করে শুরু করা যাক। এটি শুধুমাত্র একটি মুহূর্ত সময় নেবে!';

  @override
  String get dailyAverages => 'দৈনিক গড়';

  @override
  String get dailyAverageRun => 'দৈনিক গড় রান';

  @override
  String get dailyAverageCost => 'দৈনিক গড় খরচ';

  @override
  String get language => 'ভাষা';

  @override
  String get fullTank => 'সম্পূর্ণ ট্যাঙ্ক';

  @override
  String get fullTankSubtitle => 'ট্যাঙ্ক কি সম্পূর্ণ পূর্ণ করা হয়েছিল?';

  @override
  String get missedPrevious => 'আগের রিফুয়েল বাদ পড়েছে';

  @override
  String get missedPreviousSubtitle =>
      'যদি আগের কোনো রিফুয়েল বাদ পড়ে থাকে তবে এটি চিহ্নিত করুন';

  @override
  String get tripDistance => 'ট্রিপ দূরত্ব (কিমি)';

  @override
  String get enterTripDistance => 'ট্রিপ দূরত্ব লিখুন';

  @override
  String get odometerWarningTitle => 'ওডোমিটার অসঙ্গতি';

  @override
  String odometerWarningMessage(String entered, String previous) {
    return 'প্রবেশ করানো ওডোমিটার রিডিং ($entered) আগের রিডিং ($previous) এর চেয়ে কম বা সমান। আপনি কি এগিয়ে যেতে চান?';
  }

  @override
  String get partial => 'আংশিক';

  @override
  String get missed => 'বাদ পড়েছে';

  @override
  String get confirm => 'নিশ্চিত করুন';

  @override
  String get deleteVehicle => 'যানবাহন মুছে ফেলুন';

  @override
  String get cannotDeleteOnlyVehicle =>
      'একমাত্র অবশিষ্ট যানটি মুছে ফেলা যাবে না।';

  @override
  String get deleteVehicleConfirm =>
      'আপনি কি নিশ্চিত যে আপনি এই যানটি মুছে ফেলতে চান?';

  @override
  String deleteVehicleCascadeWarning(int count) {
    return 'এই যানের $count টি জ্বালানি রেকর্ড রয়েছে। এটি মুছে ফেললে সংশ্লিষ্ট সমস্ত রেকর্ড স্থায়ীভাবে মুছে যাবে। আপনি কি এগিয়ে যেতে চান?';
  }

  @override
  String get delete => 'মুছে ফেলুন';

  @override
  String get shareExport => 'এক্সপোর্ট শেয়ার করুন';

  @override
  String get exportSuccessful => 'ফাইল সফলভাবে প্রস্তুত করা হয়েছে।';

  @override
  String get folderPathHelper =>
      'ঐচ্ছিক। সিস্টেম শেয়ার শীট ব্যবহার করতে খালি রাখুন।';

  @override
  String get clear => 'পরিষ্কার করুন';

  @override
  String get today => 'আজ';

  @override
  String get yesterday => 'গতকাল';

  @override
  String daysAgo(int days) {
    return '$days দিন আগে';
  }

  @override
  String get updateAvailableTitle => 'আপডেট উপলব্ধ';

  @override
  String updateAvailableMessage(String version) {
    return 'একটি নতুন সংস্করণ ($version) উপলব্ধ রয়েছে। আপনি কি এখন আপডেট করতে চান?';
  }

  @override
  String get updateButton => 'আপডেট';

  @override
  String get laterButton => 'পরে';

  @override
  String get skipVersionButton => 'এই সংস্করণটি এড়িয়ে যান';

  @override
  String get tripMeterMode => 'ট্রিপ মিটার মোড';

  @override
  String get tripModeNone => 'নেই';

  @override
  String get tripModeSingle => 'একটি (ট্রিপ এ)';

  @override
  String get tripModeDual => 'দুটি (ট্রিপ এ ও বি)';

  @override
  String get tripMeterModeSubtitle =>
      'গাড়ির ড্যাশবোর্ডে ট্রিপ মিটার থাকলে নির্বাচন করুন';

  @override
  String get tripA => 'ট্রিপ এ (জ্বালানি ব্যবধান)';

  @override
  String get tripB => 'ট্রিপ বি (ট্যুর / মোট ব্যবধান)';

  @override
  String get syncOdometer => 'ওডোমিটার সিঙ্ক';

  @override
  String syncOdometerTooltip(String prev, String trip) {
    return 'ওডোমিটার গণনা করুন = পূর্ববর্তী ($prev) + ট্রিপ ($trip)';
  }

  @override
  String odometerTripMismatch(String delta, String trip) {
    return 'ওডোমিটার ব্যবধান ($delta কিমি) ট্রিপের ($trip কিমি) সাথে মিলছে না। সিঙ্ক করতে ট্যাপ করুন।';
  }

  @override
  String get drivingCondition => 'যাত্রার ধরন';

  @override
  String get city => 'শহর';

  @override
  String get highway => 'হাইওয়ে';

  @override
  String get mixed => 'মিশ্র';

  @override
  String get cityMileage => 'শহরের মাইলেজ';

  @override
  String get highwayMileage => 'হাইওয়ের মাইলেজ';

  @override
  String get supportedFuelTypes => 'জ্বালানির ধরন';

  @override
  String get singleFuel => 'একক জ্বালানি';

  @override
  String get dualFuel => 'দ্বৈত / দ্বি-জ্বালানি';

  @override
  String get dualFuelSubtitle =>
      'যানবাহন দুটি জ্বালানি সমর্থন করে (যেমন: পেট্রোল + সিএনজি/এলপিজি)';

  @override
  String get refuelReminders => 'আগাম রিফুয়েল সতর্কতা';

  @override
  String get volumeReminderTitle => 'প্রধান জ্বালানি পরিমাণের সতর্কতা';

  @override
  String get volumeReminderSubtitle =>
      'প্রধান ট্যাঙ্কের রিজার্ভ শেষ হওয়ার আগেই সতর্ক করবে';

  @override
  String get volumeThresholdLabel => 'সতর্কতার জ্বালানি সীমা';

  @override
  String get distanceReminderTitle => 'সম্ভাব্য দূরত্বের (DTE) সতর্কতা';

  @override
  String get distanceReminderSubtitle =>
      'মোট সম্ভাব্য দূরত্ব সীমার নিচে নামলে সতর্ক করবে';

  @override
  String get distanceThresholdLabel => 'সতর্কতার দূরত্ব সীমা';

  @override
  String get refuelWarningTitle => 'জ্বালানি ভরা প্রয়োজন';

  @override
  String get lowFuelWarning => 'কম জ্বালানি সতর্কতা';

  @override
  String get refuelNow => 'এখনই রিফুয়েল করুন';

  @override
  String get refuelCalibrationPrompt =>
      'রেঞ্জ পূর্বাভাসের জন্য একবার সম্পূর্ণ ট্যাঙ্ক ভর্তি করে \'ফুল ট্যাঙ্ক\' হিসেবে রেকর্ড করুন।';

  @override
  String primaryFuelEstimate(String volume) {
    return 'প্রধান জ্বালানি: ~$volume লিটার';
  }

  @override
  String combinedRangeEstimate(String range) {
    return 'মোট সম্ভাব্য রেঞ্জ: ~$range কিমি';
  }

  @override
  String projectedRefuelIn(int days) {
    return '~$days দিনের মধ্যে রিফুয়েল প্রয়োজন';
  }

  @override
  String get notificationTime => 'সতর্কতা বিজ্ঞপ্তির সময়';

  @override
  String get notificationTimeSubtitle =>
      'দৈনিক রিফুয়েল সতর্কতা বিজ্ঞপ্তি নির্ধারণের সময়';

  @override
  String get maintenance => 'রক্ষণাবেক্ষণ';

  @override
  String get maintenanceTasks => 'রক্ষণাবেক্ষণ কাজসমূহ';

  @override
  String get serviceHistory => 'সার্ভিসিং ইতিহাস';

  @override
  String get logServiceVisit => 'সার্ভিসিং এন্ট্রি করুন';

  @override
  String get addTask => 'নতুন কাজ যোগ করুন';

  @override
  String get editTask => 'কাজ সম্পাদনা করুন';

  @override
  String get deleteTask => 'কাজ মুছুন';

  @override
  String get taskTitle => 'কাজের শিরোনাম';

  @override
  String get intervalDistance => 'দূরত্ব ব্যবধান (কিমি)';

  @override
  String get intervalMonths => 'ব্যবধান (মাস)';

  @override
  String get reminderBuffer => 'রিমাইন্ডার বাফার (কিমি)';

  @override
  String get lastServiceOdometer => 'সর্বশেষ সার্ভিসিং ওডোমিটার';

  @override
  String get lastServiceDate => 'সর্বশেষ সার্ভিসিং তারিখ';

  @override
  String get quickDone => 'সম্পন্ন হয়েছে';

  @override
  String get confirmQuickDone => 'কাজ সম্পন্ন নিশ্চিত করুন';

  @override
  String confirmQuickDoneMsg(String task) {
    return '$task-এর সর্বশেষ সার্ভিসিং ওডোমিটার ও তারিখ বর্তমান মান দিয়ে আপডেট করবেন?';
  }

  @override
  String get statusHealthy => 'ঠিক আছে';

  @override
  String get statusDueSoon => 'শীঘ্রই প্রয়োজন';

  @override
  String get statusOverdue => 'বিলম্বিত';

  @override
  String daysRemaining(int days) {
    return '$days দিন বাকি';
  }

  @override
  String daysOverdue(int days) {
    return '$days দিন বিলম্বিত';
  }

  @override
  String kmRemaining(String km) {
    return '$km কিমি বাকি';
  }

  @override
  String kmOverdue(String km) {
    return '$km কিমি বিলম্বিত';
  }

  @override
  String lastDoneOn(String odo, String date) {
    return 'সর্বশেষ: $odo কিমি ($date)';
  }

  @override
  String targetAt(String odo) {
    return 'পরবর্তী লক্ষ্য: $odo কিমি';
  }

  @override
  String get noMaintenanceTasks =>
      'এই গাড়ির জন্য কোনো রক্ষণাবেক্ষণ কাজ যোগ করা নেই।';

  @override
  String get noServiceHistory => 'এখনও কোনো সার্ভিসিং রেকর্ড নেই।';

  @override
  String get confirmDeleteTask => 'এই রক্ষণাবেক্ষণ কাজটি মুছে ফেলবেন?';

  @override
  String get confirmDeleteTaskMsg => 'এটি স্থায়ীভাবে এই কাজটি মুছে ফেলবে।';

  @override
  String get engineOilChange => 'ইঞ্জিন অয়েল পরিবর্তন';

  @override
  String get oilFilterReplacement => 'ইঞ্জিন অয়েল ফিল্টার';

  @override
  String get airFilterClean => 'এয়ার ফিল্টার পরিষ্কার / পরিবর্তন';

  @override
  String get generalServicing => 'সাধারণ সার্ভিসিং';

  @override
  String get workshop => 'ওয়ার্কশপ / মেকানিক';

  @override
  String get serviceCost => 'সার্ভিসিং খরচ';

  @override
  String get tasksCompleted => 'এই ভিজিটে সম্পন্ন কাজসমূহ';

  @override
  String get selectAtLeastOneTask =>
      'অনুগ্রহ করে অন্তত একটি কাজ নির্বাচন করুন।';

  @override
  String get saveServiceVisit => 'সার্ভিসিং সংরক্ষণ করুন';

  @override
  String get serviceVisitLogged => 'সার্ভিসিং ভিজিট সফলভাবে সংরক্ষিত হয়েছে।';

  @override
  String get maintenanceWarningTitle => 'রক্ষণাবেক্ষণ প্রয়োজন';

  @override
  String get viewMaintenance => 'রক্ষণাবেক্ষণ দেখুন';

  @override
  String get notes => 'মন্তব্য';

  @override
  String itemsDueOrOverdue(int count) {
    return '$countটি রক্ষণাবেক্ষণ কাজে মনোযোগ দেওয়া প্রয়োজন';
  }

  @override
  String get brandOrSpec => 'পার্টস / অয়েল ব্র্যান্ড বা স্পেক';

  @override
  String get brandOrSpecHint => 'যেমন: Mobil 1 10W-40, OEM Denso';

  @override
  String get itemCost => 'আইটেমের খরচ';

  @override
  String get editServiceVisit => 'সার্ভিসিং তথ্য সম্পাদন করুন';

  @override
  String get deleteServiceVisit => 'সার্ভিসিং রেকর্ড মুছে ফেলুন';

  @override
  String get confirmDeleteServiceVisit => 'সার্ভিসিং রেকর্ড মুছে ফেলবেন?';

  @override
  String get confirmDeleteServiceVisitMsg =>
      'এটি স্থায়ীভাবে এই সার্ভিসিং রেকর্ডটি মুছে ফেলবে।';

  @override
  String get serviceVisitDeleted =>
      'সার্ভিসিং রেকর্ড সফলভাবে মুছে ফেলা হয়েছে।';

  @override
  String get serviceVisitUpdated => 'সার্ভিসিং তথ্য সফলভাবে আপডেট করা হয়েছে।';

  @override
  String get serviceVisitDetails => 'সার্ভিসিং রেকর্ডের বিবরণ';

  @override
  String get exportServiceHistory =>
      'রক্ষণাবেক্ষণ ও সার্ভিসিং হিস্ট্রি এক্সপোর্ট করুন';

  @override
  String get maintenanceReminders => 'রক্ষণাবেক্ষণ রিমাইন্ডার';

  @override
  String get enableMaintenanceReminders => 'রক্ষণাবেক্ষণ রিমাইন্ডার';

  @override
  String get enableMaintenanceRemindersSubtitle =>
      'সার্ভিসিংয়ের সময় হলে নোটিফিকেশন পান';

  @override
  String get doIt => 'এখন করুন';

  @override
  String get markDone => 'সম্পন্ন চিহ্নিত করুন';

  @override
  String get doItNow => 'এখনই করুন';

  @override
  String get markQuickDone => 'দ্রুত সম্পন্ন করুন';

  @override
  String get tasksAndReminders => 'কাজ ও রিমাইন্ডার';

  @override
  String get configureReminders => 'রিমাইন্ডার কনফিগার করুন';

  @override
  String get noActiveReminders =>
      'এই গাড়ির জন্য কোনো রিমাইন্ডার বা রক্ষণাবেক্ষণ সক্রিয় নেই।';

  @override
  String estimatedCost(String cost) {
    return 'আনুমানিক খরচ: $cost';
  }

  @override
  String refuelRemainingCountdown(String volume, String km) {
    return '~$volume লিটার বাকি (~$km কিমি)';
  }

  @override
  String get addCustomTask => 'কাস্টম কাজ যোগ করুন';

  @override
  String get intervalKm => 'ব্যবধান (কিমি)';
}
