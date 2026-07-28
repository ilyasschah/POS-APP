# Octopus Owner Dashboard — Flutter Web (PWA) Spec

_Source of truth: the SwiftUI/iOS app in this repo (`Octopus_Dashboard/`), as of 2026-07-28.
Supersedes the native-app approach in `FLUTTER_PORT_SPEC.md` — this is a **web-only**
rebuild, not a native Android/iOS build, to avoid App Store / Play Store fees and
review cycles. You already run your own server (the same one hosting the .NET
backend) — deploy the static Flutter Web build there and skip the stores entirely._

## How to use this document

Paste this whole file as a single prompt into an AI coding agent to scaffold the
project from scratch.

**Prompt to hand to the agent**, prepended to this file's contents:

> Build a Flutter Web app named "Octopus Owner Dashboard" in a new project at
> `D:/POS-APP/octopus_dashboard_web`. This is a **web-only** target — do not
> configure iOS/Android native runners, just `flutter create --platforms web`.
> The app must be a fully installable Progressive Web App (PWA): a user opens
> it in Safari (iOS) or Chrome (Android/desktop) and taps "Add to Home Screen"
> / "Install app", after which it behaves like a standalone app (no browser
> chrome, its own icon, launches full-screen). It must be extremely responsive
> and fluid on both engines — Chrome and Safari, mobile and desktop viewports —
> with no layout jank, no unstyled-content flashes, and fast first paint. Use
> Riverpod for state management and Dio for HTTP. Replicate every screen, data
> model, API call, and business rule described below exactly — this is a 1:1
> functional port of an existing working iOS app, re-platformed for the web,
> not a reinterpretation. Where the spec calls out a "known pitfall," implement
> the fix directly; don't repeat the original mistake.

---

## 1. Why web, not native

- No Apple Developer Program fee, no Google Play registration fee, no app
  review turnaround, no code-signing/provisioning headaches, no separate
  release pipelines for two stores.
- You already operate the server behind the existing C# API
  (`https://51-91-6-6.sslip.io/api` in test) — hosting one more static folder
  (the compiled Flutter Web output) on that same box costs nothing extra and
  updates are instant (redeploy the static files; no store review, no client
  update prompts).
- Distribution to the client is a URL. They open it in Safari or Chrome, tap
  **Add to Home Screen**, and from then on it opens like any other app icon —
  full-screen, no address bar, its own splash screen.
- Trade-offs to accept: no access to native-only APIs (this app doesn't need
  any — it's all HTTP + lists + charts), and iOS Safari's PWA support is
  slightly more limited than Android Chrome's (see §4 for what that changes in
  practice — mainly: no real push notifications, no background sync). Neither
  matters for this app's feature set.

---

## 2. App Overview

**Octopus Owner Dashboard** is a companion app for business owners running the
Octopus POS system — not the point-of-sale app itself (that's a separate
Flutter app elsewhere in this ecosystem), but a read-mostly management/
analytics tool: view sales analytics, browse/reprice products, check stock
levels, browse sales documents, and manage staff accounts (including
force-resetting a cashier's password).

- Single tenant per login: everything scoped to one `companyId` (currently
  hardcoded to `25` — see §8).
- JWT bearer-token auth against a C# .NET backend (ASP.NET Core + MediatR/CQRS).
- No offline mode, no local database — every screen is a thin fetch-and-display
  layer over the API. (A service worker may cache the app *shell* for fast
  repeat loads — see §4 — but data is always live.)
- Dark-mode-first visual design ("Liquid Glass": frosted/blurred translucent
  panels over a black or white base, teal accent).

---

## 3. Design System

### Color & theme
- Two modes, user-togglable in Settings, persisted (use `shared_preferences`,
  which on web maps to `localStorage`): **Dark** (default) and **Light**.
  Backgrounds are literally black / white — not Material's default surface
  colors — with content layered on top in translucent "glass" cards.
- Accent color: **teal** throughout — primary buttons, positive numbers,
  active nav-item tint, active-state icons. Approximate hex: light mode
  `#30B0C7`, dark mode `#40C8E0`.
- "Glass" effect: translucent frosted panels. On web, `BackdropFilter` +
  `ImageFilter.blur` works in both CanvasKit and HTML renderers, but **prefer
  the CanvasKit renderer** (`flutter build web --web-renderer canvaskit`) for
  correct, GPU-accelerated blur — the HTML renderer's blur support is
  inconsistent across browsers and is the single most likely cause of the
  "glass" look breaking on Safari specifically. Wrap cards in a semi-transparent
  `Container` (white/black at ~10-20% opacity) over the blur, with a 1px
  border at ~20% opacity.
- Corner radii: large and soft — 20-30px on cards/sheets, 10-12px on buttons
  and inputs.
- Settings exposes a "Liquid Glass Effect" toggle and a "Glass Transparency"
  slider (5%-50%, default 20%) — port as real preferences that actually drive
  the blur/opacity values (nice to make this one actually functional, unlike
  the iOS original where it was inert).

### Typography
- Large rounded-design bold titles ("Octopus Owner", "Octopus Dashboard").
  Use `google_fonts` for a rounded family (e.g. Nunito or SF-Rounded-alike) or
  fall back to bold system font at 32pt title / 38pt for the big "Total Sales"
  figure.
- Secondary text at reduced opacity (~60-70%) of the primary text color.

### Currency
- **Hardcoded to `"DH"` (Moroccan dirham), suffixed after the number** — e.g.
  `"1,234.56 DH"`, two decimals, thousands separator. No user-configurable
  currency setting.

---

## 4. Responsive Layout & PWA Requirements

This is the part that didn't exist in the native-app version and is the crux
of this pivot — treat it as first-class, not an afterthought.

### Breakpoints
Design three layout tiers, switched with `LayoutBuilder`/`MediaQuery`:
- **Compact (< 600px width)** — phone, or the installed home-screen PWA on a
  phone. Navigation collapses to a **bottom navigation bar** (5-6 items is a
  lot for a bottom bar — consider a `NavigationBar` with the 6 sidebar items,
  or a hamburger-triggered drawer if it feels cramped; test both and pick
  whichever fits without truncating labels).
- **Medium (600-1024px)** — tablet portrait / small laptop window. Persistent
  **navigation rail** (icons + optional labels), collapsible.
- **Expanded (> 1024px)** — desktop browser window. Persistent **full sidebar**
  with icons + labels, matching the original iOS `NavigationSplitView` layout
  most closely.

All screen content (lists, cards, charts, forms) must reflow cleanly at every
width in between these tiers — no fixed pixel widths on cards; use
`ConstrainedBox`/`Flexible`/percentage-based widths. Test at minimum: 360px
(small Android phone), 390px (iPhone), 768px (iPad portrait), 1280px (laptop),
1920px (desktop).

### PWA installability
- `web/manifest.json`: `name`, `short_name` "Octopus", `display: "standalone"`,
  `theme_color` matching the teal accent, `background_color` matching the
  dark-mode black background, and a full icon set (192px, 512px, and a
  maskable variant) generated from the app's icon.
- `web/index.html`: include the standard iOS PWA meta tags —
  `<meta name="apple-mobile-web-app-capable" content="yes">`,
  `<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">`,
  and an `<link rel="apple-touch-icon" ...>` — **Safari does not read
  `manifest.json` for install behavior the way Chrome does**; without these
  meta tags "Add to Home Screen" on iOS produces a plain bookmark with the
  wrong icon and shows browser chrome. Both the Chrome (`manifest.json`) and
  Safari (meta tags) paths must be configured for this to actually work as an
  app-like icon on both platforms.
- A minimal service worker (Flutter Web generates one by default via
  `flutter_service_worker.js`) for **app-shell caching only** — cache the
  compiled JS/assets so repeat loads are instant, but never cache API
  responses; every data fetch must hit the live backend. Don't build a "works
  fully offline" experience — that's out of scope and this app has no offline
  data model.
- Splash: Flutter Web's default splash (from `manifest.json`'s
  `background_color`/icon) is enough; no custom native splash screen work
  needed since there's no native shell.

### Performance ("very very very responsive")
- Prefer **CanvasKit** renderer for visual fidelity (blur, charts) — accept
  the larger initial download in exchange for correct rendering on Safari;
  the HTML renderer historically has font/shadow/blur inconsistencies on
  WebKit. If initial load size becomes a real complaint, revisit — but don't
  default to HTML renderer just to save KB at the cost of the "glass" look
  breaking on iOS Safari, since that's core to this app's identity.
- Lists (Products, Stock, Documents, Users) must use lazy-building widgets
  (`ListView.builder`, not `Column` + `map`) — some of these lists run into
  dozens of rows with search filtering. Since these lists are small (tens, not
  thousands, of rows), a search-input debounce is optional polish, not a
  requirement — don't over-engineer it if plain `setState`/Riverpod rebuilds
  are already smooth; measure before adding complexity.
- Avoid rebuilding the entire sidebar/nav shell on every data refresh —
  scope Riverpod providers per-screen so a Products refresh doesn't rebuild
  Dashboard's chart widgets sitting off-screen.
- Charts (`fl_chart` recommended) should animate in but not re-animate on
  every parent rebuild — key them appropriately.
- Keep the initial bundle lean: this app has 6 screens; don't pull in unused
  Riverpod/Dio/chart-library features. No need for code-splitting/deferred
  loading at this size, but avoid heavy unused packages bloating the initial
  JS payload.

### Browser support matrix to explicitly test
- Chrome desktop (primary dev target)
- Chrome on Android (the actual install target for most clients)
- Safari on iOS (the actual install target for iPhone-carrying owners)
- Safari on macOS (secondary, but same rendering engine as iOS Safari — bugs
  usually show up here too, cheaper to catch)

---

## 5. Navigation Structure

Same 6 destinations as the native spec, same order, same icons — just
re-hosted in the responsive shell from §4 instead of a native
`NavigationSplitView`:

| Icon | Title | Screen |
|---|---|---|
| `show_chart` | Dashboard | Sales analytics |
| `sell` | Products & Prices | Product list + price editor |
| `inventory_2` | Stock | Per-product stock quantities |
| `description` | Documents | Sales documents list + detail |
| `people` | User Management | Staff list + password reset |
| `settings` | Settings | Account, theme, sign out |

Default selection on login: **Dashboard**. Settings is reached **only**
through this nav — no duplicate settings entry point anywhere else in the UI.

### Critical data-refresh rule (carried over from the native build — read this)

**Every list screen must re-fetch its data every time it becomes visible, not
just the first time it's built.** The original iOS version had a real,
user-reported bug where three of six screens went stale (showed empty/no-data)
until the user navigated away and back, because they only fetched once per
widget lifetime instead of once per visit. If you use an `IndexedStack` (or
similar keep-alive pattern) to preserve each tab's scroll position across nav
switches, you must **explicitly re-trigger each screen's data fetch on
tab-select**, not rely on `initState` alone, since `initState` won't re-run
for a widget `IndexedStack` is keeping alive off-screen.

Also: **a request that gets cancelled because the user navigated away
mid-flight is not an error** — check `DioExceptionType.cancel` (if you use
Dio's `CancelToken` per screen) and silently drop cancelled requests instead
of surfacing a "couldn't load" message for them.

Each screen's Riverpod notifier should start in a **loading** state, not
empty/idle, so the first frame shows a spinner instead of a flash of "no
data" before the fetch has started.

---

## 6. Screens

### 6.1 Login
- Centered glass card (max-width constrained on wide viewports — don't let a
  login form stretch to 1920px, cap around 420-480px and center it) over a
  full-bleed black/white background.
- Title "Octopus Owner", subtitle "Business Dashboard".
- **Environment picker**: segmented control, two options **Dev** / **Test**,
  defaulting to whichever matches the current API Base URL (fallback Test).
  Selecting one overwrites the API Base URL field with a preset:
  - Dev → `http://100.114.12.38:5002/api`
  - Test → `https://51-91-6-6.sslip.io/api`
- **API Base URL** field: freely editable, pre-filled with current value.
- **Email** field, pre-filled with a test account for dev convenience.
- **Password** field with a show/hide toggle.
- Inline red error text below the password field on login failure.
- **Sign In** button: full-width (within the card's max-width), teal, shows a
  spinner in place of the label while loading, disabled while loading.
- On success, navigate to the responsive nav shell with Dashboard selected.

### 6.2 Dashboard
- Header: "OVERVIEW" eyebrow + "Octopus Dashboard" title left; pill-shaped
  "Filter Date" button (calendar icon) right, opens a date-range picker
  (modal dialog on wide viewports, bottom sheet on compact).
- **Date range picker**: grid of quick-select presets — Today, Yesterday,
  This week, Last week, This month, Last month, This year, Last Year — each
  applies immediately and closes on tap. Plus two manual date pickers (Start
  Date, End Date) and an explicit "Apply Filter" button for custom ranges.
  Default range on first load: one month ago → today.
- Loading: centered spinner. Error: warning icon + message + "Retry" button
  in a glass card.
- Loaded, stacked glass cards (responsive: single column on compact, up to
  2-column grid for the chart/list cards on expanded width if it reads
  better — the original iOS layout is single-column throughout, that's a
  safe default to replicate exactly):
  1. **Total Sales** — big bold currency figure.
  2. **Monthly Sales Trend** — bar chart (month abbreviation × total).
  3. **Hourly Peak Times** — combined line + filled-area chart (hour × total).
  4. **Top Products** — up to 5 rows, name + "N sold" left, currency total
     right, dividers between rows.
  5. **Top Customers** — up to 5 rows, name left, currency total right
     (indigo), dividers between rows.
- Pull-to-refresh equivalent on web: a visible refresh button/icon (pull-to-
  refresh gestures don't map cleanly to desktop browsers) — keep a manual
  refresh affordance rather than relying only on gesture.
- Use `fl_chart` for both charts.

### 6.3 Products & Prices
- Searchable list (filters by name or code, case-insensitive, client-side).
- Row: name (bold) + code (caption) left; sale price (teal, semibold) +
  "Cost {price}" (small, secondary) right.
- Tap opens an **Edit Price** dialog (modal dialog on wide viewports, bottom
  sheet on compact):
  - Read-only Name, Code.
  - Two numeric fields, **Sale Price** / **Cost Price**, pre-filled, numeric
    keyboard/input mode.
  - Cancel / Save actions; Save shows a spinner and disables while saving.
  - On save, the **entire product record** round-trips to the server, not
    just the two edited fields — see §7's Product Update payload note; the
    backend rejects partial updates.
  - On success: close the dialog and refresh the list.
- Standard loading/error states; manual refresh affordance.

### 6.4 Stock
- Same searchable-list shell as Products.
- **One row per product, always** — including products with zero stock
  records anywhere, shown as **"Unassigned"** rather than omitted. This is a
  deliberate rule: a stock screen must never silently hide a product for
  lack of a stock row.
- Row: name (bold) + code (caption) left, plus (if stocked in more than one
  warehouse) an extra caption line listing each warehouse's quantity. Right
  side: total quantity summed across warehouses (teal if positive, red if
  zero/negative), or "Unassigned" (grey) if no stock record exists.
- Read-only — no editing on this screen.
- Sorted alphabetically by product name.

### 6.5 Documents
- Plain list, no search. Row: document number (bold) + customer name
  (secondary) + formatted date (caption) left; total (teal, semibold) right.
- Tap navigates to a **Document Detail** screen/route (push a new route —
  don't use a dialog, this has enough content to want its own page,
  especially on compact widths):
  - "Document" section: Number, Type (human-readable name straight from the
    API), Date, Customer.
  - "Totals" section: Total (teal, semibold).
  - "Line Items" section: fetched separately per document. Each line:
    product name + "{quantity} × {unit price}" caption left, line total
    (semibold) right. Loading spinner while fetching; "No line items for
    this document." if empty; the fetch's own error text if it fails.

### 6.6 User Management
- Plain list. Row: display name (bold — prefer username, fall back to
  "first last", then email, then "Unknown"); role caption ("Admin"/"Cashier")
  + status pill (green "Active" / red "Disabled") beside it; key-icon button
  opening a **Reset Password** dialog.
- **Reset Password dialog**: title "Reset password for {name}", two password
  fields (New, Confirm), inline "Passwords don't match" when they differ and
  Confirm is non-empty, Reset button enabled only when new password ≥6 chars
  and matches Confirm, spinner while submitting. On success: close + show a
  confirmation toast/snackbar ("Password reset for {name}."). On failure:
  show the server's error message, keep the dialog open.
- Admin-triggered forced reset only — no self-service flow, and it requires
  the logged-in user to hold the Admin role server-side (§7).

### 6.7 Settings
- Sections: **Account** (email display + destructive "Sign Out"), **Appearance
  & UI** (Dark Mode toggle, Liquid Glass Effect toggle, Glass Transparency
  slider when enabled). No currency setting — deliberately removed, don't add
  one back.

---

## 7. Data Models & API Contract

**Identical to the native spec — the backend hasn't changed.** All JSON field
names are exactly what the backend emits/expects (ASP.NET Core's default
camelCase policy converts C# PascalCase automatically: `Price` → `price`,
`IsEnabled` → `isEnabled`, etc.). Get every name right; these were
reverse-engineered against the live API, not guessed.

**Auth header** on every request except login: `Authorization: Bearer {jwtToken}`.
`Accept: application/json` on GETs, `Content-Type: application/json` on
requests with a body.

### Login
`POST /Auth/Login` — no auth. Body: `{ "Email": string, "Password": string, "DeviceId": null }`.
Response: `{ "success": bool, "token": string, "message": string? }`. Store the
opaque `token` string as the bearer token.

### Dashboard
`GET /Dashboard/GetDashboardData?companyId={id}&startDate={yyyy-MM-dd}&endDate={yyyy-MM-dd}`.
Format dates in a fixed UTC/`en_US`-equivalent way — don't let the browser's
locale shift the date by a day.
```jsonc
{
  "totalSales": 12345.67,
  "monthlySales": [{ "month": 7, "year": 2026, "total": 4200.0 }],
  "hourlySales": [{ "hour": 14, "total": 800.0 }],
  "topProducts": [{ "productName": "Pepsi", "quantity": 40, "total": 400.0 }],
  "topProductGroups": [{ "groupName": "Drinks", "total": 900.0 }],
  "topCustomers": [{ "customerName": "Walk-in Customer", "total": 1200.0 }]
}
```
(`topProductGroups` is decoded but not currently displayed by any screen —
fine to leave unrendered, matching the original.)

### Products
- List: `GET /Products/GetAll?companyId={id}`
- Update: `PATCH /Products/Update?companyId={id}` — **PATCH, not PUT**;
  `companyId` is a **query param**, not a body field.

Product row shape:
```jsonc
{
  "id": 7, "companyId": 25, "productGroupId": 6, "productGroupName": "Drinks",
  "name": "Pepsi", "code": "0001", "plu": 1, "measurementUnit": "pcs",
  "price": 10.0, "isTaxInclusivePrice": true, "currencyId": null,
  "isPriceChangeAllowed": false, "isService": false,
  "isUsingDefaultQuantity": true, "isEnabled": true, "description": "pepsi",
  "dateCreated": "2026-07-05T20:01:24.884Z", "dateUpdated": "2026-07-28T20:06:22.651Z",
  "cost": 5.0, "markup": 0.0, "color": "Transparent", "ageRestriction": null,
  "lastPurchasePrice": null, "rank": null, "barcodes": ["1783281694498"],
  "image": "<base64, huge, unused — don't decode/display>",
  "lastModified": "2026-07-28T20:06:22.657Z"
}
```
Update payload has **required (non-nullable) fields server-side**: `name`,
`price`, `isTaxInclusivePrice`, `isPriceChangeAllowed`, `isService`,
`isUsingDefaultQuantity`, `isEnabled`, `cost`, `color`. An edit that only
changes price/cost must still resend the rest unchanged from the fetched
record, or the server rejects the request. Optional/nullable and fine to pass
through or omit: `productGroupId`, `code`, `plu`, `measurementUnit`,
`currencyId`, `description`, `markup`, `ageRestriction`, `lastPurchasePrice`,
`rank`.

### Stock
`GET /Stocks/GetAllStocks?companyId={id}` — a flat `(product, warehouse) →
quantity` list, **not** one row per product:
```jsonc
{ "id": 6, "quantity": 477.0, "warehouseId": 17, "warehouseName": "Main Warehouse",
  "productId": 7, "productName": "Pepsi", "companyId": 25, "companyName": "FUTUR3" }
```
Fetch the full product list separately and left-join stock rows onto it by
`productId` to get the "list ALL products" behavior in §6.4.

### Documents
- List: `GET /Document/GetAll?companyId={id}` — note singular `Document`.
- Line items: `GET /DocumentItems/GetByDocumentId?documentId={id}&companyId={companyId}`
  — note plural `DocumentItems`. This inconsistency is real backend naming,
  not a typo to fix client-side.

Document row:
```jsonc
{ "id": 55, "number": "POS1-200-000001", "userId": 9, "userName": "ilyasschah",
  "customerId": 45, "customerName": "Walk-in Customer", "companyId": 25,
  "companyName": "FUTUR3", "documentTypeId": 2, "documentTypeName": "Sales",
  "warehouseId": 17, "warehouseName": "Main Warehouse", "orderNumber": "ORD- A1",
  "date": "2026-07-16T00:00:00", "stockDate": "2026-07-16T10:10:37.307Z",
  "total": 35.0, "referenceDocumentNumber": null,
  "dateCreated": "2026-07-16T10:10:37.307Z", "dateUpdated": "2026-07-16T10:10:37.307Z",
  "internalNote": null, "note": null, "dueDate": null, "discount": 0.0,
  "discountType": 0, "paidStatus": 1, "discountApplyRule": false, "serviceType": 0 }
```
Total field is **`total`, not `totalAmount`**. Use `documentTypeName` directly
instead of hardcoding a type-ID→name map.

Line item row:
```jsonc
{ "id": 56, "companyId": 25, "documentId": 55, "documentNumber": "POS1-200-000001",
  "productId": 8, "productCode": "0002", "productName": "Shwarma",
  "measurementUnit": "pcs", "quantity": 1.0, "expectedQuantity": 1.0,
  "priceBeforeTax": 35.0, "price": 35.0, "discount": 0.0, "discountType": 0,
  "productCost": 0.0, "priceBeforeTaxAfterDiscount": 35.0, "priceAfterDiscount": 35.0,
  "total": 35.0, "totalAfterDocumentDiscount": 35.0, "discountApplyRule": false }
```
Only `productName`, `quantity`, `price`, `total` are actually displayed.

### Users
- List: `GET /Users/GetAllUsers?companyId={id}` — **action name is
  `GetAllUsers`, not `GetAll`**; this is the one list endpoint that breaks the
  naming pattern the others follow, and getting it wrong silently 404s.
- Reset password: `PATCH /Users/AdminResetPassword?companyId={id}` — **PATCH,
  not POST**; `companyId` is a query param. Body:
  `{ "userId": int, "newPassword": string }`. Requires the caller's own JWT to
  carry the Admin role (`accessLevel == 0` at login) — the server enforces a
  `ManagerOnly` policy; a Cashier-level token gets a 403. **There is no
  server-generated/blind reset** — always send a real `newPassword`.

User row:
```jsonc
{ "id": 9, "companyId": 25, "firstName": "ilyass", "lastName": "chah",
  "username": "ilyasschah", "accessLevel": 0, "isEnabled": true,
  "email": "ilyasschah18@gmail.com", "hasPinForThisDevice": false,
  "hashedPin": null, "lastModified": "2026-07-17T23:30:14.778Z" }
```
No `role` string or `isBlocked` bool exists server-side — both are derived
client-side: `roleName = accessLevel == 0 ? "Admin" : "Cashier"`, status shown
is `isEnabled` directly (not inverted).

### Universal error shape
Business-logic failures come back as `400 Bad Request` with a JSON body
containing a `message` field (occasionally `Message` — check both casings
defensively). Surface that message to the user instead of a generic error.

---

## 8. Business Rules Recap

- **`companyId` hardcoded to `25`** everywhere — no company switcher UI; keep
  it a single easy-to-find constant.
- **Role model**: `accessLevel == 0` → Admin/Manager, anything else → Cashier.
  No other role tiers.
- **Currency always `"DH"`**, never configurable.
- **Environment presets** (Dev/Test) are named constants on the login screen
  for testing against two known backends.
- **Every screen re-fetches on every visit** (§5); **cancelled requests are
  never shown as errors** (§5) — both were real bugs in the native version,
  don't reintroduce either here.
- **Stock always lists every product**, unstocked ones labeled "Unassigned."
- **Product price updates round-trip the full record**, never a partial diff.

---

## 9. Deployment Notes (brief — not a full DevOps runbook)

- Build: `flutter build web --web-renderer canvaskit --release`.
- Output lives in `build/web/` — a fully static site (HTML/JS/CSS/assets).
  Host it on the same server as the existing API (the OVH box), either as a
  static folder served by whatever's already terminating TLS there (IIS,
  nginx, etc.) at a path or subdomain of your choosing (e.g.
  `https://51-91-6-6.sslip.io/dashboard/` or a separate subdomain).
- CORS: since the web app's origin will differ from a native app's "no
  origin," confirm the backend's CORS policy allows the hosting origin for
  the `/api/*` routes — this is the one backend-side check needed to make the
  web pivot work; the native app never had to deal with CORS.
- No signing, no store accounts, no review queue — redeploying is just
  replacing the static files.
