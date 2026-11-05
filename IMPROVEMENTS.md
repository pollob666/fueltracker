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

### 1.4 Vehicle Deletion & Cascade Protections `[COMPLETED]`
- **Status:** Implemented in `DatabaseHelper`, `VehicleService`, and `ManageVehiclesPage`.
- **Current Architecture & Implementation Details:**
  - **Atomic Cascade Transaction:** `DatabaseHelper.deleteVehicleCascade(vehicleId)` executes an atomic SQLite transaction deleting child `fuel_records` before deleting the parent vehicle in `vehicles`, enforcing foreign key integrity and preventing orphaned records.
  - **Record Count Query:** `DatabaseHelper.getFuelRecordCountForVehicle(vehicleId)` and `VehicleService.getRecordCountForVehicle(vehicleId)` query exact dependent record counts via `SELECT COUNT(*) FROM fuel_records WHERE vehicleId = ?`.
  - **Confirmation Dialog:** Dynamic confirmation dialog in `ManageVehiclesPage` queries record count asynchronously and warns the user with the exact number of fuel records that will be permanently deleted (or simple confirmation if 0 records).
  - **Single-Vehicle Guard:** Deletion is disabled in the UI (disabled icon button with tooltip) and blocked programmatically when only one vehicle remains in the database.
  - **Default Vehicle Auto-Fallback:** If the deleted vehicle was configured as the active default, `VehicleService.deleteVehicle` automatically reassigns the default vehicle preference in `SharedPreferences` to the first remaining vehicle.

### 1.5 Modern Scoped Storage Export `[COMPLETED]`
- **Status:** Implemented in `ExportPage`, `SettingsPage`, and `pubspec.yaml` via `share_plus`.
- **Current Architecture & Implementation Details:**
  - **System Share Sheet Integration:** Added `share_plus: ^10.1.4`. When no custom folder path is configured, `ExportPage` stages exported CSV and JSON files in the application's temporary cache directory (`getTemporaryDirectory()`) and dispatches them via `Share.shareXFiles`.
  - **Android Scoped Storage & iOS Compliance:** Resolves permission denials on Android 11+ (API 30+) scoped storage without requiring elevated filesystem storage permissions (`MANAGE_EXTERNAL_STORAGE`).
  - **iPad Popover Safety:** Anchors `sharePositionOrigin` using the export page's `RenderBox` bounds (`box.localToGlobal(Offset.zero) & box.size`), preventing uncaught `NSInternalInconsistencyException` crashes on iPadOS / tablet form factors.
  - **Optional Custom Storage Path:** `SettingsPage` makes directory selection optional, providing clear button to revert to system share sheet export mode and descriptive helper text (`folderPathHelper`). Direct file export to custom directories is preserved when configured.

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

### 2.5 Advanced Trip Meter Support & Driving Condition Analytics `[COMPLETED]`
- **Concept:** Maximize utility of hardware trip meters (Trip A / Trip B) while remaining completely optional and zero-friction for vehicles without trip meters or users who forget to reset.
- **Architecture & Implementation Details:**
  - **Vehicle Trip Mode Configuration:**
    - Per-vehicle preference `tripMeterMode`:
      - `None` (Default for vehicles without trip meters): Completely conceals all trip meter fields across data entry and details forms to eliminate UI clutter.
      - `Single Trip` (Trip A): Exposes optional `tripDistance` field with auto-sync and validation.
      - `Dual Trip` (Trip A & Trip B): Exposes two configurable fields (e.g., "Trip A: Fuel Interval", "Trip B: Oil/Tour Interval").
  - **Auto-Sync & Typo Cross-Validation:**
    - **One-Tap Odometer Sync:** Entering `tripDistance` offers an auto-fill button to compute current odometer: $O_{\text{current}} = O_{\text{previous}} + \text{Trip}$.
    - **Non-Blocking Sanity Hint:** If user manually enters both odometer and trip, and $|\Delta O - \text{Trip}| > 1.0\text{ km}$, show non-blocking helper chip: *"Odometer delta differs from Trip. Reset late or forgot to reset?"*
  - **Fail-Safe & Missing Data Fallback:**
    - **Total Odometer as Ground Truth Anchor:** If user leaves trip field blank or forgets to reset trip, `MileageCalculator` seamlessly falls back to total odometer delta $(O_i - O_{i-1})$.
    - **Broken Odometer Fallback:** If vehicle total odometer is broken or 5-digit roll-over occurred, trip distance serves as primary interval distance for full-to-full calculation.
  - **Driving Condition Tagging:**
    - Add optional `drivingCondition` enum (`City`, `Highway`, `Mixed`) when entering trip distance.
    - Enables comparative efficiency analytics: City mileage vs. Highway cruising efficiency.

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

### 3.4 Comprehensive Vehicle Maintenance & Periodic Service Reminders `[PENDING]`
- **Concept:** Track recurring distance- and time-based periodic maintenance (e.g., General Servicing, Spark Plug, Oil Filter, Fuel Filter, Chain & Sprocket, Air Filter) with customizable intervals, bundled notifications, and multi-task service visit logging.
- **Architecture & Implementation Details:**
  - **Extensible Maintenance Catalog & Storage:**
    - SQLite table `maintenance_tasks` with foreign key cascade to `vehicles(id)`:
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `vehicleId INTEGER NOT NULL`, `taskKey TEXT`, `title TEXT NOT NULL`, `intervalKm REAL NOT NULL`, `intervalMonths INTEGER`, `lastServiceOdo REAL NOT NULL`, `lastServiceDate TEXT NOT NULL`, `reminderBufferKm REAL DEFAULT 100`, `isEnabled INTEGER DEFAULT 1`.
    - **Default Pre-Populated Tasks per Vehicle:**
      - **General Servicing:** Every 4,000 km / 6 months.
      - **Engine Oil Change:** Every 2,000–3,000 km / 3 months.
      - **Engine Oil Filter Change:** Every 4,000 km / 6 months.
      - **Air Filter Clean/Replacement:** Every 4,000 km / 6 months.
      - **Spark Plug Replacement:** Every 4,000–8,000 km / 12 months.
      - **Fuel Filter Replacement:** Every 4,000–8,000 km / 12 months.
      - **Chain & Sprocket Kit Inspection/Replacement:** Every 4,000–12,000 km.
      - *Custom Items:* Users can create custom maintenance tasks with user-defined names, km intervals, and optional month ceilings.
    - SQLite table `service_sessions` (Unified Service Visit / Receipt):
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `vehicleId INTEGER NOT NULL`, `odometer REAL NOT NULL`, `serviceDate TEXT NOT NULL`, `totalCost REAL`, `workshopName TEXT`, `notes TEXT`.
    - SQLite table `service_session_items` (Tasks completed in session):
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `sessionId INTEGER NOT NULL`, `taskId INTEGER NOT NULL`, `cost REAL`, `notes TEXT`, linking completed tasks to the session.
  - **Hybrid Prediction & Trigger Algorithm:**
    - Target Odometer: $O_{\text{due}} = O_{\text{last\_service}} + \text{Interval Km}$.
    - Calendar Limit Date (Optional): $D_{\text{time\_limit}} = D_{\text{last\_service}} + \text{Interval Months}$.
    - Projected Odometer Due Date: $D_{\text{odo\_due}} = \text{Today} + \frac{O_{\text{due}} - O_{\text{current}}}{\text{Daily Run Rate}}$.
    - Effective Due Date: $\min(D_{\text{odo\_due}}, D_{\text{time\_limit}})$ (whichever comes first).
    - Cold-Start Fallback: Falls back to user-configured default daily run (20 km/day) if $< 2$ refuel records exist.
    - Two-Stage Trigger:
      1. *Advance Warning:* Triggers when $(O_{\text{due}} - O_{\text{current}}) \le \text{Buffer Km}$ (100 km) or $\le 3\text{ days}$ to target date.
      2. *Overdue Alert:* Triggers when odometer or calendar ceiling is exceeded.
  - **Bundled Notifications & In-App Presentation:**
    - **Bundled Android Notifications:** Co-occurring due tasks are aggregated into a single non-spamming system notification (e.g., *"3 maintenance items due: General Servicing, Oil Filter, Air Filter"*) scheduled via `flutter_local_notifications`.
    - **Dashboard Summary Card:** High-visibility dashboard card showing total pending items and the nearest upcoming service with remaining km / days.
    - **Multi-Task Logging UI (`MaintenancePage`):**
      - Navigation Drawer entry point to `MaintenancePage`.
      - Visual health cards with progress indicators ($\frac{O_{\text{current}} - O_{\text{last}}}{\text{Interval Km}}$).
      - Single-visit checklist modal: User enters current odometer, date, workshop name, total cost, and selects multiple completed tasks via checkboxes (e.g., [x] Servicing, [x] Oil Filter, [x] Air Filter), atomically resetting all selected task intervals in a single database transaction.

### 3.5 Predictive Refuel Reminder `[PENDING]`
- **Concept:** Proactively alert users before fuel reaches critical reserve levels based on vehicle tank capacity, running fuel efficiency, and daily driving habits.
- **Architecture & Implementation Details:**
  - **Configuration & Storage:**
    - Add `refuelReminderThreshold` (in Liters, e.g., 5.0 L) and `tankCapacity` per vehicle in `vehicles` table and Vehicle Profile editor.
    - Global default threshold option in `AppSettings`.
  - **Prediction & Math Engine:**
    - Running Fuel Efficiency: Weighted harmonic/running average ($E = \text{km/L}$) from `MileageCalculator`.
    - Remaining Fuel: $V_{\text{rem}} = V_{\text{tank}} - \frac{O_{\text{current}} - O_{\text{last\_full}}}{E}$.
    - Distance to Reserve Threshold: $D_{\text{to\_reserve}} = (V_{\text{rem}} - V_{\text{threshold}}) \times E$.
    - Projected Refuel Date: $T_{\text{refuel\_days}} = \frac{D_{\text{to\_reserve}}}{\text{Daily Run Rate}}$.
    - Cold-Start Fallback: Uses fallback daily run (default 20 km/day) if insufficient refuel records exist.
  - **Notification & UX Delivery:**
    - **Android OS Notification:** Scheduled target notification via `flutter_local_notifications` when projected date reaches low-fuel threshold. Rescheduled automatically on every new refuel entry.
    - **In-App Banner Card:** Dashboard indicator showing remaining fuel estimate, estimated distance-to-empty, and quick "Refuel Now" action button.

### 3.6 Dashboard Last Refuel Recency & Elapsed Counter `[COMPLETED]`
- **Status:** Implemented in `DashboardPage`, `MileageCalculator`, and localization resources (`app_en.arb`, `app_bn.arb`).
- **Current Architecture & Implementation Details:**
  - **Data Display:**
    - Displays formatted calendar date (e.g., `Oct 28, 2024`) via `intl` (`DateFormat.yMMMd`).
    - Relative elapsed time counter: `"Today"`, `"Yesterday"`, or `"X days ago"` calculated from calendar date differences (`nowDate.difference(targetDate).inDays`).
    - **Cadence Warning Indicator:** `MileageCalculator.calculateAverageRefuelCadence(_filteredRecords)` calculates average days between fills. If elapsed days exceed $1.5\times$ average cadence, the badge shifts from `secondaryContainer` to `errorContainer` accent.

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

### 5.1 Fuel Receipt & Pump Meter Photo Attachments + OCR Vision Pipeline `[PENDING]`
- **Concept:** Allow capturing or picking photos of the fuel pump display or paper receipt when logging a refuel, with privacy-first on-device computer vision to automate data entry.
- **Solution & Storage:**
  - Save image files into local app documents directory; store relative image paths in `FuelRecord`.
  - Provide thumbnail preview in record details and full-screen zoom dialog.
- **Future Roadmap (TODOs):**
  - **TODO 1: Dashboard Cluster Odometer OCR:** On-device text recognition (`google_mlkit_text_recognition`) to extract digital or analog odometer reading directly from user-snapped dashboard photo, auto-populating the odometer field with confidence score.
  - **TODO 2: Dispenser Unit LCD Reader:** On-device computer vision parser to extract fuel volume (liters/gallons) and total monetary payment amount directly from the fuel station dispenser display image, bypassing manual typing.

### 5.2 Fuel Station Geofencing & Poor Fuel Quality Anomaly Flagging `[PENDING]`
- **Concept:** Capture fueling station GPS location with a proximity radius, detect return visits, and automatically flag suspect stations if vehicle mileage experiences a sudden drop.
- **Architecture & Implementation Details:**
  - **Data Model & Geofencing:**
    - SQLite table `fuel_stations`:
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `name TEXT NOT NULL`, `latitude REAL NOT NULL`, `longitude REAL NOT NULL`, `radiusMeters REAL DEFAULT 80.0`, `isSuspectQuality INTEGER DEFAULT 0`, `rating REAL`, `notes TEXT`.
    - Link `FuelRecord` to `stationId` (optional foreign key with `SET NULL` on delete).
    - Capture location on refuel entry via `geolocator`:
      - If user is within existing station radius (75–100m): Auto-fill station name and show quality indicator.
      - If new coordinates: Prompt user to save station name with configured radius (default 80m).
  - **Fuel Quality Anomaly Detection:**
    - **Timing:** Evaluated on the *subsequent* full-to-full refuel (when actual distance and consumption of tank $N$ are recorded).
    - **Trigger Condition:** If interval fuel efficiency drops $>15\%$ below the vehicle's rolling average km/L ($E_{\text{interval}} < 0.85 \times E_{\text{running}}$).
    - **Confirmation Prompt:** Display soft confirmation dialog explaining the mileage drop and asking user if they want to flag the station as "Suspect / Low Quality Fuel" (ruling out external anomalies like heavy traffic or AC usage).
  - **Proximity Alert on Return:**
    - When user opens "Add Refuel" while inside the geofence radius of a previously flagged station, display an prominent warning banner: *"⚠️ Warning: Lower fuel efficiency was recorded after fueling at this station."*

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

---

## 8. Implementation Priority Matrix (Ranked by Complexity: Lowest to Highest)

| Rank | Feature | Complexity | Target Phase | Implementation Scope & Rationale |
| :--- | :--- | :---: | :---: | :--- |
| **1** | **Dashboard Last Refuel Recency Counter** (Section 3.6) | **Very Low** (1/5) | **COMPLETED** | **Pure UI Enhancement:** Calculates `DateTime.now().difference(date).inDays` and displays `"Today"`, `"Yesterday"`, or `"X days ago"` with cadence-exceeded warning indicator. |
| **2** | **Advanced Trip Meter Support** (Section 2.5) | **Low** (2/5) | **COMPLETED** | **Form Intelligence & Fallback:** Vehicle setting (`None`/`Single`/`Dual`), hides fields when `None`, auto-fills odometer from trip, cross-checks typos ($|\Delta O - \text{Trip}|$), and gracefully defaults to total odometer if left blank or forgotten. |
| **3** | **Predictive Refuel Reminder** (Section 3.5) | **Low-Medium** (2.5/5) | **IMPLEMENT NOW** (Phase 1) | **Lightweight Math + Notifications:** Uses existing `MileageCalculator` daily run rate and km/L. Needs minor vehicle settings additions (`tankCapacity`, threshold), `flutter_local_notifications` setup, and dashboard low-fuel banner. |
| **4** | **Periodic Maintenance & Service Reminders** (Section 3.4) | **Medium** (3/5) | **IMPLEMENT NEXT** (Phase 2) | **Relational Schema + Multi-Task UI:** SQLite schema migration v5 (`maintenance_tasks`, `service_sessions`), new `MaintenancePage` with multi-select visit checklist, hybrid km/month triggers, and bundled notifications. |
| **5** | **Fuel Station Geofencing & Quality Anomaly Flagging** (Section 5.2) | **Medium-High** (4/5) | **IMPLEMENT LATER** (Phase 3) | **Location Services + Analytics:** Requires `geolocator` plugin, runtime location permissions, radius matching math, `fuel_stations` table, and subsequent-refuel anomaly verification (>15% drop). |
| **6** | **On-Device OCR Vision Pipeline (Odo & Dispenser LCD)** (Section 5.1) | **High** (5/5) | **IMPLEMENT LATER** (Future Roadmap) | **Machine Learning & Image Parsing:** Integrates `google_mlkit_text_recognition`, camera capture, image pre-processing, and regex parsers for 7-segment / odometer dial digits. |
