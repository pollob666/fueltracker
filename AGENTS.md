# AGENTS.md

This document provides an overview of the Fuel Tracker application for AI agents to understand the codebase and assist in its development.

## Project Overview

Fuel Tracker is a Flutter application designed to help users track their vehicle's fuel consumption. It allows users to record refueling events and calculates key metrics like average mileage. The app is intended to be simple and user-friendly.

## Core Functionality

- **Data Entry**: Users can input details about each refueling, including:
  - Date and Time
  - Odometer Reading
  - Fuel Type (e.g., Octane, Petrol)
  - Fuel Rate (Price per liter)
  - Volume of fuel added
  - Total amount paid

- **Database**: The application uses an `sqflite` local database to store all fuel records. The database schema is defined in `lib/database/database_helper.dart` and consists of a single table, `fuel_records`.

- **Dashboard**: The main screen of the app (`lib/pages/dashboard_page.dart`) displays important calculated metrics:
  - **Running Average Mileage**: The overall average fuel efficiency (km/l).
  - **Last Time Mileage**: The fuel efficiency calculated from the most recent refueling.
  - **Last Refuel Volume**: The amount of fuel added during the last refueling.

- **Data Model**: The core data structure is the `FuelRecord` class, defined in `lib/models/fuel_record.dart`. This model represents a single fuel entry.

## Key Technologies

- **Framework**: Flutter
- **Database**: `sqflite` for local persistence.
- **State Management**: `provider` is used for managing the app's theme and language.
- **Charting/Visualization**: `fl_chart` and `syncfusion_flutter_charts` are included for displaying data, although not heavily used in the current dashboard.
- **Localization**: The app is set up for localization with `.arb` files in `lib/l10n`.

## Codebase Structure

The main application logic is located in the `lib/` directory.

- `main.dart`: The entry point of the application. It initializes providers and sets up the `MaterialApp`.
- `database/database_helper.dart`: Contains all the logic for creating, reading, and writing to the `sqflite` database. It follows a singleton pattern.
- `models/fuel_record.dart`: Defines the `FuelRecord` data model.
- `pages/`: This directory contains the primary screens (or pages) of the application.
  - `dashboard_page.dart`: The main screen that users see when they open the app.
  - `add_data_page.dart`: The form for adding a new fuel record.
- `widgets/`: Contains reusable UI components. `drawer_widget.dart` is an example.
- `utils/`: Utility classes, such as for managing app settings.

## How to Run the App

This is a standard Flutter project. To run it, use the following command in the project root:

```bash
flutter run
```

## Instructions for Agents

- **Follow Existing Patterns**: When adding new features, adhere to the existing architectural patterns. For example, use the `DatabaseHelper` for any database operations and create new pages in the `pages` directory.
- **UI Consistency**: When making UI changes, refer to the existing pages and widgets to maintain a consistent look and feel.
- **Data Model**: Utilize the `FuelRecord` model for any operations involving fuel data.
- **State Management**: For simple state changes within a widget, `StatefulWidget` is acceptable. For app-wide state, consider using the `provider` package, following the existing setup for theme and language.
