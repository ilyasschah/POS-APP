# Handoff — OwnerDashboard (Octopus Dashboard)

_Last updated: 2026-08-22_

## 0. Environment — TEST ONLY (read this first)

This app talks **only to the OVH test backend**, never production. There is no
production backend for it to point at yet — every build, on every device,
should be configured against the test API.

- **Test API base URL:** `https://51-91-6-6.sslip.io/api`
  - Real, publicly-trusted HTTPS (Let's Encrypt via a free `sslip.io` hostname
    that resolves straight to the OVH box's IP `51.91.6.6`) — no self-signed
    cert to trust on-device, no VPN needed.
  - Backed by the `web-pos` / `web-pos-master` databases on the OVH SQL Server.
- **`apiBaseUrl` is user-editable** at runtime (`AuthManager.swift` → `LoginView.swift`
  has a plain text field for it), but the **compiled-in default in
  `AuthManager.swift:15` is still the old stale Tailscale IP**
  (`http://100.114.12.38:5002/api`) — it was never updated when the backend
  moved to IIS on the OVH box. Update that default to the test URL above (or
  at minimum, manually type the test URL into the login screen's API field on
  every fresh install/simulator run until the default is fixed).
- Do **not** point this app at any other host/IP — there's nothing else to
  point it at right now, and typing a wrong/unreachable URL into that field is
  the most likely cause of "why is nothing loading" during a session.

## 1. Current State

- App **builds and runs on a physical iPhone 17** (device id `10301946-75B8-5602-8161-8AB1B8A16454`).
- **Widget App Group sharing works**: the widget now displays real sales (verified `1.207,75 DH` on device) instead of `0.00`, using App Group `group.com.futur3.ownerapp`.
- App **display name** is "Octopus Dashboard"; dashboard header text also reads "Octopus Dashboard".
- **New: a read-only "POS Sessions" tab** (sidebar item #2) rendering the register
  sessions added in backend commit `7e43bdd`. Not built or run yet — it was written
  on the Windows side of the repo, so it still needs a first compile on the Mac.
- **App icon is currently NOT set** (AppIcon set reverted to empty) — see Failed Attempts.
- iOS 26.5 simulator/platform runtime was missing mid-session (caused build failures) and has been **reinstalled** via `xcodebuild -downloadPlatform iOS`. No simulator runtime issues remain.

## 2. Active Files

| File | Role |
|------|------|
| `OwnerDashboard/DashboardManager.swift` | Fetches dashboard data; holds `startDate`/`endDate`/`companyId` filters; builds the API URL; saves `lastTotalSales` to the shared App Group |
| `OwnerDashboard/DashboardView.swift` | Main dashboard UI; date-range picker sheet (`showDatePicker`) binds to `dashboard.startDate` / `dashboard.endDate`; "Apply Filter" calls `refreshData()` |
| `OwnerDashboard/DashboardModel.swift` | `DashboardDataDto` and related decodable models |
| `OwnerDashboard/SettingsView.swift` | Settings; `currencySymbol` via shared-store `@AppStorage` |
| `OwnerDashboard/PosSessionModels.swift` | POS session DTOs, the 10–13 status enum, currency/date/duration formatting, and the tolerant server-date JSON decoder |
| `OwnerDashboard/PosSessionsViewModel.swift` | `/PosSession/History`, `/PosSession/Summary` (lazily, per row) and `/Users/GetAllUsers` for cashier names |
| `OwnerDashboard/PosSessionsView.swift` | POS Sessions list: live-register strip, KPI tiles, filter chips, session rows + the shared glass/backdrop components |
| `OwnerDashboard/PosSessionDetailView.swift` | One session in full: hero, flags, takings, cash reconciliation, payment-mix donut, audit trail |
| `OwnerDashboard/NavigationSidebarView.swift` | Sidebar sections; `.sessions` sits between Dashboard and Products |
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
- **POS Sessions tab** (new, read-only). No backend change was needed — it runs on
  the endpoints `PosSessionController` already exposes:
  - `GET /api/PosSession/History?companyId=25&take=50` — the list (25/50/100/250 selectable).
  - `GET /api/PosSession/Summary?companyId=25&sessionId=` — one session's figures.
  - `GET /api/Users/GetAllUsers?companyId=25` — ids → cashier names; a failure here is
    swallowed and rows fall back to "User #7".
  - **Read-only on purpose.** Open/ConfirmOpening/Close/ForceClose are never called:
    the drawer is counted on the register that owns it, and an owner tapping "close"
    from a phone would strand a till mid-count.
  - **Summaries are fetched per row, lazily** (`.task` on each row/live card, deduped by
    the view model). `/History` carries no takings or order count, and each `/Summary`
    is several queries server-side, so firing 50 up front to fill four visible rows
    would hammer the API for nothing.
  - **Dates**: EF hands `DateTime` back from SQL Server as `Kind=Unspecified`, so most
    values arrive with **no** timezone suffix even though the server wrote them with
    `DateTime.UtcNow`, and .NET emits up to 7 fractional digits, which
    `ISO8601DateFormatter` refuses. `PosApi.parseServerDate` truncates the fraction to
    3 digits and appends `Z` when no offset is present — without that, every session
    time silently drifts by the device's UTC offset (the same class of bug as the
    date-filter one in §5).
  - **Frozen vs recomputed**: a closed session's `expectedCash` is what the cashier was
    held to; `/Summary` recomputes live, so the detail screen shows the frozen figure
    and adds a "Recomputed now" note only when the two disagree — that gap is late
    sales, and hiding either number would hide it.
  - Status colours follow the 10–13 lifecycle (`PosSessionState`), not a binary
    open/closed, so OPENING_CONTROL and CLOSING_CONTROL stay visually distinct from
    OPENED — they are the two states where a register exists but is not trading.
  - `companyId` is still hardcoded to **25**, matching every other view model here.

## 4. Failed Attempts

- **App icon**: generated a 1024×1024 PNG from `icon.svg` (via `qlmanage`) and wired it into `AppIcon.appiconset/Contents.json` for any/dark/tinted. Xcode kept creating duplicate PNGs (`AppIcon-1024 1.png`, `-1024 2.png`), and a build **failed** after the icon was applied. The exact build error was not captured. Icon changes were **reverted** — AppIcon set is empty again. `icon.png` / `icon.svg` / `favicon.ico` remain in the project folder untouched.
  - _Next time_: capture the actual actool/build error first, or drag `icon.png` onto the AppIcon well directly in Xcode's asset editor to avoid CLI-generated image issues. Note the same PNG was reused for the "tinted" appearance, which may be the culprit.
- **project.pbxproj edit** for wiring the widget's `CODE_SIGN_ENTITLEMENTS` was **blocked** (Xcode open); must be done via Xcode UI → OwnerWidgetExtension target → Signing & Capabilities → App Groups.
- **Misdiagnosis**: the "No available simulator runtimes … supportedRuntimes=[]" error was initially mistaken for a stale CoreSimulator service; root cause was the missing iOS 26.5 platform component. A direct device build (`iOS 26.5 must be installed to run the scheme`) confirmed it.

## 5. Next Steps

**Build the POS Sessions tab on the Mac (first compile).**

The four new files were written on the Windows checkout, so nothing has been through
`swiftc` yet. The target uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77),
so files dropped into `OwnerDashboard/` are picked up **without** editing
`project.pbxproj` — the edit that was blocked last session is not needed here.

Worth checking on that first run:
- Session timestamps read as local wall-clock time (not shifted by the UTC offset) —
  that is `PosApi.parseServerDate` doing its job.
- A closed session shows expected/counted/difference, and a live one shows a pulsing
  LIVE pill with takings that grow on pull-to-refresh.
- The test data on OVH actually has sessions for `companyId = 25`; if the list is
  empty, confirm with `GET /api/PosSession/History?companyId=25&take=50` before
  assuming the screen is broken.

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
