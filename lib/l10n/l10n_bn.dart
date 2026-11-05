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
}
