# Owner Dashboard App — Build Plan (iOS + Android)

_Drafted: 2026-07-25._

> A separate **online-only** mobile app for the **business owner**: a read-only
> window onto sales/reporting that talks **directly to the existing backend API**
> (`/api/Dashboard/*` + `/api/Reports/*`). It is NOT the POS and has no offline
> layer, no Drift, no sync engine, no cart/checkout. Think "the owner opens their
> phone and sees today's numbers."

---

## 1. Goal & scope

| In scope (MVP) | Out of scope |
|---|---|
| Login (email + password → JWT) | Selling / cart / checkout |
| Summary dashboard (KPIs, trend, top lists) | Editing products / settings / users |
| Date-range filter (today / week / month / custom) | Offline mode, local DB, sync |
| Core sales report views (mirrors POS Reports) | Kitchen display / floor plan |
| Read-only, one company per login | Any write/POST/PATCH/DELETE endpoint |

**Guiding principle:** this app **reuses the endpoints that already exist**. The
POS's own dashboard screen (`Front-End/lib/dashboard/`) computes locally from
Drift — the owner app instead calls the **server** endpoints below, so it always
reflects **all terminals' data** without needing a sync.

---

## 2. What already exists on the backend (reuse, don't rebuild)

All endpoints are `GET`, take `companyId + startDate + endDate` (+ optional
filters), and are **JWT-protected** by the fail-closed `FallbackPolicy` in
`Program.cs` — so the app must authenticate first.

### 2.1 Auth
- **`POST /api/Auth/Login`** — the only anonymous call. Body:
  `{ "Email": "...", "Password": "...", "DeviceId": null }`
  → `{ Success, Token, TokenType: "Bearer", ExpiresIn: 3600, User, Lease, Message }`.
  The JWT carries `userId`, `companyId`, and role claims. **1-hour expiry.**
- **`POST /api/Auth/Refresh`** (`[Authorize]`) — sliding renewal; exchange a
  still-valid token for a fresh one. Call it proactively before expiry.
- ⚠️ **`DeviceId` registers against the seat cap (Pillar 4).** The owner app must
  log in **without a DeviceId** so it does **not** burn a POS seat. → **Backend
  check required** (§4).

### 2.2 Dashboard — `GET /api/Dashboard/GetDashboardData?companyId&startDate&endDate`
Returns `DashboardDataDto`: `totalSales`, `monthlySales[]`, `hourlySales[]`,
`topProducts[]`, `topProductGroups[]`, `topCustomers[]`. This one call powers most
of the summary screen. (Shape mirrored in `Front-End/lib/dashboard/dashboard_model.dart`.)

### 2.3 Reports — `GET /api/Reports/<Action>?companyId&startDate&endDate&…`
33 report actions already implemented (`ReportsController.cs`):

- **Sales:** `GetSalesByProduct`, `GetSalesByProductGroup`, `GetSalesByCustomer`,
  `GetSalesByUser`, `GetSalesByPaymentType`, `GetSalesByTax`, `GetSalesByTable`,
  `GetSalesItemList`, `GetHourlySales`, `GetHourlySalesByGroup`, `GetDailySales`.
- **Money owed / discounts / refunds:** `GetUnpaidSales`, `GetProfit`,
  `GetItemsDiscounts`, `GetDiscountsGranted`, `GetRefundItemList`, `GetInvoiceList`.
- **Payments:** `GetPaymentTypesByCustomer`, `GetPaymentTypesByUser`.
- **Stock:** `GetStockMovement`, `GetStockReturnByProduct`,
  `GetLossAndDamageByProduct`, `GetReorderProductList`, `GetLowStockWarning`.
- **Purchasing:** `GetPurchaseByProduct`, `GetPurchaseBySupplier`,
  `GetPurchaseByTax`, `GetPurchaseInvoiceList`, `GetPurchaseDiscounts`,
  `GetPurchaseItemsDiscounts`, `GetUnpaidPurchase`, `GetPurchaseExpirationDate`.
- **Ledger:** `GetTransactionHistory?companyId&partnerId&startDate&endDate`.

**No new backend endpoints are needed for the MVP.** The owner app is a new
*consumer* of the existing API surface.

---

## 3. App architecture

**Stack (mirror the POS so knowledge transfers):** Flutter, Riverpod, Dio,
`fl_chart`. **No Drift, no `sqlite3_flutter_libs`, no sync** — every screen is a
live `FutureProvider.family` keyed on `(endpoint, dateRange, filters)` with
pull-to-refresh. Loading = `skeletonizer`; errors = a retry state (offline just
shows "no connection, retry", since there's no cache to fall back to).

```
/Owner-Dashboard                  ← new top-level app in the monorepo
  lib/
    api/            api_client.dart (Dio + Bearer interceptor + refresh)
    auth/           login_screen, auth_provider, secure token storage
    dashboard/      summary screen + KPI tiles + charts
    reports/        one screen per report family (reuse a generic table widget)
    models/         DTOs ported from backend (Dashboard + Reports DtOs)
    core/           theme (reuse Front-End/lib/core/app_theme.dart pattern), config
    l10n/           optional — reuse the POS arb keys if we want FR/AR
```

**Models:** port the response DTOs from the C# `Api.Models` report DTOs (and the
existing `dashboard_model.dart`). Keep them in the owner app; don't try to share a
package with the POS at first (coupling cost > benefit for an MVP).

**Auth/session:**
- Store the JWT in **`flutter_secure_storage`** (Keychain / Keystore), not
  `shared_preferences`.
- Dio request interceptor attaches `Authorization: Bearer <token>`; a response
  interceptor calls `/Auth/Refresh` on a near-expiry/401 once, else routes to
  login (same pattern as the POS `session_expiry.dart`).
- App-lock: optional biometric gate on launch (`local_auth`) since this is
  financial data on a personal phone.

**Config:** a settings screen field for the **API base URL** (like the POS's
`config.dart` `API_BASE_URL`), defaulting to the production HTTPS endpoint.

---

## 4. Backend prerequisites & gaps (must resolve before/with build)

1. **🌐 Internet-reachable, HTTPS endpoint.** Today the API is LAN/VPN only
   (`config.dart` → `http://100.114.12.38:5002/api`, a Tailscale IP; SQL on
   localhost). An owner off-site needs the API reachable from a mobile network
   over **TLS**. Options: public domain + reverse proxy (Caddy/Nginx) with a cert,
   or keep it on **Tailscale** and install Tailscale on the owner's phone.
   **JWT over plain HTTP on the public internet is unacceptable** — TLS is a hard
   requirement. → **#1 blocker, owner/infra decision.**
2. **🔑 Seatless owner login.** Confirm `POST /Auth/Login` with **no `DeviceId`**
   succeeds and does **not** consume a POS seat (Pillar 4 seat cap). If it does,
   add an owner/read-only login path that skips seat registration.
3. **👤 Role/authorization.** The Dashboard/Reports endpoints currently accept
   **any authenticated user**. Recommend the owner logs in as an **Admin/manager**
   role, and (known follow-up in `handoff.md`) tighten sensitive control-plane
   endpoints to `ManagerOnly`. Optionally add a read-only "Owner" role/claim.
4. **CORS:** not needed for a native Flutter app (Dio is not a browser). Only
   relevant if a web build is later added.
5. **Multi-company owners:** a login returns a single `companyId` (from the user).
   If one owner oversees several tenants, decide whether the app offers a company
   switcher (would need a "companies for this owner" endpoint). MVP assumes
   **one company per owner login**.

_No EF migrations are implied by this plan. Any backend change (e.g. a seatless
login path) needs the **user's API restart** — never restarted from here._

---

## 5. Screens (MVP → later)

**Phase 1 — MVP**
- **Login** — email/password, show/hide, "remember me", API-URL field, error toast.
- **Summary dashboard** — top of app:
  - KPI tiles: Total sales, Profit (`GetProfit`), Refunds (`GetRefundItemList`),
    Unpaid (`GetUnpaidSales`).
  - Trend chart: daily line/bar (`GetDailySales`) with a monthly toggle
    (`GetDashboardData.monthlySales`).
  - Hourly bar (`GetHourlySales`) — busiest hours.
  - Top products / groups / customers (from `GetDashboardData`).
  - **Date range selector** reused everywhere: Today / Yesterday / This week /
    This month / Custom.

**Phase 2 — Sales detail views** (one list screen per family, shared table widget)
- Sales by product / group / customer / user / payment type / tax / table.
- Sales item list, discounts granted, items discounts.

**Phase 3 — Stock, purchasing, invoices**
- Low-stock & reorder alerts (`GetLowStockWarning`, `GetReorderProductList`).
- Stock movement, purchases suite, invoice list with drill-down.

**Phase 4 — Polish**
- Biometric app-lock, dark/light theme, optional FR/AR (reuse POS arb keys),
  and (stretch) a **daily-summary push notification** — this one *does* need new
  backend work (a scheduled job + FCM/APNs), so it's explicitly out of MVP.

---

## 6. Security notes
- **Read-only by construction** — the app only calls `GET` endpoints; it never
  imports write paths.
- JWT in secure storage; TLS enforced; optional biometric gate.
- Owner credentials are real POS user credentials with an elevated role — treat
  the same as an admin login.

---

## 7. Distribution
- **Android:** signed APK / Play Console internal track. Straightforward.
- **iOS:** requires an **Apple Developer account** ($99/yr) for TestFlight or App
  Store. If the owner is a single known user, **TestFlight** (or ad-hoc) is the
  low-friction path. → decision needed.

---

## 8. Milestones

| Phase | Deliverable | Depends on |
|---|---|---|
| 0 | Public HTTPS endpoint + seatless login confirmed | infra/owner decision (§4.1, §4.2) |
| 1 | App scaffold, login, summary dashboard, date range | Phase 0 |
| 2 | Full sales report views | Phase 1 |
| 3 | Stock / purchasing / invoice drill-down | Phase 2 |
| 4 | Biometrics, i18n, (stretch) push | Phase 3 |

---

## 9. Open decisions for the owner/user (answer before Phase 1)
1. **Hosting:** public domain + TLS, or Tailscale-on-the-phone? (§4.1)
2. **Seat cap:** OK to add a seatless owner-login path if login currently burns a
   seat? (§4.2)
3. **Companies:** one company per owner login, or a multi-tenant switcher? (§4.5)
4. **MVP views:** is the summary dashboard enough for v1, or is a specific report
   (e.g. sales-by-product, unpaid) a must-have on day one?
5. **iOS distribution:** is there an Apple Developer account for TestFlight/App
   Store?
6. **Branding:** app name, icon, and whether it should visually match the POS
   theme.
