# Handoff

_Last updated: 2026-07-23._

> **Current phase: final polish.** **French + Arabic localization is DONE** (§2.6) — ~1,100 keys across `en`/`fr`/`ar`, plus bundled PDF fonts so Arabic actually prints. What remains is the punch-list in §2.5 and whatever the user reports next.

> 🚨 **READ FIRST — commit `b32a090` CONTAINS CORRUPTED FILES.** `menu_screen.dart` and `time_clock_screen.dart` in that commit have a blanket `A`→`p` character corruption (`pppLocalizations`, `toStringpsFixed`). `git checkout HEAD -- <those files>` restores BROKEN code. The working tree was repaired from `10b7839` and re-localized; **commit the fix and never reset those two files to `b32a090`.** Cause and prevention: §3 "Bulk-edit tooling".

> **⚠️ This file was RESET on 2026-07-16**, at the user's request, back into a *working plan* instead of an archive. Removed: the §4 "Changes Made (DONE)" log (37 items), the per-session "Active Files" lists, the runtime-verification blocks and the old next-steps. **§3 Gotchas was deliberately KEPT** — every one of those was paid for with a real bug and several are still live traps. Their "(item NN)" references point at the deleted log; read them as historical labels, not links. The deleted content was **never committed** (`handoff.md` was modified-but-unstaged), so `git show HEAD:handoff.md` predates all of it — it is gone unless recovered from a session transcript.

---

## 1. Goal

Work the task list in §2. Constraints that do not change:

- **Offline-first** — read/write local Drift, sync in the background. The app must be fully usable with the API down.
- **Cross-platform** — must compile for Windows (.exe) **and** Android (.apk). Capability-gate anything hardware-bound.
- **Theme tokens only** — no hardcoded colours (`Colors.white`, `Colors.grey[100]`…). See `CLAUDE.md`.
- **Touch-first** — 10–13" tablets; 44×44px minimum tap targets.
- **CQRS backend**, no EF migrations unless explicitly told.
- **NEVER restart the backend API** — the user runs it under the VS debugger. Build, report, ask them to restart.

## 2. The Plan — open work

Ordered roughly by dependency/value, not by the order asked. **Status keys are verified against the code — §2.0 / §2.6 as of 2026-07-22, the rest as of 2026-07-16** — so trust the "wired/inert" labels below over intuition. Where a label has since been proven wrong it is struck through and corrected in place rather than deleted (see the virtual-keyboard entry in §2.4): a confidently-wrong "inert" costs a session of rebuilding something that already exists.

### 2.0 — DONE 2026-07-23 (latest session)

- ✅ **French + Arabic localization SHIPPED.** `flutter_localizations` + `gen-l10n` (`l10n.yaml`, `generate: true`), **~1,100 keys** in each of `lib/l10n/app_{en,fr,ar}.arb`. `Application.Language` now actually drives `MaterialApp.locale` — it was a dropdown into the void for months. Scope: every screen the operator touches (POS menu, cart, checkout, discount dialog, products, settings + printer settings, reports, documents, stock, users, customers, taxes, promotions, bookings, onboarding, login/PIN, customer display).
  - **Language and writing direction stay INDEPENDENT** (user's explicit call). Picking `ar` does **not** force RTL; `App.WritingDirection` remains the only thing that flips the layout. An earlier build auto-linked them and was reverted.
  - **Dropdown/enum values are stored in English and only *displayed* translated**, via three mappers in `settings_screen.dart`: `_themeModeLabel` (theme keys), `_accentColorLabel` (accent names), `_settingOptionLabel` (screen / search mode / discount type / message position). **Never translate the option lists themselves** — those strings are the persisted values.
  - Same id→label pattern for `reports_screen` (`_reportLabel` / `_sectionName`, incl. search filtering on the *translated* label) and `product_import_screen` (`_fieldLabel`).
  - Remaining English is **deliberate**: reports const-table fallbacks, product-import **CSV header aliases** (translating them breaks column auto-matching), receipt/PDF body text, keycaps, technical dropdown values (COM ports, EAN formats, date patterns), and config defaults like the `WELCOME!` placeholder.
- ✅ **PDF fonts bundled — Arabic receipts now print glyphs, and printing is fully offline.** New `lib/printer/pdf_fonts.dart` (`PdfFonts.latin()` / `.arabic()`, parse-cached). `assets/fonts/` carries Noto Sans + Noto Naskh Arabic (~1.15 MB). **All 76 `PdfGoogleFonts` calls are gone** across receipts, invoices, 36 report exports and the stock report — that helper *downloads on first use*, which on an offline-first POS meant the first print after a fresh install could fail outright.
  - Arabic is attached as **`fontFallback`, never the base font**, so the operator's chosen face still drives Latin and a mixed-script receipt needs no language detection. Report/stock PDFs get it via `pw.ThemeData.withFont(fontFallback: …)`.
  - `test/receipt_arabic_font_test.dart` pins it and **reproduces the bug**: rendering Arabic without the fallback yields a measurably smaller PDF (nothing embedded), and the `pdf` package logs *"Unable to find a font to draw ا"*.
- ✅ **Boot order reworked: master login now comes BEFORE onboarding.** Was: onboarding gated everything. Now `MyApp.home` → registration → licence → onboarding (first run only) → PIN. `MasterLoginScreen` routes to onboarding itself on a fresh install; `OnboardingScreen` takes an injected `onFinished` callback (null when it *is* `home`, since flipping `onboardingCompleteProvider` rebuilds past it — calling Navigator there would fight the rebuild).
  - **Required a real fix, not just a reorder:** master login only saved the company *id*; `selectedCompanyProvider` stayed null until the PIN screen, and `appSettingsProvider.set()` **silently returns when there is no selected company**. Onboarding's writes would have been dropped. `loadFallbackCompany(companyId)` is now called right after the session is saved.
- ✅ **Theme/accent changes apply instantly again.** `appSettingsProvider._set()` wrote `boot_theme_color` / `boot_theme_mode` straight to SharedPreferences, bypassing `deviceAccentColorProvider` / `deviceThemeModeProvider` — which `MyApp` reads **first**. Disk updated, notifier stale, so the app kept the old theme until relaunch. Now writes go through the notifiers (same keys, so the 0 ms boot-flash cache still works).
- ✅ **Three bugs reported 2026-07-23:**
  - **Refund dialog now pre-loads the selected cart line.** `_seedFromSelectedCartItem()` in `refund_dialog.initState` seeds `_blindLines` from `cartProvider.selectedCartItemId`. It deliberately does **not** set `_blindMode` — blind return still requires the manager PIN in `_authoriseBlind`. Seeding is convenience, not an auth bypass.
  - **Dual currency now prints.** `Receipt`/`Kitchen` PDFs never read `DualCurrency.*` at all — only the cart UI did. `receipt_printer_service` now reads the same three keys and prints `≈ <amount> <sym>` under the totals, converting **`owedAmount`** (points already deducted), not `grandTotal`, so the printed conversion matches what is actually collected.
  - **Subscription expiry now refreshes.** `subscriptionInfoProvider` was explicitly *"offline-safe — decodes the cached lease, never the network"*, and the lease was only pulled at boot — so changing the expiry in the admin portal left the badge stale until an app restart. It now does a best-effort `refreshFromServer` first (wrapped; offline falls through to the cached lease). Settings tabs live in a **`LazyIndexedStack`**, so a built tab is never disposed and `autoDispose` won't re-run while you sit on it — hence the added **refresh button** on the pill row.

### 2.0.1 — DONE 2026-07-22

- ✅ **SQL Server pre-login timeouts fixed at the config level.** The API was intermittently throwing `Win32Exception (258): The wait operation timed out` with `initialization=16012; handshake=0` — a *connectivity* failure before authentication, not a schema or EF problem, which 500s every DB-touching request while it lasts. Cause: `appsettings.json` dialled the **LAN IP** (`Data Source=192.168.11.103`) even though SQL Server runs on the same box, forcing every call through the Ethernet NIC on a machine with several virtual adapters (Radmin VPN, Tailscale, two VMware). Both `DefaultConnection` and `MasterConnection` now use `Data Source=localhost` + `Connect Timeout=30` (the missing timeout defaulted to 15s — exactly the 16012 ms failure). Verified live with the app's own `pos_app_user`: both DBs connect over **`net_transport = Shared memory`** in 231 ms / 122 ms, so the NIC is bypassed entirely. **The Flutter app is unaffected** — it still reaches the API at `192.168.11.103:5002`; only the API→SQL hop changed.
  - 🚧 **Still outstanding, needs an elevated shell (user's job):** `MSSQLSERVER` startup type is **Manual**, so SQL does not come back after a reboot. `sc.exe config MSSQLSERVER start= auto`.
  - ⚠️ **This is a prime suspect for "my save silently didn't stick".** A PATCH hitting a DB timeout returned a 500 that the Flutter client used to swallow, so a save looked successful and the old value reappeared on the next pull.
- ✅ **Industry Packs REMOVED** (user: *"no need for service pack we no longer need it"*) — `industry_packs.dart` deleted, `appServiceTypePack` / `appServiceStatusPack` constants + `kSettingDefaults` entries, the `serviceTypePack` / `serviceStatusPack` getters, and both `CompanyDefaultsSeeder` lines. **Kept on purpose:** `Feature_ServiceType_Enabled` / `Feature_ServiceStatus_Enabled` — those are live and gate the custom service type/status lists that superseded the packs. `PROJECT_DOCUMENTATION.md` §"Industry adaptation" updated (it still described packs as current). Analyzer clean project-wide; C# `-t:CoreCompile` exit 0. **Existing DB rows were left in place** and are now inert — `DELETE FROM ApplicationProperties WHERE Name IN ('App_ServiceType_Pack','App_ServiceStatus_Pack','App.IndustryMode')` when you want them gone.
- ✅ **Products screen polish** — product placeholder icon unified with the POS menu grid (`Icons.inventory_2` → `PhosphorIconsRegular.forkKnife`, both in the list's image column and the edit dialog's preview); colour marker + image moved out of the General tab into a new **Appearance** tab; the category sidebar is now **resizable and persisted**.
  - The Appearance tab is gated on **`!widget.isPostCreation`** — the *same* condition as the General tab, **not** grouped with Taxes/Barcodes/Comments. Grouping it with Comments would have left a newly-created product with **no way to set a colour or image at all**, since that block is hidden during creation. It still lands right after Comments when editing.
  - Sidebar width reuses the cart's exact mechanism: new `groupSidebarWidthProvider` on the existing `_LocalDoublePref` base in `local_ui_prefs.dart` (`ui.groupSidebarWidth`, default 280, min 180, max 50% of window). Live in-memory during the drag, **one** disk write on `onHorizontalDragEnd`. Drag direction is inverted vs the cart (`+ delta.dx`) because this panel is anchored left. On-device only — never cloud-synced, so resizing on one terminal cannot change another's layout.
- ✅ **Two switches un-hardcoded** — `activeThumbColor: context.successColor` removed from the product dialog's "Is Enabled" toggle and `users_screen`'s enable/disable switch. `activeThumbColor` overrides only the **thumb**, so both rendered a green thumb on a theme-coloured track — visibly wrong against the amber accent. App-wide convention is `colorScheme.primary` or nothing.
- ✅ **Settings audit — 10 keys checked against every consumer.** Findings are recorded in **§2.6.1** because most of them are now localization-adjacent cleanup.

### 2.1 — DONE 2026-07-16
- ✅ **Settings search moved from the sidebar into the HEADER** (`SettingsHeaderBar`, a `PreferredSizeWidget` that owns the title + search + loading spinner). It was pinned at the top of the settings *sidebar*; it now sits in the AppBar's title Row, just right of "Settings" — `Flexible` + `maxWidth: 480` so it caps on a wide monitor but shrinks rather than overflows on a 10" tablet. Measured: header **1920×56** (a normal toolbar), field **480×45** at x=216, vertically centred with 5.5px either side, clearing the 44px touch minimum (its padding is 12, not the sidebar's old 10, for exactly that). Side benefit: it **survives collapsing the sidebar**, where it used to vanish. Deliberately **not** a band of its own below the AppBar — the header already had empty space, and a second band costs ~64px of vertical room that a 10–13" tablet does not have. `_SettingsSearchField` itself is unchanged; it pushes to `settingsSearchQueryProvider`, so *where* it is mounted was the whole change.
  - 🚨 **This shipped broken TWICE — read before touching it.** First as a *footer* (the user said "footer", then corrected to "header"), and that footer **ate the entire screen**: `Align` with a null `heightFactor` **EXPANDS to fill** whatever dimension it is given, and a Scaffold hands `bottomNavigationBar` a *loose but bounded* height constraint — so it grew to the full 800px, squeezed the sidebar and tab content to **zero**, and rendered a blank screen with the field floating in the vertical middle (`Alignment.centerLeft` centres vertically). `dart analyze` passed, both builds succeeded, all 39 tests passed. **Layout correctness is invisible to every other check in this repo.** A pixel bug needs a pixel check — assert sizes in a widget test, or look at the screen.
  - **`test/settings_header_bar_test.dart` (3 tests) is the pixel check.** It pins: the header stays a toolbar (`< 120`, not the full screen) and the body still renders; the field caps at 480 and stays left-aligned; and it fits `kToolbarHeight` with **no RenderFlex overflow at 1920×1080 or 1280×800**. The footer-era version of this test was **proven to catch the real bug** (revert the fix → `Expected: less than <120> / Actual: <800.0>`); it was rewritten for the header's own failure modes, which are vertical fit + narrow-screen overflow rather than unbounded growth.
- ✅ **Three table/cart bugs from one report** — see the block below (`startTableOrder`, occupancy from open orders, warehouse `?? 1` race).
- ✅ **Default discount type now applies.** `Order.DefaultDiscountType` was read correctly in `discount_dialog.initState`, then **unconditionally overwritten** by the `addPostFrameCallback` (`_cartDiscountType = cartState.manualCartDiscountType`, which is `0`/Percentage on a fresh cart). Now the saved type is restored **only when a discount is actually applied** (`> 0`); otherwise the configured default wins. `dart analyze` clean. **Not driven in the UI** — set it to `Fixed`, open the POS discount dialog on an empty cart, confirm it opens on "Fixed Amount".

### 2.2 — Needs a decision from the user (blocked)
- ⚠️ **"Two search settings" — the premise is wrong, so nothing was removed.** There is exactly **one** search bar in the POS (`menu_screen.dart:1505`, `_searchCtrl`) and **no unwired search setting**. All three are live and do *different* jobs:
  | Key | Settings label / tab | What it really does |
  |---|---|---|
  | `ButtonBar.ShowSearch` | "Search" · **General → POS Buttons** | shows/hides **the search bar itself** |
  | `Menu.ShowSearchOptions` | "Show search options" · **Order & Payment → Items** | shows/hides the **Name/Code/Barcode chips** *inside* that bar |
  | `Menu.DefaultSearch` | "Default search" · Order & Payment → Items | which mode the search starts in |

  They only *look* duplicated because both are phrased as toggles and sit in different tabs. Deleting the second removes a working feature (the ability to hide the mode chips), not dead config. **Ask the user which they actually want**: rename/move them so the distinction is obvious, or genuinely drop `Menu.ShowSearchOptions`.

### 2.3 — Removals (user chose: setting **and** button/feature) — ✅ DONE, code AND both DBs

**POS layout** (`App.PosLayout`), **New sale** (`ButtonBar.ShowNewSale`) and **Order name** (`ButtonBar.ShowOrderName` + `Order.EnableCustomOrderName` / `Order.NameRequired` / `Order.RequestNameAutomatically`) are **gone from the code** — key, `kSettingDefaults` entry, Settings control, searchable-settings entry, button/dialog/handler, and `CartState.orderName` with all its consumers. Verified by grep across **the whole repo** (Front-End, Back-End, kitchen_display): no surviving mentions outside this file and the cleanup script. `dart analyze lib` = *No issues found!*, `flutter test` = **+39**, Windows build OK.

- ✅ **The 6 backend seeder lines WERE present and are removed** (`CompanyDefaultsSeeder.DefaultProperties`: `App.PosLayout`, `ButtonBar.ShowNewSale`, `ButtonBar.ShowOrderName`, `Order.EnableCustomOrderName`, `Order.NameRequired`, `Order.RequestNameAutomatically`). `dotnet build -t:Compile` = 0 errors. **Without this, every newly-created company would have been re-seeded with the dead keys.** (An earlier note here claimed there were none — that was wrong.)
- ✅ **The orphaned rows are DELETED on both DBs** — 12 on SQL Server (6 keys × companies 25 + 27) and 6 locally (company 25); both verified at 0 afterwards. SQL Server was done first on purpose: `pullAppProperties` is a watermark **upsert**, not a full replace, so deleting locally alone would leave the server rows to be pulled back — and deleting on the server alone would strand the local copies forever, since the pull never removes rows. `Back-End/Web-POS.Api/DataBase/SQL/cleanup_removed_settings_2026-07-16.sql` remains as the audit trail / recovery inventory; **it is now a no-op**.
- 🚨 **`documents.order_number` was NOT touched, and must never be.** It is **load-bearing** — the *checkout-vs-manual document discriminator*, read at `app_database.dart`, `document_editor_screen.dart`, `sales_history_screen.dart`. If checkout stops stamping it, every reader silently flips convention and the "15.00 line billed as 12.50" tax bug returns **everywhere at once**. See the `document_items.total` gotcha in §3.
- 🚨 **`pos_orders.orderName` was NOT touched either — despite the name, it is the order NUMBER.** It stores `'ORD- A5'` / `'TALABIA #008'`; `loadOrderFromLocal` reads it back into `CartState.orderNumber`, `syncOrderNumber` parses `#NNN` out of it to drive the **daily counter**, and both the KDS push and the sync push send it as `'number'`. **Three unrelated things were named `orderName`**: this column, the removed `CartState.orderName`, and a local param in `pdf_file_name.dart`. Only the middle one was the feature. A grep-and-delete here would have broken order numbering, the KDS and the sync push at once.

### 2.4 — Features

- ✅ **Product comment button — BUILT.** `ButtonBar.ShowComment` was **inert**: the setting existed but there was no Comment button anywhere. Added to the POS header bar (`menu_screen.dart`), **greyed out until a cart line is selected** (`onTap: null` → `_MenuHeaderActionBtn` tints to 30% alpha — the same gating Quantity/Tax use). Tapping it reads that product's suggestions **straight from Drift** (a direct query on purpose — `productCommentsProvider` is an autoDispose `.family` stream whose `.future` can resolve before the watch emits, making a product WITH comments look like it has none) and opens the existing `_ProductCommentsDialog`, now reusable for editing: new `initialComment` re-hydrates the switches by splitting the stored `parts.join(', ')` and matching each part back, with anything unmatched landing in the free-text field; `confirmLabel` shows "Save" instead of "Add to Cart". New `CartNotifier.setItemComment(cartItemId, comment)` (no promo re-apply — a comment carries no price). Fully offline.

**⚠️ All three remaining features need a NEW DEPENDENCY — the app has none of them today** (`pubspec.yaml` has only `printing: ^5.12.0` for PDF and `flutter_libserialport`).

- **Cash drawer** — **0 consumers.** `Print.CashDrawer.Enabled` / `Print.CashDrawer.Command` (default `\x1B\x70\x00\x19\xFA`, the standard ESC/POS kick) exist, plus per-role `{Role}.CashDrawer.Enabled/Command` and an inert `ButtonBar.ShowCashDrawer`. **`PaymentType.openCashDrawer` also already exists** — on the client model, in Drift, and editable per payment type in `payment_types_screen.dart` — and is likewise read by nothing. So the config is fully built and only the *kick* is missing.
  - 🚧 **Blocked on a hardware decision.** `printing` is **PDF-only and cannot send raw bytes**. The drawer is usually daisy-chained off the receipt printer's RJ11 port, so the kick normally rides to the *printer*. Options: (a) win32 `OpenPrinter`/`WritePrinter` via `win32`+`ffi` for a raw passthrough job — Windows-only, no new pub dep beyond win32; (b) an `esc_pos_*` package — mostly network/USB, weaker for a Windows shared printer; (c) `flutter_libserialport` (already present) if the printer/drawer is on a COM port. **Ask how the drawer is connected before writing code.**
- **Sound** — `App.EnableSounds` (default `false`) is read in exactly ONE place, `payment_checkout_dialog.dart:739`, and only plays `SystemSound.play(SystemSoundType.click)` on checkout. Real sounds need an audio package (`audioplayers`/`just_audio`), the user's sound files as assets, and **a decision on which events fire** (scan ok / scan fail / checkout / error?). Ask for the event list first.
- ✅ ~~**Virtual keyboard**~~ — **this entry was WRONG and is corrected as of 2026-07-22: it is BUILT, not inert.** `lib/core/pos_virtual_keyboard.dart` exists, reads `App.EnableVirtualKeyboard` (`:300`), mounts app-wide as `VirtualKeyboardHost` from `main.dart:262`, and is seeded by onboarding (`onboarding_seed.dart:85`). No new package was needed. **Do not re-implement it.** Remaining question is Arabic: an `ar` layout would have to be added to it — see §2.6.

### 2.5 — Carried over (still true, from the deleted log)
- **The backend Z-report engine has never executed.** `ZReportService.GenerateZReportAsync` was rewritten (returns/tax/taxable were hardcoded, refunds were summed into sales, discounts summed percentages as money) and **compiles clean, but has not run** — it needs the user's API restart. Nothing in the app reads its output back, so a wrong result is **silent**: verify via the `ZReport` row in SQL Server, not the app.
- **Client and server scope different document sets for the Z-report.** The client reports on documents behind *unreported payments*; the server takes an *id range*, which also sweeps in unpaid/credit docs. Invisible today (no `pullZReports`), but it surfaces the moment one exists.
- **Pre-fix rows are not repaired.** Sales rung under `DiscountApplyRule = "After tax"` **with a discount** before the tax fix carry a line tax short by (discount × rate) — e.g. `POS1-200-000005` stores tax 6.00 against a 37.00 total. Z-report #2 inherits that (Tax 26.00 where truth is 27.00). The Z-report is a **snapshot**, so repairing the document would not retro-change the issued report. Left as-is by decision (dev data).
- **`pullDocuments` carries no item taxes** (`buildItems` sets neither `taxRate` nor `taxAmount`), so a document pulled from **another terminal** shows no tax and contributes 0 tax to this device's Z-report.
- **Re-enable Pillar-3 encryption before production** — `kPillar3Encryption = false` in `app_database.dart` is a deliberate dev toggle. Set `true`, relaunch (auto re-encrypts, data preserved), then `flutter test integration_test/cipher_test.dart -d windows` must pass.
- **Settings still inert:** email/SMTP; dateFormat/timezone. (Localization is **done** — see §2.0/§2.6.)
- **Numbers and dates are still not locale-aware.** `dashboard_screen.dart` hardcodes `NumberFormat.compact(locale: 'en')`, and money/date formatting is `intl` with fixed patterns. **Undecided by the user:** whether Arabic should use Eastern Arabic numerals (٠١٢٣) or Western — for a POS, Eastern numerals on prices are often *unwanted* even with an Arabic UI. Ask before changing.
- **`kitchen_display/` is NOT localized** — separate Flutter app, own strings. The user deferred it ("for kitchen display we will do it also later"). Kitchen staff are plausibly the most Arabic-first users in the building.
- **`General.TaxIncludedByDefault` is still a real bug** (see §2.6.1): the Settings toggle exists but `products_screen.dart` hardcodes `bool _isTaxInclusive = true`, so new products ignore it. Still unfixed — the user was asked and hasn't chosen.
- **Backend/security follow-ups:** tighten `/api/Master/*` to `[Authorize(Policy="ManagerOnly")]`; move the DB password out of the committed connection string; server-side per-user audit; per-user salt on the local PIN.
- **Production prerequisites:** set `Jwt__Secret` + `AdminPortal__AccessKey` in the **deployment** environment (not just this machine's `setx`); decide whether to scrub the old placeholders from git history.
- **Untested surface:** the serial scale has never met real hardware; several OPT-4 `mounted`-guard changes live in dialogs that booting the app never opens.

### 2.6 — ✅ DONE 2026-07-23: French + Arabic

**Shipped.** The table below is the *original* 2026-07-22 survey, kept because it explains the shape of the work and several rows are still true (RTL was already built; receipts are still configured separately). What changed: `flutter_localizations` + `gen-l10n` now exist, `Application.Language` drives the locale, and ~1,100 keys are translated — see §2.0 for what landed and what is deliberately still English.

**If you are adding a new screen or string, read §3 "Localization" first** — the two traps (multi-line `Text(`, and enum values that are stored English but displayed translated) are what caused every missed batch during this work.

| Piece | State | Where |
|---|---|---|
| **RTL mirroring** | ✅ **ALREADY BUILT** — a `Directionality` wraps the entire app | `main.dart:260`, driven by `App.WritingDirection` (`LTR`/`RTL`) |
| Receipt/PDF RTL | ✅ **Already built**, per printer role | `{Role}.RightToLeft` → `receipt_printer_service.dart:270`, flips `pw.TextDirection` + row order |
| Language dropdown | ⚠️ **Ships to users offering `en/fr/ar/es/de/it` — and is read by NOTHING** | control at `settings_screen.dart:1893`; `Application.Language` has **zero** consumers |
| `flutter_localizations` | ❌ absent | `pubspec.yaml` has only `intl: ^0.20.2` |
| `.arb` files / `gen-l10n` | ❌ none exist | no `l10n.yaml`, no `generate: true` |
| UI strings | ❌ **~690 literal `Text('…')` + ~470 `labelText`/`hintText`/`tooltip`**, all English | across 197 files / ~140k lines |
| Directional layout primitives | ⚠️ **0 uses** of `EdgeInsetsDirectional` or `AlignmentDirectional`; **19** `EdgeInsets.only(left/right)`, **131** `Alignment.centerLeft/Right`, **36** `TextAlign.left/right` | app-wide |

**So the shape of the work is:** wire the language setting to a real localization layer, extract ~1160 strings, translate ×2, then fix the ~186 non-mirroring layout spots that `Directionality` cannot flip on its own.

#### Suggested order
1. **Add `flutter_localizations` + `gen-l10n`** (`l10n.yaml`, `generate: true`, `lib/l10n/app_en.arb`). Wire `locale:`, `supportedLocales:`, `localizationsDelegates:` on the `MaterialApp` that already exists at `main.dart:250`. Ship `en` only and confirm nothing regresses **before** translating anything.
2. **Make `Application.Language` actually drive `locale`.** Right now it's a dropdown into the void — this is the single change that turns the existing Settings UI honest.
3. **Extract strings screen-by-screen, highest-traffic first** (POS menu → cart/checkout → products → settings). Do **not** attempt a big-bang sweep of 1160 strings; each screen is independently shippable.
4. **French.** Latin script, no direction change — this is the low-risk one and validates the whole pipeline. Watch for layout breakage: French runs ~15–20% longer than English and this UI is dense with fixed-width columns.
5. **Arabic.** Only after FR proves the pipeline. This is where the layout work lands (step 6) and where the PDF font trap bites (below).
6. **Directional layout pass** — `EdgeInsets.only(left:)` → `EdgeInsetsDirectional.only(start:)`, `Alignment.centerLeft` → `AlignmentDirectional.centerStart`, `TextAlign.left` → `TextAlign.start`. `Row`/`MainAxisAlignment` already mirror themselves under `Directionality`; these three do **not**.

#### Traps specific to this work
- 🚨 **PDF receipts will render Arabic as blank boxes.** `receipt_printer_service._font()` returns `PdfGoogleFonts.notoSansRegular()` (Latin-only) or the PDF standard-14 `pw.Font.courier()` / `times()` — **none carry Arabic glyphs**. Direction is handled; *glyphs* are not. Needs an Arabic-capable face (Noto Naskh/Sans Arabic) selected when the text is Arabic. The RTL flag being already implemented makes this failure especially easy to miss — the layout will look right and the text will be empty.
- 🚨 **`PdfGoogleFonts` and `google_fonts` fetch over the network on first use.** For an **offline-first** app that is a real regression risk the moment a font is required to render a receipt at all (Latin degrades to a bundled fallback; Arabic would not). Verify and, if confirmed, **bundle the Arabic font as an asset** — `pubspec.yaml` currently declares no `fonts:` section at all.
- ⚠️ **Language and direction are two independent settings today.** `Application.Language` and `App.WritingDirection` are unrelated keys with separate dropdowns. Picking `ar` must set RTL **automatically** — leaving a user to discover a second control in another tab is a bug, not a feature. Decide whether `App.WritingDirection` becomes derived (and the manual control disappears) or stays as an override.
- ⚠️ **Numbers and dates are not locale-aware.** `dashboard_screen.dart:921` hardcodes `NumberFormat.compact(locale: 'en')`. Decide explicitly whether Arabic uses **Eastern Arabic numerals** (٠١٢٣) or Western — for a POS, prices in Eastern numerals are often *unwanted* by the operator even when the UI is Arabic. Ask before assuming.
- ⚠️ **The unified date picker** (`lib/core/app_date_picker.dart` — always use it, never raw Material pickers) needs `GlobalMaterialLocalizations` to render non-English. That delegate comes from `flutter_localizations`, i.e. step 1.
- ⚠️ **`kitchen_display/` is a separate Flutter app** with its own strings. Decide whether KDS is in scope; kitchen staff are the likeliest Arabic-only users in the building.
- ⚠️ **Receipts are customer-facing and independent of the UI language** — a venue may want an Arabic receipt with an English UI, or both on one ticket. The per-role `{Role}.RightToLeft` setting already implies the receipt is configured separately. Don't collapse the two.

#### 2.6.1 — Settings audit (2026-07-22), incl. dead localization keys

Ten keys checked against every consumer in Flutter **and** the API. **4 of 10 are wired end-to-end:** `Feature.ServiceType.Default` (`cart_provider.dart:882`), `Order.NumberOfPaymentTypeRows` (`payment_checkout_dialog.dart:1270`), `Feature.FloorPlan.ShowAllOccupied` (`table_widget.dart:205`), `Products.Sorting` (`menu_screen.dart:1540`). The rest:

- ⚠️ **`General.TaxIncludedByDefault` is a REAL BUG, not dead config.** It has a Settings control, but the product dialog hardcodes `bool _isTaxInclusive = true` (`products_screen.dart:1075`). New products are **always** tax-inclusive regardless of the toggle — and the backend seeds the key as `false` while the client default is `true`. **Not yet fixed; the user was asked and hasn't chosen.**
- ⚠️ **`Products.Sorting` only sorts the POS menu grid**, not the products management table. May or may not be intended.
- **`Application.User.Email`** — editable in Settings → Email, read by nothing in the app or the API.
- **`Order.ShortcutKeysPaymentConfirmation`** — seeded by `CompanyDefaultsSeeder.cs:236`, **no matching constant exists in the frontend at all**.
- **`App.IndustryMode`** — removed 2026-07-16; stale rows survive in the DB. (The `Shortcut` hits in `payment_types_screen.dart` are a payment-type *column*, unrelated — don't grep-and-delete.)
- **Seeder vs client defaults disagree** where a row is missing: `General.TaxIncludedByDefault` (`false` vs `true`), `Order.NumberOfPaymentTypeRows` (`1` vs `0`).

**Why this sits under localization:** the Language dropdown is the same failure mode as the four dead keys above — a control that ships to users and changes nothing. Step 2 of §2.6 fixes the most visible instance; the others deserve the same pass while you're in there.

---

## 3. Gotchas — read these before touching the code

_Each of these cost a real bug. The "(item NN)" refs point at the removed change log; treat them as labels._

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
- **⚠️ An unsupported locale resolves to ARABIC, not English.** Flutter falls back to `supportedLocales.first` and gen-l10n emits that list **alphabetically**, so `ar` is first. `MyApp._resolveLocale()` maps anything unknown to `en` before `MaterialApp` sees it — **do not delete that guard as redundant**; without it a stale `es`/`de` value renders the whole app in Arabic. Pinned by `test/l10n_test.dart`.
- **Receipts/PDFs are language-independent of the UI on purpose.** Receipt body text, `discount_display.dart`'s labels (they print), and values written to the DB (`discount_lines.label`) stay English. The per-printer `{Role}.RightToLeft` setting already implies the receipt is configured separately.

### The expensive ones

- **NEVER restart the backend API.** The user runs it under the **Visual Studio debugger** (`devenv.exe` → `VsDebugConsole.exe`, `https` profile on :5002 + :7002). Killing it drops their debug session. Build (`dotnet build -t:Compile`), report, and **ask them to restart it** (Ctrl+Shift+F5). Stated explicitly by the user on 2026-07-16.
- **⚠️ `document_items.total` MEANS TWO DIFFERENT THINGS — always check the document's ORIGIN first.** A **checkout** document stores each line **ex-tax** (tax in `taxAmount`); a **manual editor** document stores it **tax-INCLUSIVE**. The discriminator is `documents.orderNumber` (stamped by checkout, null on manual) — **not** "has a discount", and **not** the presence of a tax. Any new reader that does `total / (1 + rate/100)` or `total - taxAmount` origin-blind will be wrong for half the documents, and *silently*: it produces a plausible number (12.50 for a 15.00 line), not an error. The same split infects `unitPrice` (ex-tax on checkout rows, tax-inclusive on manual ones) — **`priceBeforeTax` is ex-tax on both** and is the only safe field to display. **Do not hand-roll this mapping: use `DocumentItem.fromDrift(row, isCheckoutDoc: …)`.** Cloning it is exactly what left the sales-history list and the invoice PDF deriving the rate as `(price - priceBeforeTax)` — always 0 on a checkout row — so a taxed sale printed "Tax 0%".
- **⚠️ Line tax has exactly ONE source of truth: `CartNotifier.taxAmountsForItem` / `taxForItem`. Never re-derive it.** `rate/100 * lineTotal` looks obviously right and is **wrong half the time** — it silently hardcodes the "Before tax" rule while `Products.DiscountApplyRule` may be **"After tax"** (tax on the *undiscounted* price). It also ignores the proportional cart-level discount share. It was duplicated in three places; the two copies in `payment_checkout_dialog` disagreed with the cart by (discount × rate) and banked a document that contradicted its own total. `test/cart_tax_rule_test.dart` pins `lineTotal + taxForItem == grandTotal` under both rules — if it fails, someone re-derived tax again.
- **⚠️ `Discount` is a CONFIGURED VALUE, not money — summing it is meaningless.** `Document.Discount` / `documents.discount` holds the number the operator typed, and `DiscountType 0` means **percent**. So a 50% discount stores `50`, and `Sum(d => d.Discount)` adds "50" (a percentage) to "5" (another percentage) and calls the result currency — which is exactly what the backend Z-report did (**55** where the real money was **25**). It also sees only whole-order discounts, missing every item / promotion / customer-profile / loyalty one. **The only summable field is `DiscountLine.Amount` / `discount_lines.amount`** — the resolved money, which is why that table exists. Never aggregate a `discount` column.
- **⚠️ A refund's total SIGN FLIPS ACROSS THE WIRE.** Locally a refund `documents.total` (and its payment) is **negative**; the same row on SQL Server is **positive** (verified: zero negative rows in the entire `Document` table). So **classify by `documentTypeId` (4 = Refund), never by the sign** — a sign test is right on exactly one side of the wire, and summing every document into "sales" books refunds as revenue on the server. `dashboard_provider` already carries this warning; the Z-report engine did not.
- **There is NO `pullZReports`** — only `pullZReportPaymentSummaries`. The local `z_reports` row is the **only copy the app ever reads**, so nothing a Z-report states will ever be "backfilled by the server later" (a comment claimed exactly that for months while the UI showed zeros). Everything must be computed **and persisted at close time**, before `assignUnreportedPaymentsToZReport` stamps the placeholder and makes the scope unrecoverable.
- **⚠️ A stale build looks exactly like a broken fix — and the `.exe` timestamp lies.** `pos_app.exe` is the C++ runner; it does **not** change when Dart code does. To tell whether a build carries your change, check **`build/windows/x64/runner/Release/data/app.so`** (release) or **`Debug/data/flutter_assets/`** (debug). A whole session's work was reported as "nothing works" against a Release build that predated it. **Rebuild the profile the user actually runs** — `flutter build windows --debug` does NOT refresh Release.
- **⚠️ `setOrderContext` is a `copyWith` ON PURPOSE — it MOVES the held order onto a table. It does NOT start one.** Two of its three call sites (the service-type switch in `menu_screen`, the booking room picker) depend on the cart surviving. Starting a **new** order must build a fresh `CartState` — use **`startTableOrder`** (tables) or `startTablelessOrder`. Getting this wrong doesn't just show stale items: `saveOrderLocally` keys on `state.existingLocalOrderId ?? uuid()`, so an inherited id makes the next save **rewrite the previously parked order onto the new table**, moving it and emptying the old one.
- **⚠️ `floor_plan_tables.status` IS A DEAD COLUMN — occupancy comes from open `pos_orders`.** It is written only by `pullFloorPlanTables`, and server-side `FloorPlanTable.Status` is only ever assigned `0` at construction. It read 0 for **every** table, including one holding a synced open order. `tablesByFloorPlanProvider` now derives `status`/`assignedUserId` from a `leftOuterJoin` on open orders. **Anything asking "is this table taken?" must ask `pos_orders`, never that column.** The same applies to the tempting `FloorPlanTable.fromDrift` — it reads the dead column, so the provider overrides it.
- **⚠️ `?? 1` on a warehouse is a BUG, not a safe default.** `selectedWarehouseProvider` starts **null** and is seeded asynchronously. Substituting `1` while the seed is in flight targets a warehouse the company may not own **and outranks `Order.DefaultWarehouseId`**, because `effectiveWarehouseId` accepts any `activeWarehouseId > 0`. Pass the warehouse through **unresolved (nullable)** and let the cart resolve it. Two `?? 1` fallbacks still sit in `menu_screen`'s two *move*-an-order paths.
- **⚠️ TWO UNRELATED `isService` EXIST. Never grep-and-delete it.** `Product.isService` (cart, Drift, printer, refund, products, sync — ~90 hits) means *"this product is a service → skip stock deduction"* and is core business logic. The `industryMode`-derived UI flag of the same name is **gone**. Deleting the wrong one **silently breaks inventory** rather than failing loudly.

### Offline-first / sync

- **A `pullX` that uses `insertOrReplace` MUST skip locally-pending rows.** `insertOrReplace` rewrites the whole row, so any column the companion doesn't set silently reverts to its default — including `syncStatus` → `'synced'`, which strands the pending change *and* loses the local edit. Copy the `pullCustomers` guard: `if (existing != null && existing.syncStatus != 'synced') continue;`.
- **`sync_failed` is TERMINAL by design and there is no retry anywhere.** `_resolveRejection` reasons that a server *rejection* can't be fixed by retrying, so create/update rows park at `sync_failed`; the push queries only select `pending_*`, and nothing in the UI can requeue them. That assumption holds for business conflicts but **not for client bugs** — a bad payload strands real data permanently. Watch for this whenever a push payload changes.
- **A checkout artifact is NEVER one row — don't hand-delete a stuck sale.** Checkout writes `pos_orders` + `documents` + `document_items` + `payments` (+ `discount_lines`) under **one shared UUID**. Those children are written as `SyncStatuses.pending`, meaning *"my PosOrder will carry me to the server via BatchSync"* — the generic pushers deliberately exclude them. Deleting just the `pos_order` **orphans the rest forever** at "N items pending". Delete the whole UUID family or none. A manual DBeaver delete also won't fire `ON DELETE CASCADE` unless `PRAGMA foreign_keys=ON` is set for that session.
- **`pos_orders` has BOTH `tableId` and `floorPlanTableId`.** `tableId` is the live column; **`floorPlanTableId` is dead — nothing writes it.** `CartState.floorPlanTableId` persists *into* `tableId`. Targeting the wrong one compiles, runs, and updates zero rows.
- **Tapping a floor-plan table creates NO `pos_orders` row.** `table_widget.dart` only sets in-memory cart context (sentinel order id `0`); the order is materialised in Drift **at checkout**. So any "fix the row" strategy can't reach an open cart, and **the cart is the last writer at checkout** — it will overwrite a correctly-remapped row with its stale snapshot unless the value is re-resolved at the write site.
- **Drift schema is v53.** v51 = `sync_status`/`sync_error` on `floor_plan_tables`; v52 = `floor_plan_table_id_map`; v53 = `document_count`/`from_document_number`/`to_document_number` on `z_reports` + a one-off `number` backfill. Modifying any Drift table needs a `build_runner` regen; all migrations are additive and auto-apply on launch.

### Printing / PDF

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
- **⚠️ A `Win32Exception (258) … pre-login handshake` from SQL Server is CONNECTIVITY, not schema.** `initialization=16012; handshake=0` means it spent ~16s opening the socket and never reached authentication — so every DB-touching request 500s while it lasts, and the cause is nowhere near the query you were editing. The connection strings now use **`Data Source=localhost` + `Connect Timeout=30`** (fixed 2026-07-22) so the API→SQL hop runs over **shared memory** instead of crossing the Ethernet NIC on a box full of virtual adapters. **Do not "helpfully" restore the LAN IP** — SQL Server is local; only the *Flutter* client needs `192.168.11.103:5002`, and that is the API's address, not SQL's. Also note `MSSQLSERVER` startup type is **Manual**: after a reboot the service is simply not running, which looks identical to a code failure.
- **The API exe ignores `launchSettings.json`.** Launched directly it silently binds `:5000`, not `:5002`. Start it with `ASPNETCORE_URLS="http://0.0.0.0:5002"` (0.0.0.0 so Android tablets can reach it). The app never calls `Database.Migrate()` — only `CanConnect()` — so **migrations are always applied manually**.
- **The API REQUIRES `Jwt__Secret` in the environment outside Development.** `appsettings.json` ships it blank and the startup guard aborts on empty/short/placeholder. Real values are user-level env vars via `setx` (mirrored in the git-ignored `SECRETS.local.txt`). A shell opened *before* the `setx` won't see them — export inline when launching from an old session. If the API dies with *"Jwt:Secret is missing…"*, that's this.
- **Rotating `Jwt:Secret` invalidates all live tokens** — every logged-in device 401s and must re-login. `api_client.dart` → `SessionExpiry` handles it: a 401 on a *token-bearing* request (not `/Auth/Login`) clears the token and routes to login once. A 401 with **no** token, or a connection error (offline), does **not** trigger it. The discriminator is "did we send an `Authorization` header," not the path.
- **`OBJECT_DEFINITION(OBJECT_ID('name'))` = NULL is inconclusive** — enumerate with `sys.triggers` + `sys.sql_modules`.

### Flutter / UI

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
