# AGENTS.md: Project Overview and Structure

This document provides a comprehensive overview of the Fuel Tracker application, including its purpose, project structure, key components, and the technologies used. It is intended to serve as a guide for developers and contributors.

## 1. Project Overview

**Fuel Tracker** is a Flutter-based mobile application designed to help users track their vehicle's fuel consumption. The app allows users to record refueling data, view their average mileage, and monitor their fuel expenses. The project is designed to be simple, user-friendly, and theme-aware, adapting to the user's system settings for a more integrated experience.

### Key Features:

*   **Fuel Record Management:** Users can add, view, and manage their fuel records, including odometer readings, fuel volume, and paid amounts.
*   **Multi-Vehicle Support:** Add and manage multiple vehicles, each with specific fuel types and capacities, and set a default vehicle for quick data entry.
*   **Immersive User Experience:** Graphical and welcoming prompts for first-time users to guide them through adding their first vehicle and getting started with the app.
*   **Mileage Calculation:** Robust Full-to-Full calculation engine with support for partial fills, missed fill-ups, weighted running average ($\frac{\sum \Delta O}{\sum V}$ avoiding Simpson's Paradox skew), and bi-fuel trip distance recording.
*   **Predictive Refuel Reminders & Tank Range Forecasting:** Dual independent reminders per vehicle (Primary Fuel Volume threshold slider and Combined Distance-to-Empty threshold slider), intelligent Material 3 dashboard card with remaining fuel and DTE gauges, active threshold badge chips in Vehicle Management, and user-configurable daily Android notifications (`flutter_local_notifications`).
*   **Periodic Maintenance & Service Reminders:** Optional per-task maintenance tracking (Engine Oil, Oil Filter, Air Filter, General Servicing) configured in vehicle settings, visual health progress cards, dual-mode completion (one-tap quick resets or detailed multi-task visit logging with item-level oil ("Mobil") / part brand tracking), full history CRUD (Edit/Delete via Bottom Sheet), unified Tasks & Reminders screen, conditional dashboard alert cards with [Do It] and [Mark Done] quick actions, auto-hiding navigation drawer, CSV export/import parity, and scheduled push notifications.
*   **Unified Location Management & Anomaly Flagging:** Always-on GPS capture on refueling and maintenance entries with 80-meter proximity auto-clustering (`saved_locations`), multi-station disambiguation sheets, and named station tagging. Automated mileage drop ($>15\%$) and boost ($>15\%$) anomaly detection against weighted historical running averages, interactive attribution candidate diagnostics, return warning badges (Amber ⚠️ Suspect Quality) and recognition badges (Green 🟢 High Efficiency), dedicated Saved Locations manager with unnamed toggle, and full CSV import/export parity.
*   **Advanced Trip Meter & Driving Condition Analytics:** Configurable per-vehicle trip meter mode (None, Single Trip A, Dual Trip A/B), one-tap odometer auto-sync ($O = O_{\text{prev}} + \text{Trip}$), real-time non-blocking discrepancy warning chips ($|\Delta O - \text{Trip}| > 1.0\text{ km}$), driving condition tagging (City, Highway, Mixed), and condition-segregated mileage cards on the dashboard.
*   **Odometer Anomaly Safeguard:** Real-time soft confirmation dialog preventing accidental entries when odometer readings are less than or equal to previous records.
*   **Update Reminder & Version Dismissal:** Checks GitHub releases for newer versions on startup and presents an `AlertDialog` with options to update, postpone for the current session ("Later"), or permanently ignore that specific release ("Skip this version") backed by `SharedPreferences`.
*   **Data Import/Export:** Import and export your fuel data and maintenance service records in CSV format, including full attributes (fuel metrics, part/oil brands, workshop, cost) with backward compatibility for legacy records. Exported filenames are automatically generated with the date and a sequence number for easy organization (e.g., `refuel_records_20241028T1200_1.csv`, `service_records_20241028T1200_1.csv`).
*   **Dynamic Theming:** The app uses the `dynamic_color` package to adapt its color scheme to the user's system-level theme on Android, providing a personalized and integrated look and feel. Users can also manually switch between Light, Dark, and System themes.
*   **Localization:** The app supports multiple languages through the `intl` package, making it accessible to a global audience.
*   **Automated CI/CD:** A GitHub Actions workflow is set up to automatically build and release signed APKs for Android and IPAs for iOS whenever code is pushed to the `release` branch.
*   **Monetization:** The app is monetized through Google AdMob, with banner and interstitial ads. An in-app purchase option to remove ads is planned for a future release.

## 2. License

This project is licensed under the **GNU General Public License v3.0**. The full license text can be found in the [LICENSE](LICENSE) file.

## 3. Project Structure

The project follows a standard Flutter project structure, with the application's source code located in the `lib` directory. The following is a high-level overview of the key directories and files:

```
fueltracker/
├── .agents/                # Workspace agent customizations (plugins.json, skills.json)
├── android/                # Android-specific project files
├── .github/                # GitHub Actions workflows
│   └── workflows/
│       └── release.yml     # Unified CI/CD workflow for building and releasing APKs and IPAs
├── assets/                 # Application assets, such as images and icons
├── lib/
│   ├── database/           # Database-related classes
│   │   └── database_helper.dart
│   ├── l10n/                 # Localization files
│   ├── models/               # Data models for the application
│   ├── pages/                # UI screens for the application
│   ├── services/             # Services for handling business logic
│   ├── utils/                # Utility classes and helper functions
│   ├── widgets/              # Reusable UI widgets
│   ├── main.dart             # Main application entry point
│   └── theme.dart            # Centralized theme management
├── l10n.yaml               # Configuration file for localization
├── pubspec.yaml            # Project dependencies and metadata
└── README.md               # Project description
```

### Key Components:

*   **`main.dart`**: The entry point of the application. It initializes the app, sets up the theme, and configures localization.
*   **`theme.dart`**: Centralizes the app's theme management, including dynamic color generation for both light and dark modes.
*   **`lib/pages/`**: Contains all the UI screens of the application, such as the dashboard, settings, and data entry pages.
*   **`lib/models/`**: Defines the data models for the application, such as `Vehicle`, `FuelRecord`, and `FuelType`.
*   **`lib/database/database_helper.dart`**: Manages all database operations, including creating the database (schema v8 with foreign key enforcement, `saved_locations` table, and additive migrations), migrations, and record operations.
*   **`lib/services/location_service.dart`**: Geolocation capture, 80m proximity clustering, multi-station disambiguation, and attribution candidate lookup.
*   **`lib/pages/saved_locations_page.dart`**: Management interface for saved fuel stations and workshops with category filters, unnamed location toggle, and flag management.
*   **`lib/services/version_service.dart`**: Manages GitHub release version checks, session dismissal state, and permanent version skipping stored in `SharedPreferences`.
*   **`lib/utils/mileage_calculator.dart`**: Pure Dart engine for full-to-full interval calculation, weighted running averages, cost per km, and daily usage statistics.
*   **`lib/utils/maintenance_calculator.dart`**: Pure Dart engine for hybrid distance and calendar maintenance task status forecasting.
*   **`lib/utils/app_settings.dart`**: A centralized class for managing the app's settings, such as the default fuel prices and theme mode.
*   **`.github/workflows/release.yml`**: The unified CI/CD pipeline for automating the build and release process. It is triggered on every push to the `release` branch and generates a signed APK and IPA.

## 4. Technologies and Dependencies

The project is built with Flutter and relies on several key packages to provide its functionality:

*   **`flutter`**: The core framework for building the application.
*   **`sqflite`**: A database plugin for Flutter, used for local data storage.
*   **`shared_preferences`**: Used for storing simple key-value data, such as user settings and the export filename sequence.
*   **`dynamic_color`**: Enables the app to use the system's dynamic color on Android, providing a more integrated UI.
*   **`intl`**: A package for internationalization and localization, allowing the app to support multiple languages.
*   **`file_picker` & `csv`**: Used for the data import and export functionality, allowing users to manage their data in CSV format.
*   **`google_mobile_ads`**: Used for displaying Google AdMob ads for monetization.

## 5. CI/CD and Release Process

The project uses a unified GitHub Actions workflow to automate the build and release process for Android. The workflow is defined in `.github/workflows/release.yml` and is triggered on every push to the `master` branch containing a cryptographically signed commit authored or committed by `pollob666@gmail.com`.

### Workflow Steps:

1.  **Verification & Version Bump**: The workflow checks that the push event is not an automated bump commit (`ci: Bump version`) and verifies via GitHub API that the commit is cryptographically signed (`verification.verified == true`, `verification.reason == 'valid'`) and that the author or committer email is `pollob666@gmail.com`. It then calculates the new version number based on conventional commit messages (`feat:`, `feat(*):`, `refactor:`, `majorUpdate`, `BREAKING CHANGE`), and sets step outputs.

2.  **Build Android**: Decodes the release keystore from GitHub secrets, generates `key.properties`, and builds both signed release and debug APKs using Flutter (`fueltracker-v<version>-<build>-<timestamp>-release.apk` and `fueltracker-v<version>-<build>-<timestamp>-debug.apk`).

3.  **Create Release**: Downloads the generated APK artifacts and creates a GitHub Release containing both signed release and debug APK files tagged with the new version.

4.  **Commit and Push Version Bump**: Updates `pubspec.yaml` with the new version, commits with message `ci: Bump version to <version>`, and rebase-pushes back to `master`.

This automated process ensures that only verified, signed commits from the project owner trigger production releases, and prevents recursive build loops.

## 6. Monetization

The application is monetized using Google AdMob. The following ad formats are implemented:

*   **Banner Ads:** A banner ad is displayed at the bottom of the main dashboard. It can be closed by the user after 5 seconds.
*   **Interstitial Ads:** A full-screen video ad is displayed after a user saves a new fuel record. The ad is shown for 15 seconds.

### Future Monetization Plans:

*   **In-App Purchase:** An in-app purchase option will be added to allow users to permanently disable all ads in the application.

## 7. Future Development Plan

The following is a roadmap of planned features to be implemented in the future. This plan will guide the ongoing development of the application.

### Advanced Fuel Type Management

*   **Fuel Categories:** Fuel types will be categorized into `Gasoline` (e.g., Petrol, Octane), `Diesel`, and `GAS` (e.g., LPG, CNG).
*   **Customizable Units:** Users will be able to set the measurement unit for each fuel category from the settings.
    *   **Gasoline/Diesel:** Litre (default), Gallon.
    *   **GAS (CNG/LPG):** Litre, Cubic Meter (m³), or Gasoline Gallon Equivalent (GGE).

### Advanced Mileage and Cost Tracking

*   **Per-Fuel Mileage:** For vehicles with multiple fuel types, mileage will be calculated separately for each fuel type.
*   **Overall Mileage:** The app will also provide an overall mileage calculation for multi-fuel vehicles.
*   **Cost-Efficiency Tracking:** A new feature will be added to track and compare the cost-efficiency of different fuel types.

### Cloud Data Backup Options

*   Implement options to back up and restore data from cloud storage providers like Google Drive or Dropbox.

## 8. Development Environment & Workspace Invariants

### Toolchain & Environment
*   **Flutter Binary:** The Flutter SDK executable is located at `/home/andalib/software/flutter/bin/flutter`. Because this path is outside the workspace sandbox, commands invoking Flutter must run with `BypassSandbox: true`.
*   **Build Toolchain:** Flutter 3.47.9 / Dart 3.13.7, Gradle 9.4.1 wrapper, Android Gradle Plugin (AGP) 9.2.1, Kotlin 2.4.0, and Foojay Resolver Convention 1.0.0.
*   **Java 17 Compilation Target:** `android/build.gradle` enforces `sourceCompatibility` and `targetCompatibility = JavaVersion.VERSION_17` across all `subprojects` via deferred `tasks.withType(JavaCompile).configureEach`, eliminating obsolete Java 8 source/target warnings emitted when compiling Flutter plugin subprojects under JDK 21.
*   **Dual Build Signing:** `android/app/build.gradle` is configured so that both `release` and `debug` build types use `signingConfigs.release` when `android/app/key.properties` is present. If `key.properties` is absent, `debug` builds gracefully fall back to default debug keystore signing, ensuring external checkouts build without errors while local and CI environments produce debug APKs matching the release signature.
*   **R8 / ProGuard Configuration:** Release builds configure `proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'` with `android.enableR8.fullMode=false` in `gradle.properties` to retain reflective instantiations for `androidx.work` (`WorkDatabase`), `androidx.room`, `androidx.startup`, `google_mobile_ads`, `flutter_local_notifications`, and `Gson`.
*   **Artifact Naming Convention:** Android release and debug APK and App Bundle artifacts are generated with custom naming format `fueltracker-v<versionName>-<versionCode>-<yyyyMMdd-HHmm>-<variant>.apk` / `.aab` alongside default Gradle/Flutter names (`app-release.apk` / `app-debug.apk` / `app-release.aab`) to ensure both custom artifact archiving and standard Flutter CLI detection work concurrently.
*   **Package Name:** The package is named `fuel_tracker` (with an underscore). Always use `package:fuel_tracker/...` for internal package imports, never `package:fueltracker/...`.
*   **Self-Compilation Allowed:** The agent is explicitly authorized to execute Flutter and Gradle build and compilation commands directly (`flutter build apk`, `flutter build appbundle`, `./gradlew`, etc.) inside the workspace to verify builds and diagnose build issues.
*   **Automatic Workspace File Reading:** The agent is explicitly authorized to automatically read, inspect, search, and analyze any files inside the workspace as needed without prompting for interactive permission.
*   **Git Mutation Operations:** Writing to Git index (`git add`, `git commit`, `git checkout -b`, etc.) requires `BypassSandbox: true` due to filesystem permissions on `.git/index.lock`. Read-only commands (`git status`, `git log`, `git diff`) should run sandboxed first.
*   **Git Remote Protection:** Never run `git push` or propose pushing to remote repositories unless explicitly requested and confirmed by the user.

### Storage & Export Invariant
*   **Scoped Storage & File Export:** Do not rely on persistent user-selected filesystem directories or request legacy storage permissions (`WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`). For data exports (CSV/JSON), stage payload files into the temporary cache directory (`getTemporaryDirectory()`) and dispatch via native share sheet (`share_plus: SharePlus.instance.share(ShareParams(files: xFiles, ...))`).

### Database Deletion Invariant
*   **Foreign Key Cascade Protection:** Because `PRAGMA foreign_keys = ON;` is enforced and schema alters for `ON DELETE CASCADE` carry migration risks on active installs, entity deletions must execute inside an explicit atomic transaction in `DatabaseHelper` deleting child foreign key dependencies prior to the parent record. When deleting a `saved_locations` record, child `locationId` foreign key references in `fuel_records`, `service_sessions`, and `service_session_items` are atomically set to NULL before the location record is removed.

