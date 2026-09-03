# Handoff

_Last updated: 2026-09-03._

> 🧹 **This file was CLEANED on 2026-08-30 at the user's request: every item that is done, fixed and tested was deleted.** The code, its tests and git history are the record of what shipped — repeating it here only made the open work harder to find. What is left is **open work and live traps**, nothing else.

> **Current phase: final polish.** The ⭐ **NUMBERED BACKLOG** below is the actionable list — the user picks by number ("do 9"). Numbers are **STABLE** and mirrored in `POS_Manual_tests_NOTES.txt`. A closed item is now *deleted* rather than ticked, and its **number is retired — never reuse it**.
> **Closed and retired:** 1–8, 10, 12, 16–34, 36–40, 43. **Still open: 9, 11, 13, 14, 15, 35, 41, 42, 44.**
> §2 "The Plan" is gone with them — it was entirely completed work; the few lines of it that were still true moved into the backlog below. §0, §1, §3, §4 and §5 keep their numbers.

---

### The `DataBase/SQL` folder — what belongs in it

**Only the definitions of live objects, plus scripts that still have work to do.** Six spent one-offs were deleted on 2026-08-29, each verified against the live database first.

- The 26 `vw_*.sql` and 3 `trg_*.sql` files are the **only copy** of those objects' definitions — EF does not own them, so the file *is* the source. Verified one-for-one against `sys.views` / `sys.triggers`: 26 ↔ 26, 3 ↔ 3, nothing orphaned in either direction.
- `RetireProductComments_2026-08-29.sql` was **deleted on 2026-09-03** with the rest of backlog 43. It was a no-op here — `ProductComment` held 0 rows — and nothing can create a row any more, so it had no work left to do. Git history at that commit is the copy, if a database with a real catalogue ever appears.
- Anything a migration already owns does not belong here: `dotnet ef migrations script` regenerates it on demand.

🚨 **The rule this implies:** a script here is either a live object's definition or unfinished work. Anything else is a file that says a database looks one way when it no longer does — which is worse than no file, because it gets believed.

## ⭐ NUMBERED BACKLOG — the user picks by number ("do 9")

### Needs a hardware / dependency answer
9. 🧪 **READY TO TEST — Android silent printing, LAN half built 2026-08-30.** Every printer now carries a `<Role>.Connection` of `system` | `network`; `network` rasterises the finished PDF and pushes ESC/POS to port 9100. Receipts, kitchen tickets and Z-reports all route through the one dispatcher, so all three arrive. **The page is rasterised, not re-described in printer text commands** — that is what keeps the logo, the barcode, the margins and above all the **Arabic** exactly as the PDF lays them out; a printer's built-in font has no Arabic on almost any unit, so a text-command implementation would have thrown away the whole `printed_text.dart` effort. `escpos_raster.dart` (27 tests, including an encode→decode round trip that rebuilds the image) and `network_printer.dart` (10 tests over a real loopback socket) are covered; `escpos_job.dart` is the thin glue that needs a Flutter engine and cannot be unit-tested. **Still open:** a real thermal printer has never seen this, and Bluetooth / USB-OTG are not built — LAN was the agreed first transport. See `POS_Manual_tests_NOTES.txt` [B5].

### Production prerequisites (do before shipping)
11. **Re-enable Pillar-3 encryption.** `kPillar3Encryption = false` in `app_database.dart` is a dev toggle. Set `true`, relaunch (auto re-encrypts), then `flutter test integration_test/cipher_test.dart -d windows` must pass.
13. **Point the API endpoint back to production.** Dev default is `AppConfig.devBaseUrl = http://100.114.12.38:5002/api`; switch to the hosted URL before building release.
14. **Fix `flutter build apk` (JDK).** Broken on this machine — Kotlin can't parse Java 25 (`IllegalArgumentException: 25.0.2`). Install a **JDK 21** and `flutter config --jdk-dir`. Until then the tablets run a stale APK, so "still broken on Android" may just be old code.
15. **Verify the Z-report engine.** `ZReportService.GenerateZReportAsync` was rewritten but has **never executed**; a wrong result is silent (nothing reads it back). After an API restart, verify via the `ZReport` row in SQL Server.
   - **Two carry-overs that land on the same verification.** (a) Client and server scope different document sets: the client reports on documents behind *unreported payments*, the server takes an id range — the session work bounded the server side by `SessionId`, but the two have never been compared on real data. (b) `pullDocuments` carries no item taxes (`buildItems` sets neither `taxRate` nor `taxAmount`), so a document pulled from **another terminal** shows no tax and contributes **0 tax** to this device's Z-report.

### Open bugs / gaps
35. 🧪 **READY TO TEST — the reports module was localized on 2026-08-29, in one pass.** All 36 `_build*Pdf` functions in `reports_screen.dart`, their CSV exports and `stock_screen.dart`'s Stock Report now print in EN/FR/AR (106 new strings). Two shaping bugs were fixed on top: `pw.Text` never shapes Arabic, so every heading came out as disconnected letters running backwards — all 98 text runs, 53 label/value rows and 36 tables now go through `printedText`, with the Arabic face in the STYLE and not only the page theme; and a `:` written inside an Arabic label is a neutral character that gets pushed to the run's visual LEFT, so labels now pass **without** the colon and the helper adds it as its own run (this half touched the RECEIPT, Z-REPORT and INVOICE PDF too). **Awaiting the user's manual round — see `POS_Manual_tests_NOTES.txt` [35].** Not in scope: the report NAMES in the sidebar and the section headings, which were already translated. 🐛 **Crash found and fixed 2026-09-01, introduced by this same pass:** ~22 reports (Products, Product Groups, Hourly Sales by Group, and 18 more through the shared `_pdfHeader` helper) threw `Exception: Flex children have non-zero flex but incoming width constraints are unbounded` and red-screened — the colon fix's label/value `Flexible` run needs a bounded width to size against, and three call sites left their `Row`'s `Column`(s) un-`Expanded`. Fixed in `reports_screen.dart`: the shared header now routes through the one working helper (`_hdrPair`) everywhere instead of a second, unguarded copy of the same layout.
41. 🧪 **READY TO TEST — the over-refund's root cause is found and fixed, 2026-09-01.** It was never a write bug in `Document`/`DocumentItem`: `TotalAfterDocumentDiscount` (44.10 on `POS1-200-000014`) is what the customer actually paid — `Payment.Amount` matches it exactly — while `DocumentItem.Total` (44.60) is the line's price *before* the order-level discount (a promotion or loyalty points, landing in `DiscountLine` rather than the plain `Document.Discount` field, which is why `Discount` read 0 on both rows) is apportioned across the receipt at checkout (`PosOrderCheckoutService.ApportionDocumentDiscount`). `ProcessRefundCommand` was reading `PriceBeforeTaxAfterDiscount` (pre-discount) instead of `TotalAfterDocumentDiscount` (post-discount, what was paid). Fixed: refunds now derive a per-unit "price paid" (`PricePaidPerUnit` — `TotalAfterDocumentDiscount / Quantity`). Verified arithmetically against the live DB — the new formula gives exactly 44.10 for `POS1-200-000014`, not 44.60. 6 other sale lines in the DB have the same shape; not reconciled, since fixing past refunds is a separate call. **Awaiting the user's manual round — see `POS_Manual_tests_NOTES.txt`:** ring up a sale with a promo/loyalty-points discount, refund it, confirm the refund equals what was actually paid.
42. 🧪 **READY TO TEST — the offline conflict policy is BUILT, 2026-09-03.** It was the last piece of the POS Session work. Two halves, because the first alone only narrows the window:
   - **Pre-open refresh** (`OpeningControlDialog._refreshRegisterSession`). Open Register now pulls the register's sessions *before* creating one, and hands the cashier a "Sell in this session" hand-off instead of a float field when one is already live. Bounded to 6s and **fails open** — an offline till opens exactly as before, because a shop with no network must never be stopped from starting its day.
   - **Adopt-on-conflict** (`SyncManager._adoptOnRegisterConflict` → `AppDatabase.adoptSessionInto`). The `"This register already has an open session"` rejection no longer resolves to `sync_failed`. The device asks `/PosSession/Current` which session actually holds the register and re-points its orders, documents, payments and cash in/out onto it, then deletes the duplicate `shifts` row.
   - 🚨 **The opening float is DELETED, never re-pointed**, and that single line is what decides whether the drawer reconciles. Expected cash is `openingCash + cashPayments + cashIn − cashOut` where `openingCash` is the *surviving* session's own `starting_cash`, so carrying a second `opening` movement across shows two floats on one drawer for money counted into it once. See `CashMovementKind`.
   - ⚠️ **A session already CLOSED is never merged** — its payments carry a Z-report number, and moving them would restate a printed slip. That case still parks, with a message saying why. If a real till hits it, it needs a decision rather than a silent repair.
   - `test/session_offline_conflict_test.dart` — 9 tests: the merge, the float rule, the closed-session refusal, a recovery that loses the network mid-repair, and idempotency. **Awaiting the user's manual round — needs TWO TILLS on one register with the network down; see `POS_Manual_tests_NOTES.txt` [B6].**
44. 🆕 **The admin portal shows the wrong company's data, and logs you back in as another company's user** (reported 2026-08-27 in the first field-test list, the **one item of fourteen that `88f314a` did not fix** — it was never diagnosed). Reported verbatim as *"the web dashboard is not showing the correct data for that company after I log in, or the new company doesn't have access to the dashboard, I don't know, it keeps logging back to another user of another company."* **Re-test it after the item-40 rows are repaired** — a user the portal created as an "Admin" was actually written as a **cashier**, which is a complete explanation for *"the new company doesn't have access"* and would make the rest look like a data bug. If it still happens on a user that is genuinely `AccessLevel = 0`, the remaining suspect is the portal's own auth cookie/company scoping, not the API.

### Carried over — still true, not numbered

- **A company can still hold only ONE tax with a blank Code — by schema, not by app** (was backlog 20, closed 2026-09-03 on the user's call). `UQ_Tax_Code_PerCompany` is a plain unique index on `(CompanyId, Code)` and SQL Server counts an empty string as a value. The chosen fix was the free one: `Code` is now required by `AddTaxCommandValidator` and non-blank-when-sent by `UpdateTaxCommandValidator`, matching the tax form, so nothing the app does can ask for a second blank code. An existing code-less tax is left alone — `UpdateTax` still reads an ABSENT `Code` as "leave it", which is what keeps that row syncing rather than parking. **If blank codes are ever wanted, the filtered unique index (`WHERE Code IS NOT NULL AND Code <> ''`) is the schema change that allows them** — still unwritten, still needs explicit approval (CLAUDE.md rule 3).
- **`ProductComment` is retired in code but the SQL Server table is still physically there** (was backlog 43, closed 2026-09-03). Removed: domain model, `DbSet`, all six endpoints, service, repository, commands, queries, mapper; and on the till the Drift table, provider, model, `pullProductComments`, `pushPendingProductCommentOps` and the sync-status row. The local table IS dropped, by schema bump **64 → 65** (`DROP TABLE IF EXISTS product_comments`). 🚨 **The server table was deliberately left standing — no migration was written — but EF's model no longer contains it, so the next migration scaffolded for ANY reason will include a `DROP TABLE` for `ProductComment`.** That is the intended end state; read the generated migration before applying it rather than being surprised by it.
- **`canSellProvider` gates nothing and the no-sale rule is OFF** — deliberate, on the user's instruction. Turning it on is a decision, not a bug fix: it makes an open POS session mandatory before a sale can be rung.
- **Settings are no longer inert — finished 2026-09-03.** `dateFormat` is **wired** (was dead at ~85 call sites in `reports_screen.dart` plus thirteen other files, every one constructing its own `DateFormat('dd/MM/yyyy')`). One `AppDateFormat` value object in `lib/core/app_date_format.dart` behind `appDateFormatProvider`, threaded into all 36 `_build*Pdf` builders as a `dates:` parameter and read via `ref.watch` on the screens. 🚨 **CSV exports and PDF file names deliberately do NOT follow it** — `AppDateFormat.isoDate` / `isoDateTime` and the note at the top of `pdf_file_name.dart` say why at each site: a spreadsheet that parses an export must not change meaning when a display preference changes, silently, and `/` cannot appear in a filename. Also aligned three disagreeing defaults (client was `dd-MM-yyyy`, server seeded `dd/MM/yyyy`, screens drew `dd/MM/yyyy` → all `dd/MM/yyyy`). `email/SMTP` is **retired**, not built — see below. `test/app_date_format_test.dart`, 22 tests.
  - 🚨 **The first pass MISSED every table, and the user caught it at the till** — `yyyy-MM-dd` saved fine and Sales History still printed `01/09/2026 23:42`. **A sweep for `DateFormat('…')` cannot find a formatter that never calls `DateFormat`.** Seven screens plus two printed documents hand-built their dates out of `padLeft` and string joins — *while also converting the timezone* — so they were invisible to the search and to `flutter analyze`: `sales_history_screen`, `documents_screen` (which also baked in a localized month abbreviation), `session_screen`, `session_list_screen` (hardcoded English months + a 12-hour clock), `document_editor_screen`, `promotions_list_screen`, `settings_screen`'s Subscription/About rows, `receipt_printer_service._fmtDateTime`, and the Z-report slip's raw ISO date.
  - **Why they drifted, and why the fix is one object:** those call sites had to do *two* things — resolve the timezone and format the date — and the two lived apart, so the format half could be wired while the hand-rolled half went on ignoring it. `AppDateFormat` now owns both (`toDisplayZone`, `stamp`, `day`, `isoToDisplay`), and `timezone` initialisation moved into it — three screens each called `initializeTimeZones()` in their own `initState`, so one that forgot silently fell back to UTC. ⚠️ **A bare calendar date is never zone-shifted** (`day()`): shifting `2026-09-01` by an offset is how a document dated the 1st displays as the 31st.
  - ⚠️ **One existing test had to be inverted.** `pos_session_list_test.dart` asserted `fmtSessionDate` produced `'Aug 20, 10:16 AM'` — i.e. it pinned the hardcoded behaviour *as the contract*. A test that pins the bug is worse than no test: it makes the fix look like the regression. It now pins that the setting reaches the list.
  - **The lesson for the next sweep of this shape:** grep for the *output*, not the API. `\.year` interpolation, `padLeft(2, '0')`, and `toIso8601String().split` found what `DateFormat(` could not.
- **Email/SMTP is RETIRED, 2026-09-03, on the user's call.** `Email.SmtpHost`/`SmtpPort`/`FromAddress`/`FromName` and `Application.User.Email` had a full settings tab and zero consuming code on either side — nothing has ever sent an email. Removed: the `SettingKeys` constants, their defaults, the whole `_EmailTab` and its five `SearchableSetting` rows (the tab list is positional, so every `tabIndex` above 6 was shifted down one — it is not persisted anywhere, so this is safe), and seven now-orphaned `.arb` strings. Server-side the five names went into `CompanyDefaultsSeeder.ObsoleteProperties` and `Application.User.Email` left `DefaultProperties`, so the existing startup sweep deletes the rows. **When email is wanted the names are free to come back, but the product decision comes first — what SENDS? A receipt and a password reset need different plumbing, and that question was never answered.**
- **`kitchen_display/` IS localized, 2026-09-03 — EN/FR/AR.** It had no strings file at all; now `l10n.yaml` + three `.arb` files generating `KdsLocalizations`, `flutter_localizations`/`intl` added, RTL throughout. The language is chosen **on the display** (the user's call) via a 🌐 bottom sheet on both the kitchen and the *pairing* screen — the person setting it up is the one who may not read English — and it deliberately **survives an unpair**, because it belongs to the cook, not the till. Three traps handled explicitly, each commented at its site: `onGenerateTitle` not `title:` (the POS's boot crash); `resolveKdsLocale` in `kds_locale.dart` guarding the "unknown locale renders everything in Arabic" fallback, since gen-l10n emits `supportedLocales` alphabetically; and the IP address on the pairing screen pinned LTR so bidi cannot rearrange `192.168.1.50:9100` into an address the operator then mistypes. Scroll arrows moved to `PositionedDirectional` + direction-aware icons. `kitchen_display/test/kds_models_test.dart`, 24 tests. **Awaiting the user's round — `POS_Manual_tests_NOTES.txt` [B7].**
- **Dead / inconsistent settings keys, fixed 2026-09-01:** `Order.ShortcutKeysPaymentConfirmation` now has a frontend constant (`SettingKeys.shortcutKeysPaymentConfirmation`) and does something — Enter/Numpad-Enter confirms the sale on the checkout dialog when enabled (`payment_checkout_dialog.dart`). `App.IndustryMode`: added `CompanyDefaultsSeeder.RemoveObsoletePropertiesAsync`, run at every startup alongside the other backfills — sweeps stale rows for any company seeded before the removal (this DB already had zero, but other environments may not). Seeder and client now agree on `Order.NumberOfPaymentTypeRows` (both `"1"`). `Products.Sorting` now also sorts the Products management table (`products_screen.dart`), not just the POS menu grid — shared logic moved to `product_sort.dart`. **Nothing is dead here any more:** `Application.User.Email` was the last one and went with the SMTP retirement on 2026-09-03, which put all five email keys through that same sweep.
- **Backend/security follow-ups:** server-side per-user audit; per-user salt on the local PIN.
- **Deployment environment:** `Jwt__Secret` + `AdminPortal__AccessKey` must be set in the **deployment** environment, not just this machine's `setx`. Decide whether to scrub the old placeholders from git history.
- **Untested surface:** the serial scale has never met real hardware (and is Windows-only — `kScaleSupported`; Android always takes the keypad path). Several OPT-4 `mounted`-guard changes live in dialogs that booting the app never opens.
- **`box` / `pack` are a NOMINAL factor, not a per-product pack size** — `1/12` and `1/6`, hardcoded in `lib/uom/unit_of_measure.dart`. Left alone deliberately on 2026-09-03: a real pack size is a new column on the product, i.e. a **migration**, and CLAUDE.md rule 3 needs explicit approval for one. It is a migration plus a field on the product editor whenever the user asks. Until then a "box" of anything is 12.
- **RESOLVED 2026-09-01 — was "never probed":** `ProcessRefundCommand`'s comment wondered whether `DocumentItem_Insert_Trigger` already moves stock for DocumentType 220. Checked the live DB directly — **no such trigger exists**. The only 3 triggers in the whole database are `trg_Document_CompanyConsistency`, `trg_Barcode_CompanyMatch` and `trg_FloorPlanTable_CompanyConsistency`, none touching `DocumentItem` or `Stock`. The explicit stock-reversal block in `ProcessRefundCommand` is the only thing moving stock on a refund — no double-counting. Comment updated in code.

---

## 0. Ilyass Style — the UI/UX contract

_Defined 2026-08-22. Say **"use Ilyass Style"** and this is the contract._

The house layout rules for the Flutter desktop POS. They exist because the same
four defects kept reappearing: values stranded mid-row, layouts that jump at a
hardcoded breakpoint, rows stretched unreadably wide on a 2560px monitor, and
tables whose column widths nobody can change.

### 1. No dead flex space

Never trap data in the middle of a row.

`Expanded` is a **tight** flex child — it takes its whole share of the free
space whether its text needs it or not. `Expanded(label)` + `Flexible(value)`
therefore gives the label exactly half the row and starts the value at the
midpoint, which reads as centred. That is the bug, not a styling preference.

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Flexible(flex: 3, child: Text(label)),                     // hard left
    const SizedBox(width: 12),                                 // minimum gap
    Flexible(flex: 2, child: Text(value, textAlign: TextAlign.end)), // hard right
  ],
)
```

Both sides **loose** `Flexible`, `spaceBetween`, and flex caps (3/2) so a long
name ellipsizes instead of overflowing a 10-inch tablet. A bare `Text` as the
trailing child is acceptable **only** when the value cannot grow (a formatted
amount, an icon); anything user-entered gets the capped `Flexible`.

Reference: `lib/session/session_screen.dart` → `_Row`.

### 2. Math-based fluid wrapping

Grids and filter rows compute their own column count from the width they
actually got, not from a global screen breakpoint. `context.isCompact` describes
the *window*; a widget inside a split pane or a sidebar layout gets neither.

```dart
LayoutBuilder(builder: (context, constraints) {
  const gap = 12.0;
  const minTileWidth = 230.0;                 // below this the content is unreadable
  final fits = ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor();
  final perRow = fits.clamp(1, tiles.length); // or a design ceiling, e.g. 4
  final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;

  return Wrap(
    spacing: gap,
    runSpacing: gap,
    children: [for (final t in tiles) SizedBox(width: width, child: t)],
  );
});
```

Collapses 4 → 3 → 2 → 1 continuously as the window is dragged, with no jump.

References: `_StatGrid` in `lib/session/session_screen.dart`;
`_buildFilterPanel` in `lib/document/documents_screen.dart`.

### 3. Max-width caps

Reading views — label→value rows, summary cards, forms — are capped and centred
so an ultra-wide monitor cannot put a label against one edge and its amount
against the other.

```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: kMaxReadableWidth), // 1200
    child: body,
  ),
)
```

`kMaxReadableWidth` lives in `lib/core/responsive.dart`. It is a no-op below
1200px, so tablets are untouched.

**The one exception: data tables.** A table wants every pixel — it gets
horizontal scrolling instead of a cap. Cap the *reading* view, never the grid.

Reference: the `TabBarView` in `lib/session/session_screen.dart`.

### 4. Resizable, aligned data tables

Use `IlyassTable<T>` (`lib/core/ilyass_table.dart`) rather than Material's
`DataTable`:

- **Draggable columns.** Every header edge is an 8px grab strip
  (`MouseRegion` + `GestureDetector`, RTL-aware). Widths live in
  `ilyassColumnWidthsProvider(tableId)`.
- **Surplus goes to ONE column**, marked `flexible: true` — never spread evenly.
  `DataTable` spreads it, which is exactly what opens a dead zone between two
  short columns while the name column that needed the room stays clipped.
- **Money and counts are `numeric: true`** → end-aligned. A column of totals is
  read by its last digits.
- **Actions are `resizable: false`** at a fixed minimal width, icons packed with
  `visualDensity: VisualDensity.compact`, `padding: EdgeInsets.zero` and a
  36×36 tap target. Dragging an actions column only ever creates dead space.
- **One list, not two.** A column carries its own cell builder, so the header
  and the cell cannot drift out of step — the class of bug that parallel
  `if (visible['X'])` chains invite.
- Rows build lazily (`ListView.builder` + `itemExtent`), the header stays put
  while they scroll, and hover highlights the full row.

```dart
IlyassTable<Document>(
  tableId: 'documents',
  rows: documents,
  columns: [
    IlyassColumn(key: 'Customer', label: l.colCustomer, width: 220,
        flexible: true, cell: (c, d) => Text(d.customerName ?? '-')),
    IlyassColumn(key: 'Total', label: l.totalUpper, width: 140,
        numeric: true, cell: (c, d) => Text(money(d.total))),
    IlyassColumn(key: 'Actions', label: l.colActions, width: 96,
        resizable: false, cell: (c, d) => _actions(d)),
  ],
  emptyState: const EmptyView(...),
)
```

Column **visibility** stays where it already is — a `StateProvider<Map<String,
bool>>` per screen plus the existing column picker. Column **widths persist**
per table id under `ilyass.table.widths.<tableId>` in `shared_preferences`
(device-scoped, like the printer name — a width is how one operator likes their
screen, not company data), written once on drag release.

Two rules make the drag feel solid rather than glitchy, and both are load-bearing:
* **The drag is measured from where it started**, never accumulated frame by
  frame — summing `delta.dx` drifts by whatever the clamp swallowed, so after
  hitting the minimum and coming back the edge no longer sits under the pointer.
* **The flexible column is pinned for the duration of the drag**, and the pin is
  kept as an explicit width on release. Otherwise it absorbs what the dragged
  column gives up, and since it usually sits to the LEFT of the handle, pulling
  a right edge visibly slides the left half of the table. It still fills a wider
  pane afterwards — the surplus rule adds to the pinned value.

### 5. Ilyass Screen — the shape of a navigation destination

_Added 2026-08-29, extracted from End of Day._

Say **"make it an Ilyass Screen"** and this is the contract. It is about
NAVIGATION — where a screen lives and how you get out of it — where rules 1–4
are about layout. The widget is `IlyassScreen` in `lib/core/ilyass_screen.dart`.

**A sidebar destination is a TAB, never a pushed route.** It renders inside the
shell's `LazyIndexedStack`, so it keeps its scroll position and its filters,
switching to it costs no route animation, and it never stacks *on top of* the
shell it belongs to. Add an index to `PosTab` (`lib/navigation/main_layout.dart`)
and an entry to `screens` — those indices are **append-only**, because several
screens set the nav provider by literal and a stale one can arrive from settings.

Management is the one deliberate exception: it is a shell of its own, with its
own sidebar and its own tabs, so it is pushed as a route and its back arrow is
correct.

**The top-left control is decided by how the screen is MOUNTED, not by the
screen.** That is the whole reason the file exists — Cash In/Out shipped a back
arrow while it was a shell tab, pointing at a route that was not there. Never
write `leading:` by hand; hand it to `IlyassLeading`:

| Mounting | Control |
|---|---|
| Hosted, `onMenuPressed` given | ☰ hamburger, opens the sidebar |
| Hosted, no `onMenuPressed` (desktop management: permanent rail) | nothing |
| Pushed as a route | ← back arrow, pops |

🚨 **Hosted-ness cannot be inferred from `Navigator.canPop()`.** Both shells are
themselves pushed over the login screen, so `canPop()` is `true` inside every
tab. The shells wrap their stack in an `IlyassShell` inherited widget and
`IlyassLeading` reads that. A route pushed *from* a tab is built under the
Navigator — an ancestor of the shell — so it correctly finds no `IlyassShell`
and gets its back arrow.

**There is no "leave" button.** The sidebar is the way out of every destination,
so Cancel cancels the *work*; it does not navigate. When a screen genuinely must
hand control back after a commit, it calls `ilyassLeave(context,
onReturnToShell: ...)` — which pops when pushed and switches the shell to the POS
tab when hosted. A bare `Navigator.pop()` from a tab pops the shell and signs the
cashier out mid-shift.

Everything else is the End of Day header: search bar **in the header** (a search
row in the body costs a full strip of height on a 10-inch tablet), secondary
actions behind a single ⋮, the primary action as a bottom-trailing FAB, and the
title yielding to the search bar when the screen is narrow.

```dart
IlyassScreen(
  title: l.cashInOut,
  onMenuPressed: widget.onMenuPressed,   // from the shell; null when pushed
  maxContentWidth: 480,                  // forms only — never a data table
  body: form,
  footer: actionBar,                     // full-bleed bar, cap its contents
)
```

`IlyassListScaffold` is this with the list-screen defaults already set (no width
cap — tables scroll instead), and is what the twelve management list screens use.

## Where it is applied

| Screen | What |
|---|---|
| `lib/session/session_screen.dart` | `_Row` alignment, `_StatGrid` fluid wrap, 1200px cap on both tabs |
| `lib/document/documents_screen.dart` | `IlyassTable` with resizable columns, end-aligned TOTAL, tight ACTIONS. The 8 filters became the unified search bar (`lib/core/unified_search_bar.dart`) — its chip row and result-count header still follow rules 1–2. |
| `lib/reports/sales_history_screen.dart` | Both master and detail tables are `IlyassTable` (15 and 11 columns, resizable, money end-aligned); `UnifiedSearchBar` carries the user + customer filters as chips; header and toolbar band size themselves from their own content minimums |
| `lib/product/product_groups_screen.dart` | The group TREE inside an `IlyassTable`: the hierarchy became one indented Name column with an expand toggle, searching flattens it, and the old 340px-tree-plus-editor split gave way to `IlyassListScaffold` + a dialog editor |
| `lib/reports/z_report_screen.dart` | End of Day is the Z-report history in an `IlyassTable` (11 columns, money end-aligned, 5 hidden by default) with `UnifiedSearchBar` + the app date-range picker as a period chip; Close Register left the app bar for a red FAB that exists ONLY while unreported payments do, and the old Current Shift tab became its confirmation sheet |
| `lib/core/ilyass_table.dart` | The shared table + `ilyassColumnWidthsProvider` |
| `lib/core/ilyass_screen.dart` | `IlyassScreen`, `IlyassLeading`, `IlyassShell`, `ilyassLeave` — the navigation-destination contract |
| `lib/navigation/main_layout.dart` | `PosTab` indices; Sales History, Shift Management, POS Session, Cash In/Out and Credit Payments became TABS instead of pushed routes, and `Cash.ShowOnStart` now lands on the cash tab instead of pushing it over the shell |
| `lib/cash/cash_movement_screen.dart` | The screen that named the rule: hamburger instead of a back arrow, Save/Cancel through `ilyassLeave`, form capped at 480px under a full-bleed action bar |
| `lib/core/responsive.dart` | `kMaxReadableWidth` |

Still on the old pattern, and the obvious next candidates: the products list,
the stock screen, the session list table, and the remaining reports tables.

---

## 1. Goal

Work the ⭐ numbered backlog at the top of this file. Constraints that do not change:

- **Offline-first** — read/write local Drift, sync in the background. The app must be fully usable with the API down.
- **Cross-platform** — must compile for Windows (.exe) **and** Android (.apk). Capability-gate anything hardware-bound.
- **Theme tokens only** — no hardcoded colours (`Colors.white`, `Colors.grey[100]`…). See `CLAUDE.md`.
- **Touch-first** — 10–13" tablets; 44×44px minimum tap targets.
- **CQRS backend**, no EF migrations unless explicitly told.
- **NEVER restart the backend API** — the user runs it under the VS debugger. Build, report, ask them to restart.
## 3. Gotchas — read these before touching the code

_Each of these cost a real bug. This section is deliberately KEPT in full through every cleanup — none of it is "done", it is all still live. Any "(item NN)" ref points at a change log that no longer exists; treat it as a label._

### Bulk-edit tooling (🚨 cost more than any bug this session)

- **🚨 PowerShell FLATTENS a single-element array-of-arrays — and it silently turns a string replace into a CHARACTER replace.** This corrupted **8 files** across one session in three separate incidents (`T`→`e`, `h`→`i`, `A`→`p`), each a *blanket* substitution over the whole file (`AppLocalizations`→`pppLocalizations`, `TextStyle`→`eextStyle`, `child`→`ciild`, `startTime`→`starteime`).
  ```powershell
  # BROKEN: @( @(a,b) ) collapses to @(a,b), so $p is a STRING and
  # $p[0]/$p[1] are CHARS -> .Replace('A','p') runs over the entire file.
  foreach ($p in @( @('old','new') )) { $t = $t.Replace($p[0], $p[1]) }
  ```
  **Always use an ordered hashtable for replacement maps, never arrays:**
  ```powershell
  $map = [ordered]@{ 'old' = 'new' }
  foreach ($k in $map.Keys) { $t = $t.Replace($k, $map[$k]) }
  ```
  Multi-pair calls happened to work, which is why it only ever hit a few files and looked random.
- **🚨 A blanket character corruption is NOT reversible by pattern** — real `e`/`i`/`p` characters are everywhere. Recovery is git-only. And **check what HEAD actually contains before trusting `git checkout HEAD`**: commit `b32a090` captured corrupted files mid-session, so restoring from it re-introduced the damage; `10b7839` was the clean baseline.
- **Regex `[regex]::Replace` with a MatchEvaluator scriptblock is banned for bulk edits here.** Plain `.Replace(string,string)` cannot cause the above. Every localization pass after the incidents used plain string replacement only.
- **After ANY bulk edit, run this before believing the result:**
  ```
  grep -rlE "\b(pppLocal|Textplign|ciild|Tieme|eext|eype|toStringpsFixed)\b" lib/
  ```
  `flutter analyze` catches it too (a corrupted identifier is undefined), but the grep names the file instantly.

### Localization

- **⚠️ `MaterialApp.title` CANNOT use `AppLocalizations.of(context)` — it crashes the app at boot.** `title:` is evaluated in `MyApp.build`, which is *above* the `Localizations` widget `MaterialApp` itself creates, so the lookup returns null and the generated non-nullable getter throws **"Null check operator used on a null value"** on a red screen before any UI renders. Use **`onGenerateTitle: (context) => …`**, whose callback runs below `Localizations`. (Shipped broken once; `main.dart` now carries the comment.)
- **⚠️ The bulk passes kept missing MULTI-LINE `Text(`.** Settings and printer settings are written as
  ```dart
  Text(
    'Resource Mode',      // <- string on the NEXT line
    style: …,
  )
  ```
  A regex anchored on `Text\('` matches none of these. **Match on the quoted literal itself** (`'Resource Mode'`), which is newline-agnostic. Nearly the entire settings tab content and printer dialog slipped through the first pass for exactly this reason.
- **⚠️ HALF THE APP USES DOUBLE QUOTES — a single-quote-only search silently reports a screen as done.** `products_screen`, `product_groups_screen`, `stock_screen`, `customers_screen`, `users_screen`, `my_company_screen` and the promotions screens are written `Text("Save Changes")` / `_field(ctrl, "Code")` / `labelText: "Required"`. Eight screens survived two localization passes because every search was `'…'`-anchored. **Any string sweep must match `'…'` and `"…"`**, and must not filter out single-word literals — `'Code'`, `'General'`, `'Service'`, `'Details'`, `'Update'` are all real UI text.
- **⚠️ Enum-ish values are STORED in English and only DISPLAYED translated.** Theme keys (`'light'`), accent names (`'Blue'`), and dropdown options (`'Tables'`, `'Fixed'`, `'Top'`) are persisted settings values. Translating the option lists would corrupt saved settings. The display goes through `_themeModeLabel` / `_accentColorLabel` / `_settingOptionLabel` in `settings_screen.dart`; unknown values (COM ports, EAN formats, date patterns, currency codes) pass through verbatim. Same pattern in `reports_screen` and `product_import_screen`.
- **⚠️ `product_import_screen`'s `_fields[].label` MUST stay English** — it doubles as the **CSV header alias** for column auto-matching (`_fieldAliases[f.key] ?? [f.label]`). Localizing it in place means an Arabic UI stops matching an English spreadsheet. Display goes through the separate `_fieldLabel(context, key)`.
- **⚠️ Static/const data holding user-visible text cannot be localized in place** — it needs a `BuildContext`. Six of these came up: settings tabs + search index, sales-history columns, documents columns, report labels, onboarding feature slides, import fields. Convert to a **function of context** (`_tabsFor(context)`) or an **id + lookup**. Where an id list is also read in `initState` (before `AppLocalizations` is usable), split it: a `const` id list plus a context-taking labelled version — see `sales_history_screen._masterColumnIds` / `_masterColumns(context)`.
- **⚠️ Any widget test that pumps a localized screen needs the delegates**, or it throws a `_TypeError` at *build* time, not at the assertion:
  ```dart
  MaterialApp(
    locale: const Locale('en'),   // pin it — see below
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    …)
  ```
- **⚠️ An unsupported locale resolves to ARABIC, not English.** Flutter falls back to `supportedLocales.first` and gen-l10n emits that list **alphabetically**, so `ar` is first. **`resolveAppLocale()` in `lib/l10n/app_locale.dart`** maps anything unknown to `en` before `MaterialApp` — or `lookupAppLocalizations` — ever sees it. **Do not delete that guard as redundant**; without it a stale `es`/`de` value (the dropdown offered both for months) renders the whole app in Arabic. **Never pass a raw setting value to `lookupAppLocalizations`.** Code with no BuildContext should call **`l10nOf(ref)`**, which does both steps. Pinned by `test/l10n_test.dart` — 5 unit tests on the helper plus the widget-level trap, verified to fail when the guard is removed.
- **Receipts/PDFs are language-independent of the UI on purpose.** Receipt body text, `discount_display.dart`'s labels (they print), and values written to the DB (`discount_lines.label`) stay English. The per-printer `{Role}.RightToLeft` setting already implies the receipt is configured separately.

### The expensive ones

- **NEVER restart the backend API.** The user runs it under the **Visual Studio debugger** (`devenv.exe` → `VsDebugConsole.exe`, `https` profile on :5002 + :7002). Killing it drops their debug session. Build (`dotnet build -t:Compile`), report, and **ask them to restart it** (Ctrl+Shift+F5). Stated explicitly by the user on 2026-07-16.
- **⚠️ `document_items.total` MEANS TWO DIFFERENT THINGS — always check the document's ORIGIN first.** A **checkout** document stores each line **ex-tax** (tax in `taxAmount`); a **manual editor** document stores it **tax-INCLUSIVE**. The discriminator is `documents.orderNumber` (stamped by checkout, null on manual) — **not** "has a discount", and **not** the presence of a tax. Any new reader that does `total / (1 + rate/100)` or `total - taxAmount` origin-blind will be wrong for half the documents, and *silently*: it produces a plausible number (12.50 for a 15.00 line), not an error. The same split infects `unitPrice` (ex-tax on checkout rows, tax-inclusive on manual ones) — **`priceBeforeTax` is ex-tax on both** and is the only safe field to display. **Do not hand-roll this mapping: use `DocumentItem.fromDrift(row, isCheckoutDoc: …)`.** Cloning it is exactly what left the sales-history list and the invoice PDF deriving the rate as `(price - priceBeforeTax)` — always 0 on a checkout row — so a taxed sale printed "Tax 0%".
- **⚠️ Line tax has exactly ONE source of truth: `CartNotifier.taxAmountsForItem` / `taxForItem`. Never re-derive it.** `rate/100 * lineTotal` looks obviously right and is **wrong half the time** — it silently hardcodes the "Before tax" rule while `Products.DiscountApplyRule` may be **"After tax"** (tax on the *undiscounted* price). It also ignores the proportional cart-level discount share. It was duplicated in three places; the two copies in `payment_checkout_dialog` disagreed with the cart by (discount × rate) and banked a document that contradicted its own total. `test/cart_tax_rule_test.dart` pins `lineTotal + taxForItem == grandTotal` under both rules — if it fails, someone re-derived tax again.
- **⚠️ `Discount` is a CONFIGURED VALUE, not money — summing it is meaningless.** `Document.Discount` / `documents.discount` holds the number the operator typed, and `DiscountType 0` means **percent**. So a 50% discount stores `50`, and `Sum(d => d.Discount)` adds "50" (a percentage) to "5" (another percentage) and calls the result currency — which is exactly what the backend Z-report did (**55** where the real money was **25**). It also sees only whole-order discounts, missing every item / promotion / customer-profile / loyalty one. **The only summable field is `DiscountLine.Amount` / `discount_lines.amount`** — the resolved money, which is why that table exists. Never aggregate a `discount` column.
- **⚠️ A refund's total SIGN FLIPS ACROSS THE WIRE.** Locally a refund `documents.total` (and its payment) is **negative**; the same row on SQL Server is **positive** (verified: zero negative rows in the entire `Document` table). So **classify by `documentTypeId` (4 = Refund), never by the sign** — a sign test is right on exactly one side of the wire, and summing every document into "sales" books refunds as revenue on the server. `dashboard_provider` already carries this warning; the Z-report engine did not.
- **There is NO `pullZReports`** — only `pullZReportPaymentSummaries`. The local `z_reports` row is the **only copy the app ever reads**, so nothing a Z-report states will ever be "backfilled by the server later" (a comment claimed exactly that for months while the UI showed zeros). Everything must be computed **and persisted at close time**, before `assignUnreportedPaymentsToZReport` stamps the placeholder and makes the scope unrecoverable.
- **⚠️ A stale build looks exactly like a broken fix — and the `.exe` timestamp lies.** `pos_app.exe` is the C++ runner; it does **not** change when Dart code does. To tell whether a build carries your change, check **`build/windows/x64/runner/Release/data/app.so`** (release) or **`Debug/data/flutter_assets/`** (debug). A whole session's work was reported as "nothing works" against a Release build that predated it. **Rebuild the profile the user actually runs** — `flutter build windows --debug` does NOT refresh Release.
  - **`app.so`'s SIZE and mtime are both weak signals** — a 250-key localization batch rebuilt it to the byte-identical size `19776400`. **Verify by content:**
    ```
    find lib -name '*.dart' -newer build/windows/x64/runner/Release/data/app.so   # empty = current
    ```
    then grep the snapshot for a string you just added. 🚨 **Dart AOT stores strings in TWO encodings** — Latin-1 (one byte) when every code point is < 256, UTF-16LE otherwise. So English and French are found with `.encode('latin-1')` and **Arabic only with `.encode('utf-16-le')`**. Searching UTF-8 finds English, misses Arabic, and makes a perfectly good build look broken.
- **⚠️ `setOrderContext` is a `copyWith` ON PURPOSE — it MOVES the held order onto a table. It does NOT start one.** Two of its three call sites (the service-type switch in `menu_screen`, the booking room picker) depend on the cart surviving. Starting a **new** order must build a fresh `CartState` — use **`startTableOrder`** (tables) or `startTablelessOrder`. Getting this wrong doesn't just show stale items: `saveOrderLocally` keys on `state.existingLocalOrderId ?? uuid()`, so an inherited id makes the next save **rewrite the previously parked order onto the new table**, moving it and emptying the old one.
- **⚠️ `floor_plan_tables.status` IS A DEAD COLUMN — occupancy comes from open `pos_orders`.** It is written only by `pullFloorPlanTables`, and server-side `FloorPlanTable.Status` is only ever assigned `0` at construction. It read 0 for **every** table, including one holding a synced open order. `tablesByFloorPlanProvider` now derives `status`/`assignedUserId` from a `leftOuterJoin` on open orders. **Anything asking "is this table taken?" must ask `pos_orders`, never that column.** The same applies to the tempting `FloorPlanTable.fromDrift` — it reads the dead column, so the provider overrides it.
- **⚠️ `?? 1` on a warehouse is a BUG, not a safe default.** `selectedWarehouseProvider` starts **null** and is seeded asynchronously. Substituting `1` while the seed is in flight targets a warehouse the company may not own **and outranks `Order.DefaultWarehouseId`**, because `effectiveWarehouseId` accepts any `activeWarehouseId > 0`. Pass the warehouse through **unresolved (nullable)** and let the cart resolve it. Two `?? 1` fallbacks still sit in `menu_screen`'s two *move*-an-order paths.
- **⚠️ TWO UNRELATED `isService` EXIST. Never grep-and-delete it.** `Product.isService` (cart, Drift, printer, refund, products, sync — ~90 hits) means *"this product is a service → skip stock deduction"* and is core business logic. The `industryMode`-derived UI flag of the same name is **gone**. Deleting the wrong one **silently breaks inventory** rather than failing loudly.

### Offline-first / sync

- **🚨 NEVER resolve a sync lookup with `getSingleOrNull()` — it THROWS on a duplicate, and every poll's catch is bare.** One duplicate `pos_orders` row (same `serverId`) ended open-order syncing on a device *permanently and silently*: no void disappeared, no paid order left the list, no KDS "ready" landed. Use `.get()` + `firstOrNull` and heal the duplicate. The same shape was in `pullDocuments`' match-by-number.
- **🚨 A pusher that rethrows cancels every pusher after it.** `_pushAll` was a bare `await` sequence and `pushPendingOrders` rethrows any `DioException` from position 14 of 30 — so one stuck sale silently stopped documents, refunds, payments, voids, Z-reports, customers, bookings and stock from ever pushing. **Every step in `_pushAll` must go through `_step`.**
- **⚠️ The 10s open-order poll and the sync push both write `pos_orders`.** The push creates the server order *before* it can stamp the id locally, so a poll in that window can't match it and materialises a twin `svr_<id>` row. `SyncManager.pushInFlight` gates the poll — don't remove it.
- **⚠️ A delta pull can never see a DELETE.** A deleted row reports no `DateUpdated`, so a watermarked pull is structurally blind to it and the local copy lives forever. Deletions need a periodic **full-window** pass that retires what the server didn't return (`_reconcileDeletedDocuments`) — guard on `serverId != null`, `syncStatus == 'synced'`, and the pulled window.
- **🚨 `/Company/GetById` returns 404 for a missing company, NOT 200-with-null.** `GetCompanyByIdQuery` throws `KeyNotFoundException` → `ExceptionHandlingMiddleware` → 404. Any client code that infers "deleted" from an empty body is dead on arrival, because Dio raises first and a blanket `catch` swallows it. This is a general trap for **every** `GetById` in this API — they all throw rather than return null.
- **⚠️ `unlinkDevice()` does NOT touch Drift.** It clears the JWT, device JWT, lease, company id and cached users — nothing else. Anything that must actually *remove data* from a terminal has to call `AppDatabase.purgeAllLocalData()` as well.
- **⚠️ `NOCHECK CONSTRAINT ALL` does not disable TRIGGERS** (needs `DISABLE TRIGGER`), and re-arming with a bare `CHECK CONSTRAINT ALL` leaves the constraint **untrusted** (`is_not_trusted = 1`) because SQL Server never re-validates. Use `WITH CHECK CHECK CONSTRAINT ALL`.
- **🚨 `dbo.PosOrder` has NO `Status`, `WarehouseId` or `BookingId` column — and `PosOrderDto` carries no warehouse.** Warehouse is a *sourcing decision of the till doing the work*, never persisted with the order, so a pulled order must use **this device's** `effectiveWarehouseId`. Reading `o['warehouseId'] ?? 1` gave every cross-device order a warehouse the company doesn't own, and `BulkAdd` then rejected every line as out of stock. The booking link lives on **`Booking.PosOrderId`**; recover it with `bookingIdForPosOrder`.
- **🚨 `PosOrderItem.DateCreated` is SQL type `date` — the time is TRUNCATED on write.** Any "did it change?" logic built on `MAX(DateCreated)` has **one-day resolution** and cannot see a same-day edit, which is the only case that matters. Use `PosOrderDto.LastItemId` (`MAX(Id)`) — a swap re-inserts and IDENTITY never reissues.
- **⚠️ A product can occupy SEVERAL lines of one order** (`Order.SeparateRowForEachItem`). **Never match order lines by `ProductId` alone** — `BulkAdd` did it in three places and silently corrupted such orders on every re-save (one row written twice, deleted lines surviving, taxes on the wrong row). Pair by position within the ProductId group, and aggregate per product for stock checks.
- **⚠️ `app_properties` is CLOUD-SYNCED TO EVERY TERMINAL — never put a hardware or filesystem setting in it.** A Windows POS pushed its backup path, printer queue name and COM port to the Android tablets. Anything bound to *this machine* belongs in `lib/settings/device_scoped_settings.dart`. The test is venue-vs-terminal: paper size and margins are the venue's, the print-queue name is the machine's.
- **A `pullX` that uses `insertOrReplace` MUST skip locally-pending rows.** `insertOrReplace` rewrites the whole row, so any column the companion doesn't set silently reverts to its default — including `syncStatus` → `'synced'`, which strands the pending change *and* loses the local edit. Copy the `pullCustomers` guard: `if (existing != null && existing.syncStatus != 'synced') continue;`.
- **🚨 ADDING A PROPERTY TO AN EF ENTITY TAKES EFFECT THE MOMENT THE API RESTARTS — apply the migration FIRST.** There is no grace period: EF emits the new column in every SELECT/INSERT for that table, so an unapplied migration turns into *"Invalid column name"* on every request touching it. On 2026-08-06 that killed BatchSync and stranded a **paid sale**. Order: generate migration → **apply it** → restart the API → deploy the client.
- **`sync_failed` is TERMINAL by design and there is no retry anywhere.** `_resolveRejection` reasons that a server *rejection* can't be fixed by retrying, so create/update rows park at `sync_failed`; the push queries only select `pending_*`, and nothing in the UI can requeue them. That assumption holds for business conflicts but **not for client bugs** — a bad payload strands real data permanently. Watch for this whenever a push payload changes.
- **A checkout artifact is NEVER one row — don't hand-delete a stuck sale.** Checkout writes `pos_orders` + `documents` + `document_items` + `payments` (+ `discount_lines`) under **one shared UUID**. Those children are written as `SyncStatuses.pending`, meaning *"my PosOrder will carry me to the server via BatchSync"* — the generic pushers deliberately exclude them. Deleting just the `pos_order` **orphans the rest forever** at "N items pending". Delete the whole UUID family or none. A manual DBeaver delete also won't fire `ON DELETE CASCADE` unless `PRAGMA foreign_keys=ON` is set for that session.
- **`pos_orders` has BOTH `tableId` and `floorPlanTableId`.** `tableId` is the live column; **`floorPlanTableId` is dead — nothing writes it.** `CartState.floorPlanTableId` persists *into* `tableId`. Targeting the wrong one compiles, runs, and updates zero rows.
- **Tapping a floor-plan table creates NO `pos_orders` row.** `table_widget.dart` only sets in-memory cart context (sentinel order id `0`); the order is materialised in Drift **at checkout**. So any "fix the row" strategy can't reach an open cart, and **the cart is the last writer at checkout** — it will overwrite a correctly-remapped row with its stale snapshot unless the value is re-resolved at the write site.
- **Drift schema is v60** (was v53 when this line was written; v50 dropped the `PosPrinterSelection` tables, v56 added `PosOrderItemsTable.discountInputValue/Type`, **v57–v60 are the POS Session work** — the extra `shifts` columns, `sessionLocalId` on `pos_orders`/`documents`/`payments`/`starting_cash`, then `shifts.posDeviceName`). Modifying any Drift table needs a `build_runner` regen; all migrations are additive and auto-apply on launch.

### POS Sessions

- **🚨 `shifts` / `dbo.Shift` holds TWO unrelated concepts.** Attendance shifts (statuses **0/1**) and POS sessions (statuses **10–13**) share the table. The numbering is disjoint *on purpose* — an earlier draft used 0–3 and collided with attendance's `Closed = 1`. **Never read that table without discriminating**: a POS session has a `PosDeviceId` (backend) / a `posDeviceUid` or `posDeviceName` (client). Legacy `Shift.Create`/`Close`/`SyncFrom` belong to attendance and must stay untouched.
- **🚨 Every session gate FAILS OPEN and must stay that way.** `sessionGateProvider` blocks only on a positive "no open session on this register"; unresolved device id, unloaded company, Drift error → `unknown` → **sell**. Making `unknown` block was tried and reproduces exactly the failure mode it would cause: one transient fault closes the shop for the day. `PosSession.RequireOpenSession` (Settings → Sync, default `true`) is the operator-level off switch.
- **⚠️ `PaymentType.OpenCashDrawer` CANNOT tell you what cash is.** It is true for both Espèces *and* Credit, so classifying drawer cash from it banks credit sales as notes. `PosSession.CashPaymentTypeIds` is the authoritative setting; the `IsChangeAllowed` inference is a dev/legacy fallback that logs a warning and reports `CashMethodsConfigured = false`.
- **⚠️ A session’s identity is its client `localId`, not its server id.** `OpenAsync` is idempotent on it, so a lost response on retry *finds* the session instead of creating a second one. Sessions must push **before** orders (parent-first, as products do in `_pushAllInner`) or their children arrive orphaned.
- **⚠️ Rows pulled from another register are `srvs_<id>` and must never be pushed back.** `pullSessions` refreshes a locally-owned row **only while it is `synced`**, so a pull cannot clobber a close that has not been pushed yet — the same rule `pullDocuments` follows.
- **Z-reports are bounded by `SessionId`, not a document-id range.** The old `d.Id >= from && d.Id <= to` filtered by company only, so with two devices selling at once the second report consumed a range already reported. Do not reintroduce an id-range boundary.

### Units of measure / barcodes

- **🚨 Two pairs of files must stay in step, in two languages each.** The UoM catalog is hardcoded with **stable ids shared verbatim** — `Back-End/Web-POS.Api/Domain/UnitOfMeasure.cs` ↔ `Front-End/lib/uom/unit_of_measure.dart`; the pattern engine likewise — `Services/BarcodeRuleMatcher.cs` ↔ `lib/barcode/nomenclature/barcode_matcher.dart`. A divergence means the till and the server read one scale label two different ways, and nothing fails loudly.
- **🚨 Stock arithmetic is enforced by a SOURCE SCAN, not by discipline.** `StockUnitConversionTests` greps every non-migration `.cs` for `stock.Quantity ± <operand>` and fails when the operand ends in `.Quantity` — a converted operand is always a local (`restored`, `deltaInStockUnit`) or the call itself; a raw one is always some line's own quantity. It names file and line, has a companion check that any file moving stock must mention `ToReference` at all, and a third test proving the regex flags the exact line that shipped. It is anchored on `[CallerFilePath]`, not `AppContext.BaseDirectory`, because the build-around-a-locked-bin workaround redirects `BaseOutputPath` out of the repo. **This is the check to extend, not to delete, the next time stock arithmetic appears.** On the client the same rule is enforced by the compiler: `deductStockForCheckout` takes a **required** `uomId` per item and converts inside, so a fifth caller cannot forget.
- **⚠️ `snapToRounding` must count steps, never multiply them back.** `(0.35 / 0.0001).round() * 0.0001` is `0.35000000000000003`. Harmless in arithmetic, glaring on screen: `formatQuantityValue` grows its decimals until the text round-trips, so a real 350 g line printed `0.350000 kg`.
- **⚠️ Never value a stock quantity with a raw sale-unit price** — `pricePerReferenceUnit(price, uomId)` is the only sanctioned way. Multiplying a kg figure by a per-gram price valued 400 g of a 30 MAD/g product at **12.00 instead of 12 000**.
- **⚠️ A parked order stores a bare number; the unit lives on the product.** Every reopen path must rebuild lines *with* the product's `uomId` or the line silently defaults to `pcs` — a 100 g line comes back reading `x100` and deducts in the wrong unit from then on. The money never moves, which is what makes it invisible.
- **The six `Scale.Barcode.*` settings keys are deliberately KEPT** in `CompanyDefaultsSeeder` (marked deprecated) even though the nomenclature superseded them, so `BarcodeRuleSeeder.BackfillAsync` can still translate an existing company's scale format into a rule. `lib/utils/scale_barcode_parser.dart` and its test are gone.
- **Testing a price/weight label without a scale: developer mode.** Settings → About → **Developer mode** puts a draggable bug button over the app; it opens a barcode simulator that decodes what you type (rule, check digit, product key, embedded value, resulting cart line) and BUILDS valid labels from the company's own nomenclature. `buildBarcodeForRule` / `buildProductKeyForRule` / `buildInternalEan13` live next to the matcher and round-trip through it before returning.

- **🚨 A hardware list that is written down in the source is a list of lies.** Every port picker offered `COM1`–`COM10` plus `LPT1`–`LPT3`, on a till whose Windows exposes **one** serial port and no parallel port — twelve wrong answers, and picking one fails **silently**, exactly like a display with a loose cable. It cost a field visit. The ports now come from `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM` / `PARALLEL PORTS` (`lib/utils/windows_ports.dart`), which is the same key `SerialPort.GetPortNames()` reads — deliberately, so the app agrees with whatever other POS is installed on the same machine instead of the operator having to decide which one is lying. `libserialport` is unioned in because it walks the *Ports device class* instead and the two disagree at the edges. **A missing key means zero ports, never a default.**
- **🚨 `dart:io`'s `File` CANNOT open a Windows device path — at all.** `File(r'\\.\COM8').openSync(mode: FileMode.write)` throws `PathNotFoundException, errno = 161` (`ERROR_BAD_PATHNAME`) on a port that is present and writable — the same byte through `CreateFile`/`WriteFile` on the same path in the same second succeeds. `File` validates the path as a **filesystem** path before the device namespace is ever reached, so `\\.\anything` is rejected on its face. The serial customer display was built on `File`, so it **never worked on any port, on any machine, since it was written** — and because the sale path swallows the error by design, the only symptom was a display that stayed dark, which reads as dead hardware. `lib/utils/windows_device_write.dart` is the replacement (Win32, one mechanism for COM and LPT alike). ⚠️ The bare name is not a workaround: `File('COM8')` fails the same way, and where it does not it **creates a file called COM8** in the working directory — verified by accident while diagnosing this.
- **⚠️ A display's CHARACTER SET is a hardware fact, not the app's language.** `كرواسون` rendering as `???????` was correct behaviour, not a bug: the default charset is plain ASCII, which has no Arabic. Switching the app to Arabic does not give a Latin-only panel Arabic glyphs — and nothing in the protocol lets us ask a display what codepage it has, so an autodetect would be a guess whose failure mode is *worse* than `?` (random Latin letters that read as broken hardware). `CustomerDisplay.Charset` is therefore an explicit, device-scoped setting defaulting to `ascii`, with `latin1`, `cp1256` and `cp1256-visual` for hardware that can take them. The CP1256 table in `pole_display_frame.dart` is **generated from the codec, not typed** — 256 hand-copied hex pairs is a transcription error waiting to happen, and one wrong byte is one wrong letter in front of a customer.
- **⚠️ Reverse Arabic runs only, never the digits beside them.** `cp1256-visual` exists for panels that have the glyphs but do no bidi of their own. A reversed price is not a rendering quirk — it is a different number, so `_reverseArabicRuns` flips only U+0600–U+06FF and leaves everything else in place.
- **🚨 The pole display's wire carries ONE BYTE per character, and `String.codeUnits` is UTF-16.** Anything above `0xFF` is silently truncated to its low byte, so an Arabic product name did not render as boxes — it rendered as whatever Latin letters those low bytes happen to be. Garbage that reads as a display fault. `foldToDisplayText` in `lib/utils/pole_display_frame.dart` folds accented Latin to its base letter (a French menu stays legible on a bare-ASCII codepage), passes the rest of Latin-1 through, and turns everything else into `?` — which reads as *cannot show this* rather than as broken hardware.
- **⚠️ On a 20-character display, give up whole CLAUSES, never half a number.** Truncating `0.125 kg x 50.00` to fit produced `0.125 kg x 50.` — which does not read as a shortened line, it reads as a price of fifty-something. `lineItemRow` tries candidates longest-first and drops the `x price` clause intact. The running total on the right is never shortened while anything else can give: a half-printed `25.0` is a plausible amount, and it is the number the customer is actually checking.
- **⚠️ The cart line a display should name is NOT `items.last`.** With `Order.SeparateRowForEachItem` off, re-scanning a product merges into its existing line, which can sit anywhere in the list — so the last row belongs to some other product and the display would name the wrong thing at the moment the customer is watching it most closely. `_mostRecentlyChangedItem` in `menu_screen.dart` diffs previous against next by `cartItemId` and reports the line whose quantity or price actually moved; a change that is not about a line (a discount, a table move) leaves the display alone rather than picking a row at random.
- **⚠️ An empty options list red-screens `_SettingDropdown` and `_PSDropdown`** — both the missing-setting fallback and `safeValue` end in `options.first`. Harmless while every list was a literal; a live hazard now that three pickers are fed by hardware discovery, where "this machine has none" is an ordinary answer. Both now render a disabled field instead; a saved-but-absent port is kept and **labelled** rather than dropped, because silently re-pointing a configured device at a different one is worse than showing a port that is gone.
- **Port numbers move under you.** This machine reported `COM2` and `COM1` twenty minutes apart, with no hardware touched. Anything that caches a port name across a session, or writes one into a shared setting, will eventually address the wrong device — which is why `CustomerDisplay.Port` and the drawer's serial port are **device-scoped**, and why the pickers have a refresh.
- **Testing a pole display with no pole display:** com0com is installed on the dev box; `setupc install PortName=COM8 PortName=COM9` (elevated) pairs two ports, the POS writes to one and `Front-End/tool/pole_display_listener.ps1 -Port COM9` renders the other as a two-line VFD. It carries a `-SelfTest` that decodes a synthetic frame, so a failure can be pinned on the script rather than the wiring. `dart run tool/probe_ports.dart` prints what any machine's device map actually holds.

### Printing / PDF

- **🚨 Android cannot print silently through `package:printing`, at all.** `Printing.listPrinters()` has no Android implementation and `directPrintPdf` reports `directPrint: false`, so every print falls through to `layoutPdf()` and the **system print dialog** — a modal in the middle of closing a sale. The only silent route a tablet has is a raw TCP socket to the printer (port 9100, "RAW"/JetDirect), which is what `printer/network_printer.dart` and `printer/escpos_job.dart` are.
- **⚠️ Print the RASTER, not ESC/POS text commands.** The obvious implementation — emit align/bold/feed a line at a time — throws away the entire PDF layout: the logo, the barcode, the per-role margins, the RTL mirroring and, decisively, **Arabic shaping**. A thermal printer's built-in font has no Arabic on almost any unit, so a text-command receipt would print boxes in exactly the place `printed_text.dart` spent a fortnight fixing. Rasterising the finished PDF prints what the PDF shows.
- **🚨 In `GS v 0`, `1` means BLACK and `xL xH` counts BYTES per row, not pixels.** Both are the opposite of the obvious guess, and both fail invisibly at the encoder: a swapped width makes the printer expect eight times the data and eat the rest of the receipt, and a bit-stream packer that ignores the row padding shifts every row one pixel further right — the classic diagonal smear that reads as broken hardware. `test/escpos_raster_test.dart` decodes the command stream back into pixels precisely because a hand-checked byte or two cannot cover this.
- **⚠️ Split a tall raster into bands.** `yL yH` allows 65535 rows, but the real limit is the printer's input buffer — a few KB on cheap units. One band for a whole receipt overruns it and prints garbage from the middle onward. 128 rows per band.
- **⚠️ Threshold the luminance at ~200, not 128.** Anti-aliased glyph edges render around 55–60% grey; dropping them thins strokes until small Arabic diacritics vanish. And weight the channels (Rec. 601) — a flat `(r+g+b)/3` turns a two-colour logo into one solid blob.
- **🚨 `Socket.add` then `destroy()` truncates a long job.** `add` buffers; destroying the socket discards whatever has not gone out, so a long receipt prints its first few centimetres and stops — which reads as the paper running out. `await socket.flush()` before closing. Pinned by a 200 KB job over a real loopback server.
- **⚠️ A print failure must never be swallowed on the checkout path.** `payment_checkout_dialog` had `.catchError((_) {})` on the receipt print, which is the same shape as the field-test bug where the drawer opened and no paper came out. A network printer that is off fails there *every* time, so silence would make it permanent and unreportable. It now reports through `showAppSnackbar` — a snackbar, not a dialog, because the sale is already banked.
- **⚠️ The Test Print button was disabled whenever no SYSTEM printer was found** — which on Android is always, so the one control that proves a network address was unreachable on the only device that needed it.
- **"Save as PDF" ≠ "print to a PDF printer" — and the dialog tells you which.** `FilePicker.saveFile` (app-controlled name, *"Save as type: Files (\*.pdf)"*) vs Windows Print-to-PDF (**driver**-controlled name, seeded from the print job's `lpszDocName`, *"PDF Document (\*.pdf)"*). Only the first is fully ours. `Printing.layoutPdf(name:)` and `directPrintPdf(name:)` both reach the same native `StartDoc`, so the printer branch makes **no** difference to naming — don't go looking there.
- **`FilePicker.saveFile` behaves oppositely on desktop vs mobile.** Android/iOS **require** `bytes` (`ArgumentError` otherwise) and write the file for you; desktop **ignores** `bytes` and hands back a path to a file that does not exist yet, which you must write. Always pass `bytes` **and** write on desktop — `lib/printer/pdf_save_service.dart` is the only place this should be spelled out. It also throws `IllegalCharacterInFileNameException` on Windows for a bad name, so sanitize.
- **⚠️ PDF fonts are BUNDLED — never reintroduce `PdfGoogleFonts`.** It downloads the face over the network on first use, so on an offline-first POS the first print after a fresh install can fail to render at all. Everything goes through `lib/printer/pdf_fonts.dart` (`PdfFonts.latin()` / `.arabic()`, parse-cached) reading `assets/fonts/`. All 76 call sites were converted on 2026-07-23.
- **⚠️ Arabic on a receipt fails INVISIBLY — correct layout, empty boxes.** No Latin face carries Arabic glyphs (PDF standard-14 are Latin-1; Noto Sans is the Latin subset), and `{Role}.RightToLeft` already flips the *layout*, so the ticket comes out shaped perfectly with every Arabic word blank. Noto Naskh is attached as **`fontFallback`, not the base font**, so the chosen face still drives Latin and mixed-script needs no detection. Report/stock PDFs need it on `pw.ThemeData.withFont(fontFallback: …)` — a per-style `font:` sets only the base face, which is why the stock report was missed at first.
- **Dual currency must convert `owedAmount`, not `grandTotal`** — points redemption is deducted from what the customer actually pays, so converting `grandTotal` would print a figure larger than the amount collected.
- **The receipt RE-DERIVES tax from the rate using the CURRENT `discountApplyRule`.** So reprinting a sale rung under the other rule would contradict its own document. The sales-history reprint therefore carries the **stored** per-line tax as a *fixed* `MenuTax` (a fixed tax is only ever multiplied by quantity), which reproduces the banked figure under either setting. Don't "simplify" that back to a percentage rate.

### Backend / EF

- **A non-nullable reference type in a request DTO is implicitly `[Required]`.** The project has `<Nullable>enable</Nullable>` and no `SuppressImplicitRequiredAttributeForNonNullableReferenceTypes`, so `[ApiController]` model validation **rejects `null` with a 400 before the handler runs**. An optional field must be `string?`.
- **The C# `required` keyword is enforced by System.Text.Json as "must be present in JSON."** Omitting a `required` member fails deserialization outright — the controller sees a null request and returns 400 with *"missing required properties including: …"*. Any new push payload must send every `required` member.
- **A filtered unique index makes `''` and `NULL` behave oppositely.** `UQ_Customer_Code_PerCompany` is `WHERE [Code] IS NOT NULL`: unlimited NULLs, but **one `''` per company**. "No value" must be written as NULL, never `''`. Check `sys.indexes.filter_definition` before assuming a unique index applies to every row.
- **EF `HasTrigger("…")` only means "a trigger exists here"** — EF never resolves the name; it uses the declaration solely to omit the `OUTPUT` clause on write. The label is free-text and **cannot be trusted**. Always enumerate `sys.triggers`. The 3 real ones are named correctly; **4 phantom declarations remain on purpose** (`DocumentItem`, `Booking`, `Payment`, `StartingCash`). Removing them would re-enable `OUTPUT` but makes inserts fail with **SQL error 334** the day someone adds a real trigger there.
- **A trigger rename is NOT a schema change.** EF Core's migrations differ emits **no operations** for trigger metadata. Stale names in `AppDbContextModelSnapshot.cs` are inert. **Never hand-edit the snapshot or historical `*.Designer.cs` files.**
- **`dotnet ef` runs the WRONG version in `Back-End/Web-POS.Api/`** — `.config/dotnet-tools.json` pins a **local** `dotnet-ef` **9.0.8** while the project is **EF Core 10.0.9**. Use the global tool (`~/.dotnet/tools/dotnet-ef.exe`) or update the manifest. There are **two DbContexts**, so every command needs `--context Api.DataBase.AppDbContext` (or `Api.Master.MasterDbContext`).
- **⚠️ A `Win32Exception (258) … pre-login handshake` from SQL Server is CONNECTIVITY, not schema.** `initialization=16012; handshake=0` means it spent ~16s opening the socket and never reached authentication — so every DB-touching request 500s while it lasts, and the cause is nowhere near the query you were editing. The connection strings use **`Data Source=localhost` + `Connect Timeout=30`** so the API→SQL hop runs over **shared memory** instead of crossing the Ethernet NIC on a box full of virtual adapters. **Do not "helpfully" restore the LAN IP** — SQL Server is local; only the *Flutter* client needs `100.114.12.38:5002`, and that is the API's address, not SQL's. Also note `MSSQLSERVER` startup type is **Manual**: after a reboot the service is simply not running, which looks identical to a code failure.
  - 🚨 **THE FIX LIVES IN `appsettings.Local.json`, WHICH IS GIT-IGNORED — and that is why it regressed.** The committed `appsettings.json` ships both connection strings **blank**; the real ones only exist in the untracked local file (or in `ConnectionStrings__*` env vars on a server). Editing the committed file therefore changes **nothing** and cannot be verified by a clean checkout. Found back on `Data Source=192.168.11.103` on **2026-08-06** and re-fixed there. **Check the Local file, not the committed one**, and re-check it after any machine restore.
  - **Verify, don't assume — the transport is observable:** `SELECT net_transport FROM sys.dm_exec_connections WHERE session_id = @@SPID`. It must read **`Shared memory`**, not `TCP`. Re-verified 2026-08-06 with the app's own `pos_app_user` credentials: `web-pos` 194 ms, `web-pos-master` 121 ms, both shared memory. A TCP row whose `client_net_address` equals `local_net_address` is the smell — the box is talking to itself through the NIC.
  - Note `pos_app_user` maps to **dbo** in `web-pos` (so it has ALTER rights, which the company-delete sweep needs). The read-only-login suggestion in §5 applies to the **MCP** connection, not the API's.
- **The API exe ignores `launchSettings.json`.** Launched directly it silently binds `:5000`, not `:5002`. Start it with `ASPNETCORE_URLS="http://100.114.12.38:5002"` (100.114.12.38 so Android tablets can reach it). The app never calls `Database.Migrate()` — only `CanConnect()` — so **migrations are always applied manually**.
- **The API REQUIRES `Jwt__Secret` in the environment outside Development.** `appsettings.json` ships it blank and the startup guard aborts on empty/short/placeholder. Real values are user-level env vars via `setx` (mirrored in the git-ignored `SECRETS.local.txt`). A shell opened *before* the `setx` won't see them — export inline when launching from an old session. If the API dies with *"Jwt:Secret is missing…"*, that's this.
- **Rotating `Jwt:Secret` invalidates all live tokens** — every logged-in device 401s and must re-login. `api_client.dart` → `SessionExpiry` handles it: a 401 on a *token-bearing* request (not `/Auth/Login`) clears the token and routes to login once. A 401 with **no** token, or a connection error (offline), does **not** trigger it. The discriminator is "did we send an `Authorization` header," not the path.
- **`OBJECT_DEFINITION(OBJECT_ID('name'))` = NULL is inconclusive** — enumerate with `sys.triggers` + `sys.sql_modules`.

- **🚨 `ref.watch(appSettingsProvider)` without `.select` invalidates the watcher on EVERY settings change in the app.** The notifier hands out a fresh `Map` on each rebuild and `Map` has no value equality, so a theme toggle invalidates anything watching the whole map — a language, a printer name, a COM port, all of it. Measured: `registerUidProvider` re-ran **twice per unrelated write** (`AsyncLoading`, then the same string it already had).
- **🚨 That churn is how you get `setState() called during build` in a widget that has nothing to do with it.** `appSettingsProvider` is a `Notifier` that is marked dirty and flushed **lazily, inside a widget build** — so the first widget to watch a derived provider flushes settings mid-build, the derived provider invalidates itself, and Riverpod calls `setState` on the scope. The exception names whichever widget was building (`BrowserSection`, in the one that was reported), so the stack points nowhere near the cause. `sessionGateProvider` and `registerUidProvider` are `.select`ed for exactly this reason; `test/session_gate_test.dart` carries the story.
- **⚠️ A wasted provider rebuild is INVISIBLE to every value-based observer.** When the provider recomputes to the same value, `container.listen` stays silent and so does `ProviderObserver.didUpdateProvider` — both were tried against the unfixed gate and both passed. Test the observable consequence instead (an async dependency re-running, an answer flickering), and **always assert the counter sees a change it SHOULD see** — otherwise a probe wired to nothing passes forever.
- **⚠️ Overriding a provider in a test kills the very dependency under test.** The first draft of `session_gate_test.dart` overrode `registerUidProvider`, so its dependency on the settings map — the thing being fixed — was not present, and every assertion passed against the broken code. If a test exists to pin a provider's *inputs*, that provider must be the real one.

### Flutter / UI

- **🚨 NEVER put an overflow menu in the AppBar `title` slot.** Both a `MenuAnchor` and a `LayoutBuilder`-based `OverflowActionsBar` crashed the POS with **`_dependents.isEmpty` (red screen)** whenever the header rebuilt — reproducibly by renaming the POS from Settings while it sits above a still-mounted `MenuScreen`. The stable replacement, and what ships today, is a plain horizontal `SingleChildScrollView` of buttons in that slot (`menu_screen.dart`). A real "show hidden buttons" drawer would need a different, device-tested approach. _(Carried over from the deleted RESPONSIVE_PLAN.md, which was closed out on 2026-08-11.)_
- **Responsiveness has a shared foundation: `lib/core/responsive.dart`.** `context.isCompact` (<1000 dp — 7"-class tablet), `isVeryCompact` (<760), `isShort` (<680 dp tall), `dialogWidth(preferred)` and `dialogMaxHeight()`. Use these instead of new `width: 500` literals. ⚠️ **Layout overflow is invisible to `dart analyze` AND to the test suite** — it only appears when rendered, and French runs ~15–20% longer than English, so the usual cause is un-flexed `Text` in a `Row` (wrap in `Expanded` + `maxLines: 1` + ellipsis). The only reliable loop is a screenshot from the real device in French. Fixed so far: PIN pad, POS header, cart footer, discount dialog, stock table + detail rows, reports header, promotions table, tax-rate dialog, sales-history toolbar, credit-payments form.
- **`use_build_context_synchronously` — the guard must match the context.** A **local/parameter** `BuildContext` needs **`context.mounted`**; a State `mounted` check is "unrelated" to it. Conversely **`State.context`** (bare `context` in a State method with no `context` param) needs the State's **`mounted`**. Mixed blocks need each use guarded by its own matching check.
- **`_SettingDropdown` throws on an empty `options` list** (it falls back to `options.first`). Any dropdown fed from hardware discovery must union the saved value in — see `_ScalePortDropdown`, where an unplugged `COM2` must still display as `COM2`.
- **A DropdownButton fallback must be a MEMBER of its item list** — `'UTC'` is not an IANA location key. The pattern `items.contains(v) ? v : <constant>` is a trap unless that constant is provably in `items`. And **`DropdownButtonFormField` seeds from `initialValue` only once** — if the item list loads asynchronously, add `key: ValueKey(resolvedValue)` or the field keeps serving the first seed.
- **Scale unit regex:** `\b(kg|g|lb|oz)\b` can **never** match `1.234kg` — no word boundary between `4` and `k`, and that's the most common frame format. Anchor at end-of-line. (Pinned by `test/scale_weight_parser_test.dart`.)
- **⚠️ RTL is ALREADY WIRED app-wide — do not build it again, and do not assume a mirroring bug is unimplemented.** `main.dart:260` wraps the whole app in a `Directionality` driven by `App.WritingDirection`. So `Row`, `MainAxisAlignment`, `ListTile` etc. mirror for free the moment that setting flips to `RTL`. What does **not** mirror, and is what an "RTL bug" will actually be: `EdgeInsets.only(left:/right:)` (19), `Alignment.centerLeft/Right` (131) and `TextAlign.left/right` (36) — the codebase uses **zero** `EdgeInsetsDirectional` / `AlignmentDirectional`. Fix the specific widget with the directional variant; never add a second `Directionality`.
- **⚠️ `activeThumbColor` styles only the THUMB, not the track.** A switch given `activeThumbColor: context.successColor` renders a green thumb on a theme-coloured track and reads as broken rather than deliberate. App-wide convention is `colorScheme.primary` or nothing at all. (Two were removed on 2026-07-22.)
- **Dark mode was never actually broken** — an app-wide scan found 0 unconditional grey panels, 0 unconditional black body text, 1 white fill (the QR code, which *must* stay white to scan). The colour pass was *consistency*, not a legibility fix — which is why much was deliberately left: **status→colour maps** (booking/payment/promotion/stock), **fixed data palettes** (colour pickers), **`isDark`-conditional banners** (`users_screen`'s blue header needs its dark shade for white text to stay legible), **deliberate accents** and muted `Colors.grey` secondary text. Don't "finish the job" by converting these.
- **Kaspersky (historical)** — on 2026-07-04 it blocked `claude.exe` from spawning children. As of 2026-07-09 builds/tests/app launches work. If launches start failing again, that's the cause; add a trusted-app exclusion.

---

## 4. Design Note — LAN Sync Hub (roadmap, NOT built)

**Goal.** Keep a multi-device venue working when the **cloud** connection drops (the *local* Wi-Fi/LAN almost always stays up — it's the internet that's flaky). Today each device syncs only to the cloud, so when the internet dies the devices can't see each other's orders/refunds until it returns.

**Chosen architecture: (B) each device keeps its own local Drift DB + a LAN "sync hub."** Every device stays fully offline-first on its own DB (nothing regresses); a hub on the LAN reconciles the devices with each other and is the single uplink to the cloud. We explicitly rejected sharing the raw SQLite **file** over a Windows share (SMB) — SQLite's own docs warn it corrupts the file (unreliable network file locking). Sharing happens at the **service** layer, not the file layer.

**Why the Drift refund outbox was a prerequisite.** A device's *entire* unsynced state now lives in its Drift DB (orders, documents, payments, **and refunds** — the refund `shared_preferences` outbox is gone). So the hub can drain a device uniformly from one place; nothing is hidden outside the DB. Do not reintroduce out-of-DB outboxes — they would silently bypass both backup and LAN sync.

### Roles
- **Hub (host):** a **Windows POS** only. It runs a lightweight LAN service (extend the proven **KDS** pattern — `dart:io HttpServer`, token pairing, ports 9090/9091 — see `kitchen_display/` + `Front-End/lib/kitchen/kitchen_push_service.dart`) exposing sync endpoints (push pending ops / pull master+documents), then forwards everything to the cloud when the internet returns. Windows-only because it must be always-on and can host a service + hold local backups (Android can't).
- **Client (spoke):** any Windows POS or Android tablet that points its sync at the hub instead of the cloud.

### The Database setting
Add to **Settings → Database** on every POS a **sync-target toggle**:
- **"Work against: [ Cloud ]  [ Local network POS ]"**
- If **Local network POS** → fields for **Host IP, Port, Username, Password** (auth at the service layer, same trust model as KDS pairing: the LAN is the trust boundary, token/credential gates the endpoint).
- On a **Windows POS** additionally: **"Share this POS's database on the local network"** → starts the hub service (configurable **Port + Username/Password**).

### Device-type rules (enforced by the setting)
| Device | Can be Hub? | Can be Client? | If **no Windows hub** is present |
|---|---|---|---|
| **Windows POS** | ✅ yes | ✅ yes | Works Cloud or offline-local. With **two Windows POS**, pick one as hub and the other as its client (or both Cloud). |
| **Android tablet** | ❌ no (can't host a service / no local backup) | ✅ yes (to a Windows hub) | **Forced to work separately** — each tablet syncs Cloud-only (online) or runs offline-local until the cloud returns. Two tablets alone can **never** form a LAN share (no possible host). |

So the toggle must be **capability-gated**: "Share database on LAN" is hidden/disabled on Android; and "Local network POS" is only selectable when a reachable Windows hub is configured.

### Sync protocol (reuse, don't reinvent)
The hub is a "local cloud": it speaks the **same** push/pull contract the cloud does, so a client just swaps its base URL from cloud→hub. Conflict resolution reuses the existing policy — **hub/server wins for master data; local-wins for transactions; UUIDs + device-local document numbers dedupe.** Server-side idempotency on `ClientDocumentNumber` + the Drift refund outbox mean orders and refunds **replay safely** whether the target is the cloud or the hub.

### Security / licensing
- Per-device DB stays **SQLCipher-encrypted** (Pillar 3). The hub exposes a **sync API**, never the raw `.sqlite`.
- Seat/clone enforcement (Pillars 4–5) happens at the **cloud**. The hub must forward each client's `deviceId`/hardware signature to the cloud on uplink so seat counting still works — otherwise a hub could mask over-cap devices.

### Rough phases
1. Hub service on Windows POS (extend KDS `HttpServer`): auth + `push`/`pull` endpoints backed by the hub's own Drift DB.
2. Client sync-target toggle + Host/Port/User/Password settings; capability-gating per device type.
3. Point client sync at the hub; hub aggregates into its Drift DB.
4. Hub→cloud uplink (single uplink, forwards per-device identity for seat enforcement).
5. Conflict/merge hardening + "hub unreachable → fall back to Cloud/offline-local."

### Open risks
- **Hub availability:** if the Windows hub is off/asleep, clients must fall back gracefully — never hard-block a till.
- **Clock/ordering** across devices (partly handled via StockDate + server clock pin for the lease).
- **Seat enforcement** must not be weakened by the hub indirection.

---

## 5. Dev Tooling — MCP Servers (`.mcp.json`)

A project-scoped **`.mcp.json`** (repo root) wires MCP servers into Claude Code (shared via git; **secrets are `${ENV_VAR}` references, never inline** — safe to commit). Reload Claude Code after editing it; project servers are **approved on first use** (`/mcp` shows status).

| Server | What it does | Status |
|---|---|---|
| `pos-sqlite` | Queries the local **Drift** DB (`pos_app.sqlite`) — the offline-first source of truth. `@executeautomation/database-server` via `npx`. | **Live** (works because dev encryption is off, `kPillar3Encryption=false`). |
| `pos-mssql` | Queries the backend **SQL Server** (`web-pos` @ 192.168.11.103) via **`@bytebase/dbhub`** with a `--dsn`. | Set `WEBPOS_DB_USER` / `WEBPOS_DB_PASSWORD` (ideally a **read-only** login) → reload. **Connects** (verified). |
| `context7` | Up-to-date docs for Flutter / Riverpod / Drift / Dio / EF Core (`@upstash/context7-mcp`). Prevents the deprecated-API class of bug. | **Live.** |
| `dart` | First-party **Flutter/Dart tooling** (`dart mcp-server`, SDK 3.12+): analyze, run tests, hot reload, pub, package grep. | **Live.** |
| `github` | GitHub PRs / issues / CI (official **remote** server, HTTP transport). Repo: `github.com/ilyasschah/POS-APP`. | Set `GITHUB_PAT` (classic/fine-grained, `repo` scope) → reload. |

**Notes / gotchas:**
- **`pos-mssql` uses `@bytebase/dbhub`, not `@executeautomation`.** The executeautomation server forces TLS-encrypt on and the Node `tedious` driver **refuses TLS + a bare IP** (*"Setting the TLS ServerName to an IP address is not permitted"* → the server exits → `/mcp` shows "Connection closed, -32000"). DBHub takes a full DSN, so we set `?encrypt=false&trustServerCertificate=true` (the LAN is the trust boundary). DBHub **dropped its `--readonly` flag in v0.23** — simplest safe path is a **`db_datareader` SQL login** (DB-enforced).
- **`pos-mssql` is T-SQL, `pos-sqlite` is SQLite** — `ISNULL` vs `IFNULL`, and `read_query` rejects anything not starting with `SELECT` (no CTEs).
- **Windows launch form:** `npx`/`dart` servers use `"command": "cmd", "args": ["/c", "npx"/"dart", …]` — the plain `npx` form is flaky on Windows.
- Both DB servers can **write**. Prefer reads; for `pos-mssql` use a **read-only** SQL login. Avoid writes through `pos-sqlite` while the Flutter app has the DB open (SQLite file locking).
- The `pos-sqlite` DB path is **machine-specific** (`C:\Users\ILYASS\OneDrive - Devaxy\Documents\…`); a teammate cloning the repo must edit that path.
- Set env vars with `setx` then open a **new** shell / reload Claude Code:
  `setx WEBPOS_DB_USER pos_readonly` · `setx WEBPOS_DB_PASSWORD "…"` · `setx GITHUB_PAT "ghp_…"`.
- MCP config is **per-client**: this file is for Claude Code. GitHub Copilot's agent mode uses a separate `.vscode/mcp.json`.
