# Fuel Tracker

[![Build and Release APK](https://github.com/pollob666/fuel-tracker/actions/workflows/release.yml/badge.svg)](https://github.com/pollob666/fuel-tracker/actions/workflows/release.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Fuel Consumption tracker by **[pollob666](https://github.com/pollob666)**

A Flutter-based mobile application to help users track their vehicle's fuel consumption. The app allows users to record refueling data, view their average mileage, and monitor their fuel expenses.

## Key Features:

*   **Fuel Record Management:** Add, view, and manage your fuel records, including odometer readings, fuel volume, and paid amounts.
*   **Mileage Calculation:** Automatically calculates and displays the running average mileage and the last time mileage.
*   **Data Import/Export:** Import and export your fuel data in CSV format for easy data backup and migration.
*   **Dynamic Theming:** Adapts its color scheme to the user's system-level theme on Android for a personalized look and feel.
*   **Localization:** Supports multiple languages.
*   **Automated CI/CD:** A GitHub Actions workflow automatically builds and releases signed APKs whenever code is pushed to the `release` branch.

## Future Development Plan

The following is a roadmap of planned features to be implemented in the future:

### Advanced Fuel Type Management

*   **Fuel Categories:** Fuel types will be categorized into `Gasoline` (e.g., Petrol, Octane), `Diesel`, and `GAS` (e.g., LPG, CNG).
*   **Customizable Units:** Users will be able to set the measurement unit for each fuel category from the settings.
    *   **Gasoline/Diesel:** Litre (default), Gallon.
    *   **GAS (CNG/LPG):** Litre, Cubic Meter (m³), or Gasoline Gallon Equivalent (GGE).

### Multi-Vehicle Support

*   **Vehicle Profiles:** Users will be able to add and manage multiple vehicles.
    *   Each vehicle will have a name, type, and primary/secondary fuel types.
    *   For each fuel type, users can specify the tank/cylinder capacity.
*   **Default Vehicle:** Users can select one vehicle as the default for quick data entry.
*   **Dashboard Integration:** The dashboard will be updated to display information for all vehicles, with a separate refueling button to add data for each.

## License

This project is licensed under the **GNU General Public License v3.0**. The full license text can be found in the [LICENSE](LICENSE) file.
