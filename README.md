# Fuel Tracker

[![Build and Release APK](https://github.com/pollob666/fuel-tracker/actions/workflows/release.yml/badge.svg)](https://github.com/pollob666/fuel-tracker/actions/workflows/release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Fuel Consumption tracker by **[pollob666](https://github.com/pollob666)**

A Flutter-based mobile application to help users track their vehicle's fuel consumption. The app allows users to record refueling data, view their average mileage, and monitor their fuel expenses.

## Download

You can download the latest version of the application from the [GitHub Releases](https://github.com/pollob666/fuel-tracker/releases) page.

## Key Features:

*   **Tire Life, Tread Depth & Rotation Tracker:** Dedicated Tires tab in Maintenance, interactive chassis schematic (4-wheel and 2-wheel), remaining life forecasting based on $\text{mm} / 1000\text{ km}$ wear degradation, remaining legal distance projection (1.6mm legal threshold), rotation presets (FWD, RWD, Directional), and automated dashboard rotation reminder banners.
*   **Multi-Currency & International Unit Engine:** Per-vehicle configuration with global fallback in `AppSettings` for Distance (`km`, `mi`), Fuel Volume (`L`, `gal US`, `gal UK`, `kWh`), Economy Metric (`km/L`, `L/100km`, `MPG US`, `MPG UK`, `km/kWh`), and multi-currency normalization with exchange rate conversions (`exchangeRateToBase`) ensuring consistent Total Cost of Ownership across mixed currencies.
*   **Alternative Powertrain & EV Charging:** Architectural support for ICE, Hybrid, PHEV, and BEV with native `Electricity` fuel type, refuel form morphing (Start/End SoC %, charging speed kW, charging tiers), and zero tailpipe CO2 emission modeling.
*   **Adaptive Master-Detail & Tablet Layout ($\ge 720\text{ dp}$):** Material 3 `NavigationRail` with persistent side navigation on wide displays, dual-pane Master-Detail layout (Left: Vehicle selector, telemetry, alerts, running averages; Right: Trends, daily averages, last refuel details, live tire chassis schematic), and responsive width-constrained form layouts.
*   **Fuel Record Management:** Full CRUD lifecycle support—add, view, edit, and safely delete fuel records directly from the records table with soft anomaly confirmations.
*   **Multi-Vehicle Support:** Add and manage multiple vehicles, each with specific fuel types and capacities, and set a default vehicle for quick data entry.
*   **Immersive User Experience:** Graphical and welcoming prompts for first-time users to guide them through adding their first vehicle and getting started with the app.
*   **Mileage Calculation:** Robust Full-to-Full calculation engine with support for partial fills, missed fill-ups, weighted running average ($\frac{\sum \Delta O}{\sum V}$ avoiding Simpson's Paradox skew), and bi-fuel trip distance recording.
*   **Predictive Refuel Reminders & Range Forecasting:** Dual independent reminders per vehicle (Primary Fuel Volume threshold slider and Combined Distance-to-Empty threshold slider), intelligent Material 3 dashboard card with remaining fuel and range gauges, and scheduled 09:00 AM local Android notifications (`flutter_local_notifications`).
*   **Periodic Maintenance & Service Reminders:** Optional per-task maintenance tracking (Engine Oil, Oil Filter, Air Filter, General Servicing) configured in vehicle settings, visual health progress cards, dual-mode completion (one-tap quick resets or detailed multi-task visit logging with item-level oil ("Mobil") and spare part brand tracking), full history CRUD (Edit/Delete via Bottom Sheet), unified Tasks & Reminders screen, conditional dashboard alert cards with [Do It] and [Mark Done] quick actions, auto-hiding navigation drawer, CSV export/import parity, and scheduled push notifications.
*   **Unified Location Management & Anomaly Flagging:** Always-on GPS capture on refueling and maintenance logging with 80-meter proximity clustering, station naming, and multi-station disambiguation. Automated mileage drop ($>15\%$) and boost ($>15\%$) anomaly detection against weighted historical running averages, interactive attribution candidate diagnostics, return warning badges (Amber ⚠️ Suspect Quality) and recognition badges (Green 🟢 High Efficiency), dedicated Saved Locations manager with unnamed toggle, and full CSV export/import parity.
*   **Advanced Trip Meter & Driving Condition Analytics:** Configurable per-vehicle trip meter mode (None, Single Trip A, Dual Trip A/B), one-tap odometer auto-sync ($O = O_{\text{prev}} + \text{Trip}$), real-time non-blocking discrepancy warning chips ($|\Delta O - \text{Trip}| > 1.0\text{ km}$), driving condition tagging (City, Highway, Mixed), and condition-segregated mileage cards on the dashboard.
*   **Odometer Anomaly Safeguard:** Real-time soft confirmation dialog preventing accidental entries when odometer readings are less than or equal to previous records.
*   **Visual Analytics & Interactive Telemetry:** Dedicated visual telemetry dashboard powered by `fl_chart` with selectable time windows (1M, 3M, 6M, 1Y, All Time). Features multi-series fuel price fluctuation line charts with 30-day moving average smoothing and station attribution tooltips, interval station efficiency variance scatter analysis with ±15% anomaly threshold bands, driving condition consumption and cost segregation (City vs Highway vs Mixed), and carbon footprint calculation with eco-ratings and tree sapling offset equivalents.
*   **Redesigned History & Timeline Cards:** Overhauled `AllDataPage` with ergonomic Material 3 timeline cards, dynamic text search across station names and notes, date filter chips (All Dates, This Month, Last 3 Months, Custom Range), road condition selector chips, and a dual-view mode switcher toggling between timeline cards and classic tabular view.
*   **Non-Fuel Expenses & Total Cost of Ownership (TCO):** Track all non-fuel vehicle expenses (Tolls, Parking, Car Wash, Insurance, Taxes, Fines, Other) with dedicated logging sheets, category chips, and odometer stamps. Visual analytics dashboard renders monthly stacked bar charts decomposing total ownership costs into Fuel, Service, and Non-Fuel expenditures alongside true all-inclusive cost-per-kilometer metrics ($\frac{\text{Fuel} + \text{Service} + \text{NonFuel}}{\sum \Delta O}$).
*   **Printable PDF Tax & Fleet Expense Reports:** Compile audit-ready, high-resolution A4 PDF expense reports formatted for tax write-offs, employer reimbursement, and fleet management logs using `pdf` and `printing`. Reports include executive vehicle summary cards, total ownership cost KPI breakdowns, itemized refueling logs with station attribution, maintenance service history, non-fuel expense breakdowns, and formal driver/auditor verification signature sign-off blocks. Direct preview/print spooling and native share sheet dispatch are supported directly from the Export center.
*   **Scoped Attachments & ML Kit OCR Vision:** Capture and attach photos of fuel dispenser LCDs, paper cash receipts, and odometer instrument clusters using `image_picker` and on-device text recognition with `google_mlkit_text_recognition`. An intelligent regex parser automatically extracts volume (L), unit price (rate), total paid amount, and odometer readings from photo previews with one-tap auto-fill into refueling forms. Attached receipts are safely persisted in app-scoped sandbox storage with interactive full-screen pinch-to-zoom inspection (`ImageLightboxDialog`).
*   **Unified Single-File Backup & Android SAF Cloud Integration:** Single consolidated JSON backup format encapsulating vehicles, fuel types, refuel logs, service records, saved locations, non-fuel expenses, settings, and base64-encoded receipt photo attachments. Directly leverages Android's Storage Access Framework (`DocumentsUI`) to export to or import from Google Drive, Dropbox, Nextcloud, or device storage without proprietary cloud SDKs or paid plugins.
*   **Automated Background Backup (WorkManager):** Headless background backup runner powered by `workmanager` executing periodic backups (configurable frequency: 1, 3, or 7 days, optional Wi-Fi only constraint). Maintains a revolving retention window of the latest 7 local backups in app storage and automatically uploads to configured WebDAV cloud endpoints.
*   **Redesigned Validation Summary Import:** Executive validation dashboard analyzing incoming JSON backups prior to import (displaying vehicle count and names, refuel logs, maintenance sessions, expenses, locations, and settings readiness). Includes granular category checkboxes for selective restoration and transactional conflict resolution strategies: Overwrite Existing (default), Skip Existing, or Copy / Merge All with relational foreign key remapping.
*   **Client-Side Encrypted Backups & WebDAV Cloud Sync:** Secure zero-knowledge backup archives (`.ftbackup`) encrypted client-side using authenticated AES-256-CBC and PBKDF2-HMAC-SHA256 key derivation (100,000 rounds with cryptographically secure random salt and IV). Archives encapsulate complete SQLite relational databases, app settings, and base64-encoded receipt/odometer photo attachments. Built-in WebDAV client enables direct automated connectivity, directory discovery (PROPFIND XML), and backup push/pull to self-hosted Nextcloud, ownCloud, or custom WebDAV endpoints.
*   **Android Quick Actions & Home Screen Glance Widgets:** Instant interaction via Android dynamic launcher shortcuts (`quick_actions`) launching directly into "Log Refuel", "Log Service", or "Analytics" from the home screen icon. Native home screen Glance widget (`home_widget` & Kotlin `AppWidgetProvider`) displays real-time active vehicle telemetry, remaining fuel gauge, distance-to-empty (DTE) projections, odometer reading, and last refuel date with one-tap app launch.
*   **Reactive State Architecture & Riverpod:** Reactive state management powered by `flutter_riverpod` with clean repository abstractions (`VehicleRepository`, `FuelRecordRepository`), decoupling database transactions from presentation and enabling broadcast stream auto-refreshing across dashboards.
*   **Resilient CSV Import/Export & Dry-Run Inspector:** Pre-import dry-run preview modal bottom sheet with SHA-256 fingerprint duplicate detection, conflict resolution strategies (Skip, Overwrite, Merge), and complete attribute parity (Secondary Trip Distance, Driving Condition, Location Name, Coordinates).
*   **Ergonomic Refuel Form & Dynamic System UI:** Fluid edge-to-edge system navigation (`SystemUiMode.edgeToEdge`) preserving Android 12+ Material 3 Monet dynamic color palettes, bidirectional calculation lock toggles (Lock Rate, Lock Volume, Lock Paid Amount), and smooth auto-progression focus navigation.
*   **Data Import/Export & Modern Sharing:** Import and export fuel data and service records in CSV and JSON formats with modern Android Scoped Storage compatibility and system share sheet integration (`share_plus`). Supports optional custom export directories, iPad popover origin safety, full attributes (`Full Tank`, `Missed Previous`, `Trip Distance`, part/oil brands, workshop, cost) with backward compatibility for legacy records, and auto-generated timestamped filenames with sequence numbering.
*   **Dynamic Theming:** Adapts its color scheme to the user's system-level theme on Android for a personalized look and feel. Users can also manually switch between Light, Dark, and System themes.
*   **Localization:** Supports multiple languages through the `intl` package.
*   **Automated CI/CD:** A GitHub Actions workflow automatically builds and releases signed release and debug APKs whenever signed commits by the maintainer are pushed to the `master` branch.
*   **Vehicle Management & Cascade Safeguards:** A dedicated page to list, edit, set a default vehicle, and safely delete vehicles. Deletion is safeguarded by atomic database transactions that cascade delete associated child records, dynamic record-count confirmation dialogs, single-vehicle deletion protection, and automatic fallback for active default vehicles.
*   **Default Fuel Prices:** Set default fuel prices for each fuel type in the settings, which are auto-filled on the “Add Fuel Data” page.
*   **Redesigned Dashboard:** A modern and intuitive dashboard with stylized cards for better visual impact.

## Future Development Plan

The following is a roadmap of planned features to be implemented in the future:

### Advanced Fuel Type Management

*   **Fuel Categories:** Fuel types will be categorized into `Gasoline` (e.g., Petrol, Octane), `Diesel`, and `GAS` (e.g., LPG, CNG).
*   **Customizable Units:** Users will be able to set the measurement unit for each fuel category from the settings.
    *   **Gasoline/Diesel:** Litre (default), Gallon.
    *   **GAS (CNG/LPG):** Litre, Cubic Meter (m³), or Gasoline Gallon Equivalent (GGE).

### Advanced Mileage and Cost Tracking

*   **Per-Fuel Mileage:** For vehicles with multiple fuel types, mileage will be calculated separately for each fuel type.
*   **Overall Mileage:** The app will also provide an overall mileage calculation for multi-fuel vehicles.
*   **Cost-Efficiency Tracking:** A new feature will be added to track and compare the cost-efficiency of different fuel types.

## License

This project is licensed under the **GNU General Public License v3.0**. The full license text can be found in the [LICENSE](LICENSE) file.
