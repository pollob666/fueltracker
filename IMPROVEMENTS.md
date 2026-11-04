# Fuel Tracker — Improvement & Modernization Plan

This document outlines strategic, architectural, domain, and UX improvements identified for the Fuel Tracker Flutter application, tracking implementation progress and roadmap additions.

---

## 1. High-Priority: Data Integrity & Core CRUD Operations

### 1.1 Non-Destructive Database Migrations `[COMPLETED]`
- **Status:** Implemented in schema v4 with versioned migration step handlers.
- **Current Architecture:** Additive migrations (`ALTER TABLE ... ADD COLUMN ...`) prevent accidental table drops on version upgrade.

### 1.2 Enable SQLite Foreign Key Enforcement `[COMPLETED]`
- **Status:** Enabled via `onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;')`.
- **Current Architecture:** Enforces relational integrity between vehicles and fuel records at database engine level.

### 1.3 Complete CRUD for Fuel Records (Edit & Delete UI) `[COMPLETED]`
- **Status:** Implemented in `AllDataPage` via row selection modal bottom sheet (Edit & Delete actions), safe delete confirmation dialog, and adapted `AddDataPage` supporting edit mode with chronological neighbor odometer validation.

### 1.4 Vehicle Deletion & Cascade Protections `[PENDING]`
- **Current Issue:** `ManageVehiclesPage` permits creating and editing vehicles, but lacks vehicle deletion.
- **Solution:**
  - Add a delete option with verification: ensure dependent records are either reassigned or deleted cleanly with user consent.

### 1.5 Modern Scoped Storage Export `[PENDING]`
- **Current Issue:** `ExportPage` attempts direct file writing via `dart:io File` into user-selected directory paths. On Android 11+ (API 30+), Scoped Storage blocks arbitrary filesystem access without elevated storage permissions.
- **Solution:**
  - Integrate `share_plus` to dispatch exported CSV/JSON files through the native Android/iOS share sheet.
  - Or use `file_picker`'s `saveFile` method utilizing Storage Access Framework (SAF).

---

## 2. High-Priority: Fuel Math & Domain Logic

### 2.1 Full-Tank vs. Partial Fill-Up Tracking `[COMPLETED]`
- **Status:** Implemented with `isFullTank` and `missedPreviousFill` fields in `FuelRecord` and Full-to-Full calculation engine in `MileageCalculator`.

### 2.2 Bi-Fuel Multi-Fuel Odometer Isolation `[COMPLETED]`
- **Status:** Implemented with optional `tripDistance` tracking per record for bi-fuel vehicle efficiency isolation.

### 2.3 Odometer Anomaly & Sanity Validation `[COMPLETED]`
- **Status:** Implemented soft confirmation dialog warning when entered odometer reading is less than or equal to previous records.

### 2.4 Internationalization: Units & Currency Configuration `[PENDING]`
- **Current Issue:** Currency (`BDT`), distance (`km`), and consumption units (`km/l`) are hardcoded across UI components and strings.
- **Solution:**
  - Add user preferences in `AppSettings`:
    - Currency Symbol/Code (USD, EUR, GBP, BDT, INR, etc.).
    - Distance Unit (`Kilometers` vs `Miles`).
    - Efficiency Formula (`km/l`, `l/100km`, `MPG US`, `MPG UK`).
  - Automatically convert and format displayed values based on user configuration.

---

## 3. Medium-Priority: UI, UX & Visual Analytics

### 3.1 Historical Charts & Visual Analytics `[PENDING]`
- **Current Issue:** The dashboard only shows basic static text cards and a wide tabular grid.
- **Solution:**
  - Add `fl_chart` to render visual graphs:
    - Fuel efficiency trend line over time.
    - Monthly fuel expense bar chart.
    - Price-per-unit history.

### 3.2 Immersive Sticky Mode Removal `[PENDING]`
- **Current Issue:** `main.dart` configures `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`, permanently concealing the Android system status bar (clock, battery) and navigation bar. This pattern hurts usability in utility tools.
- **Solution:**
  - Remove sticky immersive mode; allow the system status bar and navigation bar to remain visible naturally, or expose it as an optional toggle under settings.

### 3.3 Genuine Cloud Sync vs. Pseudo Folder Paths `[PENDING]`
- **Current Issue:** Settings presents Google Drive and Dropbox storage options, but only requests a local directory path via standard folder picker.
- **Solution:**
  - Either remove the misleading cloud dropdown options and rely on native file export/sharing, or integrate standard OAuth backup clients (e.g., Google Drive REST API / App Data folder).

### 3.4 Vehicle Maintenance & Service Reminders `[PENDING]`
- **New Feature Expansion:**
  - Add scheduled vehicle maintenance logging (oil change, tire replacement, insurance renewal, filter check) with odometer- and date-based notifications.

---

## 4. Architecture, State Management & Code Cleanliness

### 4.1 Extract Business Logic from UI Widgets `[COMPLETED]`
- **Status:** Extracted full-to-full calculations, weighted running averages, and cost per km into pure Dart `MileageCalculator` (`lib/utils/mileage_calculator.dart`).

### 4.2 Reactive State Management `[PENDING]`
- **Current Issue:** Pages manually reload data using `_loadInitialData()` after `await Navigator.push(...)`.
- **Solution:**
  - Introduce reactive state management (e.g., Riverpod, ChangeNotifier/ValueNotifier, or Bloc) so database updates trigger UI re-renders automatically without manual page reloading.

### 4.3 Sanitization of Secrets & Ad Configurations `[PENDING]`
- **Current Issue:** Hardcoded `"YOUR_TEST_DEVICE_ID"` inside `main.dart`.
- **Solution:**
  - Load ad unit IDs and test device lists via build-time environment variables (`--dart-define`) or config files.

---

## 5. Domain & Expense Tracking Expansion `[NEW]`

### 5.1 Fuel Receipt & Pump Meter Photo Attachments `[PENDING]`
- **Concept:** Allow capturing or picking photos of the fuel pump display or paper receipt when logging a refuel.
- **Solution:**
  - Save image files into local app documents directory.
  - Store relative image paths in `FuelRecord`.
  - Provide thumbnail preview in record details and full-screen zoom dialog.

### 5.2 Fuel Brand & Station Location Tracking `[PENDING]`
- **Concept:** Compare fuel quality and fuel efficiency across different fuel brands or gas stations.
- **Solution:**
  - Add optional `stationName` / `fuelBrand` field (e.g., Shell, BP, Total, Octane 95).
  - Add optional geolocation tag (lat/lng) with station name autofill via reverse geocoding.
  - Generate brand-level efficiency and price comparison metrics.

### 5.3 Total Cost of Ownership (TCO) & Multi-Category Expenses `[PENDING]`
- **Concept:** Fuel is only one component of vehicle expenses.
- **Solution:**
  - Support non-fuel expense logging (toll fees, parking, periodic wash, repairs, annual tax, insurance).
  - Calculate total operational cost per kilometer ($\text{Total Cost} / \Delta \text{Odometer}$).

### 5.4 Trip / Journey Fuel Cost Estimator `[PENDING]`
- **Concept:** Quick interactive calculator allowing users to plan road trips.
- **Solution:**
  - Inputs: Planned trip distance (km/mi) and optional fuel price override.
  - Outputs: Estimated fuel volume required and estimated monetary expense based on the vehicle's running average.

### 5.5 Full Snapshot Backup & Restore (JSON / SQLite) `[PENDING]`
- **Concept:** CSV import/export only transfers individual fuel records, losing vehicle specifications, settings, and metadata.
- **Solution:**
  - Add single-file JSON or encrypted SQLite backup containing all vehicles, fuel records, service records, and user preferences.
  - One-tap restore to migrate smoothly across devices.

---

## 6. Mobile Integration & UX Modernization `[NEW]`

### 6.1 Home Screen Quick Action & App Shortcuts `[PENDING]`
- **Concept:** Drivers refueling at the station need immediate data entry without navigating through menus.
- **Solution:**
  - Implement Android/iOS App Shortcuts (long-press app icon) to jump directly into `AddDataPage` for the default vehicle.
  - Optional home-screen quick entry widget.

### 6.2 Filter, Sort & Search in Record History `[PENDING]`
- **Concept:** `AllDataPage` currently displays records in a single chronological stream.
- **Solution:**
  - Add date-range filters (This Month, Past 3 Months, Custom Range).
  - Add vehicle selector and fuel type filters.
  - Add text search across record notes and station names.

### 6.3 Ad-Free In-App Purchase (IAP) `[PENDING]`
- **Concept:** Provide a clean path for users to disable banner and interstitial ads permanently.
- **Solution:**
  - Integrate `in_app_purchase` package.
  - Implement non-consumable "Remove Ads" product with secure purchase state persistence in `shared_preferences`.

---

## 7. Quality, Performance & DevOps `[NEW]`

### 7.1 Automated CI Unit & Widget Test Suite `[PENDING]`
- **Concept:** Ensure calculations and migrations do not regress during future development.
- **Solution:**
  - Add unit tests for `MileageCalculator` (partial fill sequences, zero/negative deltas, bi-fuel scenarios).
  - Add unit tests for SQLite migrations in `DatabaseHelper`.
  - Add CSV parser import/export round-trip tests.
  - Integrate `flutter test` step in GitHub Actions `.github/workflows/release.yml`.

### 7.2 Strict Lints & Static Analysis Modernization `[PENDING]`
- **Concept:** Maintain clean, modern Dart code standards.
- **Solution:**
  - Update `analysis_options.yaml` with modern strict lint rule sets (`flutter_lints` / `very_good_analysis`).
  - Enable strict type checks (`strict-casts`, `strict-inference`, `strict-raw-types`).
