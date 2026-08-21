# POS Session — architecture analysis and proposal

_Written 2026-08-16. **Analysis only — no code has been changed.** Awaiting approval._

Behavioural reference: Odoo 19 POS session lifecycle. Adapted to this app, **not** copied
structurally. Vocabulary: **device**, never "till" — a *device* is the register (one install of
the app), a *session* is a period during which that device trades.

---

## Part 1 — What exists today

### 1. Device / register model

There is **no Till or Register entity in the company database.** Register identity today is:

| Where | What | Notes |
|---|---|---|
| Control-plane DB | `Master/Domain/DeviceRegistry` — `DeviceId` (GUID string), `DeviceName`, `TenantId`, `CompanyId`, `Status`, `RegisteredAt`, `LastSeenAt` | Drives licensing + seat enforcement |
| Device-local prefs | `pos.device.name` (e.g. `POS1`), `flutter_secure_storage` device id | Never synced; see `device_scoped_settings.dart` |
| Every document | The device name **already prefixes every document number** — `POS1-200-000014` | `AppDatabase.nextDocumentNumber` |

🚨 **`DeviceRegistry` is in a different database from `PosOrder`/`Document`.** A company-DB foreign
key to it is impossible. This is the single most important structural constraint in this document.

### 2. Order model

- Backend `Domain/PosOrder.cs`: `Id, CompanyId, UserId, Number, Discount, DiscountType, Total,
  CustomerId, ServiceType, ServiceStatus, FloorPlanTableId, DueDate, DateCreated`.
- Drift `pos_orders`: `localId` (UUID PK), `serverId?`, `companyId`, `userId`, `tableId`,
  `serviceType`, `serviceStatus`, `orderName`, `openedAt`, `closedAt`, `status` (0 = open,
  1 = completed), `total`, `discount`, `warehouseId`, `paymentTypeId`, `amountPaid`, `customerId`,
  `number`, `bookingId`, `syncStatus`, `syncError`.
- **No device id and no shift/session id on either side.**
- ⚠️ `PosOrder` has **no `Status` column server-side** (see `posorder-schema-gaps`): open vs completed
  is a purely local distinction.

### 3. Payment model

- Backend `Domain/Payment.cs`: `Id, CompanyId, DocumentId, PaymentTypeId, Amount, Date, UserId,
  **ZReportId?**, DateCreated` + `LockToZReport(int zReportId)`.
- Drift `payments`: `localId`, `serverId?`, `documentId` (→ `documents.localId`), `paymentTypeId`,
  `amount`, `userId`, `date`, `zReportId?`, `syncStatus`.
- **`Payment.ZReportId` is the closest thing to a session link that exists today.** It is stamped at
  Z-report time, not at sale time, and is therefore a *reporting* binding, not an operational one.

### 4. Cash management

- Backend `Domain/StartingCash.cs`: `Id, CompanyId, UserId, Amount, Description,
  **StartingCashType** (0 = in, 1 = out), **ZReportNumber?**, DateCreated`.
- Drift `starting_cash`: same fields, `type` as `'in'|'out'`, plus `localId/serverId/syncStatus`.
- UI: `lib/cash/cash_movement_screen.dart`. Sync: `pushPendingCashMovements`, `pullStartingCash`.
- **Cash movements are already implemented.** They bind to a Z-report *number*, not to a session.

### 5. Sync architecture

- `SyncManager.sync()` → `_pushAll` (30+ ordered pushers) → `pullMasterData` → `pullDocuments` →
  `pullDiscountLines`. Order in `_pushAllInner` is load-bearing: parents before children, with
  temp→real id remapping (`remapProductId`, `remapPaymentTypeId`, …).
- Two status families, documented in `lib/sync/sync_status.dart`: `pending` (checkout/refund
  artifacts, created server-side by the command path) vs `pending_create|update|delete` (manual CRUD,
  drained by the generic pushers). **Mixing them double-creates sales.**
- Existing pushers relevant here: `pushPendingShifts`, `pushPendingCashMovements`,
  `pushPendingZReports`, `pushPendingOrders` (BatchSync), `pushPendingOpenOrders`,
  `pushPendingRefundOps`, `pushPendingPayments`, `pushPendingVoids`.
- Idempotency is by client `localId` (item 33) and by server-side number reallocation (item 30).

### 6. Drift tables in scope

`pos_orders`, `pos_order_items`, `pos_order_item_taxes`, `documents`, `document_items`, `payments`,
`discount_lines`, `starting_cash`, `z_reports`, `shifts`, `pending_voids`, `local_doc_counters`.
Current `schemaVersion` is **57**.

### 7. Backend DB structure

EF Core + SQL Server, migrations in `Web-POS.Api/Migrations` (most recent:
`20260806174002_AddPosOrderItemDiscountInput`). Note `20260607192911_AddShiftAndTimeClock` — the
shift table already shipped through a migration.

⚠️ **`CLAUDE.md` forbids creating migrations unless explicitly told.** This work requires one;
that approval is requested explicitly in Part 2.

### 8. API endpoints in scope

| Controller | Actions |
|---|---|
| `ShiftsController` | `GET /api/Shifts/[action]`, `POST /api/Shifts/[action]` |
| `StartingCashController` | GetAll / GetById / by user / Add / Delete |
| `ZReportController` | `GetById`, `GetAll`, `GetLast`, `POST Generate` |
| `PosOrdersController` | includes `/PosOrder/BatchSync` — the offline checkout path |
| `DocumentController` | `/Document/Refund`, `GetSalesHistory` |

### 9. Open-order behaviour

- An open order is `pos_orders.status = 0`; a completed sale is `status = 1`.
- Every "is this still going?" query filters `status = 0`: floor-plan occupancy, Open Orders (4
  queries), kitchen push, bookings, cart reopen, `getPendingOpenOrders` (verified in item 33).
- Open orders cross devices via `syncOpenOrdersToDrift` (20 s poll) + `_pullOrderItems`, **not**
  through `sync_manager` — there is no `pullPosOrders`.
- A completed-but-unsynced sale (`status = 1`, `syncStatus = 'pending'`) is the **carrier** for its
  checkout document (item 33). Deleting it strands the sale permanently.

### 10. Refund behaviour

`lib/refund/refund_service.dart` → `POST /Document/Refund`, online-first with an offline fallback:
a 4xx is a definitive rejection (nothing written locally); anything else writes the refund locally as
`pending` and `pushPendingRefundOps` drains it. Refund documents are `documentTypeId = 4` with
negative totals/quantities. **Refunds do not go through the order/session path at all.**

### 11. Employee / user behaviour

- `users` + `UserDevicePin` (per-device PIN, sha256+base64, verified offline).
- `PosOrder.UserId` / `documents.userId` / `payments.userId` record who handled the transaction.
- `shifts.userId` is the clocked-in employee; `isDrawerShift` distinguishes the station's master
  cash-drawer shift from per-employee attendance sessions.
- `accessLevel == 0` is admin (used to gate the Reset Database card).

### 🚨 Existing defect this work must fix

`ZReportService.GenerateZReportAsync` bounds its period as
`d.Id >= fromDocumentId && d.Id <= toDocumentId` where `fromDocumentId = lastReport.ToDocumentId + 1`,
filtered **by company only**. With two devices trading simultaneously, device B's documents fall
inside device A's id range and are swept into device A's Z-report; the second Z-report then gets a
range already consumed. Cash movements have the same flaw (`ZReportNumber == null`, company-wide).
**Per-device sessions are the fix.**

---

## Part 2 — Proposal

### A. Session database schema

**Extend `Shift`; do not add a parallel `PosSession`.** (Decision taken 2026-08-16.) `Shift` already
carries `OpenedAt/ClosedAt/StartingCash/ActualEndingCash/Status` and full offline plumbing.

New company-DB table — **`PosDevice`**, the company-DB projection of an identity that already exists:

| Column | Notes |
|---|---|
| `Id` | company-DB PK, the FK target sessions need |
| `CompanyId` | |
| `DeviceUid` | the GUID from secure storage / `DeviceRegistry.DeviceId`; **unique per company** |
| `Name` | mirrors `pos.device.name` (`POS1`) — the numbering prefix |
| `FirstSeenAt`, `LastSeenAt` | |

This is **not** a duplicate register concept: `DeviceRegistry` lives in the control-plane DB and
cannot be joined to `PosOrder`. `PosDevice` is upserted on first session open from the same GUID, so
the two never diverge.

`Shift` gains:

| Column | Notes |
|---|---|
| `PosDeviceId` | FK → `PosDevice` |
| `Status` | widened from 0/1 to the Odoo lifecycle: `0 OPENING_CONTROL, 1 OPENED, 2 CLOSING_CONTROL, 3 CLOSED` |
| `ClosedByUserId` | distinct from `UserId` = opened by (§10 of the request) |
| `ExpectedCash`, `CashDifference` | persisted at close |
| `ClosingNote` | free text, from the Odoo closing dialog |
| `ForceClosed`, `ForceClosedByUserId`, `ForceCloseReason` | force-close audit (§15) |
| `LocalId` | client UUID — the idempotency key, mirroring every other offline entity |

New `PosSessionPaymentCount` (expected vs counted **per payment method**, per the screenshot):
`SessionId, PaymentTypeId, Expected, Counted, Difference`.

`SessionId` added to: `PosOrder`, `Document`, `Payment`, `StartingCash`.
`StartingCash` also gains `Type` semantics unchanged and keeps `ZReportNumber` until phase 7 retires it.

### B. Backend changes

1. `PosDevice` + `PosSession` (extended `Shift`) entities, repository, service.
2. `SessionService` owning the rules:
   - one session per device in `OPENING_CONTROL`/`OPENED`/`CLOSING_CONTROL`;
   - `Close` only from `CLOSING_CONTROL`; a `CLOSED` session cannot reopen;
   - reconciliation computed **server-side** (it is the authority);
   - late-arrival detection on BatchSync.
3. `SessionController`: `Open`, `EnterClosingControl`, `Close`, `ForceClose`, `GetOpenForDevice`,
   `GetSummary`.
4. `PosOrderCheckoutService` / BatchSync accept `sessionLocalId` and resolve it to a session id.
5. Z-report generation switched from the document-id range to `WHERE SessionId = @id`.

### C. Flutter / Drift changes

- `pos_devices` + extend `shifts` with the columns above; `SessionId` (as `sessionLocalId`) on
  `pos_orders`, `documents`, `payments`, `starting_cash`. **schemaVersion 57 → 58**, `addColumn`
  migration.
- `session_provider.dart`: `activeSessionProvider` (device-scoped stream), `SessionNotifier`
  (`open`, `enterClosingControl`, `close`, `forceClose`).
- A `SessionGuard` consulted by checkout, refund and cash-movement entry points.

### D. Synchronisation changes

- **No new mechanism.** `pushPendingShifts` becomes the session pusher and moves **before**
  `push:orders` in `_pushAllInner` (parent-first, exactly like products before orders).
- Children store the session's **`localId`**, never its server id — the same reason
  `pos_order_items` reference `pos_orders.localId`, and what makes an offline session stable.
- The client `localId` is the idempotency key: a re-pushed session updates, never duplicates.
- Sessions are `pending_create` (generic pusher, direct POST), **not** `pending` — they are not
  created as a side effect of BatchSync. Getting this backwards double-creates (see `sync_status.dart`).

### E. UI workflow

1. POS opens with no session → **Opening Control** screen: device name, last session, opening cash
   (pre-filled from the previous close, editable), **Open Session**.
2. Session open → normal POS. The header shows the session number.
3. Re-entering with a session open → **Continue Selling**, never a second session.
4. Cash In / Cash Out gain a session-bound reason field (reusing `cash_movement_screen`).

### F. Closing / reconciliation workflow

**Close Register** → `CLOSING_CONTROL` → the Odoo-style dialog from the supplied screenshot:

```
Payment Method        Expected      Counted      Difference
Cash                 1,653.11    [   0    ]     -1,653.11
  Opening                0.00
  + Cash in             30.00
  + Payments in cash 1,623.11
Bank                 4,137.70    [4,137.70]          0.00
Customer Account         0.00
Closing note [____________________]
[Close Session] [Discard]              [Daily Sale ⬇] [🖨]
```

Blocking checks before Close is enabled:
- unresolved **open orders** (`status = 0`) for this session — offer review/cancel, per Odoo;
- a **non-empty push queue** — the device knows about sales the server does not. Sync Status already
  surfaces this count (item 33), so the button gates on it;
- a cash difference over `Session.MaxDifference` requires manager authorisation (§18).

Then: compute → persist expected/counted/difference per method → generate the Z-report → `CLOSED`.

### G. Force-close workflow

Manager/admin only (`accessLevel == 0`), separate action, strong warning, mandatory reason, fully
audited (`ForceClosedBy`, `ForceCloseReason`, state before). A force-closed session **cannot reopen**.

### H. Late offline transactions

When BatchSync receives an order whose `sessionLocalId` maps to a `CLOSED` session:

1. **Accept it.** The sale is banked. (Item 33's invariant: a legitimate paid sale is never lost.)
2. **Keep the original `SessionId`.** Never reassign, never move to the next session.
3. Stamp `ArrivedAfterClose = true` + `ArrivedAt`.
4. Do **not** rewrite the original Z-report. Emit a **correction record** referencing it —
   `ZReportCorrection { OriginalZReportId, SessionId, LateOrderCount, LateAmount, DetectedAt }` —
   and surface it in Sync Status and on the session report.

This mirrors item 30's accepted trade: a visible correction beats a silent discrepancy, and both beat
a lost sale.

### I. Migration / backward compatibility

**The database can be wiped (dev phase, confirmed 2026-08-16),** so:
- no backfill, no synthetic default device, no null-session legacy rows;
- new columns can be `NOT NULL` where they belong;
- the Z-report boundary is *replaced* rather than run in parallel.

Still requires: **explicit approval to create an EF migration** (`CLAUDE.md` rule), and a Drift
`schemaVersion` bump with an `addColumn` migration for anyone not wiping.

### J. Test scenarios

| Area | Test |
|---|---|
| Arithmetic | 2,000 + 8,500 + 500 − 200 = 10,800 expected; 10,750 counted ⇒ −50. Per-method too |
| Lifecycle | OPENING_CONTROL → OPENED → CLOSING_CONTROL → CLOSED; closed cannot reopen |
| One-per-device | Second open on the same device is refused; a different device is allowed |
| Offline round trip | open → sell → cash move → close → push; ids remap; totals survive |
| Idempotency | Re-pushing a session updates, never duplicates (item 33 pattern) |
| Late arrival | Order for a CLOSED session is accepted, keeps its SessionId, flags a correction |
| Blocking close | Open orders and a non-empty push queue each block; the message names which |
| No-sale gate | Checkout, refund and cash movement all refused without an OPENED session |
| Regression | Open orders, discounts, taxes, refunds and existing sync are unchanged |

---

## Open decisions before Phase 2

1. **`PosDevice` table** — approve introducing it, given `DeviceRegistry` is unreachable from the
   company DB? (The alternative is storing a bare device-GUID string on the session with no FK.)
2. **EF migration approval** — required by `CLAUDE.md`.
3. **Parked order spanning a close** — order parked 23:50, session closes 00:00, customer pays 00:05.
   Block the close (Odoo's behaviour) or let the payment fall into the new session?
4. **Refunds** — require an OPENED session (per §9 of the request). Confirm this is acceptable given
   refunds are currently online-first and independent of orders.
5. **Force-close: admin only?**
6. **Max cash difference** — a new setting, and what default (0 = always require authorisation)?
