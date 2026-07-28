# Handoff — OwnerDashboard (Octopus Dashboard)

_Last updated: 2026-07-26_

## 1. Current State

- App **builds and runs on a physical iPhone 17** (device id `10301946-75B8-5602-8161-8AB1B8A16454`).
- **Widget App Group sharing works**: the widget now displays real sales (verified `1.207,75 DH` on device) instead of `0.00`, using App Group `group.com.futur3.ownerapp`.
- App **display name** is "Octopus Dashboard"; dashboard header text also reads "Octopus Dashboard".
- **App icon is currently NOT set** (AppIcon set reverted to empty) — see Failed Attempts.
- iOS 26.5 simulator/platform runtime was missing mid-session (caused build failures) and has been **reinstalled** via `xcodebuild -downloadPlatform iOS`. No simulator runtime issues remain.

## 2. Active Files

| File | Role |
|------|------|
| `OwnerDashboard/DashboardManager.swift` | Fetches dashboard data; holds `startDate`/`endDate`/`companyId` filters; builds the API URL; saves `lastTotalSales` to the shared App Group |
| `OwnerDashboard/DashboardView.swift` | Main dashboard UI; date-range picker sheet (`showDatePicker`) binds to `dashboard.startDate` / `dashboard.endDate`; "Apply Filter" calls `refreshData()` |
| `OwnerDashboard/DashboardModel.swift` | `DashboardDataDto` and related decodable models |
| `OwnerDashboard/SettingsView.swift` | Settings; `currencySymbol` via shared-store `@AppStorage` |
| `OwnerWidget/OwnerWidget.swift` | Widget timeline; reads `lastTotalSales` from the shared App Group |
| `OwnerDashboard/OwnerDashboard.entitlements` | Main app App Group entitlement |
| `OwnerWidget/OwnerWidget.entitlements` | Widget App Group entitlement (created this session) |
| `OwnerDashboard/Assets.xcassets/AppIcon.appiconset/` | App icon set (currently empty) |

## 3. Changes Made

- **App Group fix** (widget showing 0.00):
  - Confirmed `group.com.futur3.ownerapp` in `OwnerDashboard.entitlements`.
  - Created `OwnerWidget/OwnerWidget.entitlements` with the same App Group.
  - `DashboardManager.swift`: saves `lastTotalSales` to `UserDefaults(suiteName: "group.com.futur3.ownerapp")` and calls `WidgetCenter.shared.reloadAllTimelines()` (already correct).
  - `SettingsView.swift` & `DashboardView.swift`: `@AppStorage("currencySymbol", store: UserDefaults(suiteName: "group.com.futur3.ownerapp"))`.
  - `OwnerWidget.swift`: reads shared suite in `getTimeline` and uses shared-store `@AppStorage` (already correct).
- **Branding**:
  - Added `CFBundleDisplayName` = "Octopus Dashboard" in `OwnerDashboard/Info.plist`.
  - Changed dashboard header text "Octopus Business" → "Octopus Dashboard" in `DashboardView.swift`.
- **Environment**: reinstalled iOS 26.5 platform component (`xcodebuild -downloadPlatform iOS`).

## 4. Failed Attempts

- **App icon**: generated a 1024×1024 PNG from `icon.svg` (via `qlmanage`) and wired it into `AppIcon.appiconset/Contents.json` for any/dark/tinted. Xcode kept creating duplicate PNGs (`AppIcon-1024 1.png`, `-1024 2.png`), and a build **failed** after the icon was applied. The exact build error was not captured. Icon changes were **reverted** — AppIcon set is empty again. `icon.png` / `icon.svg` / `favicon.ico` remain in the project folder untouched.
  - _Next time_: capture the actual actool/build error first, or drag `icon.png` onto the AppIcon well directly in Xcode's asset editor to avoid CLI-generated image issues. Note the same PNG was reused for the "tinted" appearance, which may be the culprit.
- **project.pbxproj edit** for wiring the widget's `CODE_SIGN_ENTITLEMENTS` was **blocked** (Xcode open); must be done via Xcode UI → OwnerWidgetExtension target → Signing & Capabilities → App Groups.
- **Misdiagnosis**: the "No available simulator runtimes … supportedRuntimes=[]" error was initially mistaken for a stale CoreSimulator service; root cause was the missing iOS 26.5 platform component. A direct device build (`iOS 26.5 must be installed to run the scheme`) confirmed it.

## 5. Next Steps

**Fix date filtering (not working).**

Symptom: selecting a start/end date range in the date-picker sheet and tapping "Apply Filter" does not correctly filter the dashboard data.

Where to look:
- `DashboardView.swift`: the `showDatePicker` sheet binds `DatePicker`s to `$dashboard.startDate` / `$dashboard.endDate`; "Apply Filter" sets `showDatePicker = false` and calls `refreshData()`.
- `DashboardManager.swift` `fetchDashboardData(...)`: builds the URL with
  `?companyId=\(companyId)&startDate=\(startStr)&endDate=\(endStr)`, formatting dates as `yyyy-MM-dd` with a `DateFormatter`.

Likely suspects to investigate:
- Date formatting: `DateFormatter` without an explicit `locale` (use `en_US_POSIX`) and `timeZone` can produce off-by-one/locale-shifted dates → wrong range sent to the API.
- `endDate` may need to be end-of-day (inclusive) rather than the current time, so same-day/boundary sales are included.
- Confirm the API actually filters on these params and that the query string is well-formed/encoded.
- Verify `refreshData()` is re-fetching with the updated `startDate`/`endDate` and that `@Observable` state changes trigger the reload.

Acceptance: changing the range updates the Total Sales / charts to match the selected dates.
