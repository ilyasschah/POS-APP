# Field test — Verteda POS, Test server

Round 2, tested on **v1.0.6**. Everything from round 1 passed except what is below.

Status: `TODO` · `WIP` · `DONE`

---

## Open

| # | Issue | Status |
|---|---|---|
| A4 | No company logo → print a **large company name** in its place. | READY TO TEST |
| B1b | Z-report **dialog** shows `Cash In +0.00` and no opening float. The database row is correct and the session screen shows `+500.00` — only the dialog is wrong. | DONE |
| G1 | **Continue selling** / **Close Register** should be floating buttons on the POS screen, in different colours. **Close Register** also belongs in the POS menu header, and both need show/hide switches in POS Settings. | DONE |

---

### B1b — what was actually wrong

B1 itself is fine: the float **is** written to `starting_cash` as kind `opening` / `StartingCashType = 2`, the session screen shows it (`Cash movements  + 500.00 MAD`, Session #19), and expected cash comes out right (`500 + 63 = 563`, difference `0.00`).

The gap was display-only, and only in one place. The **printed** Z-report gained an `Opening cash` line; `showZReportDialog` accepted the `openingCash` argument and passed it straight through to the printer **without ever rendering a row for it**. So the one screen the cashier actually reads showed `Cash In +0.00` and nothing else, while the money sat in the drawer and in the database.

Fixed in `z_report_receipt_dialog.dart` — the dialog now renders `Opening cash` above Cash In. It stays **out** of the Cash In total on purpose: the session's own `startingCash` already carries the float into expected cash, so adding it to Cash In would count it twice and every register would read over by its float.

⚠️ The row only appears for a **session** Z-report. Opened from the Z-report list (End of Day, company-wide), there is no single session and therefore no single float, so the line is hidden rather than guessed at.

### A4 — you can now reach the "no logo" state

The receipt fallback already shipped in v1.0.6 (`logoBytes == null ? 24 : 16`). What was missing was any way to **test** it: once a company had a logo there was no way to take it off again.

`My Company` now has a **Remove logo** button (the red bin, bottom-left of the logo circle), behind a confirm. It is its own endpoint — `DELETE /Company/DeleteLogo` — rather than an empty upload, because `UpdateLogo` validates the payload as non-empty and relaxing that would let a truncated file wipe a logo by accident.

Remove the logo, print a receipt, and the company name should come out at 24pt where the logo was. If a **Header** text is set in Printer Settings it wins over the company name — that is by design, but it is the likely reason a receipt shows something other than the name.

### G1 — done

* **Session screen:** the two actions left the AppBar, where they were two identical grey buttons. They are now stacked floating buttons — **green** Continue selling, **red** Close Register. A blocked close goes grey, not a quieter red: a close that cannot happen must not look like one that can.
* **Till header:** Close Register sits after Addition, so ending the day no longer means navigating away from the POS to find the session screen.
* **Settings → POS buttons:** two new switches, `Close Register` and `Continue selling`. The Close Register switch governs the button in **both** places — one action, one switch.

---

## Closed in round 1

A1 A2 A3 A5 A6 A7 · B1 B2 · C1 · D1 · E1 E2 · F1 — all verified on v1.0.6.

Also closed alongside F1:

* **Cross-tenant hole.** `companyId` came from the query string or body on ~250 endpoints and was never compared to the caller's token, so any signed-in user could read or write another company's documents, payments, cash and users by editing the URL. Closed globally by `CompanyScopeFilter`; three deliberate exemptions, asserted by a test.
* **Control plane.** `Master/Tenants`, `Subscriptions` and `Devices` carry no `companyId`, so the tenant filter cannot help them — every cashier's token could list every tenant on the platform. They now require the admin portal's operator identity (`[ControlPlane]`).
* **Dashboard deploy never fired.** Its workflow filtered on `OCTOPUS_DASHBOARD_WEB/**` while the folder is `octopus_dashboard_web`; GitHub path filters are case-sensitive, so pushing to `test` never triggered it and it had only ever run by hand.
