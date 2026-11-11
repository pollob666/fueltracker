# Fuel Tracker Feature Review

This review summarizes the app's current user-facing strengths and suggests next improvements. It is intended to help users and maintainers choose what to work on next, not to replace the detailed [feature inventory](features.md).

Recommendations below are proposals, not claims about features that already exist. The current implementation includes vehicle-specific fuel tracking, full-to-full mileage calculations, expense and maintenance records, analytics, OCR-assisted entry, data import/export, and local or WebDAV backup options. See the [README](../README.md) and [feature inventory](features.md) for the broader capability list.

## What works well today

- **A rich vehicle log:** Fuel records can include odometer, trip, station, conditions, images, and fuel type details. Multi-vehicle support, partial fills, missed-fill handling, and weighted mileage calculations support varied logging habits. See [`add_data_page.dart`](../lib/pages/add_data_page.dart) and [`mileage_calculator.dart`](../lib/utils/mileage_calculator.dart).
- **Useful ownership context:** Maintenance, tire wear, non-fuel expenses, and fuel costs sit alongside analytics and printable reports, giving users more than a simple mileage number. See [`maintenance_page.dart`](../lib/pages/maintenance_page.dart), [`analytics_page.dart`](../lib/pages/analytics_page.dart), and [`pdf_report_generator.dart`](../lib/services/pdf_report_generator.dart).
- **Flexible entry and portability:** OCR can help capture values from receipts and gauges; CSV and archive-based backup/restore support moving data out of the app. Encrypted archives and WebDAV are available for users who configure them. See [`ocr_vision_service.dart`](../lib/services/ocr_vision_service.dart), [`export_page.dart`](../lib/pages/export_page.dart), and [`import_page.dart`](../lib/pages/import_page.dart).
- **International and alternative vehicle support:** The app includes per-vehicle units and currencies, EV charging fields, and dual-fuel vehicle configuration. The README still lists deeper multi-fuel comparisons as future work.

## Prioritized improvements

| Priority | Improvement | Why it helps | Suggested first step | Effort |
| --- | --- | --- | --- | --- |
| **P1** | **Make dual-fuel efficiency and cost comparisons clear** | Dual-fuel vehicles can record more than one fuel, but users need an easy way to understand each fuel's consumption and compare the cost of equivalent travel. This is also the remaining multi-fuel direction called out in the [README roadmap](../README.md#future-development-plan). | Define the first comparison around per-fuel full-to-full mileage and normalized cost per distance; then add a small dashboard/analytics comparison using existing fuel type and currency conversion data. Clearly label metrics that cannot be calculated from the available logs. | Medium |
| **P1** | **Make backup health and recovery status visible** | Export, encryption, periodic local backups, and WebDAV sync are powerful but require user configuration. Background backups currently omit attachments, so users may not realize that photos are excluded from that path. | Add a backup status summary showing last successful run, destination, included data, attachment handling, and the next scheduled run; surface failures with a recovery action. Document that app-local backups do not survive uninstall or device loss unless copied elsewhere. | Medium |
| **P1** | **Add lightweight guided setup for a first vehicle and first log** | The app has welcoming empty states and vehicle setup, but a short guided path could help new users choose units, configure their vehicle, and understand the first full-tank baseline needed for useful mileage estimates. | Add an optional, dismissible setup checklist that links to existing vehicle, first refuel, and backup steps. Explain that some mileage metrics appear after enough valid records have been logged. | Small to medium |
| **P2** | **Improve data-quality feedback at entry and import** | Soft odometer warnings, import previews, and duplicate checks already catch some issues. More contextual checks can prevent confusing analytics when a record is mistyped or a history has a gap. | Review the existing validation rules and add explainable warnings for suspicious volume, price, odometer jumps, dates, and imported rows. Keep unusual but possible entries savable after acknowledgment, and show which records were skipped or changed. | Medium |
| **P2** | **Make recovery cover more interrupted workflows** | Refuel entry has a draft recovery buffer. Similar protection for longer service or expense entry, plus a clear undo window after deletion, could reduce lost work and accidental data loss. | Identify the longest forms and destructive actions; prioritize draft restore for service visits and a reversible delete/undo flow for records and attachments. | Medium |
| **P3** | **Help users understand trends and estimates** | Analytics include multiple charts and calculated estimates. Brief explanations can make it clearer what data powers a metric, how much history it uses, and when a trend is too sparse to trust. | Add concise “How this is calculated” details and sample-size/context labels to mileage, range, station, carbon, and total-cost metrics. Provide an empty or low-data state when the underlying sample is too small. | Small to medium |

### Suggested order

Start with **dual-fuel comparisons**: this closes a clearly documented product gap and builds on existing vehicle/fuel records. Next, improve **backup status and recovery messaging**, since backup setup and attachment coverage affect user confidence in keeping their history. The onboarding checklist and data-quality improvements can follow without changing the app's core offline-first workflow.

## Scope and evidence notes

- This is a product-facing review, not a security audit or a claim that every platform integration has been verified on a device.
- Recommendations are grounded in the current README, `docs/features.md`, and implementation entry points linked above. Some integrations depend on platform permissions or user configuration.
- The older [improvements roadmap](IMPROVEMENTS.md) and [test report](TEST_REPORT.md) contain historical planning and verification details. Check their claims against current code before using them as a statement of present behavior.
