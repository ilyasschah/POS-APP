# POS Ecosystem — Consolidated Project Documentation

> **Single source of truth** for the POS ecosystem's architecture, planning, and audit history.
> This file consolidates what were previously six separate documents. For active, harness-loaded
> engineering rules see `CLAUDE.md` (kept separate on purpose — it is auto-loaded each session).
>
> **Last consolidated:** 2026-07-04

## Table of Contents

1. [Project Handover](#1--project-handover) — full technical context, tech stack, workflows, file map
2. [Offline Migration Plan](#2--offline-migration-plan) — the Drift/offline-first pivot plan
3. [ADR-001 — Offline-First Sync](#3--adr-001--offline-first-sync) — local SQLite mirror + outbox + delta pull
4. [ADR-002 — SaaS Multi-Tenancy & Hardware Security](#4--adr-002--saas-multi-tenancy--hardware-security) — 5-pillar commercialization blueprint
5. [Offline-First Audit & Conversion Tracker](#5--offline-first-audit--conversion-tracker) — per-screen offline-first status
6. [Project Audit (2026-07-04)](#6--project-audit-2026-07-04) — repository-wide bug/perf/architecture audit

---


<a id="1--project-handover"></a>

# 1 · Project Handover

> _Source (now consolidated): `project_handover.md`_

# POS APP — Project Handover Document
**Generated:** 2026-05-27  
**Purpose:** Complete technical context for a new AI assistant picking up this project. Read every section before writing a single line of code.

---

## 1. Project Overview & Tech Stack

### What This Is
An enterprise-grade, Aronium-inspired Point of Sale (POS) ecosystem built for two hardware targets:
- **Windows 10/11 touch-screen monitors** (compiled as a `.exe` via Flutter Windows)
- **10-inch Android tablets** (compiled as a `.apk` via Flutter Android)

The system covers the full restaurant/retail cycle: user authentication, product catalog, cart management, floor plan / table management, kitchen display, bookings/reservations, inventory control, document management, reporting, and receipt printing.

### Repository Structure
```
/POS-APP
├── /Front-End        → Flutter POS application (Windows + Android)
├── /Back-End         → C# .NET 8/9 REST API
└── /kitchen_display  → Flutter KDS (Kitchen Display System) companion app
```

### Frontend Tech Stack
| Concern | Package/Pattern |
|---|---|
| Framework | Flutter (Dart), targeting Windows + Android |
| State Management | **Riverpod v3** (`NotifierProvider`, `FutureProvider.autoDispose`, `ConsumerWidget`, `ConsumerStatefulWidget`) |
| HTTP Client | **Dio** — all API calls go through `ApiClient` (`createDio()`) |
| UI Components | Material 3, `phosphor_flutter` icons, `flutter_animate` for animations, `gap` for spacing |
| PDF / Printing | `pdf` package (programmatic PDF), `printing` package (dispatch to Windows/Android printers) |
| Fonts | `google_fonts` / `PdfGoogleFonts` (Noto Sans for receipt PDFs) |
| Local Persistence | `shared_preferences` (auth cache, offline PIN fallback) |
| Charts | `fl_chart` |
| Loading States | `skeletonizer` (wrap loading trees with `Skeletonizer(enabled: isLoading)`) |

### Backend Tech Stack
| Concern | Detail |
|---|---|
| Framework | C# .NET 8/9 Web API |
| ORM | Entity Framework Core + SQL Server |
| Pattern | CQRS via **MediatR** — thin controllers, business logic in Services, data in Repositories |
| Auth | JWT (`TokenService`), BCrypt (passwords), SHA-256 (PINs) |
| Error Contract | Business failures → `400 Bad Request` with `{ success, message, fallbackWarehouses?, failedProductId? }` |

---

## 2. Frontend Architecture & State Management

### Riverpod Provider Taxonomy

```
rawAppPropertiesProvider    → FutureProvider.autoDispose  → fetches /ApplicationProperties/GetAll
appSettingsProvider         → NotifierProvider             → merges DB props with kSettingDefaults
selectedCompanyProvider     → StateProvider                → currently active Company
currentUserProvider         → StateProvider                → logged-in user
cartProvider                → NotifierProvider<CartState>  → full cart state + item list
cartTotalProvider           → Provider (derived)           → grand total from cartProvider
allFloorPlansProvider       → FutureProvider.autoDispose   → fetches /FloorPlans/GetAll
tablesByFloorPlanProvider   → FutureProvider.autoDispose   → fetches tables for active floor plan
floorPlanProvider           → NotifierProvider<FloorPlanState> → active floor plan ID + edit mode
floorPlanTableProvider      → NotifierProvider<int?>       → selected table ID
selectedWarehouseProvider   → StateProvider                → active warehouse for stock sourcing
```

**After any mutation (POST/PATCH/DELETE), always call `ref.invalidate(relevantProvider)` to keep the UI fresh.** This is non-optional.

### `appSettingsProvider` — The Settings Engine

This is one of the most critical providers in the app. Understand it completely.

**How it works:**
1. `rawAppPropertiesProvider` fetches all `AppProperty` rows from `/ApplicationProperties/GetAll` for the selected company.
2. `AppSettingsNotifier.build()` starts with `Map.from(kSettingDefaults)` (hardcoded fallbacks in `app_settings_model.dart`), then overwrites with DB values from `rawAppPropertiesProvider`.
3. A `_pendingOverrides` map is maintained for **optimistic writes** — when the user flips a switch, the UI updates instantly before the API call completes. If the API call fails, the override is removed and the value rolls back.
4. The `set(key, value)` method is fire-and-forget: it upserts to the API (PATCH if the row exists, POST if not) then calls `ref.invalidate(rawAppPropertiesProvider)` to re-sync.

**Key code:**
```dart
// AppSettingsNotifier.set() — simplified
Future<void> set(String key, String value) async {
  _pendingOverrides[key] = value;
  state = {...state, key: value};          // Optimistic update

  final existing = _findProp(props, key);
  try {
    if (existing != null) { await dio.patch(...); }
    else { await dio.post(...); }
    ref.invalidate(rawAppPropertiesProvider);
  } on DioException {
    _pendingOverrides.remove(key);         // Rollback
    state = {...state, key: prevValue};
    rethrow;
  }
}
```

**Riverpod v3 gotcha:** Do NOT call `state = ...` inside a `fireImmediately` listener during `build()`. Use `ref.watch(rawAppPropertiesProvider).whenData(...)` in `build()` instead — Riverpod re-runs `build()` when the async source resolves.

**Riverpod v3 gotcha:** Do NOT call `ref.invalidate(...)` on two providers in the same synchronous frame. The scheduler throws `"Only one task can be scheduled at a time"`. Fix: stagger with nested `addPostFrameCallback`:
```dart
ref.invalidate(providerA);
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) ref.invalidate(providerB);
});
```
If this still throws (e.g. when another part of the app already has a task in-flight), wrap in `try { ... } catch (_) {}` — the assertion is debug-only and the invalidate will retry on the next cycle.

### Settings Screen UI Pattern

The Settings screen (`lib/settings/settings_screen.dart`) uses a two-column layout:
- **Left sidebar** (210px wide): tab list using `ListTile` with `selectedTileColor`
- **Right content area**: one tab widget per section

Each tab is built with two reusable primitives:

```dart
_TabScrollView(cards: [...])      // SingleChildScrollView wrapper
_SettingsCard(title: 'SECTION', children: [...])  // Card with bold uppercase title + divider
```

Inside cards, use these shared widgets:
```dart
_SettingSwitch(settingKey: SettingKeys.someKey, label: 'Label')
_SettingDropdown(settingKey: SettingKeys.someKey, label: 'Label', options: [...])
_SettingTextField(settingKey: SettingKeys.someKey, label: 'Label', hint: '...')
_StepperRow(label: 'Label', settingKey: SettingKeys.someKey, min: 0, max: 10)
```

All of these read/write through `appSettingsProvider` automatically. No manual save buttons — changes are persisted immediately on toggle/change/focus-loss.

### `SettingKeys` — All Known Settings Keys

Defined in `lib/app_settings/app_settings_model.dart`. Key groups:

| Group | Keys (sample) |
|---|---|
| General | `currencySymbol`, `language`, `timezone`, `dateFormat`, `taxIncludedByDefault`, `industryMode` |
| Order & Payment | `defaultPaymentType`, `allowNegativeStock`, `allowPriceChange`, `roundingMode`, `receiptFooter`, `orderPrefix`, `displayReceiptPrintDialog` |
| Products | `showProductImages`, `defaultMeasurementUnit`, `barcodeFormat`, `displayAndPrintTaxIncluded`, `discountApplyRule`, `productSorting`, `allowNegativePrice`, `costPriceBasedMarkup`, `autoUpdateCostPrice`, `updateSalePriceOnMarkup`, `enableMovingAveragePrice` |
| Menu Grid | `menuGridCols`, `menuGridRows` |
| Features | `featureFloorPlanEnabled`, `featureBookingEnabled`, `featureServiceTypeEnabled`, `featureServiceStatusEnabled` |
| Printer (Role-based) | `Receipt.PrinterName`, `Receipt.PaperSize`, `Receipt.Copies`, `Receipt.MarginTop/Bottom/Left/Right`, `Receipt.FontFamily`, `Receipt.FontSize`, `Receipt.RightToLeft`, `Kitchen.*` (same keys) |
| Receipt Toggles | `receiptPrintTaxTotals`, `receiptPrintOrderNumber`, `receiptDecimalPlaces`, etc. |
| Theme | `themeMode` (light/dark/dimmed/night/gray/high_contrast), `themeAccentColor` (hex string) |
| Kitchen Display | `kitchenDisplayIps` (comma-separated IP list) |
| Button Bar | `showSearchBtn`, `showTransferBtn`, `showCustomerBtn`, `showDiscountBtn`, ... |

**`kSettingDefaults`** in the same file provides fallback values for every key. Always check there first if a setting behaves unexpectedly.

### `industryMode` — FB vs Service

- `'FB'` = Food & Beverage (restaurant/bar mode). Shows floor plans, kitchen display, etc.
- `'Service'` = Service industry mode. Renames "Tables" → "Resources", hides F&B-specific UI.

Always gate F&B-only UI on: `(settings[SettingKeys.industryMode] ?? 'FB') == 'FB'`.

### Core UI Modules

| Module | Location | Notes |
|---|---|---|
| POS Menu / Cart | `lib/menu/menu_screen.dart` | Product grid (paginated, `menuGridCols × menuGridRows`), cart sidebar |
| Floor Plan | `lib/floor_plan/floor_plan_screen.dart` | Drag-and-drop table layout, 15s auto-refresh, dot-grid painter |
| Table Widget | `lib/floor_plan/widgets/table_widget.dart` | Per-table card, shows occupancy/lock state |
| Side Panel | `lib/floor_plan/widgets/side_panel.dart` | Floor plan settings drawer |
| Checkout Dialog | `lib/cart/payment_checkout_dialog.dart` | Numpad, payment types, receipt print trigger |
| Settings | `lib/settings/settings_screen.dart` | 14-tab settings screen |
| Printer Settings | `lib/settings/printer_settings_screen.dart` | Role-based printer config (Receipt, Kitchen) |
| Kitchen Display | `lib/kitchen/` | Push notification to KDS via HTTP POST |
| Bookings | `lib/bookings/bookings_screen.dart` | Calendar-based booking system |
| Documents | `lib/document/document_editor_screen.dart` | Invoice/document creation with line items |
| Reports | `lib/reports/` | Z-report, sales reports |
| Dashboard | `lib/dashboard/dashboard_screen.dart` | Sales overview with fl_chart graphs |

---

## 3. Backend Architecture & Database

### Controller → Service → Repository Pattern
```
Request → Controller (validation, [FromQuery]/[FromBody]) 
        → MediatR Command/Query Handler 
        → Service (business logic) 
        → Repository (EF Core DB access) 
        → Response DTO
```

**Never put business logic in controllers. Never put EF queries in services directly — use repositories.**

### Key Database Tables

| Table | Purpose |
|---|---|
| `AppProperties` | All app settings as key/value rows, scoped by `CompanyId` |
| `Company` | Multi-company support — every query is filtered by `companyId` |
| `PosUser` | App users with hashed passwords and PIN hashes |
| `UserDevicePins` | Device-specific PIN assignments (join table for multi-device PIN revocation) |
| `Product` | Full product catalog with pricing, tax, barcode, image bytes |
| `ProductGroup` | Category tree for the menu grid |
| `Warehouse` | Stock locations — linked to `Company` via direct FK `Warehouse.CompanyId` (**no join table**) |
| `Stock` | Inventory levels: `ProductId`, `WarehouseId`, `Quantity` |
| `Document` | Sales/purchase/transfer documents (parent record) |
| `DocumentItem` | Line items on a document |
| `PosOrder` | Active POS orders (in-progress table sessions) |
| `PosOrderItem` | Items attached to a POS order |
| `FloorPlan` | Floor plan definitions per company |
| `FloorPlanTable` | Individual table/resource positions on a floor plan |
| `Tax` | Tax rates — linked to products via `ProductTax` join |
| `Customer` | Customer records with optional discount |
| `PaymentType` | Configured payment methods |
| `CashMovement` | Cash-in / cash-out records for business day |
| `Promotion` | Promotional pricing rules |

### Critical SQL Gotchas

**`Document.Date` vs `Document.StockDate`:**
- `Document.Date` is a SQL `date` type (date only, no time). **Never use `DATEPART(HOUR, d.Date)`** — this crashes SQL Server.
- `Document.StockDate` is a `datetime`. Use this for any time-precision queries (hourly sales charts, etc.).

**`trg_Document_CompanyConsistency` trigger:**  
This trigger on the `Document` table validates warehouse/company consistency. It was previously broken — it referenced `dbo.WarehouseCompany` (a join table that does not exist). It was manually fixed to `JOIN dbo.Warehouse w ON w.Id = i.WarehouseId`. If checkout crashes with "Invalid object name 'dbo.WarehouseCompany'", re-check this trigger body.

**`Warehouse` has no join table with `Company`:**  
`Warehouse.CompanyId` is a direct FK. There is no `WarehouseCompany` table. Never create one.

### EF Core Patterns Used
- **Correlated subqueries** for AssignedUserId on floor plan tables (gets the user currently occupying a table via the latest open `PosOrder`)
- **`AsNoTracking()`** on all read-only queries for performance
- **DTOs** (not domain models) are always returned from the API — domain models never leave the service layer
- **No migrations without explicit instruction** — the DB schema is managed carefully and migrations must be reviewed manually

---

## 4. Core System Workflows

### 4.1 Settings Engine (Full Flow)

1. App starts → `selectedCompanyProvider` resolves to chosen company
2. `rawAppPropertiesProvider` auto-fetches all `AppProperty` rows for that company from `/ApplicationProperties/GetAll`
3. `AppSettingsNotifier.build()` merges: `kSettingDefaults` (base) ← DB values (override) ← `_pendingOverrides` (optimistic writes)
4. Any widget calling `ref.watch(appSettingsProvider)` gets the merged map
5. When user changes a setting: `ref.read(appSettingsProvider.notifier).setBool(key, v)` → instant local update → background API upsert → on success: `ref.invalidate(rawAppPropertiesProvider)` to sync
6. On API failure: value rolls back to previous, exception propagates to UI for snackbar display

### 4.2 Cart & Checkout Flow

1. User taps product → `cartProvider.notifier.addItem(menuProduct, ...)` — adds or increments existing item
2. Cart sidebar shows live totals via `cartTotalProvider` (derived from `cartProvider`)
3. User taps "Pay" → `PaymentCheckoutDialog` opens
4. **Critical:** All cart state is snapshotted in `initState()` into `late final` fields (`_cartItems`, `_grandTotal`, etc.) — the numpad uses `ValueNotifier<String>` to avoid rebuilding the whole dialog on every keystroke
5. User enters amount → selects payment type → taps "Complete"
6. `_complete()` fires: builds `CreatePosOrderRequest` DTO from snapshotted cart, POSTs to `/PosOrders/Complete`
7. On success:
   - Checks `SettingKeys.autoprint` — if `'true'`, fires `ReceiptPrinterService.printCartReceipt(...)` immediately
   - Else checks `SettingKeys.displayReceiptPrintDialog` — if `'true'`, shows `AlertDialog` asking user "Print receipt?"
   - **CRITICAL order:** The print dialog is shown and awaited BEFORE calling `Navigator.pop(ctx)`. If you pop the context first, `ctx` becomes invalid and the dialog crashes.
   - Then calls `Navigator.pop(ctx)` to close the checkout dialog
   - Then `syncLatestOrderNumber(ref, company.id)` to update the order number counter

### 4.3 Printing System

**Architecture:** Unified through `ReceiptPrinterService` (`lib/printer/receipt_printer_service.dart`). There are no other printer classes — the old split-brain model (DB-fetched `PosPrinterSelection` + `PosPrinterSelectionSettings`) was deleted. Everything now reads from `appSettingsProvider` via role-prefixed keys.

**Role pattern:** Each printer role (`'Receipt'` or `'Kitchen'`) has keys prefixed with the role name:
```
Receipt.PrinterName     Kitchen.PrinterName
Receipt.PaperSize       Kitchen.PaperSize
Receipt.Copies          Kitchen.Copies
Receipt.MarginTop       Kitchen.MarginTop
Receipt.FontFamily      Kitchen.FontFamily
Receipt.FontSize        Kitchen.FontSize
Receipt.RightToLeft     Kitchen.RightToLeft
... etc
```

**Three print functions:**
- `printCartReceipt({..., roleSettings: appSettings})` — full receipt with totals, taxes, customer info
- `printKitchenTicket({..., roleSettings: appSettings})` — kitchen-only ticket with items and comments
- `printZReport({..., roleSettings: appSettings})` — end-of-day Z-report

**PDF generation:** Uses the `pdf` package. `PdfPageFormat.roll57` (58mm) or `PdfPageFormat.roll80` (80mm) based on `PaperSize` setting. Margins, font scale, font family, and copy count all read from `roleSettings`.

**Dispatch:** `Printing.listPrinters()` finds the named Windows printer. Falls back to system default if not found. Loops `copies` times calling `Printing.directPrintPdf(...)`.

**All print calls are fire-and-forget:** `.catchError((_) {})` swallows print failures so a dead printer never crashes a checkout.

### 4.4 Floor Plan & Table Locking

**Auto-refresh:** `FloorPlanScreen` has a `Timer.periodic(15s)` that invalidates `allFloorPlansProvider` and `tablesByFloorPlanProvider` on alternating frames (nested `addPostFrameCallback`). Both `ref.invalidate` calls are wrapped in `try/catch` to swallow the Riverpod debug assertion when another task is in-flight.

**Table occupancy:** Each `FloorPlanTable` returned from the API includes `assignedUserId` — populated by a correlated subquery on the latest open `PosOrder` for that table. If `assignedUserId != null && assignedUserId != currentUserId`, the table is locked (shown in red, tapping it shows "Table occupied by another user").

**Table widget state machine:**
- `empty` → grey, tappable to start new order
- `occupied by current user` → primary color, tappable to resume order
- `occupied by other user` → error color, tap shows locked warning
- `reserved/booked` → tertiary color (booking exists)

**Edit mode:** `floorPlanProvider.state.isEditMode` unlocks drag-to-move and resize handles. Only admins can toggle edit mode (checked via `currentUserProvider` role).

### 4.5 Kitchen Display System (KDS)

**Architecture:**
- KDS runs as a separate Flutter app in `/kitchen_display`
- It runs a `dart:io HttpServer` on port **9090** (NOT shelf — shelf was replaced because it silently closed connections before sending headers)
- The POS app sends order updates via `KitchenPushService.notify(List<String> ips)` — POSTs to each IP's `http://{ip}:9090/notify`
- KDS polls and the push triggers a `_fetchData()` refresh

**Android virtual device (emulator):** Use ADB port forwarding: `adb forward tcp:9090 tcp:9090`. The emulator's IP `10.0.2.2` maps to the Windows host.

**Scroll UX:** If more than 4 orders exist, left/right arrow buttons and a `Scrollbar` appear. Managed via `ScrollController` + `_updateScrollArrows()` called in `addPostFrameCallback`.

---

## 5. Current State & Immediate Next Steps

### Recently Completed (as of 2026-05-27)

1. **KDS port migration:** 8080 → 9090 (Windows System/Hyper-V blocked 8080). Updated in both `kitchen_display/lib/kitchen_screen.dart` and `Front-End/lib/kitchen/kitchen_push_service.dart`.

2. **KDS HTTP server rewrite:** Replaced `shelf` + `shelf_router` with `dart:io HttpServer`. Each request is properly drained (`await req.drain<void>()`) and response is always closed in a `finally` block.

3. **Printer architecture unification:** Deleted `_PrinterSlotCard`, `_LayoutSettingsSheet` and all associated dead code (~415 lines) from `settings_screen.dart`. `printKitchenTicket` now uses the same `Map<String, String> roleSettings` pattern as `printCartReceipt`. No more DB-fetched printer selection model.

4. **Receipt print on checkout:** Wired up `SettingKeys.autoprint` and `SettingKeys.displayReceiptPrintDialog` in `payment_checkout_dialog.dart`. Three-way branch: auto-print silently / show dialog / skip. Print dialog shown BEFORE `Navigator.pop()`.

5. **Products Settings tab rebuilt:** New Aronium-style layout with 4 cards: GENERAL, PRODUCT DEFAULTS, MOVING AVERAGE PRICE, MENU GRID. All 8 new settings keys added to `SettingKeys` + `kSettingDefaults`.

6. **`showProductImages` wired up:** `_buildProductCard` in `menu_screen.dart` now reads `ref.watch(appSettingsProvider)[SettingKeys.showProductImages]` and skips `Image.memory()` when false.

7. **Riverpod assertion fix:** `FloorPlanScreen` auto-refresh timer wraps both `ref.invalidate` calls in `try/catch` to swallow the debug-mode "only one task" assertion.

8. **ListTile ink effect fix:** `_PCard` in `printer_settings_screen.dart` was using `Container(color:)` (→ `ColoredBox`, blocks ink). Changed to `Card` widget backed by `Material`.

### Pending / Next Tasks

#### HIGH PRIORITY

**1. Wire up "Default tax rate" placeholder in Products Settings**  
Location: `settings_screen.dart`, `_ProductsTab`, Card 2 "PRODUCT DEFAULTS"  
Currently shows `_MockCheckbox` widgets as a visual placeholder with a `// TODO:` comment.  
Needed: Fetch real tax rates from the backend (`/Taxes/GetAll?companyId=X`), display them as real checkboxes, and save the selected default tax ID(s) to a new setting key (e.g., `SettingKeys.defaultTaxIds`).  
The Tax provider already exists at `lib/tax/tax_provider.dart`. The model is at `lib/tax/tax_model.dart`.

**2. "End of Day" / Z-Report shift close dialog**  
`lib/reports/z_report_provider.dart` and `lib/reports/z_report_model.dart` exist but the close-day UI is incomplete.  
Needed: Full `EndOfDayDialog` widget that shows shift summary (total sales, payment breakdown by type, cash in/out) and triggers `ReceiptPrinterService.printZReport(...)`.

**3. Wire up remaining Products settings to app logic**  
The following keys are saved to the DB but not yet consumed by any business logic:

| Key | Where to Wire |
|---|---|
| `productSorting` (`Name`/`Code`/`Barcode`) | Sort product list in `menu_screen.dart` before pagination |
| `discountApplyRule` (`Before tax`/`After tax`) | Pre-fill `_discountApplyRule` default in `document_editor_screen.dart` |
| `allowNegativePrice` | Validate price input in `document_editor_screen.dart` and cart price-change dialog |
| `costPriceBasedMarkup` | Future: apply in product pricing calculations |
| `autoUpdateCostPrice` | Future: apply on purchase document save |
| `updateSalePriceOnMarkup` | Future: apply when cost price changes |
| `enableMovingAveragePrice` | Future: apply in stock valuation |
| `displayAndPrintTaxIncluded` | Apply in receipt PDF rendering |

**4. Verify settings tab changes reflect live in app**  
The user observed some settings weren't applying despite being saved to the DB. Root cause: settings that are wired up in `build()` methods via `ref.watch(appSettingsProvider)` will update live. Settings only read once in `initState()` will not. Audit any new settings to ensure they use `ref.watch` (not `ref.read` in initState) for live reactivity.

---

## 6. AI Instructions — Rules for the Next AI

These are strict, non-negotiable rules for this codebase. Violating them will break the app.

### Flutter / Frontend Rules

1. **Riverpod only.** Never suggest `Provider`, `GetX`, `BLoC`, or `setState`-heavy architectures. Use `ConsumerWidget`, `ConsumerStatefulWidget`, `NotifierProvider`, and `FutureProvider.autoDispose`. Always call `ref.invalidate(provider)` after any mutation.

2. **No hardcoded colors. Ever.** `Colors.white`, `Colors.black`, `Colors.grey[100]`, etc. are **forbidden**. Always use: `Theme.of(context).colorScheme.X`, `Theme.of(context).cardColor`, `Theme.of(context).scaffoldBackgroundColor`. The app supports 6 theme modes including true black ("Night") and high contrast.

3. **Dio for all HTTP.** Never use `http` package or `dart:io HttpClient` in the frontend. Always call `createDio()` from `lib/api/api_client.dart`. Catch `DioException`, check `e.response?.data` for the structured error JSON from the backend, and surface it as a user-facing snackbar — never let it crash the app.

4. **Snackbars: `showAppSnackbar` only.** Never call `ScaffoldMessenger.of(context).showSnackBar(...)` directly. Always import and use `showAppSnackbar(context, ref, 'message', isError: true/false)` from `lib/utils/snackbar_helper.dart`.

5. **Cross-platform compatibility.** The app must compile for both Windows and Android. Any package that only supports one platform needs a clean abstraction layer.

6. **Touch-first sizing.** Minimum tap target: 44×44px. Dropdowns and inputs must be comfortably fingertip-tappable. Use `LayoutBuilder` / `MediaQuery` for responsive layouts. Avoid fixed-width layouts that break on different screen sizes.

7. **Material 3 widgets only.** Use `FilledButton`, `ElevatedButton`, `OutlinedButton`, `TextButton`. Don't reinvent button widgets. Use `Card` (not `Container` with `BoxDecoration`) when you need ink effects to work inside — `Container(color:)` compiles to `ColoredBox` which blocks ripple.

8. **Settings UI pattern.** All new settings tabs must use `_TabScrollView` → `_SettingsCard` → `_SettingSwitch` / `_SettingDropdown` / `_SettingTextField`. Do not build bespoke settings UIs from scratch.

9. **Never call `setState()` inside `build()`.** This is always wrong. Use `initState()` + `didUpdateWidget()` for widget-level state initialization.

10. **Riverpod v3 async reads.** Use `ref.read(provider).value` (NOT `.valueOrNull` — removed in v3). For high-frequency input (numpad, etc.), use `ValueNotifier` + `ValueListenableBuilder` to avoid full widget rebuilds.

11. **No unnecessary packages.** Before adding a new package, check if an installed one covers the use case: `phosphor_flutter` for icons, `flutter_animate` for animations, `gap` for spacing, `skeletonizer` for loading states, `fl_chart` for charts.

### Backend Rules

12. **CQRS strictly.** Controllers validate and route. Handlers contain business logic. Repositories contain EF queries. Do not mix these layers.

13. **Never modify EF Domain Models** (`PosOrder.cs`, `PosOrderItem.cs`, etc.) to carry transient/UI data. Use Request DTOs (`CreatePosOrderRequest`, etc.) for any extra data the API needs during a transaction.

14. **No migrations without explicit instruction.** The database schema is carefully managed. Never suggest `dotnet ef migrations add ...` to solve a UI or logic problem.

15. **400 for business errors, never 500.** Out of stock, duplicate name, validation failure — always `400 Bad Request` with `{ success: false, message: "...", ...optionalContext }`. Use the established error response shape. Reserve 500s for genuine infrastructure failures.

16. **`Document.Date` is date-only.** Never use `DATEPART(HOUR, d.Date)` in SQL. Use `DATEPART(HOUR, d.StockDate)` for time-precision. This is a real production bug that burned us once already.

17. **There is no `WarehouseCompany` table.** `Warehouse.CompanyId` is a direct FK to `Company`. If any trigger or query references `dbo.WarehouseCompany`, it is a bug — check `trg_Document_CompanyConsistency`.

### Code Quality Rules

18. **Full production-ready code only.** No `// TODO: implement this`, no dummy `return null`, no placeholder logic. If something is genuinely deferred, mark it with a `// TODO:` comment explaining exactly what's needed and where to find the data.

19. **No unnecessary comments.** Don't comment what the code does — the code itself should be readable. Only comment WHY: hidden constraints, subtle invariants, non-obvious workarounds.

20. **No feature creep.** Implement exactly what was asked. Don't add error handling for impossible scenarios, don't add backwards-compatibility shims, don't introduce abstractions for hypothetical future requirements.

21. **Verify before claiming done.** If you change a setting that's supposed to affect the UI, trace the data path: Does the widget use `ref.watch(appSettingsProvider)` (reactive) or `ref.read(...)` in `initState()` (one-shot)? A setting saved to the DB but not read reactively will appear broken.

---

## 7. Upcoming Architecture Pivot: Offline-First Sync

> **STATUS: PLANNED — Not yet implemented. This section describes the target architecture the next AI must design and build.**

### 7.1 The Goal

The Flutter app currently reads and writes directly to the C# API for every operation (products, floor plans, cart actions, settings). This means **the app is completely unusable without a network connection**, which is unacceptable for a restaurant/retail POS environment where the internet can drop mid-service.

The pivot is to an **offline-first, sync-on-restore** model inspired by Loyverse POS and Odoo. The principle:

> The app reads and writes to a **local SQLite database** 100% of the time. The C# API becomes a sync target, not a live data source.

All Riverpod providers that currently make Dio HTTP calls will be rewritten to query the local DB instead. The network layer becomes a background sync engine.

---

### 7.2 Recommended Package: Drift

**Use [Drift](https://drift.simonbinder.eu/) (formerly Moor), not `sqflite` directly.**

Reasons:
- Drift provides **typed Dart table definitions** that map cleanly to the existing EF Core entities — the same column names, types, and foreign key relationships can be mirrored exactly.
- Drift generates compile-time-safe query DAOs (like EF Core's repository pattern in Dart).
- Drift supports **streams** (`watchSingleOrNull`, `watch`) — Riverpod `StreamProvider` can replace `FutureProvider` for live reactive local queries with zero polling.
- Drift handles migrations with version numbers, identical to EF Core `__EFMigrationsHistory`.
- Works on both **Windows (via `drift_sqflite` or `drift/native`)** and **Android** without platform-specific code.

**Add to `pubspec.yaml`:**
```yaml
dependencies:
  drift: ^2.x
  sqlite3_flutter_libs: ^0.5.x   # bundles SQLite on Windows + Android
  path_provider: ^2.x
  path: ^1.x

dev_dependencies:
  drift_dev: ^2.x
  build_runner: ^2.x
```

---

### 7.3 Local Schema Design

Mirror the critical C# entities as Drift tables. Every transaction table needs a `syncStatus` column.

#### Sync Status Enum
```dart
// lib/sync/sync_status.dart
enum SyncStatus { pending, synced, failed }
```

#### Core Table Definitions (Drift)

```dart
// lib/database/app_database.dart  (generated via build_runner)
import 'package:drift/drift.dart';

// ── Master Data (pulled from API, read-only locally) ──────────────────────────

class ProductsTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get cost => real()();
  TextColumn get barcode => text().nullable()();
  IntColumn get productGroupId => integer().nullable()();
  BoolColumn get isService => boolean().withDefault(const Constant(false))();
  BlobColumn get imageBytes => blob().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  // syncStatus not needed — master data is pull-only, server is authoritative
}

class TaxesTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  RealColumn get rate => real()();
  DateTimeColumn get lastModified => dateTime()();
}

class FloorPlansTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  DateTimeColumn get lastModified => dateTime()();
}

class FloorPlanTablesTable extends Table {
  IntColumn get id => integer()();
  IntColumn get floorPlanId => integer()();
  TextColumn get name => text()();
  RealColumn get positionX => real()();
  RealColumn get positionY => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  BoolColumn get isRound => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastModified => dateTime()();
}

class UsersTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get pinHash => text()();
  TextColumn get role => text()();
  DateTimeColumn get lastModified => dateTime()();
}

class AppPropertiesTable extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get value => text()();
  IntColumn get companyId => integer()();
  DateTimeColumn get lastModified => dateTime()();
}

// ── Transaction Data (written locally, synced to API) ─────────────────────────

class PosOrdersTable extends Table {
  // Use UUID strings as local IDs to avoid conflicts with server integer IDs
  TextColumn get localId => text()();                           // UUID, local PK
  IntColumn get serverId => integer().nullable()();             // null until synced
  IntColumn get tableId => integer().nullable()();
  IntColumn get userId => integer()();
  IntColumn get companyId => integer()();
  TextColumn get serviceType => text()();
  TextColumn get orderName => text().nullable()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get status => text()();                           // 'open', 'closed', 'voided'
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastModified => dateTime()();
}

class PosOrderItemsTable extends Table {
  TextColumn get localId => text()();
  TextColumn get orderId => text()();                          // FK → PosOrdersTable.localId
  IntColumn get productId => integer()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  TextColumn get comment => text().nullable()();
  IntColumn get warehouseId => integer()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

class CashMovementsTable extends Table {
  TextColumn get localId => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  RealColumn get amount => real()();
  TextColumn get type => text()();                             // 'in' or 'out'
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}

class ZReportsTable extends Table {
  TextColumn get localId => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  RealColumn get totalSales => real()();
  RealColumn get totalCashIn => real()();
  RealColumn get totalCashOut => real()();
  TextColumn get paymentBreakdownJson => text()();            // JSON map
  DateTimeColumn get closedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}
```

#### `@DriftDatabase` declaration
```dart
@DriftDatabase(tables: [
  ProductsTable, TaxesTable, FloorPlansTable, FloorPlanTablesTable,
  UsersTable, AppPropertiesTable,
  PosOrdersTable, PosOrderItemsTable, CashMovementsTable, ZReportsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override int get schemaVersion => 1;
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(path.join(dir.path, 'pos_app.sqlite'));
  return NativeDatabase.createInBackground(file);
});
```

Expose via Riverpod:
```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

---

### 7.4 Riverpod Provider Rewrites

Every `FutureProvider` that currently calls Dio must be rewritten as a `StreamProvider` backed by a Drift DAO watch query. This gives **live, reactive UI** with zero polling — Drift emits a new event whenever a row changes.

#### Before (current — network-first):
```dart
final allFloorPlansProvider = FutureProvider.autoDispose<List<FloorPlan>>((ref) async {
  final dio = createDio();
  final response = await dio.get('/FloorPlans/GetAll', ...);
  return (response.data as List).map((j) => FloorPlan.fromJson(j)).toList();
});
```

#### After (offline-first — SQLite-backed):
```dart
final allFloorPlansProvider = StreamProvider.autoDispose<List<FloorPlan>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllFloorPlans();   // Drift DAO method → SELECT * FROM floor_plans
});
```

The DAO:
```dart
// In AppDatabase or a companion DAO class
Stream<List<FloorPlanTableData>> watchAllFloorPlans() =>
    select(floorPlansTable).watch();
```

**Full provider migration list:**

| Current Provider | New Source | Notes |
|---|---|---|
| `rawAppPropertiesProvider` | `db.watchAppProperties(companyId)` | Still filtered by companyId |
| `allFloorPlansProvider` | `db.watchAllFloorPlans()` | |
| `tablesByFloorPlanProvider` | `db.watchTablesByFloorPlan(id)` | |
| `productProvider` | `db.watchProducts()` | Replaces API call |
| `productGroupProvider` | `db.watchProductGroups()` | |
| `taxProvider` | `db.watchTaxes()` | |
| `cartProvider` | Stays as `NotifierProvider` | Cart is in-memory, no DB needed until checkout |
| `currentUserProvider` | `db.getUserById(id)` | Auth still validates via JWT, but user data local |

> **Do NOT migrate `cartProvider` to SQLite.** The cart is ephemeral in-memory state. It only hits the DB at checkout time when an order is written as a local `PosOrder` row.

---

### 7.5 Sync Engine Design

#### Sync Manager
```dart
// lib/sync/sync_manager.dart
class SyncManager {
  final AppDatabase _db;
  final Ref _ref;
  
  SyncManager(this._db, this._ref);

  // Called manually (Sync button) or by connectivity watcher
  Future<SyncResult> sync() async {
    final result = SyncResult();
    try {
      await _pushPendingOrders(result);
      await _pushPendingCashMovements(result);
      await _pushPendingZReports(result);
      await _pullMasterData(result);
    } catch (e) {
      result.errors.add(e.toString());
    }
    return result;
  }

  // ── PUSH: local transactions → C# API ─────────────────────────────────────

  Future<void> _pushPendingOrders(SyncResult result) async {
    final pending = await _db.getPendingOrders();  // WHERE sync_status = 'pending'
    for (final order in pending) {
      try {
        final response = await createDio().post('/PosOrders/Complete', data: order.toApiJson());
        final serverId = response.data['id'] as int;
        await _db.markOrderSynced(order.localId, serverId);
        result.pushed++;
      } on DioException catch (e) {
        await _db.markOrderFailed(order.localId, e.message ?? 'Unknown error');
        result.errors.add('Order ${order.localId}: ${e.message}');
      }
    }
  }

  // ── PULL: master data from C# API → local SQLite ──────────────────────────

  Future<void> _pullMasterData(SyncResult result) async {
    await _pullProducts(result);
    await _pullTaxes(result);
    await _pullFloorPlans(result);
    await _pullUsers(result);
    await _pullAppProperties(result);
  }

  Future<void> _pullProducts(SyncResult result) async {
    // Use LastModified delta — only pull rows newer than local max
    final lastSync = await _db.getLastSyncTime('products');
    final response = await createDio().get('/Products/GetAll', queryParameters: {
      'companyId': _ref.read(selectedCompanyProvider)?.id,
      'modifiedAfter': lastSync?.toIso8601String(),   // C# API must support this filter
    });
    final products = (response.data as List).map(ProductTableCompanion.fromJson).toList();
    await _db.upsertProducts(products);
    await _db.setLastSyncTime('products', DateTime.now());
    result.pulled += products.length;
  }
  
  // ... similar _pullTaxes, _pullFloorPlans, _pullUsers, _pullAppProperties
}
```

#### Sync Status Riverpod Provider
```dart
enum SyncState { idle, syncing, success, failed }

class SyncNotifier extends AsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async => SyncState.idle;

  Future<void> sync() async {
    state = const AsyncValue.data(SyncState.syncing);
    try {
      final manager = SyncManager(ref.read(appDatabaseProvider), ref);
      final result = await manager.sync();
      state = AsyncValue.data(
        result.errors.isEmpty ? SyncState.success : SyncState.failed,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final syncProvider = AsyncNotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);
```

#### Manual Sync Button (UI)
Add to the app's `AppBar` or settings screen:
```dart
Consumer(builder: (context, ref, _) {
  final syncState = ref.watch(syncProvider);
  return IconButton(
    icon: syncState.isLoading
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : PhosphorIcon(PhosphorIconsRegular.arrowsClockwise),
    tooltip: 'Sync with server',
    onPressed: syncState.isLoading ? null : () => ref.read(syncProvider.notifier).sync(),
  );
}),
```

---

### 7.6 Data Strategy: Push vs Pull

| Data Type | Direction | Strategy |
|---|---|---|
| Products, Groups, Taxes | Pull only | `modifiedAfter` delta pull on sync; full pull on first install |
| Floor Plans, Tables | Pull only | Delta pull; tables have `lastModified` timestamp |
| App Properties / Settings | Bidirectional | Pull to seed local; push on user change |
| POS Orders | Push only | Written locally with `syncStatus = 'pending'`; pushed during sync |
| Order Items | Push only | Embedded in order push payload |
| Cash Movements | Push only | `syncStatus` flag; pushed during sync |
| Z-Reports | Push only | Generated locally; pushed during sync |
| Users / PINs | Pull only | Pulled to local for offline PIN verification |

#### `LastModified` Delta Pull — C# API Requirements

The following endpoints **must be updated on the backend** to accept an optional `modifiedAfter` query parameter:

```
GET /Products/GetAll?companyId=X&modifiedAfter=2026-05-01T00:00:00Z
GET /Taxes/GetAll?companyId=X&modifiedAfter=...
GET /FloorPlans/GetAll?companyId=X&modifiedAfter=...
GET /FloorPlanTables/GetByFloorPlanId?floorPlanId=Y&companyId=X&modifiedAfter=...
GET /ApplicationProperties/GetAll?companyId=X&modifiedAfter=...
```

Every EF Core entity participating in pull-sync **must have a `LastModified` column** (`DateTime`, auto-updated via a DB trigger or EF Core `SaveChanges` override). This is a backend task that must be coordinated with the Flutter sync implementation.

---

### 7.7 Conflict Resolution Policy

Keep it simple for V1:

- **Server wins for master data.** Product price changed on the server? Overwrite local on next pull. Never let local edits to master data conflict with the server.
- **Local wins for transactions.** A completed order is immutable once written locally. If it fails to push (e.g., product was deleted on server), mark it `syncStatus = 'failed'` and surface it to the manager in a "Failed Syncs" screen.
- **No CRDT, no vector clocks.** V1 is "last-write-wins on server for master data, queue-and-push for transactions." Introduce conflict resolution only if real-world collisions prove problematic.

---

### 7.8 Migration Path (How to Implement Without Breaking the Current App)

Do NOT attempt a big-bang rewrite. Follow this phased approach:

**Phase 1 — Local DB foundation (no behavioral change)**
1. Add Drift to `pubspec.yaml`, define all table schemas, run `build_runner`
2. Add `appDatabaseProvider`
3. On app startup (after login), run a full seed pull: all master data → local SQLite
4. App still reads from Dio/API for all operations — local DB is just being populated in background

**Phase 2 — Read from local DB**
1. Rewrite providers one at a time, starting with lowest-risk: `allFloorPlansProvider` → `db.watchAllFloorPlans()`
2. Sync pull now keeps local DB up to date; UI reads from SQLite
3. Writes still go directly to the API (not yet queued locally)

**Phase 3 — Write to local DB with sync queue**
1. Checkout: write order to local `pos_orders` table with `syncStatus = 'pending'`
2. Sync button pushes pending orders to API
3. Remove direct API write from checkout flow

**Phase 4 — Background sync + connectivity watcher**
1. Add `connectivity_plus` package
2. On connectivity restore → auto-trigger `SyncManager.sync()`
3. Show sync status badge in AppBar

---

### 7.9 Instructions for the Next AI

**Your first task is the Drift schema and provider migration. Follow this exact sequence:**

1. **Select the package:** Use `drift` + `sqlite3_flutter_libs`. Do not use raw `sqflite` — the lack of type safety creates the same migration pain as raw SQL strings.

2. **Design the schema first.** Before writing a single provider, define all Drift tables in `lib/database/app_database.dart`, run `flutter pub run build_runner build --delete-conflicting-outputs`, and verify the generated code compiles cleanly on both Windows and Android.

3. **Write the seed pull.** Implement `SeedService` that calls all master-data endpoints and inserts into local SQLite. Run this once after login. This is the bridge between the old and new architectures.

4. **Migrate providers one at a time.** Start with `allFloorPlansProvider` (lowest risk — read-only, no write path). Verify the floor plan screen still works before moving to the next provider.

5. **Do not touch `cartProvider` or `paymentCheckoutDialog`.** These are correct and stable. The cart stays in-memory; only the final `_complete()` write path changes (write to local DB instead of direct API POST).

6. **Preserve the `appSettingsProvider` optimistic-write pattern.** When settings are written, upsert to local `app_properties` table first, then push to API asynchronously. This preserves the current zero-latency toggle behavior.

7. **The C# backend needs `LastModified` columns and `modifiedAfter` filter params** before delta sync can work. Coordinate with the backend before implementing delta pull — use full pulls until the backend is updated.

8. **Never break the `showAppSnackbar` / Snackbar contract.** Sync errors must surface via `showAppSnackbar(context, ref, 'Sync failed: $message', isError: true)` — not thrown exceptions or generic error screens.

---

## 8. Key File Map

```
lib/
├── app_settings/
│   ├── app_settings_model.dart     ← SettingKeys constants + kSettingDefaults
│   ├── app_settings_provider.dart  ← AppSettingsNotifier (the settings engine)
│   ├── service_type_model.dart     ← CustomServiceType (JSON array setting)
│   ├── service_status_model.dart   ← CustomServiceStatus (JSON array setting)
│   └── booking_settings_model.dart ← BookingSettingsModel (JSON object setting)
├── api/
│   └── api_client.dart             ← createDio() factory — use this everywhere
├── auth/
│   ├── auth_provider.dart          ← currentUserProvider
│   ├── login_screen.dart           ← PIN grid login + offline fallback
│   └── auth_storage.dart           ← shared_preferences for offline cache
├── cart/
│   ├── cart_provider.dart          ← CartState, cartProvider, cartTotalProvider
│   ├── payment_checkout_dialog.dart ← Checkout flow with numpad + print trigger
│   └── checkout_models.dart        ← CartItem, CheckoutSnapshot DTOs
├── floor_plan/
│   ├── floor_plan_screen.dart      ← Main floor plan view (auto-refresh timer)
│   ├── floor_plan_provider.dart    ← floorPlanProvider (active plan + edit mode)
│   ├── floor_plan_table_provider.dart ← tablesByFloorPlanProvider + mutations
│   └── widgets/
│       ├── table_widget.dart       ← Per-table drag/tap widget
│       └── side_panel.dart         ← Floor plan settings drawer
├── kitchen/
│   └── kitchen_push_service.dart   ← KitchenPushService.notify() → HTTP POST to KDS
├── menu/
│   └── menu_screen.dart            ← Product grid + cart sidebar (main POS screen)
├── printer/
│   ├── receipt_printer_service.dart ← PDF gen + dispatch (Receipt, Kitchen, Z-Report)
│   └── invoice_pdf_service.dart    ← A4/A5 invoice PDF generation
├── reports/
│   ├── z_report_provider.dart      ← Z-report data fetching
│   └── z_report_model.dart         ← ZReport model
├── settings/
│   ├── settings_screen.dart        ← 14-tab settings screen
│   └── printer_settings_screen.dart ← Role-based printer configuration
├── tax/
│   ├── tax_model.dart              ← Tax model
│   └── tax_provider.dart           ← taxProvider (fetch /Taxes/GetAll)
├── utils/
│   └── snackbar_helper.dart        ← showAppSnackbar() — ALWAYS use this
└── navigation/
    └── main_layout.dart            ← Bottom nav / tab shell
```

---

## 9. SaaS Commercialization & Security Roadmap

The product is being commercialized as a **multi-tenant, seat-based SaaS** with offline subscription enforcement and anti-theft protections. The full blueprint lives in [`docs/ADR-002 — SaaS Multi-Tenancy & Hardware-Bound Security`](./docs/ADR-002-saas-multitenancy-and-hardware-security.md). Five pillars:

1. **Multi-tenant partitioning** — Master SaaS DB (tenants, Stripe billing, device registry) vs. tenant data isolated by the existing `companyId` discriminator.
2. **Offline subscription leases** — a backend-signed, time-locked `validUntil` token refreshed every sync and stored in `ApplicationProperty`; the app enters a graceful read-only block when it expires offline.
3. **Hardware-bound encryption** — SQLCipher AES-256 with a key derived at runtime from `appSalt + hardware fingerprint + tenantSecret` (never hardcoded); copying the `.sqlite` to another machine fails to decrypt.
4. **Server-side seat counter** — the BatchSync path validates the `deviceId`/hardware signature against the tenant's paid seat allowance and rejects over-cap pushes.
5. **Clone/duplication detection** — an async audit flags duplicate transaction UUIDs, colliding/out-of-order document numbers, and timeline anomalies for administrative review.

Status: roadmap. Foundations that already exist — the `companyId` filter (Pillar 1) and the `deviceId` tracker (Pillar 4) — are noted in the ADR.

---

## 10. Security Hardening — Status & Production Prerequisites

A security audit + first hardening pass landed **2026-06-30 / 2026-07-01**. Full detail is in the auto-memory `project_security_model.md`; the essentials:

### What the RBAC actually is
- Per-user RBAC (Admin vs Cashier) is enforced **only client-side** by `SecurityGuard` (`Front-End/lib/security/security_guard.dart`), fail-secure. `accessLevel 0 = Admin` (bypasses all), `1 = Cashier`. Each action is a "SecurityKey" (`level 0 = Cashier-ok`, `1 = Admin-only`), admin-configured in the Users & Security tab, sourced offline from Drift.
- **The backend does NOT enforce per-user RBAC.** See the "real architectural gap" below.

### Done in the hardening pass
- JWT now carries the **real** role (Admin/Cashier) + `accessLevel`/`companyId` claims (was hardcoded `"Admin"` for everyone).
- `ManagerOnly` policy + `[Authorize(Policy="ManagerOnly")]` on the manager-write endpoints: `UsersController` Add/UpdateUser/Delete/AdminResetPassword, `SecurityKeysController.Update`. All GETs / sync path / login / `MasterController` left open on purpose (sync + boot must never 401).
- Global Dio interceptor attaches the stored `jwt_token` to every request (`api_client.dart` `createDio()`).
- `Jwt:Secret` **fail-closed** outside Development (missing → startup abort).
- Token lifetime 60min → **7 days** + sliding-window refresh: `POST /Auth/Refresh` (`[Authorize]`) called as the `refreshToken` sync step, persisted via `AuthStorage.saveJwt`.
- 3 of 4 placeholder SecurityKeys wired: `Management.Currencies`, `UserProfile`, `FloorPlans.Design`. `Management.Countries` still a placeholder (no countries-management screen exists to gate).

### ⚠️ PRODUCTION PREREQUISITES (config, must-do before shipping)
1. **Replace `Jwt:Secret`** in `Back-End/Web-POS.Api/appsettings.json` — currently the placeholder `"change-this-to-a-long-random-secret-32plus-characters"`. Use a real 32+ char random value (`openssl rand -base64 48`). The fail-closed check only catches a *missing* secret, NOT this placeholder.
2. **Replace `AdminPortal:AccessKey`** — currently `"Admin@123"`. It guards the destructive SaaS admin portal (delete company, reset passwords).
3. **Restart the API** after any of the above so the new build/config takes effect.
4. Consider hardening the secret check to also reject known-default/placeholder strings (not just null).

### The real architectural gap (backend RBAC) — RESOLVED 2026-07-01
The JWT used to identify the device's master-login account, not the current cashier. **Now fixed** (Option A — online exchange + offline fallback): the token carries a `userId` claim and, at PIN login, the client exchanges the durable device token for a per-user token via `[Authorize] POST /Auth/UserToken?userId=` (`IssueUserTokenQuery`, companyId taken from the caller's token so a device can only mint tokens for its own tenant). Offline, it keeps using the device token unchanged; logout reverts the active token to the device token. Storage keeps `jwt_token` (active) + `device_jwt` (durable). So the backend now sees the real operator's identity + role.

**Destructive writes now gated (2026-07-01):** plain `[Authorize]` (authenticated — NOT ManagerOnly, since void/refund/discount are per-company configurable client-side) on the write actions of `PosOrderController` (Create/Checkout/Update/UpdateStatus/Void/Delete), `StocksController`, `PaymentsController`, `PromotionsController`. GETs and `PosOrder/BatchSync` stay open (BatchSync is the offline-sales lifeline with its own seat/clone protection). The sync PUSH carries the token via `createDio()`'s interceptor, and the `refreshToken` step runs before the push phase.

**Still open:** `PosOrderItemsController` writes not yet gated; server-side audit off the `userId` claim; per-user salt on the local PIN; Countries-management screen + wiring `Management.Countries`.

---

*End of handover document. Feed this entire file to the new AI before beginning any task. Pay special attention to Section 7 (Offline-First pivot) — it defines the immediate architectural direction, Section 9 (SaaS & Security Roadmap) for the commercialization blueprint, and Section 10 (Security Hardening) for the auth model + production prerequisites.*


---


<a id="2--offline-migration-plan"></a>

# 2 · Offline Migration Plan

> _Source (now consolidated): `offline_migration_plan.md`_

# Offline-First Migration Plan
**Project:** POS APP  
**Created:** 2026-05-27  
**Reference:** `project_handover.md` → Section 7 (Offline-First Sync Pivot)  
**Purpose:** Master checklist for migrating the Flutter POS app from a network-first to an offline-first SQLite/Drift architecture.

> **How to use this document:**  
> Work through phases in strict order. Do not start Phase N+1 until every checkbox in Phase N is ticked. Each checkbox represents a single, verifiable unit of work. When handing off to another AI session, paste the current state of this file as context so it knows exactly where to resume.

---

## Phase 0: Backend Prerequisites (C# .NET)

> **Goal:** Update the C# API to support delta sync. The Flutter app cannot implement efficient pull-sync until these endpoints exist. Complete this phase before writing a single line of Dart.

### 0.1 — Add `LastModified` to EF Core Entities

- [ ] Add `DateTime LastModified` column to `Product` entity (`Back-End/.../Product.cs`)
- [ ] Add `DateTime LastModified` column to `ProductGroup` entity
- [ ] Add `DateTime LastModified` column to `Tax` entity
- [ ] Add `DateTime LastModified` column to `FloorPlan` entity
- [ ] Add `DateTime LastModified` column to `FloorPlanTable` entity
- [ ] Add `DateTime LastModified` column to `AppProperty` entity
- [ ] Add `DateTime LastModified` column to `PosUser` entity
- [ ] Add `DateTime LastModified` column to `PaymentType` entity
- [ ] Add `DateTime LastModified` column to `Customer` entity
- [ ] Add `DateTime LastModified` column to `Promotion` entity
- [ ] Override `SaveChangesAsync` in `DbContext` to auto-stamp `LastModified = DateTime.UtcNow` on every INSERT and UPDATE — so no call site ever needs to set it manually:
  ```csharp
  public override Task<int> SaveChangesAsync(CancellationToken ct = default) {
      foreach (var entry in ChangeTracker.Entries()
          .Where(e => e.State is EntityState.Added or EntityState.Modified)) {
          if (entry.Entity is IHasLastModified entity)
              entity.LastModified = DateTime.UtcNow;
      }
      return base.SaveChangesAsync(ct);
  }
  ```
- [ ] Create `IHasLastModified` marker interface and apply it to all entities above
- [ ] Create and apply EF Core migration for all `LastModified` columns — **explicitly instructed, do this now**
- [ ] Backfill existing rows: `UPDATE [TableName] SET LastModified = GETUTCDATE() WHERE LastModified IS NULL`
- [ ] Verify `LastModified` columns appear correctly in SQL Server Management Studio

### 0.2 — Add `modifiedAfter` Query Parameter to GetAll Endpoints

- [ ] `GET /Products/GetAll` — add optional `DateTime? modifiedAfter` query param; filter: `WHERE LastModified > modifiedAfter` (skip filter if param is null)
- [ ] `GET /ProductGroups/GetAll` — same pattern
- [ ] `GET /Taxes/GetAll` — same pattern
- [ ] `GET /FloorPlans/GetAll` — same pattern
- [ ] `GET /FloorPlanTables/GetByFloorPlanId` — same pattern
- [ ] `GET /ApplicationProperties/GetAll` — same pattern; **do NOT return the full table blindly if modifiedAfter is provided** — only return rows newer than the timestamp to prevent overwriting local-optimistic edits
- [ ] `GET /Users/GetAll` (or equivalent) — same pattern
- [ ] `GET /PaymentTypes/GetAll` — same pattern
- [ ] `GET /Customers/GetAll` — same pattern
- [ ] `GET /Promotions/GetAll` — same pattern
- [ ] Write a Postman/Swagger test for each endpoint verifying `modifiedAfter` filters correctly
- [ ] Verify endpoints return an empty array (not 404) when no records are modified after the given timestamp

### 0.3 — Create `/PosOrders/BatchSync` Endpoint

> **Why batch?** During offline recovery a device may have accumulated dozens of orders. Individual POSTs would hammer the API and risk partial failures. A single atomic batch call is safer and faster.

- [ ] Create `BatchSyncPosOrdersRequest` DTO: accepts `List<CreatePosOrderRequest>` with each item carrying a `LocalId` (string UUID) field for client-side tracking
- [ ] Create `POST /PosOrders/BatchSync` controller action
- [ ] Process each order in the batch **independently** — one order failing must NOT roll back others; use a per-item try/catch inside the handler
- [ ] Response contract: `{ results: [{ localId, serverId, success, error }] }` — the Flutter sync engine uses `localId` to match server IDs back to local Drift rows
- [ ] If a batch item fails due to out-of-stock or deleted product, return `success: false` with the structured error message (same `{ success, message, failedProductId }` contract as existing single-order endpoint)
- [ ] Add rate limiting / max batch size guard (e.g., reject batches > 500 items with `400`)
- [ ] Write integration test: batch of 3 orders where order 2 is invalid — verify orders 1 and 3 succeed and order 2 returns `success: false`

---

## Phase 1: Local DB Foundation (Drift)

> **Goal:** Introduce Drift into the Flutter project and define the full local schema. The app behaviour does not change yet — this phase is purely additive.

### 1.1 — Add Dependencies

- [ ] Add to `Front-End/pubspec.yaml`:
  ```yaml
  dependencies:
    drift: ^2.22.0
    sqlite3_flutter_libs: ^0.5.x
    path_provider: ^2.1.x
    path: ^1.9.x
    uuid: ^4.x              # For generating local UUIDs
    connectivity_plus: ^6.x # For Phase 5 auto-sync trigger

  dev_dependencies:
    drift_dev: ^2.22.0
    build_runner: ^2.4.x
  ```
- [ ] Run `flutter pub get` and verify no dependency conflicts
- [ ] Verify the app still compiles and runs on Windows before continuing

### 1.2 — Define Drift Table Schemas

- [ ] Create `lib/database/tables/master_data_tables.dart` — define these Drift tables:
  - [ ] `ProductsTable`: `id`, `name`, `price`, `cost`, `barcode` (nullable), `productGroupId` (nullable), `isService`, `colorHex` (nullable), **`localImagePath` (TextColumn, nullable)** — ⚠️ **NEVER use BlobColumn for images — storing binary in SQLite bloats the DB and kills performance. Save the image to the device filesystem via `path_provider` and store the file path here.**
  - [ ] `ProductGroupsTable`: `id`, `name`, `parentId` (nullable), `colorHex`, `lastModified`
  - [ ] `TaxesTable`: `id`, `name`, `rate`, `lastModified`
  - [ ] `FloorPlansTable`: `id`, `name`, `color`, `lastModified`
  - [ ] `FloorPlanTablesTable`: `id`, `floorPlanId`, `name`, `positionX`, `positionY`, `width`, `height`, `isRound`, `lastModified`
  - [ ] `UsersTable`: `id`, `name`, `pinHash`, `role`, `lastModified`
  - [ ] `PaymentTypesTable`: `id`, `name`, `colorHex`, `lastModified`
  - [ ] `AppPropertiesTable`: `id`, `name`, `value`, `companyId`, `lastModified`
  - [ ] `PromotionsTable`: `id`, `name`, `discountType`, `discountValue`, `lastModified`
- [ ] Create `lib/database/tables/transaction_tables.dart` — define these Drift tables:
  - [ ] `PosOrdersTable`: `localId` (TextColumn, PK), `serverId` (IntColumn, nullable), `tableId` (nullable), `userId`, `companyId`, `serviceType`, `orderName` (nullable), `openedAt`, `closedAt` (nullable), `status`, `syncStatus` (default `'pending'`), `lastModified`
  - [ ] `PosOrderItemsTable`: `localId` (TextColumn, PK), `orderId` (FK → `PosOrdersTable.localId`), `productId`, `quantity`, `unitPrice`, `discount` (default 0), `taxRate`, `comment` (nullable), `warehouseId`, `syncStatus` (default `'pending'`)
  - [ ] `CashMovementsTable`: `localId`, `serverId` (nullable), `companyId`, `userId`, `amount`, `type` (`'in'`/`'out'`), `note` (nullable), `createdAt`, `syncStatus`
  - [ ] `ZReportsTable`: `localId`, `serverId` (nullable), `companyId`, `userId`, `totalSales`, `totalCashIn`, `totalCashOut`, `paymentBreakdownJson`, `closedAt`, `syncStatus`
- [ ] Create `lib/database/tables/sync_meta_table.dart`:
  - [ ] `SyncMetaTable`: `entityName` (TextColumn, PK), `lastSyncedAt` (DateTimeColumn, nullable) — used to store the watermark timestamp for each entity's last successful pull

### 1.3 — Create the Database Class & Riverpod Provider

- [ ] Create `lib/database/app_database.dart`:
  - [ ] Annotate with `@DriftDatabase(tables: [all tables from 1.2])`
  - [ ] Implement `_openConnection()` using `NativeDatabase.createInBackground` with `path_provider` path
  - [ ] Set `schemaVersion = 1`
  - [ ] Define `MigrationStrategy` with `onCreate` that calls `createAll()`
- [ ] Create `lib/database/database_provider.dart`:
  ```dart
  final appDatabaseProvider = Provider<AppDatabase>((ref) {
    final db = AppDatabase();
    ref.onDispose(db.close);
    return db;
  });
  ```
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Verify generated `app_database.g.dart` has no errors
- [ ] Verify the app compiles and runs on Windows with the new DB file created (check `%APPDATA%` path)
- [ ] Verify the app compiles and runs on Android emulator with the new DB file created

### 1.4 — Write DAO Methods (Stubs for Now)

- [ ] Create `lib/database/daos/master_data_dao.dart` — add stub methods (empty implementations):
  - [ ] `Future<void> upsertProducts(List<ProductsTableCompanion> rows)`
  - [ ] `Stream<List<ProductsTableData>> watchProducts()`
  - [ ] `Future<void> upsertFloorPlans(List<FloorPlansTableCompanion> rows)`
  - [ ] `Stream<List<FloorPlansTableData>> watchFloorPlans()`
  - [ ] `Future<void> upsertFloorPlanTables(List<FloorPlanTablesTableCompanion> rows)`
  - [ ] `Stream<List<FloorPlanTablesTableData>> watchTablesByFloorPlan(int floorPlanId)`
  - [ ] `Future<void> upsertTaxes(List<TaxesTableCompanion> rows)`
  - [ ] `Stream<List<TaxesTableData>> watchTaxes()`
  - [ ] `Future<void> upsertAppProperties(List<AppPropertiesTableCompanion> rows)` — upsert per-key, never full-replace
  - [ ] `Stream<List<AppPropertiesTableData>> watchAppProperties(int companyId)`
  - [ ] `Future<DateTime?> getLastSyncTime(String entityName)`
  - [ ] `Future<void> setLastSyncTime(String entityName, DateTime time)`
- [ ] Create `lib/database/daos/transaction_dao.dart` — add stub methods:
  - [ ] `Future<void> insertOrder(PosOrdersTableCompanion order)`
  - [ ] `Future<void> insertOrderItems(List<PosOrderItemsTableCompanion> items)`
  - [ ] `Future<List<PosOrdersTableData>> getPendingOrders()`
  - [ ] `Future<void> markOrderSynced(String localId, int serverId)`
  - [ ] `Future<void> markOrderFailed(String localId, String errorMessage)`
  - [ ] `Future<void> insertCashMovement(CashMovementsTableCompanion movement)`
  - [ ] `Future<void> insertZReport(ZReportsTableCompanion report)`
- [ ] Rebuild with `build_runner` after adding DAO annotations
- [ ] Verify app still compiles with no errors

---

## Phase 2: Master Data Seed & Pull Sync

> **Goal:** On login, pull all master data from the C# API into the local SQLite DB. After this phase, the local DB is fully populated and ready to serve the UI.

### 2.1 — Image Storage Strategy

- [ ] Create `lib/sync/image_cache_service.dart`:
  - [ ] `Future<String?> downloadAndSave(String productId, String imageBase64OrUrl)` — saves image bytes to `getApplicationDocumentsDirectory()/images/{productId}.jpg`, returns the local file path
  - [ ] `Future<void> deleteImage(String productId)` — cleans up orphaned image files
  - [ ] `String? resolveImagePath(String? localPath)` — returns null if file no longer exists on disk (handles app reinstall / storage clear gracefully)
- [ ] Verify image files are saved outside the SQLite DB file (confirm by checking that `app_database.sqlite` does not grow when products with images are seeded)

### 2.2 — Build `SyncManager`

- [ ] Create `lib/sync/sync_manager.dart` with `SyncManager` class accepting `AppDatabase db` and `Ref ref`
- [ ] Implement `Future<SyncResult> pullAll()` — full pull of all master data (used on first install / manual full refresh)
- [ ] Implement `Future<SyncResult> pullDelta()` — delta pull using `lastSyncedAt` watermarks per entity

#### Per-Entity Delta Pull Methods
- [ ] `_pullProducts()`:
  - [ ] Read `lastSyncedAt` for `'products'` from `SyncMetaTable`
  - [ ] Call `GET /Products/GetAll?companyId=X&modifiedAfter={lastSyncedAt}`
  - [ ] For each product with image data: call `ImageCacheService.downloadAndSave()`, store returned path in `localImagePath`
  - [ ] Upsert all returned rows via `masterDataDao.upsertProducts()`
  - [ ] Update `SyncMetaTable` with `DateTime.now().toUtc()` on success
- [ ] `_pullProductGroups()` — same delta pattern, no images
- [ ] `_pullTaxes()` — same delta pattern
- [ ] `_pullFloorPlans()` — same delta pattern
- [ ] `_pullFloorPlanTables()` — same delta pattern
- [ ] `_pullUsers()` — same delta pattern; only store `pinHash`, never raw passwords
- [ ] `_pullPaymentTypes()` — same delta pattern
- [ ] `_pullPromotions()` — same delta pattern
- [ ] `_pullAppProperties()`:
  - [ ] ⚠️ **CRITICAL — Bi-directional sync race condition prevention:** Do NOT call `dao.replaceAllAppProperties()`. Instead, upsert **per key** using the `lastModified` timestamp: only overwrite a local row if `serverLastModified > localLastModified`. This prevents a stale server value from overwriting a setting the user just changed locally that hasn't been pushed yet.
  - [ ] Implement: for each property returned by the API, check `if (serverRow.lastModified.isAfter(localRow?.lastModified ?? DateTime(0))) { upsert }; else { skip }`

### 2.3 — Seed on Login

- [ ] Create `lib/sync/sync_provider.dart`:
  - [ ] `final syncManagerProvider = Provider<SyncManager>((ref) => SyncManager(ref.read(appDatabaseProvider), ref))`
  - [ ] `final syncStateProvider = AsyncNotifierProvider<SyncNotifier, SyncPhase>(SyncNotifier.new)`
  - [ ] Define `SyncPhase` enum: `idle`, `seeding`, `pulling`, `pushing`, `success`, `failed`
- [ ] In `LoginScreen` (or `CompanySelectionScreen`), after successful login:
  - [ ] Show a full-screen "Syncing initial data…" overlay (`Skeletonizer` or `CircularProgressIndicator`)
  - [ ] Call `ref.read(syncManagerProvider).pullAll()` — await completion before navigating to `MainLayout`
  - [ ] If `pullAll()` fails and local DB already has data from a previous session: show snackbar warning "Sync failed — running in offline mode" and continue to `MainLayout` anyway
  - [ ] If `pullAll()` fails and local DB is empty (first install): show error dialog and do not proceed (app cannot function with zero data)

### 2.4 — Verify Seeded Data

- [ ] After seeding, open a DB browser (DB Browser for SQLite or Android Studio device explorer) and verify:
  - [ ] `products` table is populated with correct rows
  - [ ] `localImagePath` contains a valid on-disk path for products with images
  - [ ] `sync_meta` table contains a row per entity with a recent `lastSyncedAt`
  - [ ] `app_properties` table contains all settings for the active company
- [ ] Run the app offline (disable network adapter on Windows / enable Airplane Mode on Android) and verify the seeding data persists across app restarts

---

## Phase 3: Read-Only Provider Migration

> **Goal:** Rewrite Riverpod providers one at a time to read from local SQLite instead of calling the API. The app should be fully functional offline after this phase.

### 3.1 — Migrate `appSettingsProvider`

- [ ] Rewrite `rawAppPropertiesProvider` from `FutureProvider` (Dio call) to `StreamProvider` (Drift watch):
  ```dart
  final rawAppPropertiesProvider = StreamProvider.autoDispose<List<AppProperty>>((ref) {
    final db = ref.watch(appDatabaseProvider);
    final companyId = ref.watch(selectedCompanyProvider)?.id;
    if (companyId == null) return const Stream.empty();
    return db.masterDataDao.watchAppProperties(companyId)
        .map((rows) => rows.map(AppProperty.fromDrift).toList());
  });
  ```
- [ ] Add `AppProperty.fromDrift(AppPropertiesTableData row)` factory constructor
- [ ] Update `AppSettingsNotifier.set()`: write to local Drift DB first (optimistic), then push to API asynchronously; on API failure, revert local row
- [ ] Verify settings screen loads without network and all saved settings are correct
- [ ] Verify toggling a setting still persists across app restart

### 3.2 — Migrate `taxProvider`

- [ ] Rewrite `taxProvider` to `StreamProvider` backed by `db.masterDataDao.watchTaxes()`
- [ ] Add `Tax.fromDrift(TaxesTableData row)` factory
- [ ] Verify `tax_rates_screen.dart` loads correctly offline

### 3.3 — Migrate `allFloorPlansProvider`

- [ ] Rewrite `allFloorPlansProvider` to `StreamProvider` backed by `db.masterDataDao.watchFloorPlans()`
- [ ] Add `FloorPlan.fromDrift(FloorPlansTableData row)` factory
- [ ] Remove the 15-second auto-refresh timer in `FloorPlanScreen` — it is no longer needed; Drift streams update automatically when data changes
- [ ] Verify the floor plan tab loads and displays correct tables offline

### 3.4 — Migrate `tablesByFloorPlanProvider`

- [ ] Rewrite `tablesByFloorPlanProvider` to `StreamProvider` backed by `db.masterDataDao.watchTablesByFloorPlan(activeFloorPlanId)`
- [ ] Add `FloorPlanTable.fromDrift(FloorPlanTablesTableData row)` factory
- [ ] Verify tables display at correct positions after migration
- [ ] Verify adding/editing/deleting a table from the side panel still works (mutations must write to local DB AND push to API immediately — table geometry changes are low-conflict master data, so server-write-through is acceptable for now)

### 3.5 — Migrate `productProvider` (and `productGroupProvider`)

- [ ] Rewrite `productProvider` to `StreamProvider` backed by `db.masterDataDao.watchProducts()`
- [ ] Add `Product.fromDrift(ProductsTableData row)` factory — use `ImageCacheService.resolveImagePath(row.localImagePath)` for `imageBytes` equivalent; update `_buildProductCard` to accept a file path and use `Image.file(File(path))` instead of `Image.memory(bytes)` when `showImages` is true
- [ ] Rewrite `productGroupProvider` similarly
- [ ] Verify the menu grid loads all products with images offline
- [ ] Verify the `showProductImages` setting still toggles images correctly

### 3.6 — Offline Smoke Test

- [ ] Disable network completely on test device
- [ ] Cold-start the app (kill and reopen)
- [ ] Verify: login works (offline PIN verification from local `users` table)
- [ ] Verify: menu grid shows all products with images
- [ ] Verify: floor plan shows all rooms and tables
- [ ] Verify: settings screen shows all saved settings
- [ ] Verify: no error snackbars appear during normal navigation

---

## Phase 4: Transaction Queue & Offline Table Locking

> **Goal:** Make the checkout and cash movement flows write to local SQLite first. After this phase, transactions work completely offline.

### 4.1 — Checkout: Write Order to Local DB

- [ ] Import `uuid` package and create `UuidService` helper: `String newId() => const Uuid().v4()`
- [ ] Modify `_complete()` in `payment_checkout_dialog.dart`:
  - [ ] Before the current API POST, build a `PosOrdersTableCompanion` from the cart snapshot
  - [ ] Generate `localId = UuidService.newId()`
  - [ ] Set `syncStatus = 'pending'`, `serverId = null`
  - [ ] Write to `transactionDao.insertOrder(...)` and `transactionDao.insertOrderItems(...)`
  - [ ] **Remove the direct `dio.post('/PosOrders/Complete', ...)` call** — this now happens in the sync engine
  - [ ] On successful local write: clear the cart, show success snackbar, trigger print if configured
- [ ] Verify checkout completes with no network — order appears in local `pos_orders` table with `sync_status = 'pending'`
- [ ] Verify the receipt prints from the local transaction data (not from an API response)

### 4.2 — Offline Table Locking (Optimistic)

> **Why:** Without a live API call, we cannot know if another device has opened the same table. V1 uses optimistic locking: a device claims the table locally and we resolve merge conflicts during sync.

- [ ] Add `lockedByDeviceId` (TextColumn, nullable) and `lockedAt` (DateTimeColumn, nullable) to `FloorPlanTablesTable`
- [ ] Generate and apply local DB migration (`schemaVersion` bump to 2)
- [ ] Create `lib/sync/device_id_service.dart`: generates a stable device UUID on first launch and persists it in `shared_preferences` — this is the device's identity for conflict detection
- [ ] When a user opens a table (taps it to start an order):
  - [ ] Write `lockedByDeviceId = DeviceIdService.id` and `lockedAt = DateTime.now().utc()` to the local `floor_plan_tables` row
  - [ ] Push a lightweight `PATCH /FloorPlanTables/Lock` API call in the background (non-blocking, fire-and-forget with error swallowed) — this informs online devices as best-effort
- [ ] When displaying tables, a table is shown as "locked by another device" if `lockedByDeviceId != null && lockedByDeviceId != DeviceIdService.id`
- [ ] Add a `Lock TTL` — if `lockedAt` is older than 4 hours, treat it as stale and clear the lock locally
- [ ] Document clearly: **full conflict resolution (two devices claiming the same table simultaneously while offline) is deferred to a future phase**. V1 is optimistic — the last push to the server wins.

### 4.3 — Cash Movements

- [ ] Modify `CashMovementDialog` to write to `transactionDao.insertCashMovement(...)` with `syncStatus = 'pending'` instead of direct API POST
- [ ] Verify cash movements are recorded locally with no network

### 4.4 — Z-Report

- [ ] Modify the Z-Report close-day flow to write to `transactionDao.insertZReport(...)` with `syncStatus = 'pending'`
- [ ] Verify Z-reports are recorded locally
- [ ] Verify `ReceiptPrinterService.printZReport(...)` can construct its data from the local transaction DAO instead of an API response

---

## Phase 5: The Sync Engine (Push)

> **Goal:** Build the UI and logic to push all locally-accumulated transactions to the C# API. After this phase, the offline/online loop is complete.

### 5.1 — Sync Status Badge in AppBar

- [ ] Add a `pendingCountProvider` to `sync_provider.dart`:
  ```dart
  final pendingSyncCountProvider = StreamProvider<int>((ref) {
    final db = ref.watch(appDatabaseProvider);
    return db.transactionDao.watchPendingCount(); // SELECT COUNT(*) WHERE sync_status='pending'
  });
  ```
- [ ] In `MainLayout`'s AppBar, show a `Badge` on the sync icon when `pendingCount > 0`:
  ```dart
  Badge(
    isLabelVisible: count > 0,
    label: Text('$count'),
    child: PhosphorIcon(PhosphorIconsRegular.arrowsClockwise),
  )
  ```
- [ ] Sync icon shows `CircularProgressIndicator` (small, 18px) while `syncStateProvider` is in `pulling` or `pushing` phase

### 5.2 — Implement Push Logic in `SyncManager`

- [ ] Implement `Future<SyncResult> pushAll()` in `SyncManager`:
  - [ ] Fetch all rows from `pos_orders` where `syncStatus = 'pending'` via `transactionDao.getPendingOrders()`
  - [ ] For each pending order, also fetch its items via `transactionDao.getItemsForOrder(localId)`
  - [ ] Build `List<CreatePosOrderRequest>` batch payload — include `localId` in each item
  - [ ] POST to `POST /PosOrders/BatchSync`
  - [ ] Parse response `results` array:
    - [ ] For each `{ localId, serverId, success: true }`: call `transactionDao.markOrderSynced(localId, serverId)`
    - [ ] For each `{ localId, success: false, error }`: call `transactionDao.markOrderFailed(localId, error)`
  - [ ] Push cash movements: batch-POST to `/CashMovements/BatchSync` (create this endpoint if not exists; alternatively POST individually for now)
  - [ ] Push Z-reports: POST to `/ZReports/Sync` individually (Z-reports are low frequency)
- [ ] Implement `Future<SyncResult> sync()` = `pushAll()` then `pullDelta()` — always push before pulling to ensure server has the latest transactions before we overwrite local master data

### 5.3 — Wire Sync Button

- [ ] Add sync `IconButton` to `MainLayout` AppBar (or dedicated Settings → Sync screen)
- [ ] `onPressed`: call `ref.read(syncStateProvider.notifier).sync()`
- [ ] During sync: button is disabled, shows spinner
- [ ] On success: show `showAppSnackbar(context, ref, 'Sync complete — ${result.pushed} pushed, ${result.pulled} pulled')`
- [ ] On failure: show `showAppSnackbar(context, ref, 'Sync failed: ${result.errors.first}', isError: true)`

### 5.4 — Auto-Sync on Connectivity Restore

- [ ] Add `connectivity_plus` listener in `MainLayout.initState()`:
  ```dart
  ConnectivityPlus().onConnectivityChanged.listen((result) {
    if (result != ConnectivityResult.none) {
      ref.read(syncStateProvider.notifier).sync(); // non-awaited, fire-and-forget
    }
  });
  ```
- [ ] Add debounce (min 10 seconds between auto-sync triggers) to prevent hammering the API on flaky connections
- [ ] Verify: go offline → complete an order → come back online → sync triggers automatically → order appears on server

### 5.5 — Failed Sync Screen

- [ ] Create `lib/sync/failed_syncs_screen.dart`:
  - [ ] Lists all orders/movements where `syncStatus = 'failed'`
  - [ ] Shows error message per row
  - [ ] "Retry" button per row: resets `syncStatus = 'pending'` and triggers a targeted push
  - [ ] "Discard" button per row (with confirmation dialog): deletes the local row — use with caution, data is lost
- [ ] Link to "Failed Syncs" screen from Settings or from the sync badge long-press

### 5.6 — End-to-End Integration Test

- [ ] Test scenario: **Full offline session**
  - [ ] Disable network
  - [ ] Open table, add items, complete checkout → verify receipt prints
  - [ ] Record cash-in movement
  - [ ] Close day (Z-report)
  - [ ] Restore network
  - [ ] Tap Sync button
  - [ ] Verify all 3 transactions appear on the server with correct data
  - [ ] Verify `sync_status = 'synced'` and `server_id` populated in local DB for all rows
- [ ] Test scenario: **Partial failure**
  - [ ] Create an order referencing a product that was deleted on the server while offline
  - [ ] Sync → verify that order is marked `failed` with a meaningful error message
  - [ ] Verify the other orders in the same batch still sync successfully
- [ ] Test scenario: **Delta pull correctness**
  - [ ] Add a new product on the server via the admin panel
  - [ ] Trigger sync from the POS app
  - [ ] Verify the new product appears in the menu grid without a full reseed
  - [ ] Verify an old product that was NOT modified does NOT appear in the delta pull response

---

## Appendix: Constraint Checklist (Check Before Every PR)

- [ ] No `BlobColumn` used for images anywhere in Drift schema — images go to disk, paths go in DB
- [ ] `AppProperties` sync uses per-key timestamp comparison, never full-table replace
- [ ] All transaction writes set `syncStatus = 'pending'` before any API call
- [ ] `UUID` (v4) used for all `localId` fields — never auto-increment integers for local-first records
- [ ] All sync errors surface via `showAppSnackbar(..., isError: true)` — no silent failures, no uncaught exceptions
- [ ] `ref.invalidate(...)` is no longer called after mutations that have been migrated to Drift — Drift `StreamProvider`s update automatically; manual invalidation causes double-rebuilds
- [ ] `Device ID` is stable across app restarts (stored in `shared_preferences`), not re-generated on each launch
- [ ] Backend `LastModified` columns are set in UTC — all Flutter `DateTime` comparisons use `.toUtc()`
- [ ] `schemaVersion` in `AppDatabase` is bumped for every schema change, with a migration strategy defined

---

*Last updated: 2026-05-27 — Resume from the first unchecked box.*


---


<a id="3--adr-001--offline-first-sync"></a>

# 3 · ADR-001 — Offline-First Sync

> _Source (now consolidated): `docs/ADR-001-offline-first-sync.md`_

# ADR-001: Offline-first sync for the Flutter POS

**Status:** Proposed
**Date:** 2026-05-13
**Deciders:** ilyass chah (solo backend + frontend)
**Scope:** `/Front-End` (Flutter Windows/Android), `/Back-End` (.NET 8/9 + SQL Server)

## Context

The POS runs on Windows touch monitors and 13" Android tablets in retail/restaurant settings. Network drops are routine — Wi-Fi flaps, ISP outages, a backend deploy mid-shift. The current architecture is online-only: Dio calls hit the .NET API, which talks to a single SQL Server. When the network goes, the cashier cannot:

- Look up a product or price
- Add an item to the cart
- Save an order
- Print a receipt with a server-issued order number

Forces at play:

1. **Single SQL Server.** No replicas, no Service Broker fan-out, no second region. Whatever sync we pick must terminate at one writer.
2. **Solo developer across back-end and front-end.** Every operational surface added is one more thing to babysit. Ops burden weighs as heavily as feature scope.
3. **Inventory is shared, mutable, and contested.** Two terminals can sell the last unit. The system has *delta-based reservation logic* on the server side (per `CLAUDE.md`) — offline writes must round-trip through it, not bypass it.
4. **Order IDs and receipts.** Customers expect a printed number at checkout. A locally-issued number that mutates after reconnect is a support headache.
5. **Cross-platform Flutter.** Windows .exe + Android .apk. Anything platform-specific (e.g. SQL Server Express on Windows) is disqualified by the Android target.

The decision is: **what offline-first architecture do we adopt for the POS terminal, given those constraints?**

## Decision

Adopt **Option A — Local SQLite mirror + outbox queue + delta pull** as the offline architecture for the Flutter POS, implemented in two phases:

- **Phase 1 (ship first):** Read-side cache (products, prices, customers, warehouses) in a local SQLite store + outbox queue for order POST/PATCH. Inventory checks remain server-authoritative; offline orders are "tentative" until the server accepts them on reconnect.
- **Phase 2 (after Phase 1 is stable):** Delta-pull for master data using `RowVersion`/`UpdatedAt` watermarks, conflict surfaces in the UI for the rare reject case, and an "offline receipt" with a provisional number that gets reconciled to the server number on flush.

This avoids introducing a sync platform (Couchbase Lite, Realm, Firestore) — none of which terminate cleanly at one SQL Server with one dev maintaining it.

## Options Considered

### Option A: Local SQLite mirror + outbox queue (recommended)

Flutter app keeps a local SQLite database via `drift` or `sqflite_common_ffi` (works on both Windows and Android). Three jobs:

1. **Read mirror** — products, customers, warehouses, recent orders pulled on app start and refreshed periodically.
2. **Outbox** — when a POST/PATCH/DELETE fails (or the app is offline), the request is serialized to a local `pending_operations` table with idempotency key. A background isolate flushes it on reconnect.
3. **Server reconciliation** — server is source of truth for inventory and order numbers. The terminal shows a "Provisional #P-xxxx" until the real server ID arrives.

| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium — bounded; only one new subsystem (outbox). |
| Cost | Zero infra cost. SQLite is embedded. |
| Scalability | Per-terminal storage trivially small (megabytes). |
| Team familiarity | Solo dev — pattern is well-documented in Flutter/.NET. |
| Ops burden | Low — no new server, no replication topology. |
| Conflict handling | Server-authoritative; UI shows reject + fallback. |

**Pros**
- One SQL Server, unchanged. No replication, no broker.
- Idempotency keys + server-side `RowVersion` give safe replay without duplicates.
- Inventory delta logic on the server remains the single source of truth — no rewrite.
- Works identically on Windows .exe and Android .apk.
- Easy to reason about: read-cache + outbox is a small surface area.

**Cons**
- Tentative orders need clear UI affordance — cashier must understand "this isn't final until we're back online."
- Inventory checks during offline cart-building are stale; you can sell air. Mitigated by short pull intervals and "soft" client-side reservation.
- Receipt printing during offline needs a provisional ID format that survives reconciliation.

### Option B: Couchbase Lite / Realm Sync / Firestore (managed sync engine)

Replace direct API calls with a sync engine that gives you offline-first storage and CRDT/last-writer-wins conflict resolution out of the box. You'd stand up a Sync Gateway (or use Firestore as backing) and write a SQL Server bridge.

| Dimension | Assessment |
|-----------|------------|
| Complexity | High — two data stores (SQL Server + sync engine) + a bridge. |
| Cost | License/SaaS recurring cost (Couchbase, Realm/MongoDB Atlas, Firestore reads/writes). |
| Scalability | Excellent, but not the bottleneck here. |
| Team familiarity | Unknown — new platform for a 1-person team. |
| Ops burden | High — another server/SaaS to monitor, version, secure. |

**Pros**
- Out-of-the-box conflict resolution.
- Built for offline-first; mature mobile SDKs.
- Real-time push to terminals "for free."

**Cons**
- You now have two systems of record. Reconciling Couchbase docs back to your normalized SQL schema (with EF Core `PosOrder`/`PosOrderItem`) is a permanent maintenance job.
- Inventory delta logic — currently expressed in MediatR command handlers against EF entities — would have to be ported or fronted by a sync layer that calls back into the API.
- For a single SQL Server + solo dev, the integration effort never pays back.

### Option C: Plain HTTP retry queue, no local DB ("offline tolerance" only)

Keep the API online-only for reads. Cache the product catalog in memory or a small SQLite/file blob on app start. Queue order POSTs in memory + a small disk file. Flush on reconnect.

| Dimension | Assessment |
|-----------|------------|
| Complexity | Low. Smallest possible change. |
| Cost | Zero. |
| Scalability | Per-terminal only. |
| Team familiarity | Already how Dio is used today. |
| Ops burden | None. |

**Pros**
- Shippable in days.
- Almost no new code.

**Cons**
- App is useless on cold start without network — no cached products visible.
- No order history visible offline (cashier can't reprint).
- Doesn't scale to the obvious next ask ("can we see today's orders?", "can we add a customer offline?"). You'll rewrite to Option A within months.

### Option D: SQL Server replication or Sync Framework (per-terminal local SQL)

Install SQL Server Express on each Windows terminal, set up merge replication or Microsoft Sync Framework.

| Dimension | Assessment |
|-----------|------------|
| Complexity | High. |
| Cost | License surface grows; ops scripts per terminal. |
| Scalability | Fine, but irrelevant here. |
| Team familiarity | Replication is a specialist topic. |
| Ops burden | Very high — per-terminal SQL instances. |

**Pros**
- Native SQL Server tooling.

**Cons**
- **Disqualified by Android.** SQL Server Express does not run on Android tablets. Half the fleet has no story.
- Even on Windows, per-terminal SQL Server Express plus merge replication is a heavy operational surface for one person.

## Trade-off Analysis

The decision turns on three axes:

1. **One SQL Server vs. introducing a second data tier.** Options B and D add infrastructure. Given a single-dev team, every new tier is paid for in 24/7 support attention. Only A and C avoid this.
2. **Are offline reads needed, or just offline writes?** Option C handles only writes; the cashier can't browse the catalog or look up a recent order on a cold start without network. In practice POS users *expect* read availability the moment the app opens. A wins this on real-world usability.
3. **Conflict semantics.** Inventory is the hard case. Options B's "automatic" conflict resolution actively *hurts* — it would resolve "two terminals sold the last unit" by accepting both, then leaving the operator to discover the oversell from reports. Option A's server-authoritative reject + cashier-visible "out of stock, please refund" is the correct semantic for a POS.

A is the smallest design that handles all three correctly. C is a stepping stone toward A and is included in the plan as Phase 1's scope ceiling.

## Consequences

**What becomes easier**
- POS keeps working through routine Wi-Fi flaps and short outages.
- Cashier can look up products and recent orders offline.
- Sync subsystem is small and inspectable — one `pending_operations` table on the device, one idempotency-key column on relevant `Pos*` tables server-side.
- Existing `CreatePosOrderCommand`/EF inventory delta logic on the back-end is reused verbatim; the outbox just replays the same HTTP calls.

**What becomes harder**
- Every server-side mutation endpoint (`CreatePosOrderCommand`, `UpdatePosOrderCommand`, payment endpoints) must accept and enforce an `Idempotency-Key` header to make replay safe. This is an API contract change, not a schema change.
- The UI needs an explicit "Offline" / "Syncing" / "Synced" indicator and a tray showing the outbox queue. Without it, the cashier won't know whether an order is final.
- Provisional order numbers must be visually distinct from server numbers on receipts (e.g. `P-2026-05-13-0042` vs. `2026-05-13-0042`).
- Reject handling on flush — when the server returns 400 `{ success: false, ... }` per the project's structured-error convention, the outbox processor must surface that to the cashier and *not* silently retry forever.

**What we'll need to revisit**
- After ~6 months of Phase 1 in production: if the rate of inventory rejects on flush is high (>0.5% of offline orders), we may need a *soft client-side reservation* — broadcasting "I'm holding 2 of SKU X for 60s" via a server-pushed reservation channel. That's a meaningful design change and gets its own ADR.
- If a customer ever needs multi-region or franchise rollout, A doesn't scale to that; we'd revisit B at that point.
- Multi-terminal in the same store: today, two terminals offline could each commit conflicting writes. A handles this server-side via reject + cashier override. If shops grow past 3–4 terminals, consider peer-to-peer LAN sync (a bigger ADR).

## Action Items

### Backend (`/Back-End`)
1. [ ] Add `Idempotency-Key` middleware to the .NET API. On `POST /api/pos-orders`, `PATCH /api/pos-orders/{id}`, payment endpoints, store the key + response hash in a new `IdempotencyKeys` table; return the cached response on retry. (No EF domain-model changes — per project rule #1.)
2. [ ] Add an `UpdatedAt` (datetime2) and `RowVersion` (rowversion) column to `Product`, `Customer`, `Warehouse`, `Stock`, `PriceList` via a single migration. Expose `GET /api/sync/{entity}?since={timestamp}` endpoints for delta pulls.
3. [ ] Make sure all mutation endpoints return the project's structured `{ success, message, ... }` 400-response shape on business rejects (per project rule #4) — the Flutter outbox depends on parsing this.

### Frontend (`/Front-End`)
4. [ ] Add `drift` (cross-platform: works on Windows .exe + Android .apk) and define a local schema mirroring read-only entities + a `pending_operations` table.
5. [ ] Wrap the existing Dio client in a `SyncableApiClient` — on network failure, write the request (method, path, body, headers, idempotency key) to `pending_operations` and return a synthetic "queued" response that the UI treats as tentative.
6. [ ] Build a background isolate / timer that flushes `pending_operations` FIFO when connectivity returns, retries with exponential backoff, and routes 4xx rejects to a "needs attention" tray.
7. [ ] Add a Riverpod `connectivityProvider` and a `syncStatusProvider` (Idle / Offline / Syncing(n) / NeedsAttention(n)) and render an indicator chip in the AppBar. Use Material 3 theme tokens — no hardcoded colors (per project rule #3).
8. [ ] On order finalization while offline: generate a provisional ID `P-{yyyyMMdd}-{terminal}-{seq}`, print receipt with provisional marker, store mapping so the UI can swap to server ID when the outbox flushes.

### Validation & rollout
9. [ ] Flip the network off on a real terminal for 5 minutes during a test shift. Verify: cart works, order saves locally, reconnection flushes, inventory delta logic on the server still computes correctly.
10. [ ] Run a chaos drill: 3 minutes of intermittent connectivity (5s up / 10s down) while a cashier completes 10 orders. Confirm zero duplicates server-side (idempotency keys working).
11. [ ] After two weeks in production, pull metrics on: outbox flush latency p95, reject rate on flush, count of provisional-to-final ID reconciliations. Use those to size Phase 2.

---

**Open question for you:**
Do you want me to draft the SQL migration for `IdempotencyKeys` + the `RowVersion`/`UpdatedAt` columns now, or first sketch the Flutter `drift` schema and `SyncableApiClient` wrapper? Either is a natural Phase 1 starting point.


---


<a id="4--adr-002--saas-multi-tenancy--hardware-security"></a>

# 4 · ADR-002 — SaaS Multi-Tenancy & Hardware Security

> _Source (now consolidated): `docs/ADR-002-saas-multitenancy-and-hardware-security.md`_

# ADR-002: SaaS Multi-Tenancy & Hardware-Bound Security Architecture

**Status:** Proposed — Roadmap blueprint (foundations partially in place; see per-pillar status)
**Date:** 2026-06-16
**Deciders:** ilyass chah (solo backend + frontend)
**Scope:** `/Back-End` (.NET 8/9 + SQL Server), `/Front-End` (Flutter Windows/Android, Drift), `/kitchen_display`
**Supersedes / extends:** builds on [ADR-001 — Offline-first sync](./ADR-001-offline-first-sync.md)

---

## 1. Context & Threat Model

The POS is a **local-first** application: each terminal reads and writes a local Drift/SQLite database 100% of the time and treats the C# API as a background sync target (see ADR-001). We are now commercializing it as a **multi-tenant SaaS** sold per-terminal (seat-based) on a subscription. That introduces three problems a local-first product must solve *without* a permanent network connection:

1. **Tenant isolation** — many businesses share the same backend and SQL Server. One tenant must never see or touch another tenant's rows.
2. **Subscription enforcement offline** — a tablet may run for days offline. We must stop service when a subscription lapses, yet not punish a normal short outage.
3. **Anti-theft / anti-piracy** — the entire dataset lives in a file on the customer's machine. We must make copying that file (or cloning a terminal to dodge seat limits) useless.

### Assets we protect
- **Code & business logic** (Dart binaries, C# API).
- **Local data files** (`pos_app.sqlite` — products, prices, customers, sales history).
- **Revenue integrity** (paid seat counts, active subscriptions).

### Adversaries
- A customer copying the `.sqlite` file to extract data or run an unlicensed second terminal.
- A customer cloning a fully-provisioned terminal image to add seats without paying.
- A lapsed tenant continuing to operate fully offline to avoid the billing check.

### Non-goals (V1)
- Defeating a determined reverse-engineer with kernel/debugger access. The goal is **raising the cost of casual cloning and data extraction well above the subscription price**, plus reliable detection-after-the-fact.

---

## 2. Existing Foundations We Build On

This blueprint is not greenfield. The following are **already in the codebase** and are the hooks each pillar extends:

| Foundation | Where it lives today | Reused by |
|---|---|---|
| `companyId` tenant filter on every tenant table | Backend EF entities + Drift tables (`Customer`, `Product`, `Document`, `ApplicationProperty`, …) | Pillar 1 |
| Key/value settings metadata store | `ApplicationProperty` (backend) / `app_properties` (Drift), `companyId`-scoped | Pillar 2 (lease token) |
| Per-device identity | `deviceId` query param on `/Users/GetAllUsers`; `UserDevicePins` table | Pillars 4 |
| Local SQLite via Drift | `NativeDatabase.createInBackground(pos_app.sqlite)` | Pillar 3 |
| Sync pipeline with `syncStatus` + `lastModified` watermarks | `lib/sync/sync_manager.dart`, `/PosOrder/BatchSync` | Pillars 4, 5 |
| UUID local primary keys on transactions | `PosOrder.localId`, `Document.localId` (Drift) | Pillar 5 |
| Enterprise document numbering `YY-CCC-NNNNNN` | `DocumentsCounterRepository`, `DocumentTypeConstants` | Pillar 5 |

---

## 3. Engineering Pillars

### Pillar 1 — Multi-Tenant Database Partitioning Strategy

**Status:** Logical isolation IMPLEMENTED (`companyId`); Master SaaS DB PLANNED.

We use a **shared-schema, shared-database** tenancy model with a strict tenant discriminator, split across two logical databases:

**A. Master SaaS Database (cloud-only — to build).**
The control plane. Never replicated to a terminal. Holds:
- `Tenant` — one row per business: `tenantId`, `companyId`, status (`active` / `past_due` / `suspended` / `cancelled`), `createdAt`.
- `Subscription` — Stripe linkage: `stripeCustomerId`, `stripeSubscriptionId`, `priceTier`, `seatAllowance`, `currentPeriodEnd`, `billingStatus`.
- `TenantUser` / owner profiles — the SaaS account holders (distinct from in-POS `PosUser` operators).
- `DeviceRegistry` — registered terminal fingerprints per tenant (see Pillar 4).
- `BillingEvent` — append-only Stripe webhook ledger (idempotent).

**B. Tenant Data (operational — exists today).**
The POS business data. Currently a single shared SQL Server where **every tenant table carries a non-null `CompanyId` FK** and every query is filtered by it. This is the isolation boundary:
- Backend: each EF entity has `CompanyId`; controllers/handlers require it (`if (companyId == 0) return BadRequest(...)`).
- Frontend: every Drift tenant table has `companyId`; `sync_manager` pulls/pushes scoped by the active company.
- Global reference tables (`Country`, `Currency`, `DocumentType`, `DocumentCategory`) deliberately have **no** `CompanyId` — they are shared and read-only (see Pillar-adjacent note below).

> **Isolation invariant:** *No tenant query may execute without a resolved `companyId`.* This is enforced today by validation guards and is the single most important security property of the system. Future hardening: a global EF query filter (`HasQueryFilter`) and Drift DAO wrappers that make a missing `companyId` a compile/runtime error rather than a convention.

**Why shared-schema (not DB-per-tenant) for V1:** one SQL Server, one writer, solo operator (per ADR-001). DB-per-tenant multiplies migration, backup, and connection-pool burden with no isolation gain over a strictly-enforced discriminator. Revisit only if a tenant needs data-residency or per-tenant restore.

---

### Pillar 2 — Cryptographic Offline Subscription Leases

**Status:** PLANNED. Token store (`ApplicationProperty`) exists.

The app must keep working offline through normal outages but stop when the subscription truly lapses. We solve this with a **short-lived, signed, offline lease** — never a hard "phone home on every boot."

**Token shape (`license.lease`):** a signed token (JWT/PASETO) stored in settings metadata under a reserved key, e.g. `ApplicationProperty["License.Lease"]` / `app_properties`:
```
{
  "tenantId":   "...",
  "companyId":  42,
  "seatAllowance": 2,
  "validUntil": "2026-07-15T00:00:00Z",   // grace-extended billing period end
  "issuedAt":   "2026-06-16T09:12:00Z",
  "deviceBound": "<device-fingerprint-hash>"  // ties the lease to this terminal
}
```
- **Signed by the backend's private key**; the Flutter app holds only the **public key** and verifies the signature. The app can therefore validate a lease fully offline and cannot forge `validUntil`.
- **Issued/renewed on every successful sync.** Each sync round-trip returns a fresh lease whose `validUntil` = `Subscription.currentPeriodEnd` + a configurable **grace window** (e.g. +3 days) so a renewal that's a few hours late never locks a paying customer out.

**Offline guard rule (boot + periodic):**
1. On boot and on a periodic timer, read `License.Lease`, verify signature, check `deviceBound` matches this machine's fingerprint (Pillar 3).
2. If `now < validUntil` → full operation.
3. If `now >= validUntil` → enter a **read-only block layout**: the cashier can view data but cannot create/checkout orders, refunds, or documents; a persistent banner explains "Subscription needs to refresh — connect to the internet to sync." Reconnecting triggers a sync, which (if billing is current) returns a fresh lease and lifts the block.
4. **Anti-clock-rollback:** store the **max `validUntil` and last-seen server time** seen so far in tamper-resistant metadata; if the system clock is set *backwards* relative to the last trusted server timestamp, treat the lease as expired. (System clock is advisory only; the signed `validUntil` + monotonic high-water mark is authoritative.)

> The block is **graceful and reversible** — it is a billing nudge, not data destruction. We never delete tenant data on lapse.

---

### Pillar 3 — Hardware-Bound Database Encryption (Anti-Theft)

**Status:** PLANNED. Currently raw `NativeDatabase` (unencrypted `pos_app.sqlite`).

Upgrade the local store from raw SQLite to **SQLCipher (AES-256, full-file page encryption)** so the `.sqlite` file is unreadable at rest and **bound to the physical machine that created it**.

**Key derivation (the core rule):** the SQLCipher passphrase is **never hardcoded** in the Dart binary. It is derived at runtime:
```
key = KDF( appSalt  ||  hardwareFingerprint  ||  tenantSecret )
```
where:
- `appSalt` — a private constant delivered out-of-band (compiled-in obfuscated and/or fetched once at provisioning), rotated per release.
- `hardwareFingerprint` — a stable hardware identifier queried natively per platform:
  - **Windows:** motherboard/SMBIOS UUID or disk/CPU serial via WMI, optionally wrapped by **DPAPI**.
  - **Android:** a key in the hardware-backed **Android KeyStore** (StrongBox where available) — the KeyStore key never leaves secure hardware.
  - **iOS/macOS:** a key in the **Keychain / Secure Enclave**.
- `tenantSecret` — a per-tenant secret provisioned at first activation and stored in the platform secure store (KeyStore/Keychain/DPAPI), **not** in the DB file.

**KDF:** Argon2id (or PBKDF2-HMAC-SHA256 with a high iteration count) over the concatenated inputs. The derived key is held in memory only for the lifetime of the DB connection.

**Anti-theft outcome:** copying `pos_app.sqlite` to another machine fails — the new machine's `hardwareFingerprint` (and absent `tenantSecret` in its secure store) produce a different key, SQLCipher cannot decrypt the pages, and the app **fails closed on launch** with a "this database is bound to another device" error rather than opening with garbage.

**Migration path:** ship a one-time, on-device re-encryption step — open the existing plaintext DB, `ATTACH` a new SQLCipher DB with the derived key, copy, swap, and securely delete the plaintext file. Gated behind a schema/version flag so it runs exactly once per terminal.

> **Platform abstraction:** the native fingerprint + secure-store access must sit behind a single Dart interface with per-platform implementations (method channels), honoring the project's cross-platform rule. Windows and Android are required; iOS/macOS stubs are forward-looking.

---

### Pillar 4 — Server-Side Seat Counter Validation

**Status:** PLANNED. `deviceId` tracker EXISTS (`/Users/GetAllUsers`, `UserDevicePins`).

Subscriptions are sold per terminal ("seats"). The server enforces the cap on the **sync ingress path**, using the `deviceId` already threaded through requests.

**Mechanism:**
1. Every terminal owns a stable **device signature** = the `hardwareFingerprint` from Pillar 3 (hashed). It is sent on every sync/push request (extends the existing `deviceId` parameter into a first-class header/claim, e.g. `X-Device-Id`).
2. The Master DB `DeviceRegistry` maps `companyId → { deviceId → status }`, and `Subscription.seatAllowance` holds the paid cap (e.g. Tenant X = 2 terminals).
3. **On the first push from a new `deviceId`,** the server attempts to register it:
   - If `registeredDeviceCount < seatAllowance` → register, allow.
   - If it would exceed the cap → **reject the upload with `403 Unauthorized` / a structured `seat_limit_exceeded` error**, drop the batch (no partial write), and surface the offending `deviceId` for the tenant admin.
4. Registered devices sync normally; the seat check is O(1) and only meaningful for *new* signatures.

**Guard rule:** an unregistered or cloned device signature that pushes the active count over the tier allowance is refused at the API boundary and never writes tenant data. This pairs with Pillar 5 — even if a clone *avoids* the seat check by staying offline, its eventual sync gives it away.

> Implementation note: the seat decision belongs in the **Master DB** (control plane), checked inside the BatchSync handler before any tenant write, inside the same transaction as the device-registration upsert to avoid races between two simultaneous new devices.

---

### Pillar 5 — Transaction Duplication & Conflict Detection

**Status:** PLANNED. UUID localIds + document numbering EXIST.

A cloned database run fully offline can dodge the live seat check — but it **cannot stay consistent** with the original once both eventually sync. We turn that into a detector.

**What a clone leaks at sync time:**
- **Duplicate UUID local IDs.** Each transaction is created with a client UUID (`PosOrder.localId`, `Document.localId`). A clone inherits the original's historical UUIDs; when both terminals later push *new* work, the server sees **two distinct devices claiming the same historical UUID chain** or re-pushing already-synced `localId`s — an impossible event for a single legitimate device.
- **Document-number sequence collisions / gaps.** Numbering is `YY-CCC-NNNNNN` per company. Two clones independently minting numbers from the same starting counter produce **duplicate or out-of-order invoice numbers** within one `companyId`.
- **Receipt-name / order-name collisions** and **out-of-order `lastModified` / `openedAt` timelines** (e.g. a "new" order whose timestamp predates the last synced order from that device).

**Server-side audit pass (async, post-ingest):**
1. On each BatchSync, record `(companyId, deviceId, localId, serverNumber, clientTimestamp)`.
2. A background auditor flags a tenant when it sees, within one `companyId`:
   - the same `localId` arriving from two different `deviceId`s,
   - duplicate or non-monotonic `serverNumber` / receipt-number sequences,
   - timeline anomalies (push timestamps that regress past the device's last-seen high-water mark).
3. Flags raise a **soft administrative alert** (tenant marked `review_required` in the Master DB) — *not* an automatic lockout. A human reviews before any enforcement, to avoid penalizing legitimate edge cases (device re-image, restore-from-backup, clock skew).

> This is **defense-in-depth**: Pillar 4 blocks live over-seating; Pillar 5 catches the offline-clone that tried to route around it.

---

## 4. Implementation Roadmap (Phased)

Each phase is independently shippable and ordered by risk/value.

| Phase | Pillar(s) | Deliverable |
|---|---|---|
| **0 — Hardening (now)** | 1 | Global EF `HasQueryFilter` on `companyId`; Drift DAO guards. Makes the existing isolation invariant enforced, not just conventional. |
| **1 — Master DB & device identity** | 1, 4 | Stand up the Master SaaS DB (`Tenant`, `Subscription`, `DeviceRegistry`, Stripe webhook ledger). Promote `deviceId` to a signed header. |
| **2 — Leases** | 2 | Backend lease issuance (signed `validUntil`) on every sync; Flutter public-key verification + read-only block layout + anti-rollback high-water mark. |
| **3 — Seat enforcement** | 4 | Seat-cap check + device registration inside BatchSync (rejects over-allowance pushes). |
| **4 — Hardware encryption** | 3 | Native fingerprint + secure-store method channels (Windows/Android); SQLCipher swap; one-time on-device re-encryption migration. |
| **5 — Clone detection** | 5 | Async audit pass + `review_required` flagging + admin surface. |

---

## 5. Risks, Trade-offs & Open Questions

- **Hardware fingerprint stability vs. legitimate hardware changes.** A motherboard/disk swap, OS reinstall, or VM migration changes the fingerprint and will (correctly) refuse to decrypt. We need a **supported re-activation flow** (admin de-registers the old device, the terminal re-provisions `tenantSecret` + re-encrypts). Treat fingerprint changes as a support event, not a silent failure.
- **Grace window tuning.** Too short punishes flaky connectivity; too long weakens enforcement. Start at +3 days, make it a per-tier server setting.
- **Clock manipulation.** Mitigated by the signed `validUntil` + monotonic server-time high-water mark, but a user with full machine control can still stall. The lease's bounded lifetime (forces periodic renewal) is the real backstop.
- **iOS/macOS** are forward-looking; only Windows + Android are in scope today.
- **Backup/restore** legitimately reintroduces historical UUIDs — the Pillar 5 auditor must treat `review_required` as advisory and correlate with known restore events before any action.
- **Key management for lease signing & `appSalt` rotation** must live in a real secret store (not source control); rotating either must not brick existing terminals (support overlapping keys during rotation).

---

*This document is a forward-looking architecture blueprint. Sections marked PLANNED are not yet implemented; the `companyId` isolation (Pillar 1) and the `deviceId` foundation (Pillar 4) are the parts that exist today.*


---


<a id="5--offline-first-audit--conversion-tracker"></a>

# 5 · Offline-First Audit & Conversion Tracker

> _Source (now consolidated): `docs/offline-first-audit.md`_

# Offline-First Audit & Conversion Tracker

**Status:** Living document — work through it screen by screen.
**Created:** 2026-06-18
**Related:** [ADR-001 — Offline-first sync](./ADR-001-offline-first-sync.md) (Local SQLite mirror + outbox queue + delta pull)

---

## ⚠️ Pillar 3 (DB encryption) temporarily DISABLED

> **Why:** so the local DB can be opened in DBeaver / LINQPad to verify that the
> offline-first writes produce exactly the data we expect. **Restore before
> shipping.**

- **Switch:** `kPillar3Encryption` in
  [`app_database.dart`](../Front-End/lib/database/app_database.dart) — currently
  **`false`**.
- **Behaviour while `false`:** the DB opens as **plaintext**; on launch
  `_decryptDbIfNeeded()` decrypts any existing SQLCipher file back to plaintext
  **in place (data preserved)**. The file is `pos_app.sqlite` in the OS documents
  dir (Windows: `C:\Users\<you>\Documents\pos_app.sqlite`) — open it directly in
  any SQLite tool, no key needed.
- **The key derivation (`DeviceKeyService`) is untouched** — only the open path
  changed.

### Re-enable checklist (after offline verification is done)
- [ ] Flip `kPillar3Encryption` back to **`true`**.
- [ ] Launch once — `_encryptLegacyDbIfNeeded()` re-encrypts the plaintext DB
      automatically (data preserved).
- [ ] Delete any plaintext copies you exported for inspection.
- [ ] Confirm `PRAGMA cipher_version` is non-empty at startup (the guard throws
      if SQLCipher isn't linked).

---

## The contract (what "offline-first" means here)

A screen is **offline-first** only if all three hold:

1. **Write-local-first.** Every create/update/delete writes to the local Drift DB
   *first* — with a temp negative id (for creates) and a `syncStatus` of
   `pending_create` / `pending_update` / `pending_delete`. The dialog closes
   immediately on the local write; it never blocks on the network.
2. **Read-local-first.** The list/detail reads from a Drift `StreamProvider`, so
   the local write shows up **instantly** (no refresh, no pull, no manual Sync).
3. **Background sync.** The SyncManager has a `pushPending<Entity>Ops` that drains
   the pending rows to the cloud (POST/PATCH/DELETE) and remaps temp→real ids.
   The auto-sync watcher debounce-pushes on each write, so the cloud catches up
   on its own. Manual **Sync** is optional, never required to see your own data.

**Reference implementations to copy:** Products
([`product_provider.dart`](../Front-End/lib/product/product_provider.dart),
`pushPendingProductOps`), Customers
([`customers_screen.dart`](../Front-End/lib/customer/customers_screen.dart#L645)),
Loyalty ([`loyalty_card_provider.dart`](../Front-End/lib/loyalty/loyalty_card_provider.dart)).

### The bug pattern we are eliminating ("split-brain")

> **Read = Drift stream, but Write = direct API call.**

The list shows only local rows, but the create POSTs straight to the server and
never writes locally. Result: **save → blank list** until a manual Sync *pulls*
the row back; **offline → the write is lost entirely.** This is exactly the Tax
Rates symptom. Proof for taxes: there is no `saveTaxLocal` in the database and no
`pushPendingTaxOps` in the SyncManager — taxes are **pull-only**.

---

## Status by screen / entity

Legend: ✅ offline-first · 🔴 split-brain (broken) · ⚪ online-only (reference/read-model) · 🟦 verify

| Screen / Entity | Read | Write | Sync | Status |
|---|---|---|---|---|
| Products | Drift stream | local-first (`pending_*`) | push+pull | ✅ |
| Product Groups | Drift stream | local-first | push+pull | ✅ |
| Customers & Suppliers (+discounts) | Drift stream | local-first | push+pull | ✅ |
| Promotions (+items) | Drift stream | local-first | push+pull | ✅ |
| Documents / Sales History (+items) | Drift stream | local-first | push+pull | ✅ |
| Payments | Drift stream | local-first | push+pull | ✅ |
| Stock + Stock Controls | Drift stream | local-first | push+pull | ✅ |
| Warehouses | Drift stream | local-first | push+pull | ✅ |
| Bookings + Booking History | Drift stream | local-first | push+pull | ✅ |
| Floor Plan / Tables | Drift stream | local-first | push+pull | ✅ |
| Loyalty Cards | Drift stream | local-first | push+pull | ✅ |
| Users & Security | Drift stream | local-first (`securityKeysTable` + `pendingUserOpsTable`) | push+pull | ✅ |
| Shifts / Time Clock | Drift stream | local-first | push+pull | ✅ |
| POS Menu / Cart / Open Orders | Drift stream | local-first | push+pull | ✅ |
| Cash In/Out (Starting Cash) | Drift stream | (no API in dialog) | — | 🟦 verify |
| Tax Rates | Drift stream | **local-first** (`pending_*`, schema v40) | push+pull | ✅ *(converted 2026-06-18)* |
| Payment Types | Drift stream | **local-first** (`pending_*`, schema v41) | push+pull | ✅ *(converted 2026-06-18)* |
| Void Reasons | Drift stream | **local-first** (`pending_*`, schema v42) | push+pull | ✅ *(converted 2026-06-18)* |
| My Company | Drift cache | **local-first** fields (schema v43); logo upload online | push+pull | ✅ *(converted 2026-06-18; logo online by design)* |
| Currencies | API `FutureProvider` | API | — | ⚪ |
| Countries | API `FutureProvider` | (reference) | — | ⚪ |
| Company switcher (all companies) | API `FutureProvider` | API | — | ⚪ cross-tenant, stays online |
| Reporting / Dashboard | API `FutureProvider` | read-only | — | ⚪ server-computed, acceptable |
| Product Import | bulk API | bulk API | — | ⚪ inherently online |
| Settings / Printer Settings | local app-properties | local | — | ✅ (separate subsystem) |

---

## Why it ended up like this

The app began **100% API-backed**. Offline-first was added **later, entity by
entity**, prioritising the POS hot path (products, documents, payments, customers,
bookings…). Each of those got the *full* treatment: a local `saveXLocal`, a
`pushPending<Entity>Ops`, and a Drift-stream read.

The low-traffic **settings/reference** screens (Tax Rates, Payment Types, Void
Reasons, My Company) got only **half** the migration: their **read** was switched
to a Drift stream (cheap — point the list at the synced cache) but their **write**
was left as the original direct-API call, and the push side was never built. That
half-finished state is the "save → blank until sync" symptom. It was a shortcut,
not a design decision.

---

## Conversion worklist (do one by one)

Each conversion mirrors the Products/Customers pattern. **Definition of done** per
entity:

- [ ] Add `save<Entity>Local()` to `app_database.dart` — insert/update Drift row
      with temp negative id + `pending_create`/`pending_update`; soft-delete sets
      `pending_delete`.
- [ ] Screen's save/delete handlers call the local method and pop immediately
      (no `createDio` in the UI path).
- [ ] Add `pushPending<Entity>Ops()` to `sync_manager.dart` — POST/PATCH/DELETE,
      with the **"temp id always POSTs"** rule + temp→real id remap (same fix
      applied to Products/Product Groups).
- [ ] Wire the pusher into the sync push sequence (before the matching pull).
- [ ] Confirm the auto-sync watcher debounce-pushes on write.
- [ ] Test: create offline → appears instantly → reconnect → pushes → survives
      app restart; edit offline; delete offline.

### Order of work

1. [x] **Tax Rates** — ✅ done 2026-06-18. Schema v40 (`taxes.sync_status`);
       `saveTaxLocal`/`deleteTaxLocal`/`remapTaxId`; `pushPendingTaxOps`;
       pull preserves pending rows; screen writes local-first (zero API in UI).
       **This is the reference template for the rest.**
2. [x] **Payment Types** — ✅ done 2026-06-18. Schema v41
       (`payment_types.sync_status`); `savePaymentTypeLocal`/`deletePaymentTypeLocal`;
       `pushPendingPaymentTypeOps`; pull preserves pending; screen local-first.
3. [x] **Void Reasons** — ✅ done 2026-06-18. Schema v42; `saveVoidReasonLocal`/
       `deleteVoidReasonLocal`; `pushPendingVoidReasonOps` (Add/Update via query
       params); `replaceVoidReasons` now preserves pending rows.
4. [x] **My Company** — ✅ done 2026-06-18. Schema v43; `pullCompany` now
       persists the full field set (was a lean cache) + preserves pending;
       `Company.fromDrift` maps all fields; `saveCompanyLocal` +
       `pushPendingCompanyOps` (PATCH); screen loads company + countries from the
       local cache, saves local-first. **Logo upload stays online by design.**
5. [ ] **Decision:** Currencies / Countries — migrate the same way *only if* edited
       in the field. Countries are effectively static; Currencies optional.

### Out of scope (intentionally online)

- Reporting / Dashboard — server-computed read models.
- Company switcher / cross-tenant lists — control-plane data.
- Product Import — bulk server-side operation.


---


<a id="6--project-audit-2026-07-04"></a>

# 6 · Project Audit (2026-07-04)

> _Source (now consolidated): `PROJECT_AUDIT.md`_

## ✅ Remediation Status (updated 2026-07-04)

> The original audit is preserved below as the record. This block tracks what has
> since been fixed vs what remains. **Full running detail is in `handoff.md`.**

**DONE (all CRITICALs + all OPT/UP; only the optional OPT-4 lint cleanup + UPGRADE-1 caveat remain below):**
- **CRITICAL-1** refund idempotency — FIXED (server dedups on `ClientDocumentNumber`; client persists+queues on ambiguous failures).
- **CRITICAL-2** refund double stock reversal — CLOSED as a **false alarm** (no stock trigger exists; stock is adjusted in C#, not triggers). The misleading `sync_manager.dart` comment was corrected.
- **OPT-1** eager table rows → lazy `rowBuilder`. · **OPT-2** MenuScreen narrows its `cartProvider` watch. · **OPT-3** no more raw `Notifier.state` mutation. · **OPT-6** refund outbox fully on Drift (schema **v49**; `shared_preferences` queue removed). · **OPT-7** `'pending'` vs `'pending_create'` invariant made explicit (`SyncStatuses`).
- **UP-1** the 3 DB triggers scripted into `DataBase/SQL/`. · **UP-4** daily order counter → Drift + local-day bucketing. · **UP-5** checkout captures the Navigator before popping.
- **OPT-4** `flutter_lints` re-enabled; 154 auto-fixes + 5 real `use_build_context_synchronously` bugs fixed (0 errors/warnings).
- **OPT-5 / UP-6 (hardcoded colours) — DONE (2026-07-09).** `StatusColors` extension applied app-wide: after the initial `payment_checkout_dialog`/`menu_screen`/`bookings_screen`, the remaining 21 screens/dialogs were migrated (products, settings, stock, document_editor, documents, promotions, product_import, currencies, users, user_info, warehouses, tax_rates, time_clock, product_groups, credit/cash/refund/sync dialogs, z_report, power_modal, shared_drawer, company_selection, sales_history). `dart analyze lib` still **0 errors / 0 warnings**. Confirming the "dark mode isn't broken" finding, deliberate constructs were intentionally left: domain **status→colour maps/selectors** (booking `_statusColors`, payment Paid/Partial/Unpaid, stock low/reorder/healthy), **fixed data palettes**, **`isDark`-conditional banners**, **accents** (indigo/blueGrey, admin-orange, gradient header), and the **QR white background**.

**IN PROGRESS / REMAINING:**
- **OPT-4 residual** — 24 `use_build_context_synchronously` remain, all *guarded-but-imprecise* (functionally safe; the passed `ctx` is the State's `context`). Optional zero-lint cleanup.
- **UPGRADE-1 caveat** — triggers are now scripted, but EF's `HasTrigger("…")` labels are still fictional names (harmless; renaming needs an EF migration — deferred).

**PLANNED (not audit items, tracked in `handoff.md`):** LAN Sync Hub (design in §… of handoff, OPT-6 was its prerequisite); remaining inert settings (email/SMTP, serial scale, localization); broader backend `[Authorize]` + per-user audit/PIN salt; production secrets + API restart.

---

# PROJECT AUDIT — POS Ecosystem

**Auditor role:** Principal Systems Architect & Senior Flutter Engineer
**Date:** 2026-07-04
**Scope:** `/Front-End` (Flutter POS, 176 Dart files — primary focus), `/kitchen_display` (KDS), `/Back-End` (C# .NET API), and the JSON contracts between them.
**Method:** Read the docs (`CLAUDE.md`, `project_handover.md`, `docs/ADR-001/002`, `docs/offline-first-audit.md`), then traced the hot paths (checkout, refund, sync, menu) and cross-referenced the POS ⇄ Backend ⇄ KDS payload shapes.

---

## Executive Summary

The codebase is **mature and, on the sales hot path, genuinely well-engineered.** Offline-first checkout writes to Drift with `syncStatus:'pending'` and never touches the network in the UI thread ([`payment_checkout_dialog.dart:293-521`](Front-End/lib/cart/payment_checkout_dialog.dart)); the SyncManager drains a clean push/pull outbox; the KDS wire contract matches on both sides; and there is essentially **no TODO/placeholder debt** in `lib/` (one `UnimplementedError`, which is the standard Riverpod provider-override idiom).

That makes the findings below sharper rather than broader. The single most important issue is a **cross-boundary refund idempotency gap** that can double-refund money and double-restock inventory. There are **no reproducible crashes or memory leaks** in the reviewed hot path (the floor-plan `Timer` is correctly cancelled in `dispose`), so the "application-crashing" bucket is thin by design — I have not invented entries to fill it. The largest *systemic* issue is UI-theme drift: ~300 hardcoded `Colors.*` references that break the app's dark/"Night"/high-contrast themes, made possible because the linter is switched off.

| Boundary contract | Status |
|---|---|
| POS → Backend refund (`RefundPayload` ⇄ `ProcessRefundRequest`) | ✅ shape matches — ⚠️ **not idempotent** (see CRITICAL-1) |
| POS → Backend order (`_orderToBatchJson` ⇄ `PosOrderBatchSyncDto`), incl. per-item taxes remapped `id`→`taxId` at [`sync_manager.dart:1228`](Front-End/lib/sync/sync_manager.dart) | ✅ matches |
| POS → KDS order/item ([`kitchen_push_service.dart:145`](Front-End/lib/kitchen/kitchen_push_service.dart) ⇄ [`kds_models.dart:20`](kitchen_display/lib/kds_models.dart)) | ✅ matches (incl. `comment`, `orderRef` echo) |
| Item `comment` / `discountType` / tax routing | ✅ present end-to-end |

---

## 🔴 CRITICAL FIXES (Do This Right Now)

### CRITICAL-1 — Refunds are not idempotent → double refund of money **and** stock
**Files:** [`Front-End/lib/refund/refund_service.dart:241-295`](Front-End/lib/refund/refund_service.dart) & `:413-450` (client) · [`Back-End/Web-POS.Api/Commands/RefundCommands/ProcessRefundCommand.cs:59-228`](Back-End/Web-POS.Api/Commands/RefundCommands/ProcessRefundCommand.cs) (server)

The refund path is *at-least-once delivery with no dedup on either end*:

- **Client re-sends on any failure.** `submitRefund` POSTs to `/Document/Refund` and only falls back to a local write when the `DioException` is a *connection* type (`connectionError/connectionTimeout/receiveTimeout`, lines 279-292). `syncPendingRefunds` retries with a **catch-all that keeps the item queued** (`catch (_) { remaining.add(raw); }`, lines 444-446). So a push that **commits server-side but loses its response** (a timeout *after* the transaction committed, a 502 from a proxy, an app kill mid-await) is re-sent on the next sync.
- **Server never checks for a prior refund with the same number.** `ProcessRefundCommandHandler.Handle` (and `HandleBlindRefundAsync`) take `req.ClientDocumentNumber`, keep it verbatim (line 130-132), and unconditionally create a new refund `Document`, reverse stock, and insert a **negative `Payment`** — with **no lookup** for an existing `Document` where `Number == ClientDocumentNumber`.

**Failure scenario:** Cashier refunds receipt #A. Network drops the response after the server committed. The client sees a non-connection error (or the queued item is retried) and submits again with the same `ClientDocumentNumber`. Result: **two refund documents, two negative payments (double cash out in the Z-report), and stock restocked twice.** Either the `Document.Number` unique constraint throws a 500 (refund appears "failed" though it succeeded), or duplicates land silently.

**Fix (both ends):**
1. **Server — make it idempotent.** Before creating, look up `Documents.FirstOrDefault(d => d.Number == refundNumber && d.CompanyId == … && d.DocumentTypeId == 220)`. If found, return that existing refund (`ProcessRefundResponse` with its number/total) instead of creating a second.
2. **Client — write-local-first, then push.** Mirror checkout: write the pending refund + restore local stock **first**, enqueue, and let the SyncManager push it; on *any* push error keep it pending (never rethrow-without-persist). This also fixes CRITICAL-3.

### CRITICAL-2 — Refund stock reversal may be applied twice (handler + DB trigger)
**File:** [`Back-End/Web-POS.Api/Commands/RefundCommands/ProcessRefundCommand.cs:182-201`](Back-End/Web-POS.Api/Commands/RefundCommands/ProcessRefundCommand.cs)

The handler does an **explicit** `stock.Quantity + ri.Quantity` reversal per line, guarded by the author's own comment:

```
// Note: if DocumentItem_Insert_Trigger already handles stock direction
// for DocumentType 220, remove this block to avoid double-counting.
```

That trigger is **not in source control** — `Back-End/Web-POS.Api/DataBase/SQL/` contains only `vw_*` views, no trigger scripts. So whether a refund over-restocks by 2× **cannot be determined from the repo** and is currently unverified in code review. This is exactly the class of ambiguity that should never ship.

**Fix:** Confirm on the live DB whether `DocumentItem_Insert_Trigger` (and any `*_Update/_Delete` trigger) adjusts stock for `DocumentType 220`. Pick **one** owner of the reversal (handler *or* trigger), delete the other, and script the trigger into the repo + a migration (see UPGRADE-1). Until confirmed, treat every refund's inventory effect as suspect.

> **Why these are CRITICAL and the color/UI issues are not:** CRITICAL-1/2 corrupt money and inventory totals — the two numbers a POS exists to get right — and they do it silently. Everything below degrades experience or maintainability but does not lose or corrupt data.

---

## 🟠 OPTIMIZATIONS (Short-Term Architecture)

### OPT-1 — Lazy list is fed by eager widget construction (jank on large history)
**File:** [`Front-End/lib/reports/sales_history_screen.dart:1300-1302`](Front-End/lib/reports/sales_history_screen.dart) (and the items table at `:1436`)

`_FlexTable`'s body is correctly lazy (`ListView.separated` with `itemBuilder`, [`:165`](Front-End/lib/reports/sales_history_screen.dart)) — but the caller **pre-builds every cell widget for every document** before handing them over:

```dart
final rows = _documents
    .map((doc) => visibleCols.map((c) => cellBuilders[c.id]!(doc)).toList())
    .toList();               // ← builds N docs × M columns Widgets up front
```

For a month of sales this instantiates thousands of `Widget` objects on every rebuild, of which the `ListView` mounts ~15. The lazy list is defeated. **Fix:** change `_FlexTable` to accept a `List<Widget> Function(int index)` row-builder and call it inside `itemBuilder`, so cells are constructed only for visible rows.

### OPT-2 — MenuScreen top-level `build` watches the entire cart
**File:** [`Front-End/lib/menu/menu_screen.dart:163`](Front-End/lib/menu/menu_screen.dart)

`_MenuScreenState.build` (an ~800-line method) does `ref.watch(cartProvider)`, so **every cart mutation** (add item, qty ±, discount) rebuilds the whole scaffold subtree. The product grid (`BrowserSection`) and cart (`CartSection`) are already separate `ConsumerStatefulWidget`s — good — but the header/action-bar rebuilds needlessly on each tap. **Fix:** watch only the slices the header needs (`ref.watch(cartProvider.select((c) => c.items.length))`, service type) rather than the whole `CartState`.

### OPT-3 — UI mutates a Notifier's protected `state` directly
**File:** [`Front-End/lib/menu/menu_screen.dart:493`](Front-End/lib/menu/menu_screen.dart) & `:592`

```dart
ref.read(cartProvider.notifier).state = ref.read(cartProvider).copyWith(serviceType: 0);
```

State is being written from the widget layer, bypassing the notifier — and a `setServiceType(val)` method already exists three lines below (`:497`). This compiles only because [`analysis_options.yaml:14`](Front-End/analysis_options.yaml) silences `invalid_use_of_protected_member`. **Fix:** move the branch into a `CartNotifier` method and call that.

### OPT-4 — The linter is effectively disabled
**File:** [`Front-End/analysis_options.yaml:10`](Front-End/analysis_options.yaml)

```yaml
# include: package:flutter_lints/flutter.yaml   ← the whole ruleset is commented out
```

With `flutter_lints` off across all 176 files, `use_build_context_synchronously` (relevant to OPT-6/UPGRADE-5), `avoid_print`, `prefer_const_constructors`, and the `unnecessary_*` family are **not enforced**. Two protected-member lints are additionally ignored (`:14-15`). **Fix:** re-enable `flutter_lints`, run `flutter analyze`, and burn down the backlog — it will surface much of this audit automatically and keep it from regressing.

### OPT-5 — Widespread hardcoded colors break dark / "Night" / high-contrast themes
**~300 real `Colors.*` references across ~38 files** (after excluding ~66 legitimate `PdfColors.*` used only in receipt/report PDF generation). This directly violates the strict theme-token rule in `CLAUDE.md` and `project_handover.md` §6.2. Worst offenders:

| File | Count | Notes |
|---|---|---|
| [`menu/menu_screen.dart`](Front-End/lib/menu/menu_screen.dart) | 48 | incl. `Colors.grey` avatar bg + `Colors.white` icon at `:2235` |
| [`bookings/bookings_screen.dart`](Front-End/lib/bookings/bookings_screen.dart) | 39 | |
| [`stock/stock_screen.dart`](Front-End/lib/stock/stock_screen.dart) | ~38 | incl. `Colors.black` text at `:656` |
| [`product/products_screen.dart`](Front-End/lib/product/products_screen.dart) | 36 | |
| [`settings/settings_screen.dart`](Front-End/lib/settings/settings_screen.dart) | 32 | |
| [`cart/payment_checkout_dialog.dart`](Front-End/lib/cart/payment_checkout_dialog.dart) | 21 | `Colors.green` pay button, `Colors.white` text, accent borders |

Two sub-classes: **(a)** semantic status colors (`Colors.green`=success, `Colors.red`=error, `Colors.amber`=loyalty) — harmless-looking but should be centralised (see UPGRADE-6); **(b)** literal `Colors.black` text / `Colors.grey`/`Colors.white` backgrounds — these actually go low-contrast or invisible in the true-black "Night" theme and are the ones a user will notice. **Fix:** prioritise (b) now; route (a) through a `ThemeExtension`.

### OPT-6 — Refund uses a second outbox (`shared_preferences`) alongside its Drift pending row
**File:** [`Front-End/lib/refund/refund_service.dart:389-408`](Front-End/lib/refund/refund_service.dart) (`_pendingRefundsKey`)

Every other entity drains through the Drift `pending_*` mechanism owned by the SyncManager (the canonical pattern in `docs/offline-first-audit.md`). Refunds keep a **parallel** queue in `SharedPreferences` *and* a Drift row, so "how many refunds are unsynced?" has two answers (`pendingRefundsCountProvider` vs the Drift rows) that can diverge. **Fix:** consolidate onto the Drift outbox so there is one source of truth and one pusher.

### OPT-7 — Implicit `'pending'` vs `'pending_create'` invariant is undocumented and fragile
**Files:** [`sync_manager.dart:3620`](Front-End/lib/sync/sync_manager.dart) (`pushPendingDocuments`), `:3874` (`pushPendingPayments`)

Checkout and refund write Documents/Payments with `syncStatus:'pending'` **specifically so** the generic pushers (which only select `pending_create/update/delete`) skip them — they sync via the order/refund command path instead. This is correct today and *is* what prevents a double-create, but it is an unwritten rule: a future dev who writes a checkout row as `'pending_create'` will silently double-create it server-side. **Fix:** make it explicit — a `SyncStatus` enum with a distinct value (e.g. `pendingViaOrder`) and a one-line comment at each write site.

---

## 🟢 UPGRADES (Long-Term Roadmap)

### UP-1 — Version-control the DB triggers and objects
`DataBase/SQL/` holds only views. The `DocumentItem_Insert_Trigger` (CRITICAL-2) and `trg_Document_CompanyConsistency` (per `project_handover.md` §3) live only in the live database — invisible to review, un-diffable, and not reproducible on a fresh install. Script every trigger/function into the repo and a migration. This is the root enabler of CRITICAL-2 being unverifiable.

### UP-2 — Rename the misleading migration
[`Migrations/20260516214546_AddWarehouseCompany.cs`](Back-End/Web-POS.Api/Migrations/20260516214546_AddWarehouseCompany.cs) is named `AddWarehouseCompany` but its `Up()` actually creates the **`UserDevicePins`** table. (Confirmed the real `AppDbContextModelSnapshot.cs` has **no** `WarehouseCompany` entity, so the documented "there is no `WarehouseCompany` table" rule still holds — the abandoned entity survives only in `.vs/CopilotSnapshots`.) Rename or annotate to avoid future confusion.

### UP-3 — Close the remaining offline-read holes
Per `docs/offline-first-audit.md`, Reporting/Dashboard, Currencies, Countries, the company switcher, and Product Import remain online-only, and **Cash In/Out (Starting Cash) is still marked 🟦 "verify."** Reports/Dashboard being API-only means those screens are **blank when offline** during a service outage — the exact moment staff might want the day's numbers. Consider a local aggregation for at least the current-day sales/Z-report, and confirm the Cash In/Out dialog writes local-first.

### UP-4 — Persist the daily order-number counter
[`cart_provider.dart:25`](Front-End/lib/cart/cart_provider.dart) — `dailyOrderNumberProvider` is an in-memory `StateProvider<int>(=> 1)`, re-seeded by scanning "today's" documents with a **UTC-day** comparison (`:257-289`). In non-UTC timezones the "today" window is offset from local midnight, so the human-facing order name (`Dine in #001`) can reset or miscount around the boundary. (The *document number* from `db.nextDocumentNumber` is a persistent device-local counter and is safe — this is display/identity only.) **Fix:** seed the sequence from the persistent counter and bucket on the local business day.

### UP-5 — Stop reusing the popped dialog context for post-checkout navigation
[`payment_checkout_dialog.dart:672`](Front-End/lib/cart/payment_checkout_dialog.dart) calls `Navigator.pop(ctx)` and then reuses that same `ctx` for `Navigator.pushAndRemoveUntil` (multi-user auto-logout, `:696`) and the tab swap (`:714`). It works today only because the State is still `mounted` during the dialog's exit animation — a fragile timing dependency ("Looking up a deactivated widget's ancestor" territory). Capture the root `NavigatorState` before popping and drive the follow-up navigation from that.

### UP-6 — Introduce a small shared design layer
Add a `StatusColors` `ThemeExtension` (success/warning/danger/info) and one or two shared button wrappers. This turns OPT-5 from a 300-line find-and-replace into a mechanical migration, makes the "no literal colors" rule *enforceable* (any `Colors.green` becomes a lint failure once flutter_lints is back on), and removes button-style duplication spread across 40+ screens.

---

## What was checked and found healthy (so the above stands out)
- **Offline checkout** — pure Drift write, no Dio in the UI path, delta stock deduction, discount-line normalisation, receipt itemisation all local ([`payment_checkout_dialog.dart:293-563`](Front-End/lib/cart/payment_checkout_dialog.dart)). ✅
- **KDS boundary** — per-display printer-group filtering, full-replace semantics, best-effort fire-and-forget networking; wire shape matches the KDS parser exactly. ✅
- **Sync tax remap** — the `id`→`taxId` transform for `BatchSyncItemTaxDto` is handled at [`sync_manager.dart:1228`](Front-End/lib/sync/sync_manager.dart); no contract mismatch. ✅
- **Double-payment guard** — `pushPendingPayments`/`pushPendingDocuments` correctly ignore `'pending'` rows, so sales are not double-created. ✅ (but see OPT-7)
- **Documented SQL gotchas** — no `DATEPART(HOUR, d.Date)` misuse (hourly views use `DateCreated`/`StockDate`); no real `WarehouseCompany` table. ✅
- **Timers** — floor-plan 15s refresh `Timer` is cancelled in `dispose` ([`floor_plan_screen.dart:54`](Front-End/lib/floor_plan/floor_plan_screen.dart)); no leak. ✅
- **Snackbar contract** — zero direct `ScaffoldMessenger…showSnackBar`; all routed through `showAppSnackbar`. ✅
- **Placeholder debt** — none of substance in `lib/`. ✅

---
*Prioritise CRITICAL-1 and CRITICAL-2 before the next release — they are the only findings that put money and stock totals at risk. Everything else is safe to schedule.*


---
