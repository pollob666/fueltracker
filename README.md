# Fuel Tracker

[![Build and Release APK](https://github.com/pollob666/fuel-tracker/actions/workflows/release.yml/badge.svg)](https://github.com/pollob666/fuel-tracker/actions/workflows/release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Fuel Consumption tracker by **[pollob666](https://github.com/pollob666)**

A Flutter-based mobile application to help users track their vehicle's fuel consumption. The app allows users to record refueling data, view their average mileage, and monitor their fuel expenses.

## Download

You can download the latest version of the application from the [GitHub Releases](https://github.com/pollob666/fuel-tracker/releases) page.

## Key Features:

*   **Fuel Record Management:** Add, view, and manage your fuel records, including odometer readings, fuel volume, and paid amounts.
*   **Multi-Vehicle Support:** Add and manage multiple vehicles, each with specific fuel types and capacities, and set a default vehicle for quick data entry.
*   **Immersive User Experience:** Graphical and welcoming prompts for first-time users to guide them through adding their first vehicle and getting started with the app.
*   **Mileage Calculation:** Automatically calculates and displays the running average mileage and the last time mileage.
*   **Data Import/Export:** Import and export your fuel data in CSV format. Exported filenames are automatically generated with the date and a sequence number for easy organization (e.g., `fuel_records_2024-10-28_1.csv`).
*   **Dynamic Theming:** Adapts its color scheme to the user's system-level theme on Android for a personalized look and feel. Users can also manually switch between Light, Dark, and System themes.
*   **Localization:** Supports multiple languages through the `intl` package.
*   **Automated CI/CD:** A GitHub Actions workflow automatically builds and releases signed APKs whenever code is pushed to the `release` branch.
*   **Vehicle Management:** A dedicated page to list, edit, and set a default vehicle.
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

### Cloud Data Backup Options

*   Implement options to back up and restore data from cloud storage providers like Google Drive or Dropbox.

## License

This project is licensed under the **GNU General Public License v3.0**. The full license text can be found in the [LICENSE](LICENSE) file.
