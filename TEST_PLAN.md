# POS Test Plan

Every test this ecosystem needs, what it proves, and what has to exist before it
can run. Three suites feed one another:

| suite | where | drives |
|---|---|---|
| **Cypress** | `e2e/` | the admin portal and the owner dashboard, in a browser |
| **Flutter integration** | `Front-End/integration_test/` | the real POS app on Windows and Android |
| **Flutter unit / widget** | `Front-End/test/` | logic and guards that need no device |

---

## Legend

| | meaning |
|---|---|
| 🟩 | **Built and green** — has run end to end and passed |
| 🟨 | **Built, not yet run on a device** — code exists, `flutter analyze` clean, awaiting a real run |
| ⬜ | **Not built** |

Counts as of this revision: **28 🟩** · **2 🟨** · **119 ⬜** — 149 tests total, 30 built (20%).

---

## How the numbered chain works

The numbered Flutter tests are a **chain**: each one leaves the state the next
one needs. The number is the run order, which is why the files are named
`01_…`, `02_…` and carry `// ignore_for_file: file_names`.

```
Cypress 02  →  provisions a company        →  e2e/output/pos-credentials.json
   01       →  registers this terminal     →  the device is linked  (spends a seat)
   02       →  pins the language           →  one-time, per terminal
   03       →  groups, tax, products, kg   →  writes the catalogue back to that JSON
   04       →  stock + reorder rules       →  reads the catalogue from that JSON
   05       →  modifier groups             →
   06       →  a retail sale, by scan      →  reads a barcode from that JSON
   07       →  a real named customer       →  writes the customer to that JSON
   08       →  a second warehouse          →  split sourcing has somewhere to split
   09       →  card / voucher / account    →  credit, split payment, customer-required
   10       →  a cashier beside the admin  →  security keys become observable
   11       →  locks 2 rules, signs in as each  →  admin passes, cashier refused, rules restored
   12       →  void reasons                →  the void dialog has something to offer
   13       →  barcode nomenclature        →  21 = weight, 23 = price, alongside the seeded set
```

**🚨 Only `01` spends a licence seat.** It has to wipe and re-register to prove
the first-install path. Everything after it starts from a linked terminal and
can be re-run as often as you like.

**🚨 The handoff between tests is a FILE, not memory.** Each numbered test is its
own `flutter test` process against its own fresh app boot, so nothing survives in
memory. `pos-credentials.json` carries the company, the customer and now the
catalogue.

---

## 0 · Admin portal and dashboard — Cypress

Provisioning happens in a browser, so it stays in Cypress.

| # | Test | Proves | Status |
|---|---|---|---|
| C1 | `01-admin-login` | Anonymous redirect, wrong-password handling that does not leak whether a user exists, successful sign-in | 🟩 |
| C2 | `02-provision-company` | A company, its Master-DB subscription tenant, its logo, its first user as Admin — and writes `pos-credentials.json` | 🟩 |
| C3 | `03-dashboard-login` | The owner dashboard signs in against Dev and scopes itself to that company | 🟩 |
| C4 | `04-load-time` | First paint is measured and reported | 🟩 |
| C5 | Suspend / reactivate a subscription | A lapsed company is refused at master login with the licensing message, and recovers when reactivated | ⬜ |
| C6 | Seat cap enforcement | The 4th terminal on a 3-seat company is refused, naming the limit | ⬜ |
| C7 | Edit company profile | Name, tax number, address and logo changes reach the POS on its next sync | ⬜ |
| C8 | Dashboard reports a real sale | A sale rung up on the till appears in the owner dashboard's figures | ⬜ |
| C9 | Admin portal user management | Creating, disabling and deleting a company user | ⬜ |

---

## 1 · Foundation chain — shared by every shop type

These build the shop. Both retail and restaurant scenarios start from them.

| # | Test | Proves | Depends on | Status |
|---|---|---|---|---|
| 01 | `01_login_new_company` | Device registration, onboarding, PIN create-and-verify, licensing | C2 | 🟩 |
| 02 | `02_set_language` | The company's `Application.Language` is written and the terminal follows | 01 | 🟩 |
| 03 | `03_setup_catalog` | Groups (parent + child), a tax, three product kinds, **kg on the weighed one**, EAN-13 barcodes, all verified after sync | 01 | 🟩 |
| 04 | `04_setup_stock` | Warehouse assignment and reorder rules for every stockable product, from the recorded catalogue | 03 | 🟩 |
| 05 | `05_setup_modifiers` | Modifier groups in both shapes — optional-many and required-one, incl. a negative surcharge | 01 | 🟩 |
| 06 | `06_make_sale_retail` | The money path for a counter shop, **sold by scanning** | 03, 04 | 🟩 |
| 07 | `07_create_customer` | A real (non-walk-in) customer, online-first, recorded to the credentials file | 01 | 🟩 |
| 08 | `08_create_warehouse` | A second stock location, so item-level sourcing has somewhere to split to | 01 | 🟩 |
| 09 | `09_create_payment_types` | Card + Voucher (both `markAsPaid`) and Account (`markAsPaid: false`, `customerRequired`) | 07 | 🟩 |
| 10 | `10_create_users` | An ADMIN **and** a CASHIER, each given a PIN via *Admin: Reset Device PIN*, both recorded to `pos-credentials.json` | 01 | 🟩 |
| 11 | `11_security_rules` | The real shift change: lock Settings + Management, then sign in as each user in turn — the admin gets in, the cashier is **refused at the till** — then restore | 10 | 🟩 |
| 12 | `12_void_reasons` | Three reasons the void dialog can offer, with their ranks — `RequireReasonOnVoid` is unusable without them | 01 | 🟨 |
| 13 | `13_barcode_rules` | A weight format and a price format added alongside the seeded four, verified through the editor's own matcher | 01 | 🟨 |

---

## 2 · Retail shop

> **The shop:** counter service. Sells **by barcode**. **No** tables, **no**
> bookings, **no** saved orders to park or reopen.
>
> Configured by `configureRetailMode` — floor plan off, booking off, tableless
> on, Tables/Booking buttons hidden, landing screen `POS`.
>
> 🚨 **"No saving orders" cannot be configured — only avoided.** The till's SAVE
> button is gated solely by `cartItems.isNotEmpty` (`menu_screen.dart`): no
> feature flag, no `ButtonBar.ShowSave`. A tableless order parks fine as an open
> ticket. The retail flow scans and pays and never touches it, but the button is
> on screen. **See R50 — that is a product gap, not a test gap.**

### 2.1 Selling

| # | Test | Proves | Status |
|---|---|---|---|
| R1 | Sell by scanning a barcode | The scan path (`_handleBarcodeSubmit`), local row, server row, same number | 🟩 (06) |
| R2 | Sell by tapping a product card | The grid path, for a shop without a scanner | ⬜ |
| R3 | Sell by product code typed into search | The code lookup, which is tried before barcodes | ⬜ |
| R4 | Sell a **weighed** product | The keypad-instead-of-scale path, a fractional quantity, `kg` on the line | ⬜ |
| R5 | Sell a **weight-embedded barcode** | A scale-printed label rings up the right weight, not the raw digits. Unblocked by `13` (prefix 21) | ⬜ |
| R6 | Sell a **price-embedded barcode** | The label's price overrides the shelf price. Unblocked by `13` (prefix 23) | ⬜ |
| R7 | Sell a **service** product | No stock is deducted — the inventory check is skipped for services | ⬜ |
| R8 | Sell multiple lines | Several products in one cart, one document, correct grand total | ⬜ |
| R9 | Increase quantity on a line | The quantity keypad, and the line total following it | ⬜ |
| R10 | Remove a line | The cart and the total both drop | ⬜ |
| R11 | Clear the whole cart | Nothing is banked and no document is created | ⬜ |
| R12 | Age-restricted product | The age gate is answered before the line exists | ⬜ |
| R13 | Price-changeable product | The shelf price is offered and can be overridden | ⬜ |
| R14 | Sell with a **modifier** attached | An optional-many group's choices reach the document line | ⬜ |
| R15 | Required-one modifier **blocks** the sale | The sale cannot complete until a choice is made | ⬜ |
| R16 | Scan an unknown barcode | The reject tone fires and nothing enters the cart | ⬜ |
| R50 | **SAVE cannot be hidden** — product gap | A retail shop is told it has "no saved orders", yet the till always offers SAVE. Needs a `ButtonBar.ShowSave` setting before a test can assert its absence | ⬜ |
| R51 | Search bar off disables scanning | With `ButtonBar.ShowSearch` false there is nowhere for a scan to land — `configureRetailMode` forces it on | ⬜ |

### 2.2 Money

| # | Test | Proves | Status |
|---|---|---|---|
| R17 | Cash with change | `min(tendered, total)` is banked — change is not money the shop took | ⬜ |
| R18 | Exact cash | No change line | ⬜ |
| R19 | Card payment | A non-cash type banks correctly | ⬜ |
| R20 | **Split payment** | Part cash, part card, adding to the grand total | ⬜ |
| R21 | **Credit / tab** sale | `markAsPaid: false` banks the sale UNPAID with an outstanding balance | ⬜ |
| R22 | Credit is **refused** for the walk-in | `isCustomerRequired` blocks `C000` by name | ⬜ |
| R23 | Credit **allowed** for a real customer | The customer from `07` sold to on the Account type from `09` | ⬜ |
| R24 | Line discount | A percentage off one line, reflected in the total and the document | ⬜ |
| R25 | Document discount | A discount across the whole sale | ⬜ |
| R26 | Discount barcode | A scanned discount label applies to the line it was scanned on | ⬜ |
| R27 | Customer discount profile | A customer's own discount applies automatically | ⬜ |
| R28 | Promotion applies | An active promotion changes the price at the till | ⬜ |
| R29 | Loyalty points earned | Points land on the customer's card | ⬜ |
| R30 | Loyalty points redeemed | Points come off a sale | ⬜ |
| R31 | Tax-inclusive vs tax-exclusive | `IsTaxInclusivePrice` changes the arithmetic, not the shelf price | ⬜ |
| R32 | Dual currency display | The second currency is shown at the configured rate | ⬜ |
| R33 | Rounding mode | The configured rounding is applied to the grand total | ⬜ |

### 2.3 After the sale

| # | Test | Proves | Status |
|---|---|---|---|
| R34 | **Refund** a sale | A refund document, the stock returned, the money out | ⬜ |
| R35 | Partial refund | One line of a multi-line sale | ⬜ |
| R36 | **Void** an item before payment | The void is recorded with its reason. Unblocked by `12` | ⬜ |
| R37 | Void requires a reason | `requireReasonOnVoid` blocks a bare void. Unblocked by `12` | ⬜ |
| R38 | Reprint a receipt | The same document prints again | ⬜ |
| R39 | Documents list and editor | A banked sale is findable and readable afterwards | ⬜ |

### 2.4 Stock behaviour

| # | Test | Proves | Status |
|---|---|---|---|
| R40 | Stock **deducts** on a sale | On-hand drops by exactly what was sold | ⬜ |
| R41 | **Delta logic** on an updated order | Only the DIFFERENCE is deducted — no double-deduction | ⬜ |
| R42 | Removing an item **returns** stock | The quantity goes back on the shelf | ⬜ |
| R43 | Low-stock warning fires | A product under its threshold is flagged (set up by `04`) | ⬜ |
| R44 | Reorder point flag | A product under its reorder point is listed as needing reorder | ⬜ |
| R45 | **Out of stock** is a graceful 400 | `{ success: false, message, fallbackWarehouses, failedProductId }` — not a 500 | ⬜ |
| R46 | Fallback warehouse dialog | The UI offers the fallback warehouses the API named | ⬜ |
| R47 | `PreventNegativeInventory` off | The sale goes through and stock goes negative | ⬜ |
| R48 | **Split sourcing** | Product A from warehouse A and product B from warehouse B, in ONE cart | ⬜ |
| R49 | Unassigned products are listed | The stock screen shows every product, "Unassigned" included | ⬜ |

---

## 3 · Restaurant

> **The shop:** table service. **No** barcode selling. Tables **only**. **No**
> bookings. Orders **are** saved and reopened, their **status** changes, and they
> carry a **service type**.
>
> Needs a `configureRestaurantMode` helper — floor plan on, booking off,
> tableless off, `Feature_ServiceType_Enabled` and
> `Feature_ServiceStatus_Enabled` on.

### 3.1 Setup

| # | Test | Proves | Status |
|---|---|---|---|
| T1 | `configureRestaurantMode` | The flags above are written and the till re-renders as a floor plan | ⬜ |
| T2 | Create a floor plan | A room exists | ⬜ |
| T3 | Create tables on it | Round and square, positioned, named | ⬜ |
| T4 | Custom service types | `customServiceTypes` — dine-in, takeaway, delivery | ⬜ |
| T5 | Custom service statuses | `customServiceStatuses` — ordered, preparing, served | ⬜ |

### 3.2 Table orders

| # | Test | Proves | Status |
|---|---|---|---|
| T6 | A tap **without** a table is refused | `AllowTablelessOrders: false` sends the cashier to the floor plan | ⬜ |
| T7 | Open an order on a table | The table goes occupied and the cart carries `floorPlanTableId` | ⬜ |
| T8 | **Save** the order | It parks against the table and the cart clears | ⬜ |
| T9 | **Reopen** a saved order | Every line comes back, with its modifiers | ⬜ |
| T10 | Add to a reopened order | The delta reaches the order, not a second one | ⬜ |
| T11 | Remove from a reopened order | The line goes and the stock returns | ⬜ |
| T12 | **Transfer** to another table | The order moves; the first table frees | ⬜ |
| T13 | **Merge** two tables' orders | One order, both sets of lines | ⬜ |
| T14 | **Split** a bill | Two documents from one order | ⬜ |
| T15 | Pay and close the table | The table frees and the document banks | ⬜ |
| T16 | Occupied tables are visible | `showAllOccupiedTablesInFloorPlan` | ⬜ |
| T17 | Walk-in table order | `allowWalkInTableOrders` | ⬜ |
| T18 | An offline table keeps its order | A table created offline holds a temp negative id; `remapFloorPlanTableRefs` rewrites it | ⬜ |

### 3.3 Order status and service type

| # | Test | Proves | Status |
|---|---|---|---|
| T19 | Set the service type on an order | Dine-in / takeaway / delivery reaches the document | ⬜ |
| T20 | Change order status | Ordered → preparing → served, each persisted | ⬜ |
| T21 | Status drives the floor plan colour | The table shows what stage it is at | ⬜ |
| T22 | Kitchen print on checkout | `autoKitchenPrintOnCheckout` sends the ticket | ⬜ |

### 3.4 Kitchen Display System

| # | Test | Proves | Status |
|---|---|---|---|
| K1 | KDS onboarding | The KDS pairs with a company | ⬜ |
| K2 | KDS receives an order | An order rung up on the till appears on the kitchen screen | ⬜ |
| K3 | KDS marks an item ready | The status change reaches the till | ⬜ |
| K4 | KDS bumps a whole order | It leaves the screen and the table updates | ⬜ |
| K5 | KDS over LAN | `lan_server.dart` — the till and the KDS find each other on the network | ⬜ |
| K6 | KDS language | The KDS renders in the company's language | ⬜ |

---

## 4 · Cross-cutting — both shop types

### 4.1 Session and cash

| # | Test | Proves | Status |
|---|---|---|---|
| X1 | Open the register with a float | The opening control and the float | ⬜ |
| X2 | Sale is attached to the session | `sessionLocalId` on the document | ⬜ |
| X3 | Cash in / cash out | A movement is recorded against the drawer | ⬜ |
| X4 | Close the register | The closing control, the counted cash, the difference | ⬜ |
| X5 | `maxCashDifference` is enforced | A difference over the limit is refused or escalated | ⬜ |
| X6 | Z report | Totals match the day's sales | ⬜ |
| X7 | A session on ANOTHER terminal must be joined | Not opened over the top — the two-session guard | ⬜ |
| X8 | `RequireOpenSession` off | A sale banks unattached, by design | ⬜ |
| X9 | Sessions belong to a REGISTER | `registerUidProvider`, not `deviceUidProvider` | ⬜ |
| X10 | Shifts and time clock | Clock in, clock out, hours recorded | ⬜ |

### 4.2 Offline and sync

| # | Test | Proves | Status |
|---|---|---|---|
| X11 | Sell fully offline | The sale banks locally with a locally-issued number | ⬜ |
| X12 | Offline sale syncs on reconnect | BatchSync keeps the device's number rather than generating its own | ⬜ |
| X13 | Offline catalogue edit syncs | A product created offline gets a real id on reconnect | ⬜ |
| X14 | Temp negative ids are re-keyed | Products, taxes, groups, modifier groups, floor-plan tables | ⬜ |
| X15 | Sync conflict | Two terminals edit the same row | ⬜ |
| X16 | Pull from server | A change made in the dashboard reaches the till | ⬜ |
| X17 | Sync queue survives a restart | Pending writes are still pending after a reboot | ⬜ |
| X18 | Document delete reconcile | Already covered in `test/` — extend to the real app | ⬜ |

### 4.3 Hardware

| # | Test | Proves | Status |
|---|---|---|---|
| X19 | Receipt printing | The layout, the totals, the footer | ⬜ |
| X20 | Receipt custom labels | `receiptUseCustomLabels` and the label overrides | ⬜ |
| X21 | Invoice A5 / RTL | `invoicePrintA5`, `invoiceRightToLeft` | ⬜ |
| X22 | Cash drawer opens | `cashDrawerCommand` fires on a cash sale | ⬜ |
| X23 | Customer display | The serial and web customer displays show the line and the total | ⬜ |
| X24 | Scale integration | A configured scale delivers a weight | ⬜ |
| X25 | Sounds | Scan OK, scan fail, checkout, error | ⬜ |

### 4.4 Platform, UI and access

| # | Test | Proves | Status |
|---|---|---|---|
| X26 | **Android tablet, 10-inch landscape** | No RenderFlex overflow anywhere in the chain (CLAUDE.md rule 2) | ⬜ |
| X27 | **Dark mode** across every screen | No hardcoded colours (CLAUDE.md rule 3) | ⬜ |
| X28 | Arabic / RTL | Layout mirrors correctly | ⬜ |
| X29 | Ilyass Screen contract | A sidebar destination is a TAB; `IlyassLeading` decides from the mounting | ⬜ |
| X30 | `ilyassLeave` returns to the shell | A bare `Navigator.pop()` from a tab would sign the cashier out | ⬜ |
| X31 | Security key blocks a tab | Covered by `11` for Settings and Management. 🚨 There is **no override flow** — `guardWithDialog` says "ask an admin" with an OK button and nothing else; an earlier draft of this plan wrongly listed a PIN override | 🟩 (11) |
| X32 | PIN lockout | Repeated wrong PINs | ⬜ |
| X33 | Licence expiry mid-session | The till degrades gracefully | ⬜ |
| X34 | App update check | `autoCheckUpdates` | ⬜ |
| X35 | DB backup and restore | `dbAutoBackup`, `dbBackupOnClose`, restore path | ⬜ |

---

## 5 · Guards and utilities — no device needed

These protect the test suite itself, and run in plain `flutter test`.

| # | Test | Proves | Status |
|---|---|---|---|
| G1 | `dropdown_smart_default_test` | The Index-0 rule skips null placeholders AND disabled category headers, filtering by value not localised text | 🟩 |
| G2 | `locale_settle_test` | `waitForStableLocale` survives a locale that changes mid-run | 🟩 |
| G12 | `clear_search_test` | `clearSearch` tolerates a screen with no search box; `searchList` still fails loudly on one — the Users screen has none | 🟩 |
| G13 | `sibling_finder_test` | Two ambiguous-finder traps: `find.ancestor` cannot reach a control laid out BESIDE its label (`enclosingRow` can); and `find.byIcon` alone hits the till's *disabled* Modifiers button instead of sidebar Quick Settings (`sidebarIconButton` does not) | 🟩 |
| G3 | `cipher_test` | Local database encryption | 🟩 |
| G4 | `clear_local_data_test` | Wipes this terminal's saved identity | 🟩 |
| G5 | `smart_defaults_test` | The resolution rule against the real app (levels 2 and 3) | 🟩 |
| G6 | `device_name_test` | Existing | 🟩 |
| G7 | `document_delete_reconcile_test` | Existing | 🟩 |
| G8 | `document_session_link_pull_test` | Existing | 🟩 |
| G9 | `session_offline_conflict_test` | Existing | 🟩 |
| G10 | Helper contract guard | Every `helpers/*.dart` exports exactly one flow and hardcodes no UI string | ⬜ |
| G11 | `verifyPersisted` SQL guard | The generated T-SQL escapes `[` — a naive `LIKE '%[E2E …]%'` matches almost every row | ⬜ |

---

## 6 · What to build next

Ordered by how much each unlocks.

1. **R19–R23 money paths** — `09` just built the types that unblock card, split payment and credit, and `07` built the customer the credit path demands. This is the largest ready-to-write block in the plan.
3. **R48 split sourcing + R45–R46 out-of-stock 400** — `08` unblocks both. The 400 is a named contract in CLAUDE.md with a structured payload, worth pinning before it drifts.
4. **12 void reasons + 13 barcode rules** — the last two foundation pieces; `13` unblocks R5/R6/R26 (weight-, price- and discount-embedded barcodes).
5. **R40–R42 stock movement** — the delta logic is core business logic in CLAUDE.md and has no test at all.
6. **T1–T9 restaurant basics** — a whole shop type with nothing built. `configureRestaurantMode` is the unlock, and it mirrors `retail_mode_helper.dart`.
7. **X11–X14 offline** — the app is offline-first and none of that path is covered end to end.
8. **X26–X27 tablet and dark mode** — two hard rules in CLAUDE.md that nothing currently enforces.

---

## Appendix · Helpers available today

Each flow lives in its own file (`Front-End/integration_test/helpers/`), per the
"Modular Test Helpers with Smart Defaults" contract in `CLAUDE.md`.

| helper | exports |
|---|---|
| `e2e_context.dart` | `E2EContext`, `E2EArtifact` |
| `login_helper.dart` | `loginToCompany` |
| `set_language_helper.dart` | `setTerminalLanguage` |
| `create_tax_helper.dart` | `createTax` |
| `create_group_helper.dart` | `createProductGroup` |
| `create_product_helper.dart` | `createProduct`, `ProductKind` |
| `add_barcode_helper.dart` | `addBarcode` |
| `setup_stock_helper.dart` | `assignStock`, `setStockRules`, `openStockFor` |
| `create_modifier_group_helper.dart` | `createModifierGroup`, `E2EModifierOption`, `awaitModifierGroup` |
| `record_catalog_helper.dart` | `recordE2ECatalog`, `loadE2ECatalog`, `E2EProduct`, `E2ECatalog` |
| `create_customer_helper.dart` | `createCustomer` |
| `create_warehouse_helper.dart` | `createWarehouse`, `openWarehouses` |
| `create_payment_type_helper.dart` | `createPaymentType` |
| `create_user_helper.dart` | `createUser`, `UserRole` |
| `security_rule_helper.dart` | `setSecurityLevel`, `securityLevelOf`, `SecurityLevel` |
| `reset_user_pin_helper.dart` | `setUserDevicePin` |
| `record_users_helper.dart` | `recordE2EUser`, `loadE2EUsers`, `E2EUser` |
| `switch_user_helper.dart` | `logoutFromTill`, `signInAsUser` |
| `guarded_access_helper.dart` | `expectGuardedScreen`, `GuardedScreen` |
| `create_void_reason_helper.dart` | `createVoidReason` |
| `barcode_rule_helper.dart` | `addBarcodeRule`, `testBarcodeMatch`, `openBarcodeRules` |
| `retail_mode_helper.dart` | `configureRetailMode` |
| `open_register_helper.dart` | `ensureRegisterOpen`, `ensureTablelessAllowed` |
| `make_sale_helper.dart` | `makeSale`, `E2ESale` |
| `verify_product_helper.dart` | `verifyProduct` |
| `verify_sale_helper.dart` | `verifySaleBanked`, `verifySaleOnServer` |
| `verify_persisted_helper.dart` | `verifyPersisted`, `writeRunManifest` |

### Helpers still needed

| helper | for |
|---|---|
| `restaurant_mode_helper.dart` | T1 — the mirror of `retail_mode_helper` |
| `create_floor_plan_helper.dart` | T2, T3 |
| `save_order_helper.dart` | T8, T9 — park and reopen |
| `order_status_helper.dart` | T19–T21 |
| `refund_helper.dart` | R34, R35 |
| `discount_helper.dart` | R24–R27 |
| `session_helper.dart` | X1–X6 — cash in/out, close, Z report |
| `offline_helper.dart` | X11–X14 — cutting and restoring the network |
