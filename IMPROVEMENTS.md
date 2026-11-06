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

### 3.4 Comprehensive Vehicle Maintenance, Periodic Service Reminders & Optional Detailed Service Logs `[COMPLETED]`
- **Status:** Fully implemented in `DatabaseHelper` (Schema v7), `MaintenanceCalculator`, `MaintenancePage`, `DashboardPage`, `NotificationService`, `ExportPage`, `ImportPage`, and localization resources (`app_en.arb`, `app_bn.arb`).
- **Concept:** Track recurring distance- and time-based periodic maintenance (e.g., General Servicing, Spark Plug, Oil Filter, Fuel Filter, Chain & Sprocket, Air Filter) with customizable intervals, bundled notifications, and dual-mode service completion: quick one-tap reset ("Mark Done Only") OR full refuel-style detailed maintenance history logging (with Edit/Delete, CSV/JSON import/export, item-level part/engine oil ("Mobil") brand details, and saved workshop/parts shop locations).
- **Architecture & Implementation Details:**
  - **Extensible Maintenance Catalog & Storage:**
    - SQLite table `maintenance_tasks` with foreign key cascade to `vehicles(id)`:
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `vehicleId INTEGER NOT NULL`, `taskKey TEXT`, `title TEXT NOT NULL`, `intervalKm REAL NOT NULL`, `intervalMonths INTEGER`, `lastServiceOdo REAL NOT NULL`, `lastServiceDate TEXT NOT NULL`, `reminderBufferKm REAL DEFAULT 100`, `isEnabled INTEGER DEFAULT 1`.
    - **Default Pre-Populated Tasks per Vehicle:**
      - **General Servicing:** Every 5,000 km / 6 months.
      - **Engine Oil Change:** Every 3,000 km / 3 months.
      - **Engine Oil Filter Change:** Every 6,000 km / 6 months.
      - **Air Filter Clean/Replacement:** Every 4,000 km / 6 months.
      - *Additional / Custom Items:* Spark Plug, Fuel Filter, Chain & Sprocket, or user-defined tasks with custom names, km intervals, and optional month ceilings.
    - SQLite table `service_sessions` (Unified Service Visit / Receipt):
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `vehicleId INTEGER NOT NULL`, `odometer REAL NOT NULL`, `serviceDate TEXT NOT NULL`, `totalCost REAL`, `workshopName TEXT`, `locationId INTEGER` (optional FK to `saved_locations(id)` `ON DELETE SET NULL`), `notes TEXT`.
    - SQLite table `service_session_items` (Tasks, Engine Oil / "Mobil", & Parts completed in session):
      - Columns: `id INTEGER PRIMARY KEY AUTOINCREMENT`, `sessionId INTEGER NOT NULL`, `taskId INTEGER NOT NULL`, `brandOrSpec TEXT` (e.g., `"Mobil 1 10W-40"`, `"NGK Spark Plug"`), `cost REAL`, `locationId INTEGER` (optional override FK to `saved_locations(id)` `ON DELETE SET NULL` if part/oil was bought at a different shop than the servicing workshop), `notes TEXT`.
  - **Dual-Mode Service Completion (Optional Detailed Logging vs. Quick Done):**
    - **Mode A — Quick Done ("Mark as Done Only"):** Zero-friction one-tap confirmation updating `lastServiceOdo` and `lastServiceDate` directly when the user chooses not to record receipt/part details.
    - **Mode B — Detailed Service & Parts Log (Refuel-Record Parity):**
      - Multi-task visit logger where user records Date, Odometer, main Workshop/Service Location (select from existing saved locations or save new name), Total Cost, and Notes.
      - Per-item details for each selected task (Engine Oil / "Mobil" change, parts replacement, servicing): optional Brand/Part Specification, Item Cost, Item Notes, and optional separate Parts/Oil Purchase Shop location (defaults to the session's main workshop if not overridden).
      - Atomically inserts the `service_sessions` + `service_session_items` records and resets `lastServiceOdo` and `lastServiceDate` for all checked tasks in a single transaction.
    - **Full History CRUD & Export Parity (Like Refuel Records):**
      - **Maintenance History View:** Tabular/card history log of all recorded `service_sessions` per vehicle displaying Date, Odometer, Workshop/Location (with suspect warning badge if flagged), Tasks/Parts Summary, Brand/Spec, and Cost.
      - **Edit & Delete Support:** Row selection modal bottom sheet allowing users to Edit or Delete past maintenance records (with safe confirmation dialog).
      - **CSV & JSON Import/Export:** Extend `ExportPage` and `SettingsPage` import/export pipelines to include maintenance sessions, item-level part/oil brands, costs, and location references alongside refuel records.
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
      - Navigation Drawer entry point to `MaintenancePage` with tabs/sections for **Active Tasks** (health progress cards) and **Service History** (detailed logs).

### 3.5 Predictive Refuel Reminder & Tank Range Forecasting `[COMPLETED]`
- **Concept:** Proactively alert users before fuel reaches critical reserve levels based on vehicle tank capacity, running fuel efficiency, daily driving habits, and bi-fuel tank configuration.
- **Architecture & Implementation Details:**
  - **Dual Independent Reminders & Vehicle Configuration:**
    - **Primary Fuel Volume Reminder:** Triggers when primary tank remaining volume drops below a configurable threshold (slider from 0.8 L to tank capacity, displaying live volume and percentage of full tank).
    - **Combined Distance-to-Empty (DTE) Reminder:** Triggers when combined range across all vehicle fuel tanks drops below a configurable distance threshold (slider from 15 to 200 km).
    - **Vehicle Fuel Setup:** Material 3 `SegmentedButton` configuring `[Single Fuel]` vs `[Dual / Bi-Fuel]`, dynamically adjusting secondary tank inputs and auto-clearing secondary settings on single fuel.
    - **Vehicle Management Chips:** `ManageVehiclesPage` displays active reminder threshold badges (`[🔔 ≤ X L]`, `[🔔 ≤ Y km]`) alongside fuel setup chips.
  - **Forecasting Engine (`MileageCalculator`):**
    - **Anchor-to-Full-Tank Tracking:** Anchors burn calculations strictly to the most recent full-tank fill ($O_{\text{anchor}}$), accumulating subsequent partial fills to prevent volume uncertainty.
    - **Burn Rate & Autonomy:** Computes daily run rate (km/day) and daily fuel burn rate (L/day), deriving remaining primary volume ($V_{\text{rem}} = C_{\text{primary}} - \text{burn}$) and dual-fuel combined range ($\text{DTE}_{\text{total}} = \text{DTE}_{\text{primary}} + \text{DTE}_{\text{secondary}}$).
    - **Calibration Guard:** Safely marks vehicles without a historical full-tank fill as uncalibrated (`isCalibrated == false`), rendering a friendly dashboard prompt instead of false alarms.
  - **Configurable Push Scheduling & Delivery:**
    - **Configurable Global Time:** TimePicker setting in `SettingsPage` (default 09:00 AM, stored in `AppSettings` / `SharedPreferences`); auto-reschedules active reminders across all vehicles on update.
    - **Local Notifications:** Exact alarm scheduling via `flutter_local_notifications` 22.3.3 and `timezone` on the projected low-fuel date, with immediate alert dispatch if already below threshold.
    - **Dashboard Card:** Unified Material 3 telemetry card displaying live remaining volume, combined DTE, and days remaining, dynamically shifting to warning accent with a one-tap "Refuel Now" action button. Auto-rescheduled on any refuel entry change in `AddDataPage`.

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

### 5.2 Unified Location Management (Fuel Stations & Service/Parts Shops) & Mileage-Drop Quality Anomaly Flagging `[PENDING]`
- **Concept:** Provide a unified location management system for refueling stations, servicing workshops, and engine oil ("Mobil") / spare parts shops. Support hybrid GPS geofencing (auto-detecting return visits within radius) alongside manual selection from saved locations or one-tap saving of new location names. Automatically detect sudden post-refuel or post-service mileage drops and empower the user to flag suspect fuel stations, workshops, or parts/oil shops.
- **Architecture & Implementation Details:**
  - **Unified Saved Locations Data Model & Geofencing:**
    - SQLite table `saved_locations`:
      - Columns:
        - `id INTEGER PRIMARY KEY AUTOINCREMENT`
        - `name TEXT NOT NULL`
        - `type TEXT NOT NULL DEFAULT 'fuel_station'` (`'fuel_station'`, `'service_shop'`, or `'both'`)
        - `latitude REAL` (nullable — supports manual named locations saved without GPS)
        - `longitude REAL` (nullable)
        - `radiusMeters REAL DEFAULT 80.0`
        - `isSuspectFuel INTEGER DEFAULT 0` (flagged for poor/adulterated fuel quality)
        - `isSuspectServiceOrParts INTEGER DEFAULT 0` (flagged for counterfeit/poor engine oil "Mobil", bad replacement parts, or poor servicing)
        - `suspectReason TEXT` (e.g., *"Mileage dropped 18% after Mobil 10W-40 change / refueling"*)
        - `rating REAL`
        - `notes TEXT`
    - **Relational Links:**
      - `FuelRecord`: Add optional `locationId INTEGER` (FK to `saved_locations(id)` `ON DELETE SET NULL`).
      - `ServiceSession`: Add optional `locationId INTEGER` (FK to `saved_locations(id)` `ON DELETE SET NULL`) for the main servicing workshop.
      - `ServiceSessionItem`: Add optional `locationId INTEGER` (FK to `saved_locations(id)` `ON DELETE SET NULL`) for the specific shop where engine oil ("Mobil") or replacement parts were purchased/changed (defaults to session `locationId` if not overridden).
  - **Hybrid Location Selection & New Location Saving Workflow:**
    - Applies across **Refueling (`AddDataPage`)** and **Servicing / Engine Oil ("Mobil") / Parts Change (`MaintenancePage`)**:
      - **Existing Saved Locations Picker:** Searchable dropdown / autocomplete filtered by context (`fuel_station` + `both` during refueling; `service_shop` + `both` during maintenance/oil/parts logging), displaying suspect warning badges (`⚠️ Suspect Fuel` / `⚠️ Suspect Oil/Parts`) next to previously flagged locations.
      - **GPS Auto-Detection (When Location Available):** Queries `geolocator` on form open; if within an existing location's `radiusMeters` (default 80m), auto-selects the location and surfaces any active quality warning banner.
      - **New Location Save Prompt:** If the user types a new location name or visits new GPS coordinates, offers a clean prompt/toggle to save the location name (with optional current GPS coordinates and category `fuel_station` / `service_shop` / `both`) into `saved_locations` for future one-tap selection.
  - **Mileage-Drop Anomaly Detection & Smart Cause Attribution:**
    - **Timing:** Evaluated on a full-to-full refuel when interval fuel efficiency $E_{\text{interval}}$ is computed.
    - **Trigger Condition:** Interval fuel efficiency drops $>15\%$ below the vehicle's rolling weighted average km/L ($E_{\text{interval}} < 0.85 \times E_{\text{running}}$).
    - **Candidate Lookup:**
      1. **Recent Fuel Station:** The `saved_locations` entry attached to the refuel(s) that supplied the fuel consumed during this low-mileage interval.
      2. **Recent Service / Engine Oil ("Mobil") / Parts Location:** Any `service_sessions` (and their item-level `service_session_items` for Engine Oil, Filters, Spark Plugs, General Servicing, etc.) logged within the last 1–2 refuel intervals or within the last $500\text{ km}$ prior to the mileage drop.
    - **Smart Cause Picker Dialog:**
      - Displays a non-blocking diagnostic dialog showing the exact mileage drop percentage ($E_{\text{interval}}$ vs. $E_{\text{running}}$) and presents the candidate causes so the user can rule out traffic/weather or flag the culprit:
        - `[ ] Flag Fuel Station: <Station Name> (Suspect Fuel Quality)`
        - `[ ] Flag Workshop / Parts Shop: <Workshop / Shop Name> — <Task / Brand, e.g., Mobil 10W-40 / Air Filter> (Suspect Engine Oil / Bad Parts / Servicing)`
      - User can select either, both, or dismiss ("Normal Traffic / Dismiss").
      - Confirming updates `isSuspectFuel = 1` and/or `isSuspectServiceOrParts = 1` along with `suspectReason` on the respective `saved_locations` records.
  - **Proactive Proximity & Selection Alerts on Return:**
    - When the user selects a flagged location from the dropdown or enters its GPS geofence radius in `AddDataPage` or `MaintenancePage`, display a high-visibility warning banner:
      - *Fuel Station Warning:* `"⚠️ Warning: Mileage dropped significantly after refueling at this station."*
      - *Service / Parts / Oil Warning:* `"⚠️ Warning: Mileage dropped after engine oil / parts change or servicing at this location (<suspectReason>)."*
    - Users can also manage, review, or clear suspect flags anytime from a dedicated **Saved Locations** management view.

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
| **3** | **Predictive Refuel Reminder** (Section 3.5) | **Low-Medium** (2.5/5) | **COMPLETED** | **Dual Independent Reminders & Range Forecasting:** Configurable Volume-based (primary tank) and Distance-based (combined DTE) reminders, unified Material 3 dashboard card, active threshold chips in vehicle management, and user-configurable daily Android notification time via `flutter_local_notifications`. |
| **4** | **Periodic Maintenance, Service Reminders & Optional Detailed Service Logs** (Section 3.4) | **Medium** (3.5/5) | **COMPLETED** | **Relational Schema + Dual-Mode Logging, Optional Reminders & History CRUD:** SQLite schema (`maintenance_tasks`, `service_sessions`, `service_session_items` with item-level oil/"Mobil"/part brand & shop location), per-task optional toggles in vehicle configuration, auto-hiding drawer menu, `MaintenancePage` with unified Tasks & Reminders (fuel countdown + maintenance cards with `[Do It Now]` and `[Mark Quick Done]`), dashboard alert cards with `[Do It]` and `[Mark Done]`, estimated service cost, and CSV/JSON export parity. |
| **5** | **Unified Location Management & Mileage Anomaly / Boost Flagging (Fuel, Oil & Parts)** (Section 5.2) | **Medium-High** (4/5) | **COMPLETED** | **Always-On GPS Geofencing + Smart Anomaly & Boost Badging:** Unified `saved_locations` schema v8 (`fuel_station`, `service_shop`, `both`), 80m proximity auto-clustering, "Save & Name Location" toggle, multi-station proximity disambiguation bottom sheet, Mileage-Drop Anomaly Detection ($>15\%$ drop) attributing culprit to step $N-1$ refuel location or recent service (Amber warning badge ⚠️ on return), Mileage-Boost Detection ($>15\%$ gain) marking location Green (`🟢 High Efficiency`), and Saved Locations management screen with "Show Unnamed Locations" toggle and CSV export/import parity. |
| **6** | **On-Device OCR Vision Pipeline (Odo & Dispenser LCD)** (Section 5.1) | **High** (5/5) | **IMPLEMENT LATER** (Future Roadmap) | **Machine Learning & Image Parsing:** Integrates `google_mlkit_text_recognition`, camera capture, image pre-processing, and regex parsers for 7-segment / odometer dial digits. |
