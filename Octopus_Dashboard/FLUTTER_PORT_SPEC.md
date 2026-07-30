# Octopus Owner Dashboard — Flutter/Android Port Spec

_Source of truth: the SwiftUI/iOS app in this repo (`Octopus_Dashboard/`), as of 2026-07-28._

## How to use this document

This file is written to be pasted **as a single prompt** into an AI coding agent to
scaffold a pixel-and-behavior-equivalent Flutter app. It contains everything the
original app's source code and its backend integration encode implicitly: screen
layouts, navigation, data shapes, exact API contracts, and the non-obvious bugs
that were already hit and fixed once during iOS development — don't reintroduce them.

**Prompt to hand to the agent**, prepended to this file's contents:

> Build a Flutter app named "Octopus Owner Dashboard" in a new project at
> `D:/POS-APP/octopus_dashboard_flutter` (or similar), targeting Android as the
> primary platform (Flutter's cross-platform nature means iOS/Windows/desktop
> should also build, but Android is what gets tested). Use Riverpod for state
> management and Dio for HTTP, matching this ecosystem's existing Flutter
> conventions. Replicate every screen, data model, API call, and business rule
> described below exactly — this is a 1:1 port of an existing working iOS app,
> not a reinterpretation. Where the spec calls out a "known pitfall," implement
> the fix directly; don't repeat the original mistake.

---

## 1. App Overview

**Octopus Owner Dashboard** is a companion app for business owners running the
Octopus POS system. It is *not* the point-of-sale app itself (that's a separate
Flutter app in `/Front-End` elsewhere in this ecosystem) — it's a read-mostly
management/analytics app: view sales analytics, browse/reprice products, check
stock levels, browse sales documents (invoices/receipts), and manage staff
accounts (including force-resetting a cashier's password).

- Single tenant per login: everything is scoped to one `companyId` (currently
  hardcoded to `25` everywhere — see §6).
- JWT bearer-token auth against a C# .NET backend (ASP.NET Core + MediatR/CQRS).
- No offline mode, no local database — every screen is a thin fetch-and-display
  layer over the API.
- Dark-mode-first visual design ("Liquid Glass": frosted/blurred translucent
  panels over a black or white base, teal accent).

---

## 2. Design System

### Color & theme
- Two modes only, user-togglable in Settings, persisted: **Dark** (default) and
  **Light**. Backgrounds are literally `Colors.black` / `Colors.white` — not
  Material's default surface colors — with all content layered on top in
  translucent "glass" cards.
- Accent color: **teal**, used for primary buttons, positive numbers (sale
  price, positive totals), the sidebar's selection tint, and active-state icons.
  Approximate hex: light mode `#30B0C7`, dark mode `#40C8E0` (iOS system teal).
  A single `Colors.teal`-family value is fine if exact parity isn't critical.
- "Glass" effect: translucent frosted panels (iOS `.ultraThinMaterial`) — in
  Flutter, approximate with `BackdropFilter(filter: ImageFilter.blur(...))`
  wrapping a semi-transparent `Container` (e.g. white/black at ~10-20% opacity
  over the blur), with a thin 1px border at ~20% opacity (`Colors.white.withOpacity(0.2)`
  in dark mode, `Colors.black.withOpacity(0.2)` in light mode). Every card,
  sheet, list background, and the sidebar itself uses this treatment.
- Corner radii: large, soft — 20-30px on cards and sheets, 10-12px on buttons
  and input fields.
- Settings also exposes (but nothing currently reads besides the on/off state):
  a "Liquid Glass Effect" toggle and a "Glass Transparency" slider (5%-50%,
  default 20%). Port these as inert preferences unless you want to actually
  wire transparency into the blur opacity.

### Typography
- Large rounded-design bold titles for headers ("Octopus Owner", "Octopus
  Dashboard") — Flutter equivalent: a rounded font family or just bold system
  font at large size (32pt title, 38pt for the big "Total Sales" figure).
- Standard system font elsewhere; secondary text at `.caption`/`.footnote`
  sizes with reduced opacity (~60-70%) of the primary text color.

### Currency
- **Hardcoded to `"DH"` (Moroccan dirham), suffixed after the number** —
  e.g. `"1,234.56 DH"` — two decimal places, thousands separator, always.
  There is **no user-configurable currency setting** — it was deliberately
  removed. Do not add one.

---

## 3. Navigation Structure

A persistent **sidebar** (source: `NavigationSidebarView.swift`, built on
`NavigationSplitView`) with these items, in this order:

| Icon (SF Symbol) | Title | Screen |
|---|---|---|
| `chart.line.uptrend.xyaxis` | Dashboard | Sales analytics |
| `tag.fill` | Products & Prices | Product list + price editor |
| `shippingbox.fill` | Stock | Per-product stock quantities |
| `doc.text.fill` | Documents | Sales documents (invoices/receipts) list + detail |
| `person.2.fill` | User Management | Staff list + password reset |
| `gearshape.fill` | Settings | Account, theme, sign out |

Flutter equivalent: a `NavigationDrawer` or a permanent side `NavigationRail`
(this is a business/tablet-leaning app, so a permanent rail on wide screens,
collapsing to a drawer on narrow phones, is reasonable) with the same 6 items,
same order, same icons (use Material icon equivalents: `show_chart`,
`sell`/`local_offer`, `inventory_2`, `description`, `people`, `settings`).
Default selection on login: **Dashboard**.

**Settings is reached only through the sidebar.** There is deliberately no
second settings entry point anywhere else in the app (this was a real bug that
got fixed — an extra gear icon on the Dashboard toolbar used to open Settings
as a duplicate modal; it was removed). Don't add one.

### Critical navigation-lifecycle rule (read this before writing any screen)

**Every list screen must re-fetch its data every time it becomes visible, not
just the first time.** The iOS version originally used SwiftUI's `.task`
modifier (fires once per view identity) for Products/Documents/Users, while
Dashboard used `.onAppear` (fires every time). Because the sidebar's detail
pane doesn't necessarily destroy a tab's view when you switch away, `.task`-based
screens went stale: switching to another tab and back showed no data ("no
products" etc.) until the background fetch that started on first visit finally
completed. The fix was to switch every screen to an explicit "reload on every
appearance" pattern.

**In Flutter, this means:** call your refresh/load function from
`initState`-equivalent lifecycle **and whenever the screen re-enters view**
(e.g. `RouteObserver.didPopNext`, or just re-fetch in `build`/`onTap` at the
navigation-item level, or use `AutomaticKeepAliveClientMixin: false` so each
tab visit is a fresh widget). Do **not** rely on a widget only fetching once in
`initState` if the navigation shell can keep the widget alive off-screen and
bring it back without recreating it (e.g. `IndexedStack`-based tab navigation).
If you use `IndexedStack` to preserve scroll position, explicitly re-trigger
the fetch on tab-select, not just on first mount.

Also: **network requests that get cancelled because the user navigated away
mid-flight are not errors.** Don't surface a cancelled/aborted request as a
"couldn't load" error message — just silently drop it (this was a second real
bug, fixed by checking for `URLError.cancelled` before setting an error string
in the iOS version). In Dio, check `DioExceptionType.cancel` the same way.

Each list ViewModel/notifier should start in a **loading** state (not
"empty"/idle) so the very first frame shows a spinner instead of a flash of
"no data" before the fetch has even started.

---

## 4. Screens

### 4.1 Login

- Centered glass card over full-bleed black/white background.
- Title "Octopus Owner", subtitle "Business Dashboard".
- **Environment picker**: a segmented control with two options, **Dev** and
  **Test**, defaulting to whichever matches the current API Base URL (falls
  back to Test if neither matches). Selecting one overwrites the API Base URL
  field below with a preset:
  - Dev → `http://100.114.12.38:5002/api` (local backend over Tailscale)
  - Test → `https://51-91-6-6.sslip.io/api` (hosted test backend, real HTTPS)
- **API Base URL** field: freely editable text field, pre-filled with the
  current value (default: the Test URL above). Editing it manually doesn't
  need to keep the segmented control in sync — it's a one-way convenience,
  not a strict binding.
- **Email** field, pre-filled for dev convenience with a test account.
- **Password** field: `SecureField`-style with a show/hide eye-icon toggle.
- Inline error text (red) below the password field if login fails.
- **Sign In** button: full-width, teal, shows a spinner in place of the label
  while the request is in flight; disabled while loading.
- On success, navigate to the sidebar shell with Dashboard selected.

### 4.2 Dashboard

- Header row: "OVERVIEW" eyebrow label + "Octopus Dashboard" title on the
  left; a pill-shaped "Filter Date" button (calendar icon) on the right that
  opens a bottom sheet.
- **Date range filter sheet**: a grid of quick-select presets — Today,
  Yesterday, This week, Last week, This month, Last month, This year, Last
  Year — each computing a concrete `[start, end]` range and immediately
  applying + closing the sheet on tap. Below the presets, two manual date
  pickers (Start Date, End Date) plus an explicit "Apply Filter" button for
  custom ranges. Default range on first load: one month ago → today.
- **Loading state**: centered spinner.
- **Error state**: warning icon + message + "Retry" button, in a glass card.
- **Loaded state**, stacked glass cards:
  1. **Total Sales** — big bold number (38pt), currency-formatted.
  2. **Monthly Sales Trend** — bar chart, x = month abbreviation (JAN, FEB...),
     y = total. Only shown if data exists.
  3. **Hourly Peak Times** — combined line + filled area chart, x = hour
     (e.g. "14h"), y = total. Only shown if data exists.
  4. **Top Products** — up to 5 rows: product name + "N sold" caption on the
     left, currency total on the right, dividers between rows.
  5. **Top Customers** — up to 5 rows: customer name left, currency total
     right (indigo-colored instead of teal), dividers between rows.
- Pull-to-refresh re-fetches with the current date range.
- Chart library: Flutter has no first-party Charts framework equivalent;
  use `fl_chart` (bar chart + line/area chart) or `syncfusion_flutter_charts`.

### 4.3 Products & Prices

- Searchable list (search bar filters by product name or code,
  case-insensitive, client-side).
- Each row: product name (bold) + code (caption, secondary color) on the
  left; sale price (teal, semibold) + "Cost {price}" (small, secondary) on
  the right.
- Tapping a row opens an **"Edit Price" sheet**:
  - Read-only "Product" section: Name, Code.
  - "Pricing (DH)" section: two numeric text fields, **Sale Price** and
    **Cost Price**, pre-filled with current values, decimal keyboard.
  - Toolbar: Cancel (left) / Save (right, shows spinner while saving,
    disabled while saving).
  - On save, only price/cost change — but see §6 for why the *entire* product
    record must be sent back to the server, not just the two edited fields.
  - On successful save: dismiss the sheet and refresh the list.
- Empty/error states same pattern as Dashboard (spinner / "Couldn't load
  products" + message).
- Pull-to-refresh supported.

### 4.4 Stock

- Same searchable-list shell as Products.
- **One row per product — every product, always**, even ones with zero stock
  records anywhere. This is a deliberate business rule (see §6): a
  stock/inventory screen must never silently hide a product just because it
  has no stock row yet.
- Row: product name (bold) + code (caption) on the left. If the product has
  stock in **more than one warehouse**, an extra caption line lists each
  warehouse and its quantity (e.g. `"Main Warehouse: 477 · Overflow: 12"`).
  On the right: the **total quantity summed across all warehouses**, teal if
  positive, red if zero/negative; or the literal word **"Unassigned"** (grey)
  if the product has no stock record at all in any warehouse.
- Read-only screen — no editing here (stock quantity edits, if ever added,
  are a separate future concern; this screen is view-only in the current
  app).
- Sort order: alphabetical by product name.
- Same loading/error/empty patterns, pull-to-refresh.

### 4.5 Documents

- Plain list (no search), each row:
  - Document number (bold) + customer name (secondary) + formatted date
    (caption) on the left.
  - Total amount (teal, semibold) on the right.
- Tapping a row pushes a **Document Detail** screen:
  - "Document" section: Number, Type (the human-readable type name from the
    API, e.g. "Sales" — not a guessed/hardcoded mapping), Date, Customer.
  - "Totals" section: Total (teal, semibold).
  - "Line Items" section: fetched separately per-document (see §6 API list).
    Each line: product name + "{quantity} × {unit price}" caption on the
    left, line total (semibold) on the right. Loading spinner while
    fetching; "No line items for this document." if the list comes back
    empty; the fetch's own error text if it fails.
- Pull-to-refresh on the list screen only (not the detail screen).

### 4.6 User Management

- Plain list, each row:
  - Display name (bold) — prefer username; if blank, fall back to
    "first last"; if that's blank too, fall back to email; final fallback
    "Unknown".
  - Role caption ("Admin" or "Cashier" — see §6 for how this is derived) +
    a status pill/badge next to it: green "Active" or red "Disabled".
  - A key-icon button on the right that opens a **Reset Password sheet**.
- **Reset Password sheet**:
  - Title: "Reset password for {display name}".
  - Two `SecureField`s: "New password", "Confirm password".
  - Inline red text "Passwords don't match" if they differ and the confirm
    field is non-empty.
  - Reset button enabled only when new password is ≥6 characters **and**
    matches the confirm field. Shows a spinner while submitting.
  - On success: dismiss the sheet and show a confirmation alert ("Password
    reset for {name}."). On failure: the alert shows the server's error
    message instead, and the sheet stays open.
- No self-service "forgot password" flow exists in this app — this is an
  **admin-triggered forced reset** only, requiring the logged-in user to hold
  the Admin role server-side (see §6, `ManagerOnly` policy).

### 4.7 Settings

- Glass list over the full-bleed black/white background, sections:
  - **Account**: email (read-only display) + destructive "Sign Out" button
    (clears the auth token and returns to Login).
  - **Appearance & UI**: "Dark Mode" toggle, "Liquid Glass Effect" toggle,
    and (only shown when Liquid Glass is on) a "Glass Transparency" slider
    (5%-50%, default 20%) with a live percentage label.
- No "Done"/dismiss button — this screen is a permanent sidebar destination,
  not a modal, and has no close affordance.
- **No currency setting.** (Explicitly removed — see §2.)

---

## 5. Data Models

All JSON field names below are **exactly** what the backend emits/expects —
ASP.NET Core's default camelCase JSON policy converts C# PascalCase property
names automatically (`Price` → `price`, `IsEnabled` → `isEnabled`, etc.).
Get every field name right; there is no tolerance for guessing here, this was
reverse-engineered against the live API.

### Product
```jsonc
// GET /api/Products/GetAll response row
{
  "id": 7,
  "companyId": 25,
  "productGroupId": 6,
  "productGroupName": "Drinks",
  "name": "Pepsi",
  "code": "0001",
  "plu": 1,
  "measurementUnit": "pcs",
  "price": 10.0,
  "isTaxInclusivePrice": true,
  "currencyId": null,
  "isPriceChangeAllowed": false,
  "isService": false,
  "isUsingDefaultQuantity": true,
  "isEnabled": true,
  "description": "pepsi",
  "dateCreated": "2026-07-05T20:01:24.884Z",
  "dateUpdated": "2026-07-28T20:06:22.651Z",
  "cost": 5.0,
  "markup": 0.0,
  "color": "Transparent",
  "ageRestriction": null,
  "lastPurchasePrice": null,
  "rank": null,
  "barcodes": ["1783281694498"],
  "image": "<base64, huge, unused by this app — don't decode/display it>",
  "lastModified": "2026-07-28T20:06:22.657Z"
}
```
Only decode the fields you need for the app (name, code, price, cost, plus
everything required to round-trip an update — see the Update payload below).
Ignore `image`/`barcodes`/dates/company/group-name fields.

### Product Update payload (PATCH body)
The update endpoint's request DTO has **many required (non-nullable) fields**
server-side. An update that only intends to change price/cost must still
resend every other field unchanged, fetched from the same product record, or
the server rejects it with a validation error. Required: `name`, `price`,
`isTaxInclusivePrice`, `isPriceChangeAllowed`, `isService`,
`isUsingDefaultQuantity`, `isEnabled`, `cost`, `color`. Optional (nullable,
fine to omit or pass through): `productGroupId`, `code`, `plu`,
`measurementUnit`, `currencyId`, `description`, `markup`, `ageRestriction`,
`lastPurchasePrice`, `rank`.

### User
```jsonc
// GET /api/Users/GetAllUsers response row
{
  "id": 9,
  "companyId": 25,
  "firstName": "ilyass",
  "lastName": "chah",
  "username": "ilyasschah",
  "accessLevel": 0,
  "isEnabled": true,
  "email": "ilyasschah18@gmail.com",
  "hasPinForThisDevice": false,
  "hashedPin": null,
  "lastModified": "2026-07-17T23:30:14.778Z"
}
```
There is **no `role` string field and no `isBlocked` bool** in the API — both
are derived client-side:
- `roleName`: `accessLevel == 0 ? "Admin" : "Cashier"` (matches the backend's
  own JWT-issuance logic — 0 is the only "manager" level).
- Status shown as Active/Disabled is just `isEnabled`, not inverted.

### Document
```jsonc
// GET /api/Document/GetAll response row
{
  "id": 55,
  "number": "POS1-200-000001",
  "userId": 9, "userName": "ilyasschah",
  "customerId": 45, "customerName": "Walk-in Customer",
  "companyId": 25, "companyName": "FUTUR3",
  "documentTypeId": 2, "documentTypeName": "Sales",
  "warehouseId": 17, "warehouseName": "Main Warehouse",
  "orderNumber": "ORD- A1",
  "date": "2026-07-16T00:00:00",
  "stockDate": "2026-07-16T10:10:37.307Z",
  "total": 35.0,
  "referenceDocumentNumber": null,
  "dateCreated": "2026-07-16T10:10:37.307Z",
  "dateUpdated": "2026-07-16T10:10:37.307Z",
  "internalNote": null, "note": null, "dueDate": null,
  "discount": 0.0, "discountType": 0, "paidStatus": 1,
  "discountApplyRule": false, "serviceType": 0
}
```
The field is **`total`, not `totalAmount`**. Use `documentTypeName` directly
for the type label instead of hardcoding a documentTypeId→name map.

### Document line item
```jsonc
// GET /api/DocumentItems/GetByDocumentId response row
{
  "id": 56, "companyId": 25,
  "documentId": 55, "documentNumber": "POS1-200-000001",
  "productId": 8, "productCode": "0002", "productName": "Shwarma",
  "measurementUnit": "pcs",
  "quantity": 1.0, "expectedQuantity": 1.0,
  "priceBeforeTax": 35.0, "price": 35.0,
  "discount": 0.0, "discountType": 0,
  "productCost": 0.0,
  "priceBeforeTaxAfterDiscount": 35.0, "priceAfterDiscount": 35.0,
  "total": 35.0, "totalAfterDocumentDiscount": 35.0,
  "discountApplyRule": false
}
```
Only `productName`, `quantity`, `price`, `total` are actually displayed.

### Stock
```jsonc
// GET /api/Stocks/GetAllStocks response row
{
  "id": 6, "quantity": 477.0,
  "warehouseId": 17, "warehouseName": "Main Warehouse",
  "productId": 7, "productName": "Pepsi",
  "companyId": 25, "companyName": "FUTUR3"
}
```
This is a flat list of `(product, warehouse) → quantity` rows — **not**
one row per product. The client must fetch the full product list separately
and left-join stock rows onto it by `productId` to get the "list ALL
products" behavior described in §4.4.

### Dashboard data
```jsonc
// GET /api/Dashboard/GetDashboardData response
{
  "totalSales": 12345.67,
  "monthlySales": [ { "month": 7, "year": 2026, "total": 4200.0 }, ... ],
  "hourlySales": [ { "hour": 14, "total": 800.0 }, ... ],
  "topProducts": [ { "productName": "Pepsi", "quantity": 40, "total": 400.0 }, ... ],
  "topProductGroups": [ { "groupName": "Drinks", "total": 900.0 }, ... ],
  "topCustomers": [ { "customerName": "Walk-in Customer", "total": 1200.0 }, ... ]
}
```
`topProductGroups` is decoded but never displayed by the current UI — port
the field but it's fine if the widget just doesn't render it (matches the
original).

---

## 6. API Contract

**Base URL** is user-configurable (see §4.1). All paths below are relative to
`{apiBaseUrl}` (e.g. `https://51-91-6-6.sslip.io/api`).

**Auth header** on every request except login: `Authorization: Bearer {jwtToken}`.
Also send `Accept: application/json` on GETs, `Content-Type: application/json`
on requests with a JSON body.

### Login
| | |
|---|---|
| Method / Path | `POST /Auth/Login` |
| Auth | none (`[AllowAnonymous]`) |
| Body | `{ "Email": string, "Password": string, "DeviceId": null }` |
| Response | `{ "success": bool, "token": string, "message": string? }` (also `tokenType`, `expiresIn`, `user` — unused by this app) |
| Notes | On non-200, response body has a `message` explaining why (e.g. bad credentials). Store the whole opaque `token` string as the bearer token — don't try to decode/validate it client-side. |

### Dashboard
| | |
|---|---|
| Method / Path | `GET /Dashboard/GetDashboardData` |
| Query params | `companyId` (int), `startDate` (`yyyy-MM-dd`), `endDate` (`yyyy-MM-dd`) |
| Notes | Format dates with a fixed `en_US_POSIX`-equivalent locale/UTC — **do not use the device locale/timezone for formatting**, it can shift the date by one day and silently send the wrong range. |

### Products
| | |
|---|---|
| List | `GET /Products/GetAll?companyId={id}` |
| Update | `PATCH /Products/Update?companyId={id}` — **PATCH, not PUT.** `companyId` is a **query param**, not a body field. Body: the full product payload described in §5 (all required fields present). |

### Stock
| | |
|---|---|
| List | `GET /Stocks/GetAllStocks?companyId={id}` |

*(Add/Update/Delete stock endpoints exist server-side —`POST /Stocks/Add`,
`PATCH /Stocks/Update`, `DELETE /Stocks/Delete` — but are out of scope; this
app's Stock screen is read-only.)*

### Documents
| | |
|---|---|
| List | `GET /Document/GetAll?companyId={id}` |
| Line items | `GET /DocumentItems/GetByDocumentId?documentId={id}&companyId={companyId}` |

Note the controller name is singular **`Document`** (not `Documents`) for the
main list, but **`DocumentItems`** (plural) for line items — this is a real
backend inconsistency, not a typo to "fix" client-side.

### Users
| | |
|---|---|
| List | `GET /Users/GetAllUsers?companyId={id}` — **action name is `GetAllUsers`, not `GetAll`.** This one differs from every other list endpoint's naming convention; getting it wrong silently 404s. |
| Reset password | `PATCH /Users/AdminResetPassword?companyId={id}` — **PATCH, not POST.** `companyId` is a query param. Body: `{ "userId": int, "newPassword": string }`. Requires the caller's own JWT to carry the **Admin** role (`accessLevel == 0` at login time) — the server enforces a `ManagerOnly` authorization policy on this endpoint; a Cashier-level token gets a 403. |

There is **no server-generated/"blind" password reset** — you must always
supply a real `newPassword` string; that's why the UI has two password fields
instead of a single confirm button.

### Universal response-shape note
Business-logic failures generally come back as `400 Bad Request` with a JSON
body containing at least a `message` field (sometimes `Message` — check both
casings defensively when parsing errors, the codebase is inconsistent about
it). Show that message to the user rather than a generic "something went
wrong."

---

## 7. Business Rules / Non-obvious Behavior Recap

- **`companyId` is hardcoded to `25`** everywhere in the current app — there
  is no multi-tenant company switcher. Keep it a single constant, easy to
  find and change later, but don't build UI for switching companies.
- **Role model**: only two effective roles exist client-side, derived from
  `accessLevel`: `0` = Admin/Manager, anything else = Cashier. This mirrors
  the backend's own JWT role-claim logic — don't invent additional role
  tiers.
- **Currency is always "DH", never configurable.**
- **Environment presets** (Dev/Test) are a developer convenience baked into
  the login screen for testing against two known backends; keep both URLs as
  named constants so they're easy to update later without hunting through
  the codebase.
- **Every list screen must always re-fetch on becoming visible** (§3) and
  **must not treat a cancelled in-flight request as an error** (§3) — these
  were real, user-reported bugs on iOS; don't reintroduce either.
- **Stock must show every product**, including ones with zero stock records,
  labeled "Unassigned" rather than omitted.
- **Product price updates must round-trip the full record**, not a partial
  diff — the backend's update DTO has required fields beyond price/cost.

---

## 8. Out of Scope for the Flutter Port

- **Home-screen widget** (`OwnerWidget/` in the iOS source): a small iOS
  WidgetKit widget showing last-known total sales, fed via an iOS App Group
  shared `UserDefaults`. Android's home-screen widget system (`AppWidgetProvider`
  + RemoteViews, or Glance for Compose users — Flutter has no first-party
  equivalent, `home_widget` package is the closest) works completely
  differently and isn't a straightforward port. Treat this as an optional
  stretch goal, not part of the core app; the six sidebar screens above are
  the actual product.
- Any Windows/desktop-specific chrome — this port's primary target is
  Android, per the requesting instructions.
