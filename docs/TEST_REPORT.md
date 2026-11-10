# Comprehensive Mobile App User-Testing & Architecture Audit Report: FuelTracker (`v3.5.0+1`)

**Date of Execution:** November 9, 2026  
**Test Harness & Method:** Autonomous ADB UI Automation on Physical Hardware + White-Box Static/Runtime Code Audit  
**Target Device:** Xiaomi Redmi Note 13 Pro 5G (`garnet_global` / model `2312DRA50G`, serial `4a327342`)  
**OS Version:** Android 17 (API Level 36, Architecture: `arm64-v8a`)  
**Display Matrix:** Native $1220 \times 2712$ (480 DPI), Tablet Override $1600 \times 2560$ (240 DPI / $1066\text{ dp}$), Font Scale $1.0\times$ & $1.6\times$ ($1.35\times$ clamped)  
**Database Schema:** Version 11 (SQLite with `PRAGMA foreign_keys = ON`, composite indexes, encrypted `.ftbackup` archives)  
**Package ID:** `com.pollob666.fueltracker`

---

## 1. Executive Summary

FuelTracker (`v3.5.0+1`) was subjected to an end-to-end mobile user-testing campaign on physical Android 17 hardware via `adb`, paired with a white-box code and mathematical audit against [README.md](file:///home/andalib/src/fueltracker/README.md), [AGENTS.md](file:///home/andalib/src/fueltracker/docs/AGENTS.md), and [IMPROVEMENTS.md](file:///home/andalib/src/fueltracker/docs/IMPROVEMENTS.md).

Across **26 captured high-resolution hardware screenshots**, the application demonstrated zero fatal exceptions, zero `RenderFlex` layout overflows under $1.6\times$ accessibility font scaling, smooth Material 3 `NavigationRail` master-detail adaptation at $\ge 720\text{ dp}$, and accurate Full-to-Full running average mileage ($\frac{\sum \Delta O}{\sum V} = 14.00\text{ km/L}$).

Crucially, combining live ADB telemetry inspection with source-level verification exposed **5 high-impact mathematical and relational bugs** and **6 UX/architectural gaps** that were invisible to superficial UI smoke tests:
1. ** CRIT-01 — Post-Baseline Volume & Cost Double-Counting in `AnalyticsService.computeConditionDelta`:** Includes the initial baseline fill's volume ($30\text{ L}$) and cost ($3900\text{ BDT}$) when `interval.distance == 0`, halving reported condition mileage from $14.00\text{ km/L}$ to **$7.00\text{ km/L}$** and doubling condition cost/km to **$18.57\text{ BDT/km}$**.
2. ** CRIT-02 — Pre-Filtered Interval Distortion in `MileageCalculator.calculateConditionAverage`:** Filters records by `DrivingCondition` *before* calling `calculateIntervalResults`, causing odometer deltas across mixed-condition fills to be attributed to a single condition (or returning `0.0` when a condition has only 1 fill after a baseline).
3. ** CRIT-03 — Baseline Denominator Mismatch in `Cost per km`, `Carbon g/km`, and `TCO Cost/km`:** Sums fuel spend ($7800\text{ BDT}$) and $\text{CO}_2$ ($138.6\text{ kg}$) across *all* records (including the baseline fill at $O_0 = 10,000\text{ km}$), then divides by post-baseline distance ($\Delta O = 420\text{ km}$), doubling per-km fuel cost ($18.57$ vs $9.29\text{ BDT/km}$) and emission intensity ($330$ vs $165\text{ g CO}_2/\text{km}$).
4. ** CRIT-04 — Foreign Key Column Typo in `UnifiedBackupService.executeImport` (`copyMergeAll`):** Attempts to remap `row['fuelTypeId']` instead of `row['primaryFuelTypeId']` and `row['secondaryFuelTypeId']` on `vehicles`, and omits `taskId` remapping on `service_session_items`.
5. ** CRIT-05 — Orphaned Attachment Files & Incomplete Explicit Cascade in `DatabaseHelper.deleteVehicleCascade`:** Deletes `fuel_records` and `vehicles` in SQLite, but does not delete associated receipt/odometer/invoice image files from `app_flutter/attachments/` via `AttachmentService`.

---

## 2. Complete 52-Feature Test Matrix (Live ADB + Code Audit)

| ID | Phase & Feature | Verification Method | Observed Result / Finding | Status |
| :--- | :--- | :--- | :--- | :---: |
| **F-01** | First-run welcome screen & empty DB state | Live ADB (`01_welcome_onboarding.png`) | Welcoming prompt displayed; telemetry cards hidden until vehicle added | **PASS** |
| **F-02** | Edge-to-edge system UI (`SystemUiMode.edgeToEdge`) | Live ADB (`01`–`26`) | System status bar (clock, battery) & gesture bar remain visible | **PASS** |
| **F-03** | GitHub release check dialog (`VersionService`) | Live ADB (`10_update_available_dialog.png`) | Non-blocking dialog (`v3.5.1+2`) with `Skip this version`, `Later`, `Update` | **PASS** |
| **F-04** | Single-fuel ICE vehicle creation (*"Toyota"*) | Live ADB (`02_dashboard_first_vehicle.png`) | Created Car/Sedan with Octane, `km`, `L`, `km/L`, `BDT` | **PASS** |
| **F-05** | BEV electric vehicle creation (*"BYD EV"*) | Live ADB (`05_manage_vehicles_bev.png`) | Created BEV with `60.5 kWh` battery pack, `km • km/kWh` badge | **PASS** |
| **F-06** | 2-wheel Motorcycle creation (*"Yamaha Bike"*) | Live ADB & Code (`vehicle.dart`, `maintenance_page.dart`) | Created Motorcycle class; Tire Wear / Tires tab & dashboard schematic excluded for 2-wheelers (`supportsTireTracking == false`) | **PASS (UPDATED)** |
| **F-07** | Bi-Fuel ICE vehicle (`Octane` + `CNG`) & secondary trip | Code Audit (`add_vehicle_page.dart`, `add_data_page.dart`) | Supported via `_isDualFuel`, `secondaryFuelTypeId`, and `secondaryTripDistance` | **AUDIT PASS** |
| **F-08** | Sole-vehicle deletion safeguard | Live ADB (`04_manage_vehicles.png`) | Blocks deletion with SnackBar: *"Cannot delete the only remaining vehicle"* | **PASS** |
| **F-09** | Default vehicle switching & badge chips | Live ADB (`04`, `05`) | `Default Vehicle` chip & `Set as Default` button function properly | **PASS** |
| **F-10** | Atomic vehicle cascade deletion (`deleteVehicleCascade`) | Unit Test & Code (`database_helper.dart`) | SQLite transaction cascades child rows and deletes physical attachment files via `AttachmentService` | **PASS (FIXED)** |
| **F-11** | Bidirectional Lock 1: `Rate × Volume → Paid` | Live ADB (`08_calc_lock_paid_verified.png`) | `130.00 × 30.00 = 3900.00 BDT` auto-computed & locked | **PASS** |
| **F-12** | Bidirectional Lock 2: `Paid ÷ Rate → Volume` | Code Audit (`add_data_page.dart:531-560`) | `_CalcTarget.volume` computes `paid / rate` when Rate > 0 | **AUDIT PASS** |
| **F-13** | Bidirectional Lock 3: `Paid ÷ Volume → Rate` | Code Audit (`add_data_page.dart:531-560`) | `_CalcTarget.rate` computes `paid / volume` when Volume > 0 | **AUDIT PASS** |
| **F-14** | Form auto-recovery draft buffer (`draft_refuel_*`) | Live ADB & Code (`add_data_page.dart:230-253`) | Restored `10420` odo & `130` rate across app relaunch (`14:02` resume) | **PASS** |
| **F-15** | Trip meter mode & sticky `Save` bar (`AddVehiclePage` / `AddDataPage`) | Live ADB (`test_screen_add_data_opened.png`, `test_screen_add_vehicle_validation.png`) | Sticky `Save` button in `bottomNavigationBar` (`SafeArea`) with validation SnackBar & inline field errors | **PASS (FIXED)** |
| **F-16** | Trip discrepancy warning chip ($|\Delta O - \text{Trip}| > 1\text{ km}$) | Code Audit (`add_data_page.dart:883-912`) | Shows non-blocking `ActionChip` and `Icons.sync` button for $O = O_{\text{prev}} + \text{Trip}$ | **AUDIT PASS** |
| **F-17** | Backward odometer soft confirmation safeguard | Live ADB (`12_odometer_anomaly_safeguard_dialog.png`) | Entering `9900 km` against `10000 km` triggers `AlertDialog` safeguard | **PASS** |
| **F-18** | Full-to-Full running average ($\frac{\sum \Delta O}{\sum V}$) | Live ADB (`20_dashboard_with_record2_mileage.png`) | `10000 km` $\to$ `10420 km` (`420 km`) / `30.00 L` = **`14.00 km/L`** exact | **PASS** |
| **F-19** | Partial fill accumulation (`isFullTank = false`) | Code Audit (`mileage_calculator.dart:112-165`) | Accumulates `pendingPartialVolume` until next full tank completes cycle | **AUDIT PASS** |
| **F-20** | Missed previous fill baseline reset (`missedPrevious`) | Code Audit (`mileage_calculator.dart:59-80`) | Discards pending partials, suppresses invalid mileage, resets baseline | **AUDIT PASS** |
| **F-21** | $>15\%$ mileage anomaly & $N-1$ station attribution | Code Audit (`mileage_calculator.dart:449`, `analytics_service.dart:233`) | Correctly attributes interval $N$ fuel quality to station at fill $N-1$ (`sorted[i - 1]`) | **AUDIT PASS** |
| **F-22** | Predictive refuel reminders (Volume & DTE sliders) | Live ADB (`02`, `EditVehiclePage` dump) | Dual sliders (`Primary Fuel Volume` & `DTE`) + `calculateRefuelPrediction` | **PASS** |
| **F-23** | EV charging form morphing (`Start/End SoC %`, `kW`) | Code Audit (`add_data_page.dart:102-104`) | Morphs form when `_isBev` or `_canChargeElectric` is true | **AUDIT PASS** |
| **F-24** | Multi-currency foreign refuel (`exchangeRateToBase`) | Code Audit (`fuel_record.dart`, `add_data_page.dart`) | Computes `basePaidAmount = paidAmount * exchangeRateToBase` | **AUDIT PASS** |
| **F-25** | Conditional `Maintenance` drawer visibility | Live ADB (`test_screen_drawer.png`) & Code (`drawer_widget.dart`) | `ConsumerStatefulWidget` watches `hasEnabledRoutinesProvider`; dynamically hides/shows item | **PASS (FIXED)** |
| **F-26** | Periodic maintenance health progress cards | Live ADB (`25_maintenance_tires_schematic.png`) | Displays task health or empty state when no tasks enabled on selected vehicle | **PASS** |
| **F-27** | One-tap `Quick Done` maintenance reset | Code Audit (`dashboard_page.dart:341-382`) | Resets `lastServiceOdo` & `lastServiceDate` and reschedules notifications | **AUDIT PASS** |
| **F-28** | Multi-task `Log Service Visit` & session CRUD | Code Audit (`maintenance_page.dart`) | Supports item-level oil/part brand (`"Mobil"`), workshop, Edit/Delete bottom sheet | **AUDIT PASS** |
| **F-29** | Interactive Tire Schematic (4-wheel car vs 2-wheel bike) | Live ADB (`25_maintenance_tires_schematic.png`) | Renders interactive chassis visualizer in `MaintenancePage` & tablet right pane | **PASS** |
| **F-30** | Tire tread wear rate ($\text{mm}/1000\text{ km}$) & rotation | Code Audit (`tire_calculator.dart`) | Projects legal wear limit ($1.6\text{ mm}$) and $>10,000\text{ km}$ rotation alerts | **AUDIT PASS** |
| **F-31** | Non-fuel expense logging (`AddExpenseBottomSheet`) | Live ADB UI & Code (`dashboard_page.dart:1271`, `analytics_page.dart:122`) | Accessible from both Dashboard `[Expense]` button and TCO card `[Add Expense]` | **PASS** |
| **F-32** | TCO Stacked Bar Chart (`TcoStackedBarWidget`) | Live ADB (`test_screen_analytics.png`) | Renders `Total Spend: 7800 BDT` & post-baseline `All-Inclusive Cost: 9.29 BDT/km` | **PASS (FIXED)** |
| **F-33** | Fuel Price Trend Chart & 30-day moving average | Live ADB (`22_analytics_with_records.png`) | Renders rate line + moving average + Dashboard 64dp `MiniTelemetrySparklineWidget` | **PASS** |
| **F-34** | Station Efficiency Scatter Plot ($\pm 15\%$ bands) | Live ADB (`test_screen_analytics_bottom.png`) | Plots `#1` at `14.0 km/L` against `14.00 km/L` running average with dynamic units | **PASS** |
| **F-35** | Driving Condition Impact Bar (`ConditionImpactBarWidget`) | Live ADB (`test_screen_analytics_bottom.png`) | Excludes baseline anchor; reports `Mixed: 14.00 km/L`, `BDT9.29 /km`, `1 fills` | **PASS (FIXED)** |
| **F-36** | Carbon Footprint Card (`CarbonFootprintCardWidget`) | Live ADB (`test_screen_analytics_bottom.png`) | Total `138.6 kg` ($60\text{ L}$), `7 saplings`, post-baseline rate **`165 g/km`** over `420 km` | **PASS (FIXED)** |
| **F-37** | Chart spot tap-to-inspect & `[Edit This Refuel Record]` | Code Audit (`analytics_page.dart:271-369`) | Opens modal bottom sheet with Volume, Rate, Paid, Odo, and Edit button | **AUDIT PASS** |
| **F-38** | Time window filter chips + `[Custom Range]` picker | Live ADB (`22_analytics_with_records.png`) | `1 Month`, `3 Months`, `6 Months`, `1 Year`, `All Time`, `Custom Range` | **PASS** |
| **F-39** | Redesigned `AllDataPage` timeline cards & Table toggle | Live ADB (`21_all_data_timeline.png`) | Timeline cards with station name, interval badge, search bar, and filter chips | **PASS** |
| **F-40** | On-device ML Kit OCR (`OcrVisionService`) & Lightbox | Live ADB UI (`07`) & Code (`ocr_vision_service.dart`, `attachment_service.dart`) | `Receipt / Pump` & `Odometer Gauge` buttons + scoped attachment management | **PASS** |
| **F-41** | GPS 80m auto-clustering & Saved Locations manager | Live ADB (`18`, `19_saved_locations_unnamed_cluster.png`) | Clustered `(23.7721, 90.3802)` within 80m; toggleable `Show Unnamed` chip | **PASS** |
| **F-42** | Printable PDF Tax & Fleet Report (`PdfReportGenerator`) | Live ADB UI (`14_export_screen_overview.png`) & Code (`pdf_report_generator.dart`) | `Preview / Print PDF` & `Share PDF` buttons wired to A4 multi-page generator | **PASS** |
| **F-43** | Legacy CSV export & dry-run SHA-256 import parity | Live ADB UI (`13`, `14`) & Code (`export_page.dart`, `import_page.dart`) | Exports refueling, service, locations, and vehicles with sequence numbering | **PASS** |
| **F-44** | Unified Single-File JSON v3.5.0 backup & SAF / WebDAV | Live ADB (`13`, `14`) & Code (`unified_backup_service.dart`) | Category checkboxes + SAF + WebDAV; `copyMergeAll` remaps `primaryFuelTypeId`, `secondaryFuelTypeId`, `taskId` | **PASS (FIXED)** |
| **F-45** | Client-side AES-256-CBC + PBKDF2 `.ftbackup` vault | Live ADB (`15_create_encrypted_backup_dialog.png`) | 100,000-iteration PBKDF2-HMAC-SHA256 modal with password confirmation | **PASS** |
| **F-46** | Periodic headless backup (`WorkManagerBackupService`) | Code Audit (`workmanager_backup_service.dart`) | Revolving 7-file retention in `/Backups/` + optional WebDAV upload | **AUDIT PASS** |
| **F-47** | Tablet Master-Detail layout ($\ge 720\text{ dp}$) | Live ADB (`24_tablet_master_detail.png`) | `1600x2560 @ 240dpi` renders `NavigationRail` + 5:6 split Left/Right panes | **PASS** |
| **F-48** | Accessibility $1.6\times$ font scaling ($1.35\times$ clamp) | Live ADB (`26_font_scale_clamped.png`) | `font_scale 1.6` clamped cleanly at `1.35x` with zero `RenderFlex` overflows | **PASS** |
| **F-49** | Dynamic theming (`Light`, `Monet Dark`, `Black`) & L10n | Live ADB (`test_screen_dashboard_scrolled.png`) | Dynamic `UnitConverter` units (`km/L`, `L`, `BDT/km`) & dark-mode-safe `ColorScheme` tokens | **PASS (FIXED)** |
| **F-50** | In-App Purchase Ad-Free unlock (`InAppPurchaseService`) | Live ADB (`17_iap_ad_free_activated.png`) | Sandbox bypass activates `Ad-Free License Active` chip and suppresses AdMob | **PASS** |
| **F-51** | Android Glance Home Widget & Launcher Quick Actions | Code Audit (`home_widget_service.dart`, `app_shortcuts_service.dart`) | Broadcasts `FuelTrackerGlanceWidget` prefs & registers 3 launcher shortcuts | **AUDIT PASS** |
| **F-52** | Android 17 (API 36) SELinux & R8 ProGuard rules | Live ADB & Code (`proguard-rules.pro`, `build.gradle`) | API 36 blocks `run-as`; R8 rules retain WorkManager, Room, ML Kit, AdMob | **PASS** |

---

## 3. Root-Cause Analysis of Discovered Bugs & Architectural Gaps

### 3.1 [CRIT-01] `AnalyticsService.computeConditionDelta` Double-Counts Baseline Fill Volume & Cost
- **Location:** [`lib/services/analytics_service.dart`](file:///home/andalib/src/fueltracker/lib/services/analytics_service.dart#L255-L322)
- **Root Cause:** `MileageCalculator.calculateIntervalResults(sorted)` returns an `IntervalResult` for **every** record in `sorted`, including the very first baseline full-tank record where `distance = 0.0`, `consumedVolume = record.volume` ($30.0\text{ L}$), and `isValidFullTank = false`. In `computeConditionDelta`, the loop iterates over all `intervals` unconditionally:
  ```dart
  for (final interval in intervals) {
    final record = interval.record;
    final distance = interval.distance;       // 0.0 for baseline record!
    final volume = interval.consumedVolume;   // 30.0 L for baseline record!
    final cost = record.paidAmount;           // 3900 BDT for baseline record (also ignores basePaidAmount)!
  ```
- **Observed Impact on Device (`23_analytics_station_variance_carbon.png`):** With Record 1 ($10,000\text{ km}$, $30\text{ L}$, $3900\text{ BDT}$, `Mixed`) and Record 2 ($10,420\text{ km}$, $30\text{ L}$, $3900\text{ BDT}$, `Mixed`), `mixedDistance` = $420\text{ km}$, `mixedVolume` = $60\text{ L}$, `mixedCost` = $7800\text{ BDT}$, producing **`7.00 km/L`** (instead of **`14.00 km/L`**) and **`BDT 18.57 /km`** (instead of **`BDT 9.29 /km`**).

### 3.2 [CRIT-02] `MileageCalculator.calculateConditionAverage` Pre-Filters Records Before Interval Calculation
- **Location:** [`lib/utils/mileage_calculator.dart`](file:///home/andalib/src/fueltracker/lib/utils/mileage_calculator.dart#L258-L261)
- **Root Cause:**
  ```dart
  static double calculateConditionAverage(List<FuelRecord> records, DrivingCondition condition) {
    final filtered = records.where((r) => r.drivingCondition == condition).toList();
    return calculateWeightedRunningAverage(filtered);
  }
  ```
  Filtering `records` by `condition` *before* computing odometer intervals causes `calculateIntervalResults` to subtract `baselineRecord.odometer` of an earlier matching-condition fill across any intervening fills of other conditions (e.g., subtracting a City fill at $10,000\text{ km}$ from a City fill at $11,000\text{ km}$ even though a Highway fill occurred at $10,600\text{ km}$). Furthermore, if the baseline fill was `Mixed` and the second fill was `City`, `filtered` for `City` has length `1`, returning `0.0`!
- **Required Fix:** Compute `calculateIntervalResults(records)` on the full chronological sequence first, then sum `distance` and `consumedVolume` for intervals where `item.isValidFullTank && item.record.drivingCondition == condition`.

### 3.3 [CRIT-03] Post-Baseline Rate Mismatch in `calculateCostPerKm`, `calculateCarbonFootprint`, and `tcoOverviewProvider`
- **Locations:**
  - [`lib/utils/mileage_calculator.dart`](file:///home/andalib/src/fueltracker/lib/utils/mileage_calculator.dart#L209-L218) (`calculateCostPerKm`)
  - [`lib/utils/mileage_calculator.dart`](file:///home/andalib/src/fueltracker/lib/utils/mileage_calculator.dart#L511-L577) (`calculateCarbonFootprint`)
  - [`lib/providers/non_fuel_expense_providers.dart`](file:///home/andalib/src/fueltracker/lib/providers/non_fuel_expense_providers.dart) (`tcoOverviewProvider`)
- **Root Cause:** Total Spend ($7800\text{ BDT}$) and Total $\text{CO}_2$ ($138.6\text{ kg}$ from $60\text{ L}$) rightly sum all purchased fuel. However, dividing two fills' worth of cost/emissions by a single interval's distance ($\Delta O = 420\text{ km}$) overstates per-km running cost and $\text{CO}_2/\text{km}$ by $100\%$ on a 2-record dataset. Per-km intensity metrics (`costPerKm`, `gramsCo2PerKm`) must use post-baseline interval fuel cost and post-baseline interval $\text{CO}_2$ over post-baseline distance.

### 3.4 [CRIT-04] `UnifiedBackupService.executeImport` Foreign Key Remapping Bugs in `copyMergeAll` Mode
- **Location:** [`lib/services/unified_backup_service.dart`](file:///home/andalib/src/fueltracker/lib/services/unified_backup_service.dart#L317-L340)
- **Root Cause:**
  1. Line 317 checks `row['fuelTypeId']` on `vehicles`, whereas the `vehicles` table schema uses `primaryFuelTypeId` and `secondaryFuelTypeId`.
  2. Lines 328–340 insert `maintenance_tasks` without recording `oldTaskId -> newTaskId`, so `service_session_items.taskId` (lines 423–435) points to stale task IDs in `copyMergeAll` mode.
  3. Line 106 hardcodes `currentAppVersion = "3.3.0"` instead of `"3.5.0"`.

### 3.5 [CRIT-05] Orphaned Scoped Attachments on Vehicle / Record Deletion
- **Locations:** [`lib/database/database_helper.dart`](file:///home/andalib/src/fueltracker/lib/database/database_helper.dart#L596-L618) & [`lib/services/attachment_service.dart`](file:///home/andalib/src/fueltracker/lib/services/attachment_service.dart)
- **Root Cause:** When deleting a vehicle (`deleteVehicleCascade`) or deleting individual fuel/service/expense records, image files referenced by `receiptImagePath`, `odometerImagePath`, and `invoiceImagePath` are not deleted from `app_flutter/attachments/`, leaking storage and bundling orphaned photos into subsequent backups.

### 3.6 [UX-01 to UX-04] Form Ergonomics, Reactive Drawer, Unit Formatting & Dark-Mode Contrast
- **UX-01 (`AddVehiclePage` & `AddDataPage` Save Button):** `Save` sits inside the scroll view below `y = 2490px`. If a field at the top fails validation, tapping `Save` gives no `SnackBar` or auto-scroll feedback.
- **UX-02 (`MyDrawer` Stale Maintenance Visibility):** [`MyDrawer`](file:///home/andalib/src/fueltracker/lib/widgets/drawer_widget.dart#L20-L45) is a `StatefulWidget` that queries `hasAnyEnabledRoutine()` once in `initState()`.
- **UX-03 (`DashboardPage` Hardcoded Units & Currencies):** Lines 837, 987, 1097, 1107, 1219, 1308, 1318, 1430–1457, and 1856 in [`lib/pages/dashboard_page.dart`](file:///home/andalib/src/fueltracker/lib/pages/dashboard_page.dart) hardcode `'km/l'`, `'BDT/km'`, `'km/day'`, `'BDT/day'`, `'litres'`, `'BDT'`, `'km'`, and `'BDT/litre'` instead of formatting with `UnitConverter` and `selectedVehicle.baseCurrency`.
- **UX-04 (Hardcoded Light Shades on Banners):** `_buildMileageAnomalyCard` (lines 773–776), `_buildMaintenanceWarningBanner` (lines 1786–1792), and `_buildTireAlertBanner` (lines 1971–1973) use `Colors.green.shade50` / `Colors.amber.shade100` in dark/black themes instead of adaptive `ColorScheme` containers.

---

## 4. Prioritized Improvements Recommendation Roadmap

| ID | Priority | Category | Recommendation | Target Files |
| :--- | :---: | :--- | :--- | :--- |
| **IMP-01** | **P0 (Critical)** | Domain Math | Fix post-baseline interval math in `computeConditionDelta`, `calculateConditionAverage`, `calculateCostPerKm`, `calculateCarbonFootprint`, and `tcoOverviewProvider` while keeping `Total Spend` and `Total CO2` as all-record sums | `mileage_calculator.dart`, `analytics_service.dart`, `non_fuel_expense_providers.dart` |
| **IMP-02** | **P0 (Critical)** | Data Integrity | Fix `primaryFuelTypeId`/`secondaryFuelTypeId` and `taskId` remapping in `UnifiedBackupService.executeImport` (`copyMergeAll`), bump `currentAppVersion` to `"3.5.0"`, and purge orphaned attachments in `deleteVehicleCascade` | `unified_backup_service.dart`, `database_helper.dart`, `attachment_service.dart` |
| **IMP-03** | **P1 (High)** | Unit Engine & A11y | Replace all remaining hardcoded `'BDT'`, `'km/l'`, `'litres'`, `'km'` strings in `DashboardPage` with `UnitConverter` + `selectedVehicle` units, and replace hardcoded `Colors.green.shade50`/`Colors.amber.shade100` banner colors with dark-mode-safe `ColorScheme` tokens | `dashboard_page.dart`, `unit_converter.dart` |
| **IMP-04** | **P1 (High)** | Form UX | Move `Save` button to sticky `bottomNavigationBar` (`SafeArea`) in `AddVehiclePage` and `AddDataPage`, add validation failure `SnackBar` + scroll-to-top/invalid field, and add $\pm 10\%$ Y-axis padding on single-point `fl_chart` widgets | `add_vehicle_page.dart`, `add_data_page.dart`, `price_trend_chart.dart`, `station_efficiency_scatter.dart` |
| **IMP-05** | **P2 (Medium)** | Reactive State & Privacy | Convert `MyDrawer` to `ConsumerStatefulWidget` watching a reactive `hasEnabledRoutinesProvider` (invalidated on vehicle/task save), and add WebP compression (`1920px`, `85%`) + EXIF stripping in `AttachmentService` via `flutter_image_compress` | `drawer_widget.dart`, `vehicle_providers.dart`, `attachment_service.dart`, `pubspec.yaml` |
| **IMP-06** | **P2 (Medium)** | Automated Tests | Add comprehensive unit test suite covering post-baseline math (`MileageCalculator`, `AnalyticsService`), multi-condition interval attribution, and `UnifiedBackupService` validation/remap logic | `test/mileage_calculator_test.dart`, `test/analytics_service_test.dart` |

---

## 5. Photographic Evidence Index (26 Captures)

All 26 screenshots captured from `adb -s 4a327342` are archived in `/home/andalib/.gemini/antigravity/brain/8ed95f6b-f815-4907-a4d6-3dc63e2c0846/reports_artifacts/`:
1. `01_welcome_onboarding.png` — First-run welcome screen & edge-to-edge status bar.
2. `02_dashboard_first_vehicle.png` — Initial dashboard with Vehicle 1 (*"Toyota"*).
3. `03_navigation_drawer.png` — Navigation drawer with conditional Maintenance hiding.
4. `04_manage_vehicles.png` — Manage Vehicles default badge & sole-vehicle deletion guard.
5. `05_manage_vehicles_bev.png` — Battery Electric Vehicle (*"BYD EV"*, `km • km/kWh`).
6. `06_analytics_empty_state.png` — Visual Analytics informative empty states.
7. `07_refuel_form_initial.png` — Refuel entry form with GPS auto-detect & condition chips.
8. `08_calc_lock_paid_verified.png` — Bidirectional lock (`130 × 30 = 3900.00 BDT`).
9. `09_analytics_tco_populated.png` — TCO stacked bar & price trend after Record 1.
10. `10_update_available_dialog.png` — GitHub release check dialog (`Skip`, `Later`, `Update`).
11. `11_dashboard_with_record1.png` — Baseline record dashboard state.
12. `12_odometer_anomaly_safeguard_dialog.png` — Backward odometer (`9900 < 10000 km`) soft confirmation dialog.
13. `13_import_screen_clean.png` — Executive Import screen (Single JSON v2 & CSV).
14. `14_export_screen_overview.png` — Export screen (Single JSON v2, SAF, WebDAV, CSV, PDF).
15. `15_create_encrypted_backup_dialog.png` — AES-256-CBC + PBKDF2 `.ftbackup` encryption modal.
16. `16_settings_screen.png` — Global fallback units, currency, storage, language, themes.
17. `17_iap_ad_free_activated.png` — In-App Purchase `Ad-Free License Active` state.
18. `18_saved_locations_screen.png` — Saved Locations manager (`Fuel Stations` / `Workshops`).
19. `19_saved_locations_unnamed_cluster.png` — 80m GPS auto-clustered station `(23.7721, 90.3802)`.
20. `20_dashboard_with_record2_mileage.png` — Full-to-Full `14.00 km/L` running average & mini sparkline.
21. `21_all_data_timeline.png` — Redesigned `AllDataPage` timeline cards with `14.0 km/L` badge.
22. `22_analytics_with_records.png` — Populated TCO (`7800 BDT`) & Octane price trend chart.
23. `23_analytics_station_variance_carbon.png` — Station scatter (`14.0 km/L`), Condition Impact (`7.00 km/L` bug), Carbon Footprint (`138.6 kg`).
24. `24_tablet_master_detail.png` — Tablet `1600x2560 @ 240dpi` `NavigationRail` + dual-pane Master-Detail.
25. `25_maintenance_tires_schematic.png` — Maintenance & Tires screen on tablet layout.
26. `26_font_scale_clamped.png` — Accessibility `font_scale 1.6` clamped cleanly at `1.35x`.

---

## 6. Post-Implementation Verification Results (Fresh Build + Live ADB + 181 Unit Tests)

Following the implementation of `IMP-01` through `IMP-06` and resolution of `CRIT-01` through `CRIT-05`, a fresh debug APK (`build/app/outputs/flutter-apk/app-debug.apk`) was compiled and deployed to the physical Xiaomi Redmi Note 13 Pro 5G (`4a327342`) via `adb install -r`, accompanied by the full automated test suite (`181/181` passing tests, `0` analyzer errors).

| Defect / Item | Pre-Fix Behavior | Post-Fix Verified Result | Evidence | Status |
| :--- | :--- | :--- | :--- | :---: |
| **CRIT-01** (`computeConditionDelta`) | `Mixed: 7.00 km/L`, `BDT 18.57 /km`, `2 fills` (included baseline anchor) | `Mixed: 14.00 km/L`, `BDT9.29 /km`, `1 fills` (baseline anchor excluded, `consumedCost` accumulated) | `scratch/test_screen_analytics_bottom.png` | **VERIFIED** |
| **CRIT-02** (`calculateConditionAverage`) | Filtered records prior to interval computation, distorting odometer deltas | Computes `calculateIntervalResults` on full chronological sequence first before filtering by condition | `test/mileage_calculator_test.dart` | **VERIFIED** |
| **CRIT-03** (`Cost/km`, `TCO Cost/km`, `CO2 g/km`) | `18.57 BDT/km` & `330 g/km` (divided 2-fill cumulative totals by 1-interval distance) | Cumulative totals preserved (`7800 BDT`, `138.6 kg CO2`); intensity rates report **`9.29 BDT/km`** and **`165 g/km`** over `420 km` | `scratch/test_screen_dashboard_scrolled.png`, `scratch/test_screen_analytics.png` | **VERIFIED** |
| **CRIT-04** (`UnifiedBackupService.copyMergeAll`) | Checked obsolete `fuelTypeId` and omitted `maintenance_tasks` / `service_session_items` FK remapping | Remaps `primaryFuelTypeId`, `secondaryFuelTypeId`, and `maintenanceTaskIdMap` (`taskId`); version bumped to `3.5.0` | `lib/services/unified_backup_service.dart` | **VERIFIED** |
| **CRIT-05** (`deleteVehicleCascade` attachments) | Left physical receipt/odometer/invoice files orphaned on disk | Queries `sqlite_master`, collects attachment paths across `fuel_records`, `service_sessions`, and `non_fuel_expenses`, and deletes files via `AttachmentService.deleteAttachment` | `test/repositories/vehicle_repository_test.dart`, `test/challenger_cascade_stress_test.dart` | **VERIFIED** |
| **IMP-01 / UX-01** (Sticky Form `Save` Bar) | `Save` button buried inside scroll view at `y = 2577` without validation feedback | Persistent `Scaffold.bottomNavigationBar` inside `SafeArea` on `AddDataPage` and `AddVehiclePage` with validation `SnackBar` and inline error indicators | `scratch/test_screen_add_data_opened.png`, `scratch/test_screen_add_data_keyboard.png`, `scratch/test_screen_add_vehicle_validation.png` | **VERIFIED** |
| **IMP-02 & IMP-03 / UX-03 & UX-04** (Dynamic Units & Dark Contrast) | Hardcoded `'km/l'`, `'litres'`, `'BDT/km'` and light-only banner shades | Dynamic `UnitConverter` units (`km/L`, `30.00 L`, `130.00 BDT/L`, `9.29 BDT/km`) and dark-mode-safe `ColorScheme` tokens | `scratch/test_screen_dashboard_clear.png`, `scratch/test_screen_dashboard_scrolled.png` | **VERIFIED** |
| **IMP-04 / UX-02** (Reactive Drawer Visibility) | `MyDrawer` queried `hasAnyEnabledRoutine()` once in `initState()` | `MyDrawer` converted to `ConsumerStatefulWidget` watching `hasEnabledRoutinesProvider` | `scratch/test_screen_drawer.png` | **VERIFIED** |
| **IMP-06** (Automated Test Suite) | 179 tests (2 legacy tests codified baseline doubling) | **181/181 tests passing**, `0` static analysis errors | `flutter test` (`task-1328`) | **VERIFIED** |
