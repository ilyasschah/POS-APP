# Handoff

_Last updated: 2026-07-09._

_**2026-07-09 session:** closed the **entire audit** — finished the colour-token pass (OPT-5), burned the lint residual down to a **true zero-lint baseline** (OPT-4), corrected the EF **`HasTrigger`** labels against `sys.triggers`, **wired the serial weighing scale** (`Scale.Enabled/Port/BaudRate`), and **closed a live backend auth hole** (45 unauthenticated controllers → fail-closed `FallbackPolicy`) plus moved the committed secrets to env vars (§4 item 20). Then added **graceful 401 → login** handling so a dead/rotated token routes to the login screen instead of an endless 401 flood (item 21), and **reorganised the tests** + added a device-reset utility (item 22). All verified against the running API / app. (Note: local DB encryption is **intentionally off for the dev phase** — `kPillar3Encryption = false`; re-enable for production — see item 22.)_

_**2026-07-04 session:** the repo-wide audit + remediation, doc cleanup/consolidation, two settings-wiring items (invoice.\*, dbBackupOnClose), re-enabling `flutter_lints`, and starting the colour-token pass._

_**Verification note:** unlike 2026-07-04 (when Kaspersky blocked the agent from spawning processes), the 2026-07-09 work **was** run — `dart analyze`, `flutter test`, `flutter build windows`, `flutter build apk`, `dotnet build`, plus the API and the Windows app launched against a live SQL Server. The remaining untested surface is named explicitly in §5 and §6._

---

## 1. Goal

Two tracks:
- **Audit remediation** — act on the repo-wide audit (in `PROJECT_DOCUMENTATION.md` §6): money/data-critical first, then perf/architecture optimizations.
- **Settings wiring** — make editable-but-inert app settings actually do something.

Constraints: offline-first (Drift-local writes + background sync), cross-platform (Windows .exe + Android .apk), CQRS backend, strict theme tokens on the frontend (no hardcoded colours).

## 2. Current State

**The audit is complete.** Every CRITICAL, OPT and UP item is resolved — **OPT-5 (colour tokens) and the OPT-4 lint residual were both finished on 2026-07-09.** Verification baseline: `dart analyze lib` = **"No issues found!"** (0 errors, 0 warnings, **0 info** — a true zero-lint baseline); `flutter build windows --debug` succeeds and the app boots clean against a live API; `dotnet build` = 0 errors. The deferred `HasTrigger` rename is also done (no migration was needed — see §6). Only the non-audit work below remains.

Highlights:
- **Refund integrity solid** — CRITICAL-1 (idempotency, client+server) fixed; CRITICAL-2 (double stock reversal) proven a false alarm; OPT-6 moved the refund outbox fully into Drift (schema **v49**).
- **Zero-lint baseline** — `dart analyze lib` prints *"No issues found!"*. Keep it there: `flutter_lints` is on, so a stray `Colors.green` or an unguarded `BuildContext` now shows up immediately.
- **API is live and hardened** — rebuilt and restarted on `0.0.0.0:5002` with the fail-closed `FallbackPolicy` (§4 item 20) and the strong `Jwt__Secret` env var (`Database status: OK`, swagger 200). The two secrets are now **env vars with strong values** (blank in `appsettings.json`); the only secrets task left is setting them in the **deployment** environment — see §6.
- **Serial weighing scale wired** (Windows-only, capability-gated) — see §4 item 19.
- **Graceful 401 → login** (item 21) and a **cleaned-up test suite** with a device-reset utility (item 22). Note: local DB encryption (Pillar 3) is **deliberately disabled for the dev phase** (`kPillar3Encryption = false`, so the DB can be inspected in DBeaver/LINQPad); flip it to `true` for production — see item 22.
- **Docs consolidated** — repo root now holds only `CLAUDE.md` + `PROJECT_DOCUMENTATION.md` (the latter merges the old handover, offline-migration plan, ADR-001/002, offline-first audit, and the project audit as §6).

## 3. Active Files

### Touched 2026-07-09

Frontend (`Front-End/`):
- `lib/scale/scale_weight_parser.dart` **(new)** + `lib/scale/scale_service.dart` **(new)** — serial scale (§4 item 19).
- `test/scale_weight_parser_test.dart` **(new)** — 11 tests pinning the frame formats (moved out of `test/scale/` in the item-22 reorg).
- `lib/menu/quantity_keypad_dialog.dart` — now a `ConsumerStatefulWidget`; live weight + "Use weight".
- `lib/settings/settings_screen.dart` — new `SERIAL CONNECTION` card (+ OPT-5 colours, OPT-4 guard).
- `pubspec.yaml` — `flutter_libserialport: ^0.6.0`.
- **OPT-5 colours** across 21 screens/dialogs (products, settings, stock, document_editor, documents, promotions, product_import, currencies, users, user_info, warehouses, tax_rates, time_clock, product_groups, credit/cash/refund/sync dialogs, z_report, power_modal, shared_drawer, company_selection, sales_history).
- **OPT-4 guards** in `loyalty/loyalty_cards_screen.dart` (6), `cart/payment_checkout_dialog.dart` (5), `auth/user_info_screen.dart` (4), `cash/cash_movement_screen.dart` (3), `product/products_screen.dart` (3), `floor_plan/widgets/table_widget.dart` (2), `settings/settings_screen.dart` (1).
- `lib/auth/session_expiry.dart` **(new)** — graceful 401 → login (§4 item 21). Wiring: `lib/auth/auth_token_cache.dart` (`onTokenSet` hook), `lib/api/api_client.dart` (`onError` interceptor), `lib/main.dart` (`navigatorKey` + hook wiring), `lib/auth/login_screen.dart` (`sessionExpired` flag).
- **Tests reorganised** (§4 item 22): `test/` = unit only; `integration_test/` = on-device. Added `integration_test/clear_local_data_test.dart` (resets the terminal). Deleted `widget_test.dart` + the two v39 clone tests.

Backend (`Back-End/Web-POS.Api/`):
- `DataBase/AppDbContext.cs` — 3 `HasTrigger` labels corrected (§4 item 18). **No migration** was needed or created.
- `Program.cs` — fail-closed `FallbackPolicy`, `/Admin` Razor exemption, `/` `.AllowAnonymous()`, strengthened `Jwt:Secret` guard (§4 item 20).
- `Controllers/AuthController.cs` (`Login`), `Controllers/MasterController.cs` (`LeasePublicKey`, `Lease`) — `[AllowAnonymous]`.
- `appsettings.json` — `Jwt:Secret` + `AdminPortal:AccessKey` blanked (real values now in env vars / git-ignored `SECRETS.local.txt`).
- `.gitignore` — ignores `SECRETS.local.txt`.

### Touched 2026-07-04

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

> **Note:** earlier revisions of this file pointed at agent memories (`project_refund_integrity`, `project_settings_wiring`, `project_order_numbering`, `project_offline_first_status`). No such memory store exists on this machine — **this file and `PROJECT_DOCUMENTATION.md` are the only source of truth.** Don't go looking for them.

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
15. **OPT-4 (DONE)** — re-enabled `flutter_lints`. Phase 1 `dart fix --apply lib` = 154 auto-fixes across 29 files; misc = 2 `print`→`debugPrint`, 3 curly-brace clusters, 1 `// ignore`; Phase 2 = fixed all **5 genuinely-unguarded** `use_build_context_synchronously` (real BuildContext-across-async bugs). Phase 3 (2026-07-09) = the last **24** info-level residuals → see item 17.
16. **app_properties multi-company seed collision (found during the runtime test)** — `AppSettingsNotifier._tempIdForKey` + `SyncManager._seedMissingAppPropertyDefaults` derived the offline temp id from the setting **key only**, so a 2nd company seeding the same key collided on the `app_properties.id` PK (`SqliteException(1555): UNIQUE constraint` — seen live during the test; also a *silent* cross-company overwrite risk via `insertOnConflictUpdate`). Now both hash **`(companyId, key)`** (identical formula so a seed + a later edit still resolve to the same row). **Pre-existing bug** (not from this session's other work). Compile-clean; live confirmation needs a company login (seed fires on sync).

17. **OPT-4 residual (DONE, 2026-07-09)** — all 24 `use_build_context_synchronously` fixed → `dart analyze lib` = *"No issues found!"*. Per file: `loyalty_cards` (6), `payment_checkout` (5), `user_info` (4), `cash_movement` (3), `products` (3), `table_widget` (2), `settings` (1). The fix is mechanical but **splits by what kind of `BuildContext` is used after the `await`** — the rule is in §5, and getting it backwards is why these lingered. Two sites needed judgment rather than a swap: `payment_checkout._complete`'s `catch` (its `setState` needs State `mounted`, so the snackbar moved to `context`), and `user_info`'s nested `builder: (ctx) => StatefulBuilder(builder: (context, …))` dialogs, where `Navigator.pop(ctx)` + `showAppSnackbar(context, …)` used *two different* contexts under one guard (consolidated onto `context`; `ctx` still serves the Cancel buttons).
18. **`HasTrigger` rename (DONE, 2026-07-09)** — the 3 real trigger labels in `AppDbContext.cs` now match `sys.triggers`. **No EF migration was needed** (the old "needs a migration" note was wrong — see §5). 4 phantom declarations deliberately kept.
19. **Serial weighing scale wired (2026-07-09)** — `Scale.Enabled` / `Scale.Port` / `Scale.BaudRate` now drive a real scale. (`Scale.Barcode.*` was *already* wired via `utils/scale_barcode_parser.dart` → `menu_screen`; that's the separate **label-printing** scale.)
    - **`lib/scale/scale_weight_parser.dart`** — pure, unit-tested, tolerant parser for continuous-mode frames: `ST,GS,+  1.234kg`, `US,NT,-  0.100 kg`, `1.234kg`, bare `1.234`. Strips STX/ETX/CR/LF framing; honours the `ST`/`US` stability flag; returns `null` on unparseable frames (normal when first attaching to a port — callers ignore nulls, they are not errors).
    - **`lib/scale/scale_service.dart`** — `SerialScaleService` (opens the port, buffers the trailing partial line because serial delivers arbitrary chunks, emits one `ScaleReading` per frame) + `scaleConfigProvider`, `availableSerialPortsProvider`, `scaleReadingProvider`.
    - **`scaleReadingProvider` is `autoDispose` on purpose** — the COM port is held open *only* while something listens (the quantity keypad, or the settings live-test). The POS never keeps a port locked in the background, and nothing polls.
    - **Windows-only, capability-gated:** `kScaleSupported == Platform.isWindows`. **Never construct `SerialScaleService` when it is false.**
    - **UI:** Settings → Weighing Scale gained a `SERIAL CONNECTION` card (enable switch, port dropdown over *detected* ports + rescan button, baud dropdown, and a live read-out so wiring/baud is proven there rather than mid-sale). `quantity_keypad_dialog.dart` shows the live weight with a **"Use weight"** button **disabled until the reading is stable**, so a swinging pan can't be banked. The manual keypad always remains → an offline scale never blocks a sale.
    - **No unit conversion, ever.** The parser returns the scale's own number and unit; if the scale reads `g` on a line priced per `kg`, the keypad shows an explicit mismatch warning instead of guessing (silently converting would be a 1000× pricing bug).
20. **Backend auth hardening (2026-07-09) — closed a real, live-proven vulnerability.** Before: **45 of 54 controllers had no `[Authorize]`** and there was **no fallback policy**, so anyone on the LAN could create/read/delete products, documents, customers, warehouses, tenants, etc. **with no token** (probed live: `POST /api/Products/Add` → 400 unauthenticated; `GET /api/Master/Tenants` → 200, a full tenant-list leak).
    - **Fix = fail-closed `FallbackPolicy`** (`Program.cs`): `RequireAuthenticatedUser()` now applies to every endpoint **unless** it opts out with `[AllowAnonymous]`. A newly-added controller is protected by default. The deliberate anonymous allowlist is exactly four things: `POST /api/Auth/Login`, `GET /api/Master/LeasePublicKey`, `GET /api/Master/Lease` (the licensing bootstrap — its security is the RS256 signature, and it's fetched around token-refresh boundaries), and the `/Admin` portal + `/` redirect (the portal has its own `AdminPortalGate` shared-secret, so its Razor pages are exempted via `AllowAnonymousToFolder("/Admin")` and `/` via `.AllowAnonymous()`).
    - **Secrets moved out of the committed `appsettings.json`** (they were `Jwt:Secret = "change-this-…"` and `AdminPortal:AccessKey = "Admin@123"`, both live in git). Now blank in the file; real values are **user-level env vars** `Jwt__Secret` / `AdminPortal__AccessKey` (set via `setx`, recorded in the git-ignored `Back-End/Web-POS.Api/SECRETS.local.txt`). The startup guard was strengthened to abort outside Development when `Jwt:Secret` is **empty, <32 chars, or a known placeholder** — not just missing (the old guard passed the placeholder). The DB password is still in the connection string — **left working, flagged for a follow-up** (moving it needs a live DB-connect re-test).
    - **⚠️ Rotating the JWT secret invalidates every existing session.** Any device holding a token signed with the old placeholder gets 401 on its next online call and must re-login. Expected for a secret rotation; the app stays usable offline meanwhile. **Item 21 makes this graceful** (routes to login instead of spewing 401s).
    - **Follow-up (not done):** the `/api/Master/*` control-plane reads/mutations (`Tenants`, `Subscriptions`, `Devices`, `Provision`, `CheckDevice`, `CloneAlerts`) now require *any* authenticated user — they should be tightened to `[Authorize(Policy="ManagerOnly")]` (Admin role). Left for a follow-up so the role model is confirmed first. `ReleaseDevice` must stay any-authenticated (a cashier releases their own seat on sign-out).
21. **Graceful 401 / session-expiry handling (2026-07-09) — frontend follow-up to item 20.** After the secret rotation, running the app produced an **endless wall of `sync step … failed — 401`** because the cached token was signed with the old secret and nothing handled the rejection. Now a token-bearing 401 clears the token and routes to the login screen once, with a "Your session expired. Please sign in again." message.
    - **`lib/auth/session_expiry.dart` (new)** — `rootNavigatorKey` (wired onto `MaterialApp` in `main.dart`) + a debounced `SessionExpiry` coordinator. `onUnauthorized()` clears the token and `pushAndRemoveUntil`s the login screen **once**; the debounce re-arms only when a fresh token is issued.
    - **The discriminator matters:** the Dio `onError` interceptor (`api_client.dart`) fires only when the 401 came from a request that **carried an `Authorization` header** *and* wasn't `/Auth/Login`. A 401 with no token is an ordinary auth failure (bad credentials) handled by the caller; being **offline is a connection error, not a 401**, so this never fires when the network is merely down.
    - **No import cycle:** `SessionExpiry` never imports the UI. `main.dart` injects the login route via `SessionExpiry.loginRouteBuilder` and re-arms the debounce via `AuthTokenCache.onTokenSet = SessionExpiry.reset` (a new hook on the cache). `login_screen.dart` gained a `sessionExpired` flag that shows the snackbar on arrival.
    - **Live-proven:** ran via `flutter run` against the still-rotated token — the handler fired **exactly once** (`pushAndRemoveUntil` to `LoginScreen(sessionExpired: true)`), no crash, no navigation loop, and the 401 flood was gone (the first sync step's 401 triggered the redirect before the wall could accumulate).
    - **Known limitation:** if a background 401 lands **mid-sale**, `pushAndRemoveUntil` clears the nav stack, so an in-progress in-memory cart would be lost. This is rare (only on secret rotation or a 7-day-offline token expiry, since sliding refresh renews while online) and was the explicit trade for "route to login." A gentler variant (a persistent "session expired — tap to sign in" banner that doesn't force-navigate mid-sale) is a possible refinement.
22. **Test reorg + a device-reset utility (2026-07-09).** Cleaned the test suite and added a way to wipe a terminal's saved identity for auth/token-expiry testing.
    - **Layout is now the Flutter-standard split** and *cannot* be a single folder: `test/` = pure-Dart unit tests (`flutter test`, headless); `integration_test/` = on-device tests. **Verified live why:** an integration test moved under `test/` throws `MissingPluginException` — Flutter only wires native plugins (path_provider, shared_preferences, secure storage) for tests in the exact `integration_test/` folder. See `test/README.md`.
    - **Kept:** `test/error_handler_test.dart`, `test/scale_barcode_parser_test.dart`, `test/scale_weight_parser_test.dart` (units, 20 tests, all pass); `integration_test/cipher_test.dart` (Pillar-3 encryption check). **Deleted:** `test/widget_test.dart` (broken counter boilerplate — `main.dart` has no counter), `integration_test/pull_clone_test.dart` (brittle: hardcoded company #18 + exact seeded counts, v39-era, backend-dependent), `integration_test/schema_clone_test.dart` (a served-its-purpose v38→v39 migration check; schema is v49).
    - **New `integration_test/clear_local_data_test.dart`** — wipes this machine's `SharedPreferences` (device id, company id, cached users, API base URL, theme, lease clock…) **and** `flutter_secure_storage` (JWT, device token, lease). Leaves the Drift DB untouched (local orders survive; only auth/registration resets). After it runs, the app boots to master login with a fresh device id. Run: `flutter test integration_test/clear_local_data_test.dart -d windows`. *(Not run by the agent — it wipes real data; left for the user, as requested.)*
    - **Pillar-3 encryption is INTENTIONALLY OFF for the dev phase — not a bug.** `cipher_test` initially "failed" (the local `pos_app.sqlite` has the plaintext `"SQLite format 3"` header), but that is by design: `app_database.dart` has a master switch `const bool kPillar3Encryption = false` (line ~4487) so the DB opens as plaintext and can be inspected with DBeaver/LINQPad during development. The `_openConnection()` path auto-**decrypts** an existing encrypted file when the switch is off and auto-**re-encrypts** it when flipped back on (data preserved either way), so it's fully reversible. `cipher_test` now **auto-skips while `kPillar3Encryption == false`** and becomes the pass/fail gate once it's `true`. **Production checklist:** set `kPillar3Encryption = true`, relaunch (auto re-encrypts), then run `flutter test integration_test/cipher_test.dart -d windows` and confirm it passes.

### Runtime verification

**2026-07-09 (agent ran everything; Kaspersky no longer blocking):**
- ✅ `dart analyze lib` → **No issues found!** (0 errors / 0 warnings / 0 info) — after all of OPT-5, OPT-4, the serial scale, and the graceful-401 work (item 21).
- ✅ **Graceful 401 (item 21) live-proven** via `flutter run` against the rotated token: the session-expiry handler fired **exactly once**, routed to `LoginScreen(sessionExpired: true)`, no crash / no loop, and the previously-endless 401 flood was gone. (Note: a **directly-launched** debug `.exe` sends Dart `print`/`debugPrint` to the debugger channel, not stdout — so to see Dart logs you must use `flutter run`, not the built exe.)
- ✅ **Test reorg (item 22):** `flutter test` = **+20 all pass** (the broken `widget_test.dart` is deleted; `integration_test/` not scanned); the integration harness runs on device (`cipher_test` opened the DB + read `PRAGMA cipher_version`). `cipher_test` now **auto-skips** while `kPillar3Encryption == false` (encryption intentionally off for dev — item 22), so it no longer reads as a failure.
- ✅ `flutter build windows --debug` and `flutter build apk --debug` both succeed (cross-platform rule holds with the new serial plugin; `serialport.dll` + `libserialport.so` ship correctly).
- ✅ Windows app **launches** against the live API — clean boot, no exceptions, with the new native plugin registered.
- ✅ Backend `dotnet build` = 0 errors / 0 warnings; API restarted and healthy on `0.0.0.0:5002` (`Database status: OK`, swagger 200).
- ✅ **Auth hardening (item 20) live-proven against the running API:** allowlist reachable without a token (`Auth/Login` → 401 with the handler's JSON body and *no* `WWW-Authenticate` challenge = it ran; `Master/LeasePublicKey` & `Master/Lease` → 200); formerly-open endpoints now **401 without a token** (`Products/Add`, `Products/GetAll` — was 200, `Document/Add`, `Warehouses/Add`, `Master/Tenants` — was 200); a **valid forged token → 200** on `Products/GetAll` and `Master/Tenants` (authenticated path intact); a **tampered signature → 401** (new secret validates); the **secret guard fails closed** (empty secret in Production aborts startup with the guard message); infra unaffected (`/swagger` 200, `/` 302, `/admin/companies` → 403 from `AdminPortalGate`, not a JWT 401).
- ⚠️ **Not exercised:** the scale against real hardware; the OPT-4-touched *dialog* flows (checkout, PIN/password change, loyalty add/edit/delete, comment delete, table tap, customer display) — booting the app doesn't open them; and a **real end-to-end login from the Flutter app** after the secret rotation (verification used a forged token, valid because the secret is known — the happy-path login flow was traced in code, not driven in the UI). See §6.

**2026-07-04 (Kaspersky paused by the user):**
- ✅ **Backend** builds + boots (`Database status: OK`, listening on :5002, swagger→200). CRITICAL-1 change runs.
- ✅ **Frontend** builds for Windows + launches, no exceptions.
- ✅ **OPT-6 v49 migration** verified on the real local Drift DB (read-only query): `user_version=49`, `documents.is_blind` + `documents.approved_by_user_id` PRESENT.
- ⚠️ Surfaced the **app_properties collision** above (fixed, item 16) — the value of running it.

## 5. Failed Attempts / Gotchas

- **Kaspersky (historical)** — on 2026-07-04 it flagged `claude.exe` spawning children, so nothing could be launched. As of 2026-07-09 the agent **can** run builds, tests, the API and the app. If launches start failing again, that's the cause; add a trusted-app exclusion.
- **EF `HasTrigger("…")` only means "a trigger exists here"** — EF never resolves the name; it uses the declaration solely to omit the `OUTPUT` clause on write. So the label is free-text and **cannot be trusted to tell you what the DB actually has.** Always enumerate `sys.triggers`. (Trusting these labels caused the CRITICAL-2 false alarm.) As of 2026-07-09 the 3 real ones are named correctly; **4 phantom declarations remain on purpose** (`DocumentItem`, `Booking`, `Payment`, `StartingCash` — no such triggers exist). Removing them would re-enable `OUTPUT` (faster inserts) but makes inserts fail with **SQL error 334** the day someone adds a real trigger there. Don't "tidy" them without weighing that.
- **A trigger rename is NOT a schema change.** EF Core's migrations differ emits **no operations** for trigger metadata — `has-pending-model-changes` reports none after a rename, so no migration is needed (an earlier note in this file claimed otherwise and was wrong). Stale names left in `AppDbContextModelSnapshot.cs` are inert and get regenerated by the next real migration. **Never hand-edit the snapshot or historical `*.Designer.cs` files.**
- **`dotnet ef` runs the WRONG version in `Back-End/Web-POS.Api/`** — `.config/dotnet-tools.json` pins a **local** `dotnet-ef` **9.0.8** while the project is **EF Core 10.0.9**. Use the global tool (`~/.dotnet/tools/dotnet-ef.exe`) or update the manifest. There are also **two DbContexts**, so every command needs `--context Api.DataBase.AppDbContext` (or `Api.Master.MasterDbContext`).
- **The API exe ignores `launchSettings.json`.** Launched directly it silently binds `:5000`, not the `:5002` the Flutter app expects. Start it with `ASPNETCORE_URLS="http://0.0.0.0:5002"` (0.0.0.0 so Android tablets can reach it). The app never calls `Database.Migrate()` — only `CanConnect()` — so **migrations are always applied manually**.
- **The API now REQUIRES `Jwt__Secret` in the environment outside Development** (item 20). `appsettings.json` ships it blank and the startup guard aborts on empty/short/placeholder. The real value is a **user-level env var** already set via `setx` (mirrored in the git-ignored `Back-End/Web-POS.Api/SECRETS.local.txt`), plus `AdminPortal__AccessKey`. A brand-new shell inherits the `setx` value, but a shell open *before* the `setx` won't — export them inline when launching from an old session: `Jwt__Secret=... AdminPortal__AccessKey=... ASPNETCORE_URLS=http://0.0.0.0:5002 ./Web-POS.Api.exe`. If the API dies at startup with *"Jwt:Secret is missing…"*, that's this — the env var isn't visible to that process.
- **Rotating `Jwt:Secret` invalidates all live tokens** — every logged-in device 401s on its next online call and must re-login. As of item 21 the Dio client (`api_client.dart` → `SessionExpiry`) **does** handle this: a 401 on a *token-bearing* request (not `/Auth/Login`) clears the token and routes to login once. A 401 with **no** token, or a plain connection error (offline), does **not** trigger it. So when adding new auth-optional endpoints, remember the discriminator is "did we send an `Authorization` header," not the path.
- **`use_build_context_synchronously` — the guard must match the context.** A **local/parameter** `BuildContext` (a `ctx`/`context` param, a `build(context)` param, an `itemBuilder(context, i)` param) needs **`context.mounted`**; a State `mounted` check is "unrelated" to it. Conversely **`State.context`** (bare `context` in a State method with *no* `context` param) needs the State's **`mounted`** — `context.mounted` is "unrelated" there, because the analyzer can't tie repeated `context` *getter* calls together. Mixed blocks (e.g. `setState` + a snackbar taking `ctx`) need each use guarded by its own matching check.
- **`_SettingDropdown` throws on an empty `options` list** (it falls back to `options.first`). Any dropdown fed from hardware discovery must union the saved value in — see `_ScalePortDropdown`, where an unplugged `COM2` must still display as `COM2`.
- **Scale unit regex:** `\b(kg|g|lb|oz)\b` can **never** match `1.234kg` — there is no word boundary between `4` and `k`, and that is the most common frame format. Anchor at end-of-line instead. (Caught by `test/scale_weight_parser_test.dart`.)
- **`OBJECT_DEFINITION(OBJECT_ID('name'))` = NULL is inconclusive** (name may not exist) — enumerate with `sys.triggers` + `sys.sql_modules`.
- **Drift schema is now v49** — modifying any Drift table needs a `build_runner` regen; existing installs auto-migrate on launch (v49 is additive/non-destructive).
- **OPT-5 finding: dark mode was never actually broken** — the app-wide scan found 0 unconditional grey-panel backgrounds, 0 unconditional black body text, 1 white fill (the QR code, which *must* stay white to scan). The big `Colors.*` counts were `PdfColors.*` (PDF gen), `isDark`-conditional, shadows, and deliberate accents. The colour pass was therefore *consistency*, not a legibility fix — which is why so much was deliberately left alone: **status→colour maps/selectors** (booking `_statusColors`, payment Paid/Partial/Unpaid, promotions Active/Inactive/Disabled, stock low/reorder/healthy), **fixed data palettes** (colour pickers), **`isDark`-conditional banners** (`users_screen`'s blue section header needs its dark-blue shade for white text to stay legible — `infoColor`'s dark variant is *light* blue and would break contrast), **deliberate accents** (indigo/blueGrey avatars, admin-orange role avatar, the About-tab gradient header) and muted `Colors.grey` secondary text. Don't "finish the job" by converting these.

## 6. Next Steps (REMAINING / PLANNED)

**The audit is fully closed.** Every CRITICAL / OPT / UP item, plus the deferred `HasTrigger` cleanup, is done — see §4 for what changed and §5 for the rules learned. `dart analyze lib` = *"No issues found!"*. Everything below is **non-audit** work.

**Outstanding verification.** None of these is a known bug; they are *untested surface* left by this session:
- **The serial scale has never met real hardware.** The parser is unit-tested against the documented CAS/Toledo frame formats, but the **port, baud rate and actual frame layout need one physical scale** to confirm. The live read-out in Settings → Weighing Scale → `SERIAL CONNECTION` exists precisely to make that a 30-second check rather than a debugging session.
- **The OPT-4 `mounted`-guard changes all live inside dialogs**, which booting the app never opens: checkout (print dialog + navigator capture), user PIN/password change, loyalty add/edit/delete, product-comment delete, floor-plan table tap, customer display. Open each once.
- **Re-enable Pillar-3 encryption before production** (intentionally off in dev). Set `kPillar3Encryption = true` in `app_database.dart`, relaunch (the DB auto re-encrypts, data preserved), then run `flutter test integration_test/cipher_test.dart -d windows` — it un-skips and must pass. This is a deliberate toggle, **not a bug** (see item 22).

**Settings wiring — still inert:** email/SMTP; localization (language/dateFormat/timezone). *(Serial scale and `Scale.Barcode.*` are both wired — see §4 item 19.)*

**Backend/security follow-ups:** the blanket `[Authorize]` gap is **closed** (item 20 — fail-closed `FallbackPolicy`, live-proven). Remaining:
- Tighten the `/api/Master/*` control-plane to `[Authorize(Policy="ManagerOnly")]` (see item 20 follow-up).
- Server-side per-user audit off the `userId` claim; per-user salt on the local PIN.
- Move the **DB password** out of the committed connection string into env/user-secrets (needs a live DB-connect re-test).
- **Pillar 3 — flip encryption back on for production.** Encryption is deliberately disabled in dev (`kPillar3Encryption = false` in `app_database.dart`) so the DB can be inspected with standard tools. The plumbing is complete (`DeviceKeyService` derives the hardware-bound key; `_encryptLegacyDbIfNeeded`/`_decryptDbIfNeeded` convert in place on the switch). Just set it to `true` and confirm `cipher_test` passes — see the outstanding-verification bullet above. (So ADR-002 Pillar 3 and the §7 LAN-hub assumption hold once the switch is on.)

**Feature (designed, NOT built): LAN Sync Hub** — see §7. OPT-6 (Drift refund outbox) is the prerequisite and is now done.

**Production prerequisites (before shipping):**
- **Secrets:** `Jwt:Secret` + `AdminPortal:AccessKey` are already moved to env vars with strong values (item 20). Before shipping, set them in the **deployment** environment (not just this dev machine's `setx`), and decide whether to scrub the old placeholder values from git history. Rotating the JWT secret again will force every device to re-login.
- **E2E-verify on the user's machine** (some of this is the untested surface above): a **real login from the Flutter app** end-to-end now that the JWT secret changed (existing sessions are invalidated — expect a re-login); the serial scale against real hardware; refund retry doesn't double-charge; invoice PDF reflects the Invoice settings; closing the desktop window triggers a backup; the offline order counter behaves near midnight; multi-user checkout returns to login with no crash; sign-out frees the device seat; deleting a throwaway company returns the app to master login.

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
