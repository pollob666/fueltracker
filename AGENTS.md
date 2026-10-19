# AGENTS.md: Project Overview and Structure

This document provides a comprehensive overview of the Fuel Tracker application, including its purpose, project structure, key components, and the technologies used. It is intended to serve as a guide for developers and contributors.

## 1. Project Overview

**Fuel Tracker** is a Flutter-based mobile application designed to help users track their vehicle's fuel consumption. The app allows users to record refueling data, view their average mileage, and monitor their fuel expenses. The project is designed to be simple, user-friendly, and theme-aware, adapting to the user's system settings for a more integrated experience.

### Key Features:

*   **Fuel Record Management:** Users can add, view, and manage their fuel records, including odometer readings, fuel volume, and paid amounts.
*   **Multi-Vehicle Support:** Add and manage multiple vehicles, each with specific fuel types and capacities, and set a default vehicle for quick data entry.
*   **Immersive User Experience:** Graphical and welcoming prompts for first-time users to guide them through adding their first vehicle and getting started with the app.
*   **Mileage Calculation:** The app automatically calculates and displays the running average mileage and the last time mileage, providing users with insights into their vehicle's fuel efficiency.
*   **Data Import/Export:** Users can import and export their fuel data in CSV format. Exported filenames are automatically generated with the date and a sequence number for easy organization (e.g., `fuel_records_2024-10-28_1.csv`).
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
*   **`lib/database/database_helper.dart`**: Manages all database operations, including creating the database, inserting records, and retrieving data.
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

The project uses a unified GitHub Actions workflow to automate the build and release process for both Android and iOS. The workflow is defined in `.github/workflows/release.yml` and is triggered on every push to the `release` branch.

### Workflow Steps:

1.  **Version Bump**: The workflow begins by determining the new version number based on the commit message, updating `pubspec.yaml`, and committing the change. This job runs first to ensure the version is bumped only once per release.

2.  **Build Android & iOS (Parallel)**: After the version is bumped, two jobs run in parallel:
    *   **Build Android**: Builds the signed APK on a Linux runner.
    *   **Build iOS**: Builds the unsigned IPA on a macOS runner.

3.  **Create Release**: Once both build jobs are complete, a final job downloads the APK and IPA artifacts and creates a single GitHub Release containing both files.

This automated process ensures that every release is built consistently and securely, without the need for manual intervention.

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
