# Handoff

_Last updated: 2026-07-04. This session: a repo-wide **audit** + remediation, a **doc cleanup/consolidation**, two **settings-wiring** items (invoice.\*, dbBackupOnClose), re-enabling **`flutter_lints`**, and starting a **colour-token** pass. Everything below is `dart analyze` / `dotnet build` clean; **nothing was run end-to-end** (Kaspersky blocks this agent from launching the app — see §5), so runtime verification is the user's._

---

## 1. Goal

Two tracks:
- **Audit remediation** — act on the repo-wide audit (in `PROJECT_DOCUMENTATION.md` §6): money/data-critical first, then perf/architecture optimizations.
- **Settings wiring** — make editable-but-inert app settings actually do something.

Constraints: offline-first (Drift-local writes + background sync), cross-platform (Windows .exe + Android .apk), CQRS backend, strict theme tokens on the frontend (no hardcoded colours).

## 2. Current State

**The audit is effectively complete.** Every CRITICAL is resolved and every OPT/UP is done; **OPT-5 (colour tokens) is now finished too** (2026-07-09), leaving only the OPT-4 lint residuals (24 info-level, optional zero-lint cleanup). Verification baseline: `dart analyze lib` = **0 errors, 0 warnings, 24 info-level lints** (all the safe `use_build_context_synchronously` residuals from OPT-4); `dotnet build` = 0 errors.

Highlights:
- **Refund integrity solid** — CRITICAL-1 (idempotency, client+server) fixed; CRITICAL-2 (double stock reversal) proven a false alarm; OPT-6 moved the refund outbox fully into Drift (schema **v49**).
- **Backend not live until API restart**, and two placeholder secrets remain (`Jwt:Secret`, `AdminPortal:AccessKey`) — see §6 production prereqs.
- **Docs consolidated** — repo root now holds only `CLAUDE.md` + `PROJECT_DOCUMENTATION.md` (the latter merges the old handover, offline-migration plan, ADR-001/002, offline-first audit, and the project audit as §6).

## 3. Active Files (touched this session)

Frontend (`Front-End/lib/`):
- `core/status_colors.dart` **(new)** — `StatusColors` BuildContext extension (OPT-5 foundation).
- `printer/invoice_pdf_service.dart` + `reports/sales_history_screen.dart` — invoice.\* settings; `_FlexTable` lazy `rowBuilder` (OPT-1).
- `database/backup_scheduler.dart` + `navigation/main_layout.dart` — dbBackupOnClose (WindowListener).
- `refund/refund_service.dart` + `refund/refund_dialog.dart` — CRITICAL-1 client + OPT-6 (prefs queue removed).
- `sync/sync_manager.dart` + `sync/sync_notifier.dart` + `sync/sync_status.dart` **(new)** — OPT-6 `pushPendingRefundOps`, OPT-7 `SyncStatuses`.
- `database/app_database.dart` (+ regenerated `.g.dart`) — Drift **v49** (`is_blind`, `approved_by_user_id` on `documents`).
- `cart/cart_provider.dart` — OPT-3 (`setServiceType`/`setServiceStatus`), UP-4 (`syncOrderNumber` → Drift + local-day).
- `cart/payment_checkout_dialog.dart` — UP-5 (navigator capture), OPT-5 (colours), OPT-4 guards.
- `menu/menu_screen.dart` + `bookings/bookings_screen.dart` — OPT-2 (cart-watch scope), OPT-5 (colours), OPT-4 guards.
- `document/document_editor_screen.dart`, `api/api_client.dart`, + 29 files touched by `dart fix` (OPT-4 Phase 1).
- `pubspec.yaml` + `analysis_options.yaml` — `flutter_lints` re-enabled (OPT-4).

Backend (`Back-End/Web-POS.Api/`):
- `Commands/RefundCommands/ProcessRefundCommand.cs` — refund idempotency dedup (CRITICAL-1 server).
- `DataBase/SQL/trg_*.sql` **(3 new)** — the live DB triggers, scripted (UP-1).

Memory: `project_refund_integrity.md`, `project_settings_wiring.md`, `project_order_numbering.md`, `project_offline_first_status.md` (schema v49) updated.

## 4. Changes Made (DONE)

1. **Audit + cleanup** — generated the audit; consolidated 6 docs → `PROJECT_DOCUMENTATION.md`; deleted the old audit generator (`generate_audit.js`, `node_modules/`, `package*.json`, `POS_Architecture_Audit.pdf/.docx`) + a stray `.csproj.Backup.tmp`.
2. **invoice.\* wired** — `invoice_pdf_service.dart` honours Title / PrintA5 / Columns.Tax / Columns.Discount / GlobalHeader / GlobalFooter (via a `settings` param + `_InvColumn` model).
3. **dbBackupOnClose wired** — `MainLayout` (`WindowListener`) runs an on-close backup before `windowManager.destroy()`; DB-backup automation (OnStart+Interval+OnClose) complete.
4. **CRITICAL-1 refund idempotency** — server dedups on `ClientDocumentNumber` (verified + blind); client persists+queues on ambiguous failures, only rethrows definitive 4xx. Retries can no longer double-refund.
5. **CRITICAL-2** — verified via `sys.triggers` there is **no stock trigger** → false alarm; refund handler's explicit reversal left untouched; fixed the misleading `sync_manager.dart` comment.
6. **OPT-1** — `_FlexTable` builds cells lazily per visible row (was building all cells up front).
7. **OPT-2** — `_MenuScreenState.build` narrows to `cartProvider.select((c) => (serviceType, serviceStatus, selectedCartItemId, items.isEmpty, activePosOrderId))`; tap handlers read the live cart via `ref.read`.
8. **OPT-3** — replaced two raw `CartNotifier.state =` mutations with `setServiceType(regenerateOrderName:false)` + new `setServiceStatus`.
9. **OPT-6** — refund outbox 100% in Drift. Schema **v49** (`is_blind`, `approved_by_user_id`); `SyncManager.pushPendingRefundOps` rebuilds `/Document/Refund` from local rows in the push phase; deleted the `shared_preferences` refund queue; `pendingRefundsCountProvider` counts Drift. `build_runner` regenerated.
10. **OPT-7** — `lib/sync/sync_status.dart` (`SyncStatuses` + the `pending` vs `pending_create` invariant), applied at `pushPendingDocuments`/`pushPendingPayments` + checkout/refund pointer-comments.
11. **UP-1** — scripted the 3 live DB triggers (`trg_Barcode_CompanyMatch`, `trg_Document_CompanyConsistency`, `trg_FloorPlanTable_CompanyConsistency`) into `DataBase/SQL/` as idempotent `CREATE OR ALTER` (manual-apply, verbatim from `sys.sql_modules`).
12. **UP-4** — `cart_provider.syncOrderNumber` rewritten network→Drift (offline-first; survives restart) with **local-day** bucketing (fixes the UTC-day miscount near midnight).
13. **UP-5** — `payment_checkout_dialog._complete` captures `Navigator.of(ctx)` **before** popping and drives post-checkout nav from it (removes a "deactivated widget's ancestor" risk in multi-user auto-logout).
14. **OPT-5 (DONE)** — `StatusColors` extension (`lib/core/status_colors.dart`), theme-brightness-aware. Semantic colours migrated app-wide: first `payment_checkout_dialog.dart`, `menu_screen.dart` (+ grey avatar → `colorScheme`), `bookings_screen.dart`; then (2026-07-09) the remaining 21 screens/dialogs (products, settings, stock, document_editor, documents, promotions, product_import, currencies, users, user_info, warehouses, tax_rates, time_clock, product_groups, credit/cash/refund/sync dialogs, z_report, power_modal, shared_drawer, company_selection, sales_history). Deliberate palettes / status-selectors / `isDark` banners / accents / the QR white background were intentionally left (see §6).
15. **OPT-4 (mostly)** — re-enabled `flutter_lints` (0 errors/warnings). Phase 1 `dart fix --apply lib` = 154 auto-fixes across 29 files; misc = 2 `print`→`debugPrint`, 3 curly-brace clusters, 1 `// ignore`; Phase 2 = fixed all **5 genuinely-unguarded** `use_build_context_synchronously` (real BuildContext-across-async bugs). (24 safe residuals in §6.)
16. **app_properties multi-company seed collision (found during the runtime test)** — `AppSettingsNotifier._tempIdForKey` + `SyncManager._seedMissingAppPropertyDefaults` derived the offline temp id from the setting **key only**, so a 2nd company seeding the same key collided on the `app_properties.id` PK (`SqliteException(1555): UNIQUE constraint` — seen live during the test; also a *silent* cross-company overwrite risk via `insertOnConflictUpdate`). Now both hash **`(companyId, key)`** (identical formula so a seed + a later edit still resolve to the same row). **Pre-existing bug** (not from this session's other work). Compile-clean; live confirmation needs a company login (seed fires on sync).

### Runtime verification (Kaspersky paused by the user, 2026-07-04)
- ✅ **Backend** builds + boots (`Database status: OK`, listening on :5002, swagger→200). CRITICAL-1 change runs.
- ✅ **Frontend** builds for Windows + launches, no exceptions.
- ✅ **OPT-6 v49 migration** verified on the real local Drift DB (read-only query): `user_version=49`, `documents.is_blind` + `documents.approved_by_user_id` PRESENT.
- ⚠️ Surfaced the **app_properties collision** above (fixed, item 16) — the value of running it.

## 5. Failed Attempts / Gotchas

- **Cannot run the app/API from this agent** — Kaspersky flags `claude.exe` spawning children (false positive); API/app launches fail. **All E2E verification is the user's** (add a trusted-app exclusion, or run manually). Everything here is build/analyze only.
- **EF `HasTrigger("…")` names are fictional** — they don't match the real DB triggers; EF only needs to know *a* trigger exists to skip its `OUTPUT` clause. Always verify triggers against `sys.triggers`, not `HasTrigger`. (This wrong-comment class caused the CRITICAL-2 false alarm.)
- **`OBJECT_DEFINITION(OBJECT_ID('name'))` = NULL is inconclusive** (name may not exist) — enumerate with `sys.triggers` + `sys.sql_modules`.
- **Drift schema is now v49** — modifying any Drift table needs a `build_runner` regen; existing installs auto-migrate on launch (v49 is additive/non-destructive).
- **OPT-5 finding: dark mode is NOT actually broken** — app-wide scan found 0 unconditional grey-panel backgrounds, 0 unconditional black body text, 1 white fill. The big `Colors.*` counts are `PdfColors.*` (PDF gen), `isDark`-conditional, shadows, and deliberate accents. So the remaining colour work is *consistency*, not a legibility fix.

## 6. Next Steps (REMAINING / PLANNED)

**Audit — one low-urgency item still open:**
- **OPT-5 (colour tokens) — DONE (2026-07-09).** Consistency pass complete across all remaining screens (`products_screen`, `settings_screen`, `stock_screen`, `document_editor_screen`, `documents_screen`, `promotions_list_screen`, `product_import_screen`, `currencies_screen`, `users_screen`, `user_info_screen`, `warehouses_screen`, `tax_rates_screen`, `time_clock_screen`, `product_groups_screen`, `credit_payment_dialog`, `cash_movement_dialog`, `refund_dialog`, `sync_status_dialog`, `z_report_screen`, `power_modal`, `shared_drawer`, `company_selection_screen`, `sales_history_screen`) via the `StatusColors` extension (`green→successColor`, `red→dangerColor`, `amber/orange→warningColor`, `blue→infoColor`, `white`-on-fill→`onStatusColor`; `power_modal` used the local `cs.error`). `dart analyze lib` = **0 errors, 0 warnings** (only the 24 OPT-4 `use_build_context_synchronously` info residuals remain — unchanged). **Deliberately LEFT** (verified not legibility bugs): domain **status→colour maps/selectors** (booking `_statusColors`, payment Paid/Partial/Unpaid badges in `documents_screen`/`document_editor_screen`, promotions Active/Inactive/Disabled, stock low/reorder/healthy pickers), **fixed data palettes** (product-group + status colour pickers), **`isDark`-conditional banners** (e.g. `users_screen` blue section header — white text needs the dark-blue shade), **deliberate accents** (indigo/blueGrey avatars & edit icons, admin-orange role avatar, the About-tab gradient header), the **QR-code white background** (must stay white to scan), and muted `Colors.grey` secondary text.
- **OPT-4 residual — 24 `use_build_context_synchronously`** (all "guarded by an *unrelated* mounted check"). Functionally **safe** — the passed `ctx` IS the State's `context`, already `mounted`-guarded; the analyzer just can't prove `ctx == this.context`. Info-level, non-breaking. Fix (optional, for a zero-lint baseline) = use `context` instead of the passed `ctx` param, or guard with `ctx.mounted`. Files: `loyalty_cards` (6), `user_info` (4), `cash_movement` (3), `products` (3), `table_widget` (2), `payment_checkout` (2), `settings` (1).

**Deferred cleanup (needs a decision):**
- **`HasTrigger` rename** — EF's fictional trigger-name labels in `AppDbContext.cs` could be renamed to match the real triggers, but the model snapshot records them, so doing it cleanly needs an **EF migration** (metadata-only, no DB DDL). Purely cosmetic; left alone pending a go-ahead to create a migration.

**Settings wiring — still inert:** email/SMTP; serial scale (`scaleEnabled/scalePort/scaleBaudRate`); localization (language/dateFormat/timezone). See the `project_settings_wiring` memory.

**Backend hardening:** broader `[Authorize]` on documents/customers/tax/warehouses/bookings/loyalty writes; server-side per-user audit off the `userId` claim; per-user salt on the local PIN.

**Feature (designed, NOT built): LAN Sync Hub** — see §7. OPT-6 (Drift refund outbox) is the prerequisite and is now done.

**Production prerequisites (before shipping):** replace `Jwt:Secret` + `AdminPortal:AccessKey` in `appsettings.json`, then **restart the API**. Then E2E-verify on the user's machine: refund retry doesn't double-charge; invoice PDF reflects the Invoice settings; closing the desktop window triggers a backup; the offline order counter behaves near midnight; multi-user checkout returns to login with no crash; sign-out frees the device seat; deleting a throwaway company returns the app to master login.

---

## 7. Design Note — LAN Sync Hub (roadmap, NOT built)

**Goal.** Keep a multi-device venue working when the **cloud** connection drops (the *local* Wi-Fi/LAN almost always stays up — it's the internet that's flaky). Today each device syncs only to the cloud, so when the internet dies the devices can't see each other's orders/refunds until it returns.

**Chosen architecture: (B) each device keeps its own local Drift DB + a LAN "sync hub."** Every device stays fully offline-first on its own DB (nothing regresses); a hub on the LAN reconciles the devices with each other and is the single uplink to the cloud. We explicitly rejected sharing the raw SQLite **file** over a Windows share (SMB) — SQLite's own docs warn it corrupts the file (unreliable network file locking). Sharing happens at the **service** layer, not the file layer.

**Why OPT-6 was a prerequisite.** A device's *entire* unsynced state now lives in its Drift DB (orders, documents, payments, **and refunds** — the refund `shared_preferences` outbox is gone as of OPT-6). So the hub can drain a device uniformly from one place; nothing is hidden outside the DB. Do not reintroduce out-of-DB outboxes — they would silently bypass both backup and LAN sync.

### Roles
- **Hub (host):** a **Windows POS** only. It runs a lightweight LAN service (extend the proven **KDS** pattern — `dart:io HttpServer`, token pairing, ports 9090/9091 — see `kitchen_display/` + `Front-End/lib/kitchen/kitchen_push_service.dart`) exposing sync endpoints (push pending ops / pull master+documents), then forwards everything to the cloud when the internet returns. Windows-only because it must be always-on and can host a service + hold local backups (Android can't).
- **Client (spoke):** any Windows POS or Android tablet that points its sync at the hub instead of the cloud.

### The Database setting the user asked for
Add to **Settings → Database** on every POS a **sync-target toggle**:
- **"Work against: [ Cloud ]  [ Local network POS ]"**
- If **Local network POS** → fields for **Host IP, Port, Username, Password** (auth at the service layer, same trust model as KDS pairing: the LAN is the trust boundary, token/credential gates the endpoint).
- On a **Windows POS** additionally: **"Share this POS's database on the local network"** → starts the hub service (configurable **Port + Username/Password**).

### Device-type rules (enforced by the setting)
| Device | Can be Hub? | Can be Client? | If **no Windows hub** is present |
|---|---|---|---|
| **Windows POS** | ✅ yes | ✅ yes | Works Cloud or offline-local. With **two Windows POS**, pick one as hub and the other as its client (or both Cloud). |
| **Android tablet** | ❌ no (can't host a service / no local backup) | ✅ yes (to a Windows hub) | **Forced to work separately** — each tablet syncs Cloud-only (online) or runs offline-local until the cloud returns. Two tablets alone can **never** form a LAN share (no possible host). |

So the toggle must be **capability-gated**: "Share database on LAN" is hidden/disabled on Android; and "Local network POS" is only selectable when a reachable Windows hub is configured — otherwise the device is forced Cloud/offline-local.

### Sync protocol (reuse, don't reinvent)
The hub is a "local cloud": it speaks the **same** push/pull contract the cloud does, so a client just swaps its base URL from cloud→hub. Conflict resolution reuses the existing policy — **hub/server wins for master data; local-wins for transactions; UUIDs + device-local document numbers dedupe.** CRITICAL-1 (server-side idempotency on `ClientDocumentNumber`) + OPT-6 (Drift refund outbox) mean orders and refunds **replay safely** whether the target is the cloud or the hub.

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
- **Hub availability:** if the Windows hub is off/asleep, clients must fall back gracefully (Cloud or offline-local) — never hard-block a till.
- **Clock/ordering** across devices (partly handled via StockDate + server clock pin for the lease).
- **Seat enforcement** must not be weakened by the hub indirection.
