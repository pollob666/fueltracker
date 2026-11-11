# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Updated GitHub Actions cache, Gradle setup, and artifact actions to Node.js 24-compatible releases to avoid the Node.js 20 deprecation warning.

## [3.7.0+3] - 2026-11-09
### Fixed
- Post-baseline volume and cost calculation skews across intervals.
- Relational foreign key remapping for `copyMergeAll` backups.
- Refuel form input focus and bidirectional recalculation quirks.
- Chassis visualization and tire tab exclusion for 2-wheelers.

## [3.5.1+2] - 2026-11-08
### Changed
- CI/CD build matrix to JDK 17 via `actions/setup-java@v5`.
- Gradle download configuration to avoid 504 gateway timeouts.

## [3.5.0+1] - 2026-11-08
### Added
- Visual telemetry analytics dashboard powered by `fl_chart` with fuel price trends and station efficiency variance.
- Support for customizable measurement units for GAS categories (`m³`, `GGE`, `L`).
- Official in-app purchase architecture (`in_app_purchase`) for ad-free lifetime licenses.
- Tier 3 internationalization engine supporting mixed currencies, distance, and volume metrics.
- Tire life, tread depth degradation, and rotation tracking for 4-wheel vehicles.
- Alternative powertrain and EV charging support (Start/End SoC %, kW charging speeds).
- Tablet adaptive master-detail layout with persistent `NavigationRail` for screens >= 720 dp.
- Single-file JSON unified backup schema (v3.5.0) with Android Storage Access Framework (SAF) integration and WorkManager periodic backup automation.
- Client-side AES-256-CBC encrypted backups (`.ftbackup`) with PBKDF2-HMAC-SHA256 key derivation.
- Pure Dart WebDAV client for automated cloud backup synchronization.
- Android dynamic launcher quick actions and Home Screen Glance telemetry widgets.
- Scoped receipt and odometer photo attachments with on-device ML Kit OCR text recognition.
- Printable high-resolution PDF fleet and tax expense reports with signature verification blocks.
- Non-fuel vehicle expenses tracking (Tolls, Parking, Wash, Insurance, Taxes) and Total Cost of Ownership (TCO) breakdown.
- Redesigned history timeline view with dynamic filtering and card/table mode toggle.

## [3.1.0+1] - 2026-11-06
### Added
- Tier 1 reactive architecture with Riverpod 2.x and SQLite schema v9.
- Resilient CSV import/export preview bottom sheet with SHA-256 duplicate fingerprinting.
- Refuel form sticky bottom navigation action bar and edge-to-edge UI.
- Dual release and debug signed build outputs in CI release workflow with maintainer cryptographic signature verification.

## [3.0.0+1] - 2026-11-06
### Added
- Periodic maintenance task and service log tracking with hybrid distance and calendar scheduling.
- GPS station clustering and mileage anomaly flagging.
- Dual independent predictive refuel reminders and distance-to-empty forecasting.
- Configurable per-vehicle trip meter modes and driving condition tagging (City, Highway, Mixed).
- Multi-fuel vehicle support with single and dual fuel modes.
- Soft anomaly safeguards for odometer entry errors.
- Vehicle cascade deletion safeguards with image attachment cleanup.
- Full CRUD lifecycle (add, view, edit, delete) for fuel records.
- Robust Full-to-Full calculation engine resolving partial fills and Simpson's Paradox.
- Database schema migration to version 4 with strict foreign key constraints.

## [2.0.8+8] - 2026-01-20
### Changed
- Dependency upgrades and dashboard UI refinements.

## [2.0.7+7] - 2025-12-03
### Fixed
- Release workflow regex version matching.

## [2.0.5+6] - 2025-11-19
### Added
- Quick "Add ReFuel" Android launcher action.
- Settings option to disable advertisements.
### Changed
- Release workflow optimized for Android-only builds.
- Deprecated `withOpacity` calls updated to `withValues`.

## [2.0.2+3] - 2025-11-19
### Changed
- Android package identifier standardized to `com.pollob666.fueltracker`.

## [2.0.1+2] - 2025-11-04
### Added
- In-app language selection.
- Hybrid composition support for Android web views and ads.
### Changed
- Improved backup and restore handling.

## [2.0.0+1] - 2025-11-04
### Added
- Google Mobile Ads integration with bottom navigation banner ad.

## [1.4.1+2] - 2025-11-04
### Changed
- Platform indicator added to release artifact filenames.

## [1.4.0+1] - 2025-11-04
### Added
- Automated iOS IPA packaging in CI release workflow.

## [1.3.0+1] - 2025-11-04
### Changed
- Consolidated Android and iOS release workflows.

## [1.2.3+123] - 2025-10-28
### Added
- Build timestamp appended to release APK filenames.

## [1.2.2+122] - 2025-10-28
### Added
- Automated semantic version calculation in CI release workflow.

## [1.2.1+121] - 2025-10-28
### Added
- Multi-vehicle management and default vehicle switching.
- In-app GitHub release update notifications.
- Dynamic theme selection (Light, Dark, System) and redesigned navigation drawer.

## [1.0.0+1] - 2024-10-18
### Added
- Initial release of Fuel Tracker: fuel consumption logging, mileage calculations, and expense tracking.
