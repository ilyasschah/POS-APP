# Field test — Verteda POS, Test server

First real-hardware run. Printer, cash drawer and scanning all work. Everything below is what broke.

Status: `TODO` · `WIP` · `DONE`

---

## A · Printing / receipt

| # | Issue | Status |
|---|---|---|
| A1 | Kitchen printer settings must not show the **Cash drawer** tab or **Print barcode** — neither applies to a kitchen ticket. | DONE |
| A2 | Kitchen printer **Test demo** prints a receipt demo. It should print a kitchen-ticket demo: products + comments/modifiers. | DONE |
| A3 | With **Show printing dialog** disabled, payment opens the drawer but **nothing prints**. Silent-print path is broken. | DONE |
| A4 | No company logo → print a **large company name** in its place instead of nothing. | DONE |
| A5 | Receipt barcode prints the **order id**; it must be the **document barcode number**. | DONE |
| A6 | A product with a modifier prints as one merged `25.00`. Show the **base price alone (20.00)**, the extra on its own line beneath, and only the **line total (25.00)** in totals. Same in the payment item list. | DONE |
| A7 | Quantity must carry its **unit**: `0.125 kg × 50.00 dh`, not `0.125 × 50.00 dh`. Receipt **and** payment item list. | DONE |

## B · Cash session / Z-report

| # | Issue | Status |
|---|---|---|
| B1 | **Cash in** entered when opening a session is never written to the cash-movement table, so the Z-report has no opening float. | DONE |

**B1 done.** Two halves. The Z-report prints an **Opening cash** line from the session's `startingCash`, and the float is now a real row in `starting_cash` under a **third kind** — `opening` locally, `StartingCashType = 2` on the wire. It is displayed and never summed: expected cash is `openingCash + cashPayments + cashIn - cashOut`, so a plain type-0 row would have added the float twice and every register would have read over by it. All four server sums and both client sums already name the kind they want (`== 0` / `== 1`), so the new kind falls through untouched — `CashMovementKind` documents why that must never be rewritten as "everything that is not out". Written at `confirmOpening`, i.e. the counted figure, not the expected one.

| B2 | Z-report prints to the receipt printer from the **End of Day** screen, but not from the **POS session-closing dialog**. | DONE |

## C · Hardware

| # | Issue | Status |
|---|---|---|
| C1 | Customer display does not work. POS settings offer **COM10** while Windows only has **COM1–COM5 + LPT1** — the port list is not enumerated from the machine. Needs real port discovery, and LPT support. | DONE |

## D · Products

| # | Issue | Status |
|---|---|---|
| D1 | Deleting a product barcode does not stick — it disappears for ~1 s and comes back. Blocks switching a sold product over to sell-by-weight. | DONE |

## E · Layout

| # | Issue | Status |
|---|---|---|
| E1 | Sidebar **full screen** button does nothing on Windows (works on macOS). | DONE |
| E2 | At **1366×768** the cart is too tight — barely 2 items visible. Add a **show/hide keypad** toggle to give the cart its height back. | DONE |

## F · Web dashboard

| # | Issue | Status |
|---|---|---|
| F1 | After logging in as the new company, the dashboard shows another company's data and keeps falling back to a different user. New company appears to have no dashboard access. | DONE |

**F1 root cause.** `AppConfig.companyId = 25` was a compile-time constant applied to every request, so the dashboard reported company 25's figures whoever signed in, and a new company looked like it had "no access" because the server was never asked about it. Two smaller faults compounded it: the login field was pre-filled with a hardcoded developer address, and the bearer token was persisted (despite a comment claiming it was not) without the company it belonged to, so a reload came back up under the previous session. The tenant now comes from `user.companyId` in the login response, is stored and cleared with the token, and the API client refuses to build a scoped request without one.

**Cross-tenant hole — CLOSED.** It was not the dashboard endpoint alone: tenant scope was carried by a `companyId` in the query string or body on ~250 endpoints and never once compared to the caller's token, so documents, payments, cash movements, customers and users were readable and writable the same way. Fixed globally with `Filters/CompanyScopeFilter.cs`, registered in `Program.cs` — fail closed, opt out with `[AllowCrossCompany]`. Exemptions are exactly three: `Master.Provision` (the company being created), `Master.CheckDevice` (master login, before a company is chosen) and `Company.GetAll` (the master-login picker). A test asserts that list stays at three.

**Still open, same family:** `Master/Tenants`, `Master/Subscriptions` and `Master/Devices` take no `companyId`, so the tenant filter does not apply — any authenticated user can list every tenant on the platform. That needs a control-plane role, not a tenant check, and is a separate decision.

