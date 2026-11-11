# Fuel Tracker Workspace Directives

## 1. UI Modifications & Generative UI
- **Generative UI Previews:** For any UI-related modifications (screens, widgets, AppBars, TabBars, contrast or layout changes), create and embed an interactive before/after Generative UI artifact (`/generative_ui`) for visual verification.
- **M3 Monet Theme Contrast:**
  - **AppBar Bottom (Tabs):** Never place bare `TabBar` directly inside `appBar.bottom`. Always wrap in `PreferredSize` containing a `Container` with `colorScheme.surfaceContainer`, subtle top/bottom borders, and M3 pill indicators (`primary.withValues(alpha: 0.18)`).
  - **AppBar Actions & Controls:** Controls placed in `appBar.actions` (DropdownButton, SegmentedButton) must explicitly map active/inactive foreground colors to `colorScheme.onPrimary` or use container chips to prevent white-on-peach low-contrast text.
  - **Title Space Protection:** AppBar action dropdowns must enforce `BoxConstraints(maxWidth: 88-100)` with `TextOverflow.ellipsis`, and the AppBar title must use `titleSpacing: 8` and `FittedBox` to prevent truncation.

## 2. Refuel Data Entry & Calculations
- **Primary Input:** Default calculation lock target is `CalculationLockTarget.volume` (user primarily enters Paid Amount and Rate; Volume is calculated).
- **Bidirectional Dynamic Sync:** Text changes in Paid Amount recalculate Volume without wiping text; text changes in Volume recalculate Paid Amount without clearing Rate.

## 3. Multi-Vehicle State Synchronization
- **Global Selection Sync:** All pages (`DashboardPage`, `MaintenancePage`, `AnalyticsPage`, `AllDataPage`) must observe and update `activeVehicleIdProvider`.
- **Selection Preservation:** Refresh and listener callbacks must preserve the user-selected vehicle (`preserveSelection = true`) and never revert to the default vehicle unexpectedly.

## 4. Device Testing & Screenshots
- **Physical Device Captures:** Pull device screenshots via `adb exec-out screencap -p > docs/screenshots/<name>.png`. Do not use `run-as` on Android 14+ (API 34+) due to SELinux restrictions.
- **In-App Long Screenshot:** Use `LongScreenshotService.captureAndShare(...)` wrapping root content in `RepaintBoundary`.
