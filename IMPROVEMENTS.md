# FuelTracker Improvements & Roadmap Specification

---

## 1. Executive Summary & Architecture Audit

An exhaustive technical, architectural, and user experience audit was conducted across the `pollob666/fueltracker` repository. The codebase represents a mature, privacy-first Flutter mobile utility with strong mathematical foundations for fuel accounting. However, scaling the application toward commercial fleet utility, advanced visual analytics, multimodal input (OCR), and robust multi-device synchronization requires addressing core architectural bottlenecks.

### 1.1 Current State Overview & Core Strengths
- **Robust Mathematical Engine:** `MileageCalculator` (`lib/utils/mileage_calculator.dart`) implements an uncompromising Full-to-Full calculation algorithm. It mathematically resolves partial refuel sequences, baseline resets on missed fills, and weighted running averages ($\frac{\sum \Delta O}{\sum V}$), completely eliminating Simpson's Paradox skew.
- **Relational Integrity & Safety Guards:** The SQLite database (`DatabaseHelper.dart`, schema version 8) strictly enforces `PRAGMA foreign_keys = ON;`. High-risk entity deletions (such as vehicles or saved locations) execute within atomic transactions that cascade or detach child foreign keys, preventing orphaned data or database corruption.
- **Proactive Maintenance & Anomaly Detection:** The platform features hybrid predictive maintenance forecasting (combining daily odometer run rates with calendar time limits) and an anomaly detection engine that flags $>15\%$ mileage drops/boosts with attribution diagnostics.
- **Privacy & Native Scoped Storage Parity:** The app requires zero account sign-up and operates 100% offline. File exports stage cleanly into application cache directories and dispatch via the native OS share sheet (`share_plus`), adhering to modern Android 11+ (API 30+) scoped storage requirements without legacy storage permissions.

### 1.2 Identified Architectural & UX Gaps

```
+-----------------------------------------------------------------------------------------------------+
|                                    IDENTIFIED SYSTEM GAPS                                           |
+-------------------------------------+---------------------------------------------------------------+
| 1. State Management Bottleneck      | Imperative setState() and manual _loadInitialData() triggers  |
|                                     | cause uncoordinated re-renders and redundant database I/O.    |
| 2. Database Indexing & Scalability  | Schema v8 lacks composite B-tree indexes; large datasets      |
|                                     | suffer full table scans during vehicle-filtered queries.      |
| 3. Hardcoded Units & Currencies     | UI displays hardcoded "BDT", "km", and "km/l", preventing     |
|                                     | seamless international adoption (Miles, Gallons, MPG, EUR).   |
| 4. Data Pipeline Inconsistencies    | CSV export omits newer schema columns (driving conditions,    |
|                                     | trip deltas, GPS coordinates); no backup schema versioning.   |
| 5. Form Ergonomics & Input Friction | Circular controller dependencies when computing Vol/Rate/Cost;|
|                                     | immersive sticky mode permanently hides system clock/battery. |
| 6. Missing Visual Analytics         | Raw tabular data forces high cognitive load; lack of visual   |
|                                     | trendlines, expense distributions, and station comparisons.   |
+-------------------------------------+---------------------------------------------------------------+
```

1. **State Management & Data Flow Bottlenecks:**
   - **No Reactive Framework:** The application currently relies on plain `StatefulWidget` instances with local `setState()`. There is no global or scoped reactive state layer (such as Riverpod, Bloc, or Signals).
   - **Manual Navigation Invalidation:** When child forms (`AddDataPage`, `MaintenancePage`, `ManageVehiclesPage`) pop back to parent views (`DashboardPage`, `AllDataPage`), data reloads imperatively via `await Navigator.push(...); _loadInitialData();`. If underlying SQLite tables change via background tasks, notifications, or deep links, UI states desynchronize.
   - **Redundant SQLite I/O:** Every tab switch and page navigation re-executes heavy multi-table joins and full-record list sorts, resulting in frame drops on older hardware.

2. **Database Engine & Persistence Gaps:**
   - **Absence of Database Indexes:** In schema v8, tables `fuel_records`, `service_sessions`, and `saved_locations` have primary and foreign keys, but lack secondary indexes on frequently filtered/sorted fields (`vehicleId`, `date`, `odometer`, `latitude`, `longitude`). As records exceed 1,000 entries, queries execute linear $O(N)$ full table scans.
   - **Lack of Reactive Query Streams:** SQLite operations are purely one-shot futures. The app cannot observe live database table streams.

3. **Data Pipeline, Export & Cloud Backup Limitations:**
   - **Export Schema Drift:** The CSV export method in `ExportPage` (`_exportRefuelingDataAsCsv`) has lagged behind schema updates: it omits `secondaryTripDistance`, `drivingCondition`, `locationId`, `latitude`, and `longitude`. Re-importing a CSV export drops these critical telemetry fields.
   - **Pseudo Cloud Storage:** `SettingsPage` displays options for "Google Drive" and "Dropbox", but internally binds them to a local folder picker path. There is no authenticated REST API client, OAuth token management, or true cloud sync.
   - **No Cryptographic Security for Backups:** Database and JSON exports are written in plaintext. Sensitive financial and travel geolocations are vulnerable if files are stored on unencrypted external media.

4. **UI/UX Ergonomics & Accessibility Deficits:**
   - **Immersive Sticky Mode Usability Penalty:** `main.dart` configures `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`, permanently concealing the Android system status bar (clock, battery) and navigation gesture bars. For a utility application opened frequently at fuel pumps, this creates significant friction.
   - **Tabular Data Density (`AllDataPage`):** History is displayed inside a horizontal-scrolling `DataTable` wrapped in nested scroll views. On modern 360–400dp mobile screens, horizontal panning is clumsy, column alignment wraps awkwardly, and search/filter capabilities (date range, fuel type) are absent.
   - **Form Calculation Lock Inflexibility:** `AddDataPage` hardcodes a circular listener (`Rate + Paid -> Volume` or `Volume + Rate -> Paid`). Users who know their total payment and dispensed volume cannot automatically derive the pump price rate without manual calculation.
   - **Accessibility & Dynamic Color Edge Cases:** The Monet dark theme implementation in `theme.dart` forces `primary: Color(0xFF22484e)` over Android 12+ wallpaper dynamic colors, partially negating Material You personalization. Certain badge chips use fixed color shades (`Colors.green.shade50`) that violate WCAG 2.1 AA contrast ratios in dark mode.

---

### 1.3 Architecture Audit Scorecard

```
+----------------------------------------------------------------------------------------------------+
|                                    COMPREHENSIVE AUDIT SCORECARD                                   |
+------------------------+--------+------------------------------------------------------------------+
| Metric                 | Grade  | Key Evaluation Findings                                          |
+------------------------+--------+------------------------------------------------------------------+
| Domain Mathematics     | A+     | Flawless full-to-full math, weighted averages, and anomaly logic |
| Data Safety & Integrity| A-     | Atomic transactions, foreign key enforcement; lacks DB indexes  |
| Platform & Permissions | B+     | Scoped storage compliant; missing camera & app shortcuts        |
| Visual Analytics & BI  | D      | Completely absent; lacks interactive charts and trendlines       |
| State Management       | D+     | Fragmented setState(); no reactive streams or caching            |
| UI Ergonomics & M3     | B-     | Good M3 card baseline; penalized by sticky mode & wide table     |
| Cloud & Sync Pipelines | F      | Pseudo cloud folder pickers; unversioned & unencrypted exports   |
| Extensibility (EV/TCO) | C-     | Rigidly petrol/diesel focused; no EV kWh, tires, or non-fuel TCO |
+------------------------+--------+------------------------------------------------------------------+
| OVERALL ARCHITECTURE   | B-     | Structurally solid core requiring modern architectural evolution |
+------------------------+--------+------------------------------------------------------------------+
```

---

## 2. Prioritized Roadmap Matrix

The matrix below organizes all planned modernization initiatives by impact, engineering complexity, target release milestone, and priority tier.

| ID | Feature / Improvement | Impact | Effort | Target Milestone | Priority Tier | Primary Modules Affected |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **STA-01** | **Reactive State Management Migration (Riverpod)** | High | L | v3.1.0 | **Tier 1** | Entire App, Database, Providers |
| **DAT-01** | **SQLite Indexing & Schema v9 Migration** | High | S | v3.1.0 | **Tier 1** | `DatabaseHelper.dart`, Models |
| **EXP-01** | **Resilient Export/Import v2 (Validation & Parity)**| High | M | v3.1.0 | **Tier 1** | `ExportPage`, `ImportPage`, CSV |
| **UXX-01** | **Remove Immersive Sticky Mode & Fix Monet Colors** | Med | S | v3.1.0 | **Tier 1** | `main.dart`, `theme.dart` |
| **UXX-02** | **Refuel Form UX (Bidirectional Lock & Auto-Next)** | High | M | v3.1.0 | **Tier 1** | `AddDataPage`, Form Widgets |
| **ANA-01** | **Interactive Fuel Trend & Price Analytics (`fl_chart`)**| High | M | v3.2.0 | **Tier 2** | `DashboardPage`, New Analytics |
| **REP-01** | **Printable PDF Tax & Fleet Expense Reports** | High | M | v3.2.0 | **Tier 2** | `ExportPage`, `pdf`, `printing` |
| **HST-01** | **Card/List View, Date Filters & Search in History**| High | M | v3.2.0 | **Tier 2** | `AllDataPage`, Search Filters |
| **TCO-01** | **Multi-Category Non-Fuel Expense Tracker** | High | M | v3.2.0 | **Tier 2** | DB, Models, `DashboardPage` |
| **SEC-01** | **Client-Side Encrypted Automated Cloud Backups** | High | L | v3.3.0 | **Tier 2** | Storage, WebDAV, Google Drive |
| **OCR-01** | **Receipt & Odometer OCR Vision Pipeline** | High | L | v3.3.0 | **Tier 2** | `AddDataPage`, ML Kit, Camera |
| **WGT-01** | **App Shortcuts & Home Screen Quick-Fill Widget** | Med | M | v3.3.0 | **Tier 2** | Android Native, `home_widget` |
| **INT-01** | **Multi-Currency & International Unit Engine** | Med | M | v3.4.0 | **Tier 3** | AppSettings, Calculator, UI |
| **FLT-01** | **Tire Life, Tread Depth & Rotation Tracker** | Med | M | v3.4.0 | **Tier 3** | Maintenance, DB, UI |
| **EVV-01** | **Electric Vehicle (BEV/PHEV) Energy & Charging** | Med | L | v3.4.0 | **Tier 3** | Models, Calculator, FuelTypes |
| **TAB-01** | **Adaptive Master-Detail Layouts (Tablet/Foldable)**| Low | M | v3.5.0 | **Tier 3** | Responsive Layouts, Navigation |

---

## 3. Detailed Technical Specifications

---

### 3.1 Rich Analytics & Interactive Data Visualization

#### Problem Statement & Rationale
Currently, `DashboardPage` only displays numeric summary cards (`Running Average`, `Last Time Mileage`, `Cost Per Km`, `City/Highway Mileage`). Users cannot observe long-term trends, seasonal efficiency degradation, fuel price inflation, or station quality variance over time. Introducing visual telemetry empowers drivers to optimize driving habits and identify cost drains.

#### Proposed Architecture & Packages
- **Charting Package:** `fl_chart: ^0.70.2` (Hardware-accelerated, high-performance canvas rendering with smooth pinch-to-zoom and cursor touch tooltips).
- **Architecture:** Dedicated `AnalyticsService` extracting time-bucketed datasets from `MileageCalculator`. Clean separation of raw database entities from aggregated charting data points (`FlSpot`, `BarChartGroupData`).

```
+----------------------------------------------------------------------------------------------------+
|                                    ANALYTICS DATA PIPELINE                                         |
+---------------------+      +---------------------+      +-------------------+      +---------------+
| SQLite Database     | ---> | MileageCalculator   | ---> | AnalyticsService  | ---> | FL Chart UI   |
| (Raw Fuel Records)  |      | (Interval Math)     |      | (Bucketing & Agg) |      | (Line/Bar/Pie)|
+---------------------+      +---------------------+      +-------------------+      +---------------+
```

#### Detailed Feature Specifications

##### A. Multi-Series Fuel Price Fluctuation Over Time
- **Chart Type:** `LineChart`.
- **X-Axis:** Refuel Date (Time scale formatted as `MMM yyyy` or `dd MMM`).
- **Y-Axis:** Price per unit of volume (e.g., $ rate/L).
- **Features:** 
  - Dual line series for bi-fuel vehicles (e.g., Octane vs CNG).
  - 30-day moving average trendline overlay to smooth out micro-fluctuations.
  - Interactive tooltip showing refueling location name, volume bought, and total expenditure.

##### B. Rolling Mileage vs. Fuel Station Efficiency
- **Chart Type:** Combined Scatter Plot & Station Variance Bar Chart.
- **Metric:** Compares interval efficiency ($E_{\text{interval}}$) of each fill against the all-time vehicle average ($E_{\text{running}}$), color-coded by station flag status (Amber for Suspect Quality, Green for High Efficiency, Neutral for Normal).
- **Insight:** Highlights stations consistently delivering $>10\%$ below running average.

##### C. Total Cost of Ownership (TCO) Monthly/Annual Breakdown
- **Chart Type:** Stacked `BarChart`.
- **Bars:** Grouped by Month or Year.
- **Segments:**
  - Segment 1 (Primary Fuel Cost)
  - Segment 2 (Secondary Fuel Cost, if bi-fuel)
  - Segment 3 (Periodic Maintenance & Parts: Engine Oil, Filters, Servicing)
  - Segment 4 (Non-Fuel Expenses: Tolls, Parking, Insurance, Taxes)
- **Top Summary:** Total Cost per Kilometer ($\text{TCO} / \text{Total Distance}$).

##### D. Carbon Footprint & Environmental Impact
- **Metric:** Computed $\text{CO}_2$ emissions ($kg$) based on fuel volume and standardized emission coefficients:
  $$\text{CO}_{2\text{ Gasoline}} = V_{\text{litres}} \times 2.31\text{ kg/L}$$
  $$\text{CO}_{2\text{ Diesel}} = V_{\text{litres}} \times 2.68\text{ kg/L}$$
  $$\text{CO}_{2\text{ CNG}} = V_{\text{m}^3} \times 2.75\text{ kg/m}^3$$
  $$\text{CO}_{2\text{ LPG}} = V_{\text{litres}} \times 1.51\text{ kg/L}$$
- **UI:** Visual gauge displaying monthly emissions with comparison to vehicle class averages ($g\text{ CO}_2/\text{km}$).

##### E. Driving Condition Impact Analytics
- **Chart Type:** Grouped Bar / Radar Chart showing consumption rates ($L/100\text{km}$ or $km/L$) segregated by City, Highway, and Mixed conditions.
- **Insight:** Exact monetary cost penalty of heavy city traffic vs highway cruising.

#### UI/UX Flow & Screen Mockup Description
- **Location:** New bottom-navigation tab or top-level dashboard tab: `Analytics`.
- **Time Filter Chips:** `[1 Month]`, `[3 Months]`, `[6 Months]`, `[1 Year]`, `[All Time]`, and `[Custom Range]`.
- **Vehicle Selector:** Dropdown chip anchored to top app bar.
- **Interactions:** Horizontal scrubbing along line charts triggers a floating tooltip chip highlighting exact dates, costs, and fuel stations. Tap on a point allows direct navigation to that fuel record's edit bottom sheet.

#### Implementation Checklist & Acceptance Criteria
- [ ] Add `fl_chart` to `pubspec.yaml`.
- [ ] Implement `AnalyticsService` with bucketing algorithms (Daily, Weekly, Monthly).
- [ ] Implement `PriceTrendChartWidget`, `TcoStackedBarWidget`, and `ConditionDeltaWidget`.
- [ ] Integrate emission math into `MileageCalculator.calculateCarbonFootprint()`.
- [ ] **Acceptance Criteria:** Chart renders 500+ data points smoothly at 60 FPS without UI jank; handles single-record or zero-record edge cases gracefully with informative empty illustrations.

---

### 3.2 Enterprise-Grade Data Pipeline, Reporting & Cloud Sync

#### Problem Statement & Rationale
Vehicle expense logs are essential for business tax write-offs, fleet expense reimbursements, and private resale value verification. The current plain CSV export lacks PDF formatting, lacks schema versioning, silently drops newly added relational fields, and offers no genuine encrypted cloud backup.

#### Proposed Architecture & Packages
- **PDF Generation & Native Printing:** `pdf: ^3.11.1`, `printing: ^5.13.2`.
- **Client-Side AES-256 Encryption:** `encrypt: ^5.0.3`, `crypto: ^3.0.6`.
- **Cloud Storage API Clients:** Direct HTTPS REST clients for Google Drive App Data Folder and WebDAV / Nextcloud.

```
+----------------------------------------------------------------------------------------------------+
|                                    BACKUP & EXPORT ARCHITECTURE                                    |
+---------------------+                                                                              |
| App Local State     |                                                                              |
| (SQLite + ShPref)   |                                                                              |
+----------+----------+                                                                              |
           |                                                                                         |
           v                                                                                         |
+---------------------+       +-------------------------+       +----------------------------------+ |
| Serialization Engine| ----> | JSON Bundle (v2 Schema) | ----> | AES-256-GCM Encryption Pipeline  | |
+---------------------+       +-------------------------+       +-----------------+----------------+ |
                                                                                  |                  |
           +----------------------------------------------------------------------+                  |
           |                                                                                         |
           v                                                                                         v
+---------------------+                                                       +--------------------+ |
| Local File Export   |                                                       | Cloud Backup Sync  | |
| (.ftbackup / .zip)  |                                                       | (WebDAV / GDrive)  | |
+---------------------+                                                       +--------------------+ |
+----------------------------------------------------------------------------------------------------+
```

#### Detailed Feature Specifications

##### A. PDF Tax & Fleet Expense Reports
- **Document Structure:**
  - Header: Application logo, report generation date, report interval, vehicle license plate/name, initial and final odometer, and total distance traveled.
  - KPI Summary Block: Total Fuel Volume, Total Fuel Spend, Total Maintenance Spend, Overall Mileage, and Average Cost/km.
  - Vector Efficiency Chart: Embedded high-resolution vector chart of monthly fuel expenses.
  - Itemized Refueling Table: Date, Odometer, Delta km, Fuel Type, Station Name, Rate, Volume, Total Cost, Receipt Attached (Yes/No).
  - Itemized Maintenance Table: Date, Odometer, Workshop Name, Tasks Executed, Parts/Oil Brand ("Mobil"), Incurred Cost.
- **Export Options:** Direct native print spooling (`Printing.layoutPdf`) or PDF document sharing (`SharePlus`).

##### B. Resilient CSV & JSON Import/Export Pipeline (v2 Schema)
- **JSON Unified Backup Schema (`schema_version: 2`):**
  ```json
  {
    "schema_version": 2,
    "app_version": "3.1.0",
    "export_timestamp": "2026-11-06T12:00:00Z",
    "device_info": "Pixel 9 Pro",
    "vehicles": [...],
    "fuel_types": [...],
    "fuel_records": [...],
    "maintenance_tasks": [...],
    "service_sessions": [...],
    "service_session_items": [...],
    "saved_locations": [...],
    "non_fuel_expenses": [...],
    "app_settings": {...}
  }
  ```
- **CSV Exporter Parity Update:**
  Include all modern fields in `refuel_records.csv`:
  `Date,Odometer,Vehicle,Fuel Type,Price Rate,Volume,Paid Amount,Full Tank,Missed Previous,Trip Distance,Secondary Trip Distance,Driving Condition,Location Name,Latitude,Longitude`
- **Import Dry-Run Preview Modal:**
  Before mutating SQLite tables, the importer executes a dry run:
  - Validates schema format and checks data types.
  - Detects duplicate records using a composite deterministic hash:
    $$H = \text{SHA256}(\text{vehicleId} + \text{date} + \text{odometer} + \text{volume})$$
  - Displays summary dialog: *"Found 120 records (115 new, 5 duplicates)"*.
- **Conflict Resolution Selector:**
  - `Skip Duplicates`: Preserves existing database rows.
  - `Overwrite Existing`: Updates existing rows matching composite keys.
  - `Merge / Import All`: Force imports as new entries.

##### C. Client-Side Encrypted Automated Backups
- **Security:** AES-256-GCM authenticated encryption. Key derived from a user master password using PBKDF2 with SHA-256 (100,000 iterations and a random 16-byte salt stored in the file header).
- **Storage Providers:**
  - **Local Storage:** Scoped cache export (`.ftbackup`).
  - **WebDAV / Nextcloud:** Standard HTTP Basic Auth against user-provided Nextcloud/ownCloud endpoints.
  - **Google Drive:** Dedicated App Data folder (`drive.appdata` scope). Completely isolated from normal user drive files; cannot read or tamper with user personal documents.
- **Automation:** Scheduled background sync triggered weekly or after every 3 refuels via `workmanager` or periodic alarms.

#### Implementation Checklist & Acceptance Criteria
- [ ] Add `pdf`, `printing`, `encrypt`, and `crypto` to `pubspec.yaml`.
- [ ] Implement `PdfReportGenerator` generating Material-themed A4/Letter documents.
- [ ] Upgrade CSV export/import parsers to include all location and trip fields.
- [ ] Implement `BackupEncryptionService` with AES-256-GCM and PBKDF2.
- [ ] Implement `GoogleDriveSyncService` and `WebDavSyncService`.
- [ ] **Acceptance Criteria:** Successfully export and re-import a complete dataset across Android devices with 0 data loss; import validates corrupted files and rolls back cleanly without partial table corruption.

---

### 3.3 Receipt & Image Attachments with On-Device OCR

#### Problem Statement & Rationale
Manual entry of odometer numbers, price rates, volume, and total amounts while standing at a noisy fuel pump is prone to human error and friction. Drivers often take photos of receipts or dispenser LCD meters intending to log them later. Providing on-device image capture with OCR eliminates manual data entry while maintaining 100% privacy.

#### Proposed Architecture & Packages
- **Image Capture & Picking:** `image_picker: ^1.1.2`.
- **Image Compression & Resizing:** `flutter_image_compress: ^2.3.0`.
- **On-Device Computer Vision / OCR:** `google_mlkit_text_recognition: ^0.14.0` (Offline, privacy-preserving, runs locally on Neural Networks API / GPU).

```
+----------------------------------------------------------------------------------------------------+
|                                    OCR & ATTACHMENT PIPELINE                                       |
+-------------------+      +-------------------------+      +--------------------------------------+ |
| Camera / Gallery  | ---> | flutter_image_compress  | ---> | App Sandboxed Storage                | |
| (Raw 12MP Photo)  |      | (Resize 1080p, WebP)    |      | (/attachments/fuel_rec_102.webp)     | |
+-------------------+      +-------------------------+      +--------------------------------------+ |
                                       |                                                             |
                                       v                                                             |
                           +-------------------------+                                               |
                           | ML Kit Text Recognition |                                               |
                           +------------+------------+                                               |
                                        |                                                            |
                                        v                                                            |
                           +-------------------------+                                               |
                           | Regex & Semantic Parser |                                               |
                           +------------+------------+                                               |
                                        |                                                            |
         +------------------------------+------------------------------+                             |
         |                              |                              |                             |
         v                              v                              v                             |
+-----------------+            +------------------+           +------------------+                   |
| Odometer Field  |            | Fuel Rate Field  |           | Dispensed Volume |                   |
+-----------------+            +------------------+           +------------------+                   |
+----------------------------------------------------------------------------------------------------+
```

#### Detailed Feature Specifications

##### A. Scoped Storage & Thumbnail Strategy
- **File System Structure:** Attachments are stored within the app’s sandboxed documents directory under `attachments/`:
  - Full-resolution compressed image: `attachments/refuel_<id>_<uuid>.webp` (max dimension 1920px, 85% quality, EXIF stripped for privacy).
  - Thumbnail: `attachments/thumbs/refuel_<id>_<uuid>_thumb.webp` (max dimension 240px).
- **Database Linking:** Add relative paths `receiptImagePath TEXT` and `odometerImagePath TEXT` to `fuel_records` and `invoiceImagePath TEXT` to `service_sessions`.
- **Backup Archive Support:** Full backup archives bundle these attachments into a single compressed `.zip` archive alongside the JSON manifest.

##### B. ML Kit OCR Parsing Engine
- **Target Surfaces:**
  1. Fuel Dispenser LCD Displays (litres, rate, total price).
  2. Paper Fuel Receipts.
  3. Vehicle Instrument Cluster (digital or mechanical odometers).
- **Heuristic Regex Extraction Pipeline:**
  - **Odometer Recognition:** Searches for digit blocks near tokens like `ODO`, `TOTAL`, `km`, `mi`:
    ```dart
    final odoRegex = RegExp(r'(?:ODO|TOTAL|KM)?\s*([0-9]{3,7}(?:\.[0-9])?)', caseSensitive: false);
    ```
  - **Volume Recognition:** Searches for volume indicators:
    ```dart
    final volRegex = RegExp(r'([0-9]{1,4}\.[0-9]{2})\s*(?:L|Ltr|Gal|m3)', caseSensitive: false);
    ```
  - **Price / Rate Recognition:** Extracts currency blocks and unit rates ($/L):
    ```dart
    final rateRegex = RegExp(r'(?:Rate|Price|Unit)[\s:]*([0-9]{1,4}\.[0-9]{2})', caseSensitive: false);
    final totalRegex = RegExp(r'(?:Total|Paid|Amount|Net)[\s:]*([0-9]{1,5}\.[0-9]{2})', caseSensitive: false);
    ```

##### C. Interactive OCR Verification UX
- **Scanning Camera Sheet:** A modal view showing live camera feed or captured image with highlighted bounding boxes around detected text blocks.
- **Suggestion Chips:** Beneath the image preview, recognized values appear as clickable action chips:
  `[Odo: 48,250 km]`, `[Vol: 34.50 L]`, `[Total: $62.10]`, `[Rate: $1.80/L]`.
- **One-Tap Population:** Tapping a chip populates the respective form field. Tapping an unknown number allows the user to assign it via a popup: *"Use as: [Odometer] [Volume] [Rate] [Total Cost]"*.

#### Implementation Checklist & Acceptance Criteria
- [ ] Add `image_picker`, `flutter_image_compress`, and `google_mlkit_text_recognition` to `pubspec.yaml`.
- [ ] Add `CAMERA` permission to `AndroidManifest.xml` and iOS `Info.plist` with clear rationale strings.
- [ ] Implement `OcrVisionService` with regex heuristics for dispensers, odometers, and paper slips.
- [ ] Build `ReceiptCameraModal` widget with interactive bounding box tap selection.
- [ ] Add thumbnail previews in `AddDataPage` and `AllDataPage` with full-screen zoomable lightbox.
- [ ] **Acceptance Criteria:** Successfully extracts volume and total cost from standard pump displays with $\ge 85\%$ accuracy in varying daylight/night lighting conditions; gracefully handles non-receipt images without crashing.

---

### 3.4 Modern Mobile Integration & Ergonomic UI/UX Refactor

#### Problem Statement & Rationale
The application is used frequently on the road. The existing interface suffers from several ergonomic limitations:
1. `SystemUiMode.immersiveSticky` permanently hides the OS status bar.
2. The form calculation logic has circular dependencies.
3. Lack of quick home-screen entry forces drivers to launch the app, wait for ad configuration checks, and tap multiple navigation steps.
4. Tabular data on mobile displays requires awkward horizontal scrolling.

#### Detailed Feature Specifications

##### A. Immediate Usability & Theme Fixes
- **Eliminate Sticky Immersive Mode:**
  Replace `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` in `main.dart` with standard edge-to-edge transparent system bars:
  ```dart
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  ```
- **Monet Dynamic Color Compliance:**
  Update `theme.dart` so `getMonetDarkTheme` and `getLightTheme` do NOT overwrite `primary` with hardcoded `Color(0xFF22484e)` when dynamic color schemes are available from the operating system.

##### B. Bidirectional Refuel Form UX with Calculation Locks
- **Problem:** Currently, entering `Rate` and `Paid Amount` calculates `Volume`. Entering `Volume` and `Rate` calculates `Paid Amount`. If the user has `Volume` and `Paid Amount` from a receipt, they cannot automatically derive `Rate`.
- **Solution:** Add an explicit **Calculation Target Toggle** (Lock Mode):
  - `[Lock Volume]`: User inputs Rate & Paid $\rightarrow$ Volume auto-calculates.
  - `[Lock Paid Amount]`: User inputs Volume & Rate $\rightarrow$ Paid auto-calculates.
  - `[Lock Rate / Unit Price]`: User inputs Volume & Paid $\rightarrow$ Rate auto-calculates.
- **Form Keyboard Auto-Progression:**
  Configure all numeric inputs with `textInputAction: TextInputAction.next` and automatic `FocusNode.requestFocus()` progression, allowing users to enter data rapidly with one hand.

##### C. Dynamic App Shortcuts & Home Screen Widget
- **Android App Shortcuts (`quick_actions` or native Android shortcuts):**
  Long-pressing the app icon exposes two immediate launcher shortcuts:
  1. `Log Refuel`: Directly opens `AddDataPage` for the active default vehicle.
  2. `Log Service`: Directly opens `MaintenancePage` with the service logging dialog.
- **Home Screen Quick Widget (`home_widget: ^0.7.1`):**
  Material 3 Glance-based Android widget displaying:
  - Default vehicle name and visual fuel level gauge.
  - Estimated Distance to Empty (DTE) in kilometers.
  - Quick action button `[+]` launching directly into the refuel log.

##### D. Redesigned History View (`AllDataPage`)
- **Card-List View by Default:** Replace the rigid horizontal `DataTable` with an ergonomic card-based timeline on mobile devices ($<600\text{dp}$ width).
- **Timeline Card Anatomy:**
  - Header: Refueling date, days elapsed badge, and station name.
  - Central Stat: Large odometer reading, accompanied by interval mileage badge ($\text{km/L}$) highlighted in soft green/amber depending on performance.
  - Sub-Metrics: Volume dispensed, price rate, total paid amount, driving condition icon (`🏙️`, `🛣️`, `🔄`).
  - Action Strip: Quick Edit, Delete, and View Receipt buttons.
- **Filter & Search Bar:** Top expandable search bar supporting:
  - Text search across station names and notes.
  - Date range filtering (`This Month`, `Last 3 Months`, `Custom`).
  - Fuel type selector chips for bi-fuel vehicles.

##### E. Tablet, Foldable & Desktop Adaptive Layouts
- Use `LayoutBuilder` to detect screen width $>720\text{dp}$.
- Render an adaptive **Master-Detail Two-Pane Layout**:
  - Left Pane (40% width): Vehicle selector, timeline history list, and quick action FAB.
  - Right Pane (60% width): Persistent record details, interactive telemetry graphs, and maintenance status cards.

#### Implementation Checklist & Acceptance Criteria
- [ ] Update `main.dart` to `SystemUiMode.edgeToEdge`.
- [ ] Refactor `theme.dart` to honor wallpaper-derived dynamic colors.
- [ ] Implement locked calculation modes in `AddDataPage`.
- [ ] Add `quick_actions` and configure dynamic launcher shortcuts.
- [ ] Rebuild `AllDataPage` with adaptive Card-List layout, search bar, and filter chips.
- [ ] **Acceptance Criteria:** Single-handed data entry takes $<15$ seconds at the pump; system status bar remains visible; desktop/tablet displays clean two-pane layout without horizontal table clipping.

---

### 3.5 Advanced Vehicle & Fleet Features

#### Problem Statement & Rationale
Modern vehicles increasingly utilize alternative powertrains (BEVs, PHEVs) and require maintenance tracking beyond basic fluids (specifically tire tread wear, tire rotations, and general fleet operating costs). FuelTracker must broaden its domain models to accommodate these automotive systems.

#### Detailed Feature Specifications

##### A. Electric Vehicle (BEV) & Plug-in Hybrid (PHEV) Support
- **Vehicle Powertrain Classification:**
  Extend `VehicleType` or add `PowertrainType`: `ice` (Internal Combustion), `bev` (Battery Electric Vehicle), `phev` (Plug-in Hybrid), `hybrid` (HEV).
- **Energy Metric Models:**
  - Battery capacity in kilowatt-hours ($kWh$).
  - Charging events log:
    - Odometer reading.
    - Starting State of Charge ($SoC_{\text{start}} \%$) $\rightarrow$ Ending State of Charge ($SoC_{\text{end}} \%$).
    - Energy added ($kWh$) and charging power rate ($kW$).
    - Charging tier: AC Level 1, AC Level 2 (Home Wallbox), or DC Fast Charging.
    - Total charging session cost.
- **Efficiency Metric:** Automatically computes $kWh/100\text{km}$ or $km/kWh$ (equivalent to $km/L$), alongside cost per kilometer.
- **Battery Degradation Tracker:** Tracks nominal usable capacity over lifetime odometer mileage.

##### B. Comprehensive Tire Life, Tread Wear & Rotation Tracker
- **Data Models:**
  - SQLite table `tires`: Tracks brand, model, size, DOT manufacture code, purchase date, and initial tread depth ($mm$).
  - SQLite table `tire_logs`: Tracks individual axle positions (`FL`, `FR`, `RL`, `RR`), tread depth measurements across outer/center/inner grooves, and rotation timestamps.
- **Predictive Rotation Reminders:** Recommends tire rotation every 8,000–10,000 km based on vehicle drive type (FWD, RWD, AWD).
- **Tread Life Forecast:** Projects remaining tire life in kilometers before reaching the legal wear limit ($1.6\text{ mm}$ or $2/32"$).

##### C. Multi-Currency & International Travel Engine
- **Foreign Currency Refueling:**
  Allows entering refuel expenses in foreign currencies (e.g., EUR, INR, USD, BDT) while traveling across borders.
- **Conversion Math:** Stores transaction currency code, exchange rate to vehicle base currency, and converted base cost:
  $$\text{Cost}_{\text{base}} = \text{Cost}_{\text{foreign}} \times \text{ExchangeRate}$$
- **Exchange Rate Sources:** User-specified rate or optional offline cached ECB/central bank exchange rates.

---

### 3.6 Reactive Architecture & State Management Migration

#### Problem Statement & Rationale
Currently, state is trapped inside individual widget states. Migrating to a modern reactive state architecture resolves data desynchronization, eliminates redundant database reads, and makes the application fully unit-testable.

#### Proposed Architecture: `flutter_riverpod`
- **Dependency:** `flutter_riverpod: ^2.6.1`.
- **Repository Pattern:** Wrap `DatabaseHelper` inside pure Dart repositories (`VehicleRepository`, `FuelRecordRepository`, `MaintenanceRepository`).
- **Reactive Invalidation:** When a record is inserted, modified, or deleted, Riverpod providers automatically invalidate and push updated streams to all listening UI widgets.

```dart
// Example Architecture:
final vehicleListProvider = AsyncNotifierProvider<VehicleNotifier, List<Vehicle>>(VehicleNotifier.new);

final activeVehicleIdProvider = StateProvider<int?>((ref) => null);

final fuelRecordsProvider = StreamProvider.autoDispose.family<List<FuelRecord>, int>((ref, vehicleId) {
  final repository = ref.watch(fuelRecordRepositoryProvider);
  return repository.watchRecordsForVehicle(vehicleId);
});

final vehicleAnalyticsProvider = Provider.autoDispose.family<VehicleAnalytics, int>((ref, vehicleId) {
  final records = ref.watch(fuelRecordsProvider(vehicleId)).value ?? [];
  return MileageCalculator.computeFullAnalytics(records);
});
```

#### Database Schema Evolution: Migration to Version 9
To support the specifications above, execute non-destructive additive DDL migrations in `DatabaseHelper._onUpgrade()`:

```sql
-- Migration Step: v8 -> v9
-- 1. Indexing for Query Performance
CREATE INDEX IF NOT EXISTS idx_fuel_records_vehicle_date ON fuel_records(vehicleId, date);
CREATE INDEX IF NOT EXISTS idx_fuel_records_odometer ON fuel_records(odometer);
CREATE INDEX IF NOT EXISTS idx_service_sessions_vehicle ON service_sessions(vehicleId, serviceDate);
CREATE INDEX IF NOT EXISTS idx_saved_locations_coords ON saved_locations(latitude, longitude);

-- 2. Image Attachments & Multi-Currency Support
ALTER TABLE fuel_records ADD COLUMN receiptImagePath TEXT;
ALTER TABLE fuel_records ADD COLUMN odometerImagePath TEXT;
ALTER TABLE fuel_records ADD COLUMN currencyCode TEXT DEFAULT 'BDT';
ALTER TABLE fuel_records ADD COLUMN exchangeRateToBase REAL DEFAULT 1.0;

-- 3. EV & Alternative Powertrain Support
ALTER TABLE fuel_records ADD COLUMN energyKwh REAL;
ALTER TABLE fuel_records ADD COLUMN socStart REAL;
ALTER TABLE fuel_records ADD COLUMN socEnd REAL;
ALTER TABLE service_sessions ADD COLUMN invoiceImagePath TEXT;

-- 4. Non-Fuel Expense Tracking
CREATE TABLE IF NOT EXISTS non_fuel_expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicleId INTEGER NOT NULL,
  date TEXT NOT NULL,
  odometer REAL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  currencyCode TEXT DEFAULT 'BDT',
  notes TEXT,
  receiptImagePath TEXT,
  FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
);

-- 5. Tire Management System
CREATE TABLE IF NOT EXISTS tires (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicleId INTEGER NOT NULL,
  brand TEXT NOT NULL,
  model TEXT,
  size TEXT NOT NULL,
  dotCode TEXT,
  installedOdo REAL NOT NULL,
  installedDate TEXT NOT NULL,
  currentTreadDepthMm REAL,
  isArchived INTEGER DEFAULT 0,
  FOREIGN KEY (vehicleId) REFERENCES vehicles (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tire_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tireId INTEGER NOT NULL,
  date TEXT NOT NULL,
  odometer REAL NOT NULL,
  position TEXT NOT NULL,
  treadDepthMm REAL,
  notes TEXT,
  FOREIGN KEY (tireId) REFERENCES tires (id) ON DELETE CASCADE
);
```

---

## 4. UI/UX Refinement Checklist

A structured punch list of design, accessibility, and micro-interaction improvements:

### Micro-Interactions & Motion
- [ ] **Fluid Animated Counters:** Implement `AnimatedFlipCounter` or implicit tween animations on dashboard statistics (`Running Average`, `Cost/km`, `Total Spend`) when switching vehicles.
- [ ] **Tactile Haptic Feedback:** Trigger `HapticFeedback.lightImpact()` on form submission, `selectionClick()` on segmented button toggles, and `mediumImpact()` on deleting records.
- [ ] **Smooth Transition Routes:** Implement Material 3 Shared Axis (`SharedAxisPageRoute`) transitions between the Dashboard, Add Data, and Analytics screens.

### Design System & Theme Adaptability
- [ ] **Pure Material 3 Card Elevation:** Reduce default card elevation from heavy `6.0` to Material 3 standard `1.0` or `2.0`, relying on tonal surface tinting (`surfaceContainerHighest`) for depth.
- [ ] **True Dynamic Monet Harmony:** Ensure dynamic colors harmoniously tint all neutral surfaces and cards rather than overriding them with fixed dark teal constants.
- [ ] **High-Contrast Pure Black Theme (OLED):** Ensure the `black` theme provides true `#000000` background surfaces with high-contrast borders for battery savings on OLED panels.

### Accessibility (a11y) & Usability
- [ ] **Text Scaling Protection:** Wrap custom header layouts in `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.35)` to prevent overflow on devices configured with extra-large system accessibility fonts.
- [ ] **Screen Reader Semantics:** Add `Semantics(label: ..., button: true)` tags to all icon buttons, anomaly warning badges, and custom progress indicators.
- [ ] **WCAG 2.1 AA Contrast Ratios:** Eliminate hardcoded color combinations (e.g., light green chip on white card) and strictly use `Theme.of(context).colorScheme` color pairings (`colorScheme.onErrorContainer` on `colorScheme.errorContainer`).

### Error Recovery & Empty States
- [ ] **Friendly Empty State Art:** Replace blank screens or raw progress spinners with vector illustrations and actionable guidance (e.g., *"No fuel records yet. Tap '+' to record your first fill-up!"*).
- [ ] **Form Auto-Recovery & Draft State:** Persist unsubmitted refuel form inputs into a temporary draft buffer in `SharedPreferences` so accidental app backgrounding never loses entered odometer numbers.

---

## 5. Security, Backup & Data Privacy Standards

Because FuelTracker collects sensitive location telemetry, financial expenditure logs, and travel timestamps, the platform must uphold rigorous data privacy and cryptographic standards.

### 5.1 Scoped Storage & Sandbox Isolation
- **Zero Legacy Permissions:** The app must never request `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, or `MANAGE_EXTERNAL_STORAGE`. All file creations remain strictly within app-internal directories:
  - Cache operations: `getTemporaryDirectory()` (auto-cleansed by OS under memory pressure).
  - Persistent attachments: `getApplicationDocumentsDirectory()/attachments/`.
- **System Share Sheet Dispatch:** Staged exports dispatch solely through standard platform contracts (`share_plus: SharePlus.instance.share(ShareParams(...))`).

### 5.2 Cryptographic Standards for Cloud & File Backups
- **Symmetric Encryption Cipher:** AES-256 in GCM (Galois/Counter Mode) providing authenticated encryption with associated data (AEAD). This ensures backups cannot be decrypted or tampered with.
- **Key Derivation Function (KDF):** User passwords must pass through PBKDF2 using HMAC-SHA256:
  - Salt: Cryptographically secure random 16-byte salt generated per export.
  - Iteration Count: Minimum 100,000 rounds.
- **Zero Cloud Metadata Exposure:** When syncing to Google Drive or WebDAV, backup filenames are pseudonymized (e.g., `ft_backup_6a1f8b4.enc`), and file contents are encrypted prior to network transmission.

### 5.3 Camera & Photo Privacy
- **Metadata Sanitization (EXIF Stripping):** Snapped receipt photos frequently contain embedded GPS coordinates, camera serial numbers, and capture timestamps in EXIF tags. The compression pipeline (`flutter_image_compress`) must strip all EXIF metadata before saving to disk.
- **Zero Third-Party Telemetry:** No user-uploaded receipts or odometer images may be transmitted to cloud OCR APIs. All computer vision processing must execute 100% on-device via `google_mlkit_text_recognition`.

### 5.4 Battery-Efficient GPS Geofencing
- **Zero Continuous Background Tracking:** FuelTracker must never run persistent background location tracking services.
- **On-Demand Ephemeral Fixes:** Location is queried strictly on form initialization (`LocationAccuracy.high` with a 5-second timeout). Once a single coordinate fix is obtained to match nearby `saved_locations` within 80 meters, the GPS hardware is immediately powered down to protect battery life.

---

## 6. Implementation Phasing & Milestones

```
+----------------------------------------------------------------------------------------------------+
|                                    IMPLEMENTATION TIMELINE                                         |
+----------------------------------------------------------------------------------------------------+
| MILESTONE 1 (v3.1.0) - Core Architecture & Form Ergonomics                                         |
| [X] Remove Immersive Sticky Mode & Fix Dynamic Theming                                             |
| [ ] SQLite Schema v9 Migration (Indexes + Image Paths + Currency)                                  |
| [ ] Bidirectional Form Calculation Locks in AddDataPage                                            |
| [ ] CSV & JSON Exporter Full-Parity & Dry-Run Validation                                            |
| [ ] Migrate Core State to Riverpod Repositories & Providers                                        |
+----------------------------------------------------------------------------------------------------+
| MILESTONE 2 (v3.2.0) - Visual Analytics & Fleet Reporting                                          |
| [ ] Interactive FL Chart Integration (Price Trends, Rolling Mileage, Station Scatter)             |
| [ ] Total Cost of Ownership (TCO) & Non-Fuel Expense Logging Module                                |
| [ ] Carbon Footprint Estimation Engine                                                             |
| [ ] Printable PDF Tax & Fleet Expense Reports (pdf / printing)                                    |
| [ ] AllDataPage Card-List Redesign with Date Filters & Search                                      |
+----------------------------------------------------------------------------------------------------+
| MILESTONE 3 (v3.3.0) - Vision OCR & Automated Cloud Sync                                           |
| [ ] On-Device ML Kit OCR for Pump Meters, Odometers & Receipts                                     |
| [ ] Scoped Image Storage & Compression Pipeline (WebP)                                             |
| [ ] Encrypted Automated Backups (AES-256-GCM + PBKDF2)                                              |
| [ ] Google Drive AppData & WebDAV Sync Providers                                                   |
| [ ] Android App Shortcuts & Home Screen Glance Widget                                              |
+----------------------------------------------------------------------------------------------------+
| MILESTONE 4 (v3.4.0) - Alternative Powertrains & Fleet Operations                                  |
| [ ] Battery Electric Vehicle (BEV) kWh & Charging Session Tracker                                  |
| [ ] Tire Lifecycle, Tread Depth Wear & Rotation Reminder Module                                    |
| [ ] Multi-Currency Transaction Engine with Offline Conversion                                      |
| [ ] Adaptive Two-Pane Master-Detail Layout for Tablets & Foldables                                  |
+----------------------------------------------------------------------------------------------------+
```

---
*Authored by the Principal Mobile Architect & Automotive Software Engineer for `pollob666/fueltracker`.*
