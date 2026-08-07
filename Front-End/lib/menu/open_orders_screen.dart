import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/bookings/bookings_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/sync/sync_manager.dart' show SyncManager;
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/utils/status_helper.dart';

/// Service-status code the Kitchen Display stamps on an order when staff tap
/// "DONE" (see `kitchen_display/lib/kitchen_screen.dart` → `updateStatus(.., 3)`).
/// The POS treats this as "food ready" and surfaces it as a badge + card colour.
const int kServiceStatusReady = 3;

/// Suspended/open orders streamed from the local Drift `pos_orders` table.
/// Includes both `synced` rows (have a real `serverId`) and `pending` rows
/// (saved offline, not yet pushed). Filters by `status=0` (open) — closed
/// orders from a completed checkout live with `status=1` and don't show.
///
/// Shape preserves the legacy API map contract so the screen body below
/// doesn't need touching. `id` falls back to `0` for pending rows, which routes
/// `_reopen` down the local branch.
///
/// NB both reopen paths are LOCAL-FIRST — `loadOrderById` and
/// `loadExistingOrder` each return `loadOrderFromLocal` as soon as a row exists,
/// so their API fallbacks only run for an order this device has never seen.
/// That is why [syncOpenOrdersToDrift] has to bring the line items down with the
/// header: whatever it writes IS what the cart shows.
final openOrdersProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.posOrdersTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.status.equals(0));

  return query.watch().map((rows) => rows.map((r) => <String, dynamic>{
        'id': r.serverId ?? 0,
        'localId': r.localId,
        'number': r.orderName ?? 'ORD-${r.serverId ?? "PENDING"}',
        'total': r.total ?? 0.0,
        'userId': r.userId,
        'floorPlanTableId': r.tableId,
        'warehouseId': r.warehouseId,
        'serviceStatus': r.serviceStatus,
        'syncStatus': r.syncStatus,
      }).toList());
});

/// Live count of open orders the kitchen has marked ready (serviceStatus = 3).
/// Drives the persistent badge on the POS menu + the "View open sales" nav item.
/// Streams straight from Drift, so it updates the instant a background pull
/// writes the new status — no manual refresh needed.
final readyOrdersCountProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(0);

  final query = db.select(db.posOrdersTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.status.equals(0))
    ..where((t) => t.serviceStatus.equals(kServiceStatusReady));

  return query.watch().map((rows) => rows.length);
});

/// Polls the server for open-order changes (notably the serviceStatus the KDS
/// sets when staff mark an order ready) and writes them into Drift. Kept alive
/// for the whole post-login session by a `ref.watch` in MainLayout, so the
/// "ready" badge stays live even while the cashier is on the POS menu and the
/// Open Orders screen isn't mounted. Rebuilds (new timer) when the company
/// changes; the timer is cancelled on logout via `ref.onDispose`.
final kitchenStatusWatcherProvider = Provider<void>((ref) {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return;
  final db = ref.watch(appDatabaseProvider);

  Future<void> tick() async {
    try {
      await syncOpenOrdersToDrift(
        db,
        companyId,
        // This terminal's own sourcing warehouse — the server does not store one
        // per order. Read fresh each tick so a warehouse switch is picked up.
        fallbackWarehouseId: ref.read(cartProvider.notifier).effectiveWarehouseId,
      );
    } catch (_) {
      // Offline or transient API error — local Drift state stays as-is.
    }
  }

  tick(); // immediate first pull so the badge is fresh on login
  // 10s (was 20s): the app-wide background pull of open orders — it drives the
  // "ready" badge, the Open Orders list AND floor-plan table occupancy (all Drift
  // streams that re-emit the moment this writes), so a faster tick means changes
  // made on another device (e.g. a tablet occupying a table) surface sooner.
  final timer = Timer.periodic(const Duration(seconds: 10), (_) => tick());
  ref.onDispose(timer.cancel);
});

/// Replaces an order's local LINES with the server's.
///
/// 🚨 Without this the sync below writes a header and nothing else, and an order
/// rung up on another terminal opens with an EMPTY CART while its total reads
/// correctly. Both reopen paths — `loadExistingOrder` (floor-plan tap) and
/// `loadOrderById` (Open Orders list) — short-circuit to `loadOrderFromLocal`
/// the moment a local row exists, so their API fallbacks never run and the
/// missing lines are never noticed.
///
/// Caller MUST have established the row is server-authoritative
/// (`syncStatus == 'synced'`): this deletes the local lines outright, so running
/// it against an order with unpushed local edits would destroy them.
Future<void> _pullOrderItems(
  AppDatabase db,
  int companyId,
  String orderLocalId,
  int serverId,
  int warehouseId,
  ApiClient api,
) async {
  final rows = await api.getOrderItems(companyId, serverId);

  await db.transaction(() async {
    await (db.delete(db.posOrderItemsTable)
          ..where((t) => t.orderId.equals(orderLocalId)))
        .go();

    for (var i = 0; i < rows.length; i++) {
      final it = rows[i] as Map<String, dynamic>;
      final itemServerId = (it['id'] ?? it['Id']) as int?;

      // taxesJson is read back by loadOrderFromLocal for the tax IDS only — it
      // re-derives rate/isFixed from the local taxes cache, so a stale rate
      // banked here could never contradict the cart. `amount` is what the push
      // path writes; server-authoritative rows are never pushed, so it is 0.
      final taxes = (it['taxes'] ?? it['Taxes']) as List?;
      final taxesJson = (taxes == null || taxes.isEmpty)
          ? null
          : jsonEncode([
              for (final t in taxes)
                {'id': (t['id'] ?? t['Id']) as int? ?? 0, 'amount': 0.0},
            ]);

      await db.into(db.posOrderItemsTable).insert(
            PosOrderItemsTableCompanion(
              localId: Value(
                itemServerId != null ? 'svri_$itemServerId' : '${orderLocalId}_$i',
              ),
              orderId: Value(orderLocalId),
              productId: Value((it['productId'] ?? it['ProductId']) as int? ?? 0),
              quantity:
                  Value(((it['quantity'] ?? it['Quantity']) as num?)?.toDouble() ?? 0),
              unitPrice:
                  Value(((it['price'] ?? it['Price']) as num?)?.toDouble() ?? 0),
              discount:
                  Value(((it['discount'] ?? it['Discount']) as num?)?.toDouble() ?? 0),
              discountType:
                  Value((it['discountType'] ?? it['DiscountType']) as int? ?? 0),
              taxesJson: Value(taxesJson),
              comment: Value((it['comment'] ?? it['Comment']) as String?),
              warehouseId: Value(warehouseId),
              // Pulled FROM the server — nothing to push back.
              syncStatus: const Value('synced'),
            ),
          );
    }
  });
}

/// Collapses local `pos_orders` rows that share a `serverId` down to one.
///
/// 🚨 Why this exists: [syncOpenOrdersToDrift] resolves its Case-1 match with
/// `getSingleOrNull()`, which **throws** when the query returns more than one
/// row. Its only production caller ([kitchenStatusWatcherProvider]) swallows
/// errors, so a single duplicate silently ended open-order syncing on that
/// device for good — no voids landing, no paid orders leaving the list, no KDS
/// "ready" badge. The race that created them is now prevented (see the
/// `pushInFlight` guard), but devices already carrying a duplicate need it gone.
///
/// The keeper is the row with real local provenance: a UUID localId outranks a
/// pull-materialised `svr_<id>` sentinel, because the UUID row is the one the
/// cart, discount lines and document rows all reference.
Future<void> _healDuplicateServerIds(AppDatabase db, int companyId) async {
  final rows = await (db.select(db.posOrdersTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.serverId.isNotNull()))
      .get();

  final byServerId = <int, List<PosOrdersTableData>>{};
  for (final r in rows) {
    (byServerId[r.serverId!] ??= []).add(r);
  }

  for (final entry in byServerId.entries) {
    if (entry.value.length < 2) continue;

    final group = entry.value;
    // Prefer a locally-originated row; among those, the one that actually has
    // line items (an empty sentinel carries nothing worth keeping).
    PosOrdersTableData? keeper;
    for (final r in group) {
      if (r.localId.startsWith('svr_')) continue;
      keeper ??= r;
      final itemCount = await (db.select(db.posOrderItemsTable)
            ..where((t) => t.orderId.equals(r.localId)))
          .get()
          .then((i) => i.length);
      if (itemCount > 0) {
        keeper = r;
        break;
      }
    }
    keeper ??= group.first;

    for (final r in group) {
      if (r.localId == keeper.localId) continue;
      await db.transaction(() async {
        await (db.delete(db.posOrderItemsTable)
              ..where((t) => t.orderId.equals(r.localId)))
            .go();
        await (db.delete(db.posOrdersTable)
              ..where((t) => t.localId.equals(r.localId)))
            .go();
      });
      debugPrint(
        'syncOpenOrdersToDrift: dropped duplicate order row ${r.localId} '
        '(serverId ${entry.key}); kept ${keeper.localId}.',
      );
    }
  }
}

/// Fetches open orders from the API and reconciles them into the local Drift
/// `pos_orders` table **and their line items**. Shared by the Open Orders
/// screen's manual refresh and the background [kitchenStatusWatcherProvider].
/// Three cases:
///   1. Row already exists by serverId → patch its serviceStatus/total/table
///      so KDS "ready" updates (and edits from other devices) land locally.
///   2. A local-UUID row matches by order name → stamp its serverId.
///   3. Brand-new server order → insert with a `svr_<id>` sentinel localId.
/// Finally, sentinel rows for orders no longer open on the server are removed.
/// [api] exists purely as a test seam — production callers use the default.
/// [fallbackWarehouseId] is the warehouse THIS terminal should source a
/// server-originated order from.
///
/// 🚨 It is required because **`PosOrderDto` carries no warehouse at all** — and
/// neither does the `PosOrder` table; warehouse is a sourcing decision made by
/// the till doing the work, never persisted with the order. This code read
/// `o['warehouseId'] ?? 1`, so every open order pulled from another terminal
/// landed on **warehouse 1** — an id company 25 does not even own (it has 17 and
/// 20). Editing such an order then failed outright: the save posts to
/// `/PosOrderItem/BulkAdd` with `warehouseId: 1`, the server finds no `Stock`
/// rows for that warehouse, and rejects every line with *"Product X is out of
/// stock in this warehouse"*. Two devices, and the second one simply could not
/// save. Pass the device's own `effectiveWarehouseId`.
Future<void> syncOpenOrdersToDrift(
  AppDatabase db,
  int companyId, {
  required int fallbackWarehouseId,
  ApiClient? api,
}) async {
  // 🚨 Never reconcile while SyncManager's push phase is running. Both write
  // `pos_orders`, and the push creates a server order BEFORE it can stamp the
  // serverId back onto the local row (`/PosOrder/Create` → `setServerId`). A
  // poll landing inside that window sees an order it can't match locally and
  // materialises a SECOND row for it (Case 3, `svr_<id>`) — two local rows for
  // one order, on one table. That is the "saving an old order created a new one
  // with the same table id" bug, and it also poisons every later poll (see the
  // duplicate heal below). Skipping is free: the next tick is 10s away.
  if (SyncManager.pushInFlight) return;

  final client = api ?? ApiClient();
  final orders = await client.getAllPosOrders(companyId);
  final now = DateTime.now().toUtc();

  // Heal any duplicate serverId groups left by an earlier build's race before
  // touching anything else — `getSingleOrNull` below THROWS on a duplicate, and
  // the only caller catches silently, so one duplicate used to kill this
  // device's open-order sync permanently (voids never disappeared, paid orders
  // never left the list). Keep the row carrying local work; drop the sentinel.
  await _healDuplicateServerIds(db, companyId);

  final openServerIds = <int>{};

  for (final o in orders) {
    final id = (o['id'] ?? o['Id']) as int? ?? 0;
    if (id == 0) continue;
    final status = (o['status'] ?? o['Status']) as int? ?? 0;
    if (status != 0) continue; // only open orders
    openServerIds.add(id);

    final serviceStatus =
        (o['serviceStatus'] ?? o['ServiceStatus']) as int? ?? 0;
    final total = ((o['total'] ?? o['Total']) as num?)?.toDouble();
    final tableId = (o['floorPlanTableId'] ?? o['FloorPlanTableId']) as int?;
    final serverName =
        (o['number'] ?? o['Number'] ?? o['orderNumber']) as String?;
    // PosOrderDto carries the customer (Id + Name). Without banking the id here
    // an order rung up against a customer on one terminal reopened as Walk-in on
    // every other one: loadOrderFromLocal restores the customer from
    // `pos_orders.customerId`, and this pull is the only thing that ever writes
    // that column for an order this device did not create.
    final customerId = (o['customerId'] ?? o['CustomerId']) as int?;
    // The WHOLE-ORDER discount. Case 3 used to hardcode 0 and Case 1 never
    // reconciled it, so a cart-level discount applied on one till vanished on
    // every other one — and worse, re-saving there pushed the 0 back, wiping the
    // discount on the till that granted it.
    final discount = ((o['discount'] ?? o['Discount']) as num?)?.toDouble() ?? 0;
    final discountType = (o['discountType'] ?? o['DiscountType']) as int? ?? 0;
    final serviceType = (o['serviceType'] ?? o['ServiceType']) as int? ?? 0;

    // Line-content change detectors (PosOrderDto). All absent on an API build
    // that predates them — left null, the checks below simply skip and the
    // total-only behaviour applies.
    final serverItemCount = (o['itemCount'] ?? o['ItemCount']) as int?;
    final rawStamp = (o['itemsLastChanged'] ?? o['ItemsLastChanged']) as String?;
    final itemsLastChanged =
        rawStamp == null ? null : DateTime.tryParse(rawStamp)?.toUtc();
    // 🚨 The detector that actually works for a SAME-DAY edit. `ItemsLastChanged`
    // is MAX(PosOrderItem.DateCreated), and that column is SQL type `date` — the
    // time is truncated on write, giving it one-DAY resolution. A same-price
    // swap on another till moves neither Total nor ItemCount, and its stamp
    // compares equal, so it was invisible for the rest of the day. MAX(Id)
    // always advances: a swap re-inserts, and IDENTITY never reissues.
    final lastItemId = (o['lastItemId'] ?? o['LastItemId']) as int?;

    // Case 1: Already in Drift matched by serverId — patch the volatile fields
    // (serviceStatus is the whole point: that's how a KDS "ready" reaches POS).
    //
    // `.get().firstOrNull` rather than `getSingleOrNull()`: the latter THROWS on
    // a duplicate, and this function's production caller swallows errors, so one
    // duplicate row used to stop open-order sync on the device forever. Dupes
    // are prevented (the pushInFlight guard) and healed (_healDuplicateServerIds
    // above), but this must never be the thing that takes the poll down again.
    final existingByServerId = await (db.select(db.posOrdersTable)
          ..where((t) => t.serverId.equals(id))
          ..limit(1))
        .get()
        .then((r) => r.firstOrNull);
    if (existingByServerId != null) {
      // A row with unpushed local work owns its own header. The server's copy
      // predates that work, so writing total/tableId back over it reverted the
      // cashier's just-saved edit (and the push then sent the reverted total).
      // serviceStatus is the exception — it is the KDS "ready" signal and is
      // only ever set server-side.
      final locallyOwned = existingByServerId.syncStatus != 'synced';
      // Don't let a server pull DOWNGRADE a locally-set "ready" (3). The KDS
      // marked it done over the LAN; the backend may not have caught up yet
      // (offline, or mid-flight). Keep it at 3 until the order leaves the open
      // list (status != 0 → it won't be returned here at all).
      final keepReady =
          existingByServerId.serviceStatus == kServiceStatusReady &&
              serviceStatus < kServiceStatusReady;
      final effectiveStatus =
          keepReady ? kServiceStatusReady : serviceStatus;
      final totalChanged =
          !locallyOwned && existingByServerId.total != total;
      final tableChanged =
          !locallyOwned && existingByServerId.tableId != tableId;
      // Only adopt the server's customer on a row with nothing unpushed. On a
      // 'pending' row the cashier may have just picked a customer that this
      // pull has not seen yet — taking the server's (older) value would wipe it.
      final adoptCustomer =
          !locallyOwned && existingByServerId.customerId != customerId;
      // The rest of the header. These were never reconciled at all, so an edit
      // made on another till stayed invisible here — and because this device
      // then pushed its own stale copy back on the next save, the two terminals
      // could ping-pong an order between two different states indefinitely.
      final discountChanged = !locallyOwned &&
          (existingByServerId.discount != discount ||
              existingByServerId.discountType != discountType);
      final serviceTypeChanged =
          !locallyOwned && existingByServerId.serviceType != serviceType;
      final nameChanged = !locallyOwned &&
          serverName != null &&
          serverName.isNotEmpty &&
          existingByServerId.orderName != serverName;
      if (existingByServerId.serviceStatus != effectiveStatus ||
          totalChanged ||
          adoptCustomer ||
          tableChanged ||
          discountChanged ||
          serviceTypeChanged ||
          nameChanged) {
        await (db.update(db.posOrdersTable)
              ..where((t) => t.localId.equals(existingByServerId.localId)))
            .write(PosOrdersTableCompanion(
          serviceStatus: Value(effectiveStatus),
          total: totalChanged ? Value(total) : const Value.absent(),
          tableId: tableChanged ? Value(tableId) : const Value.absent(),
          customerId:
              adoptCustomer ? Value(customerId) : const Value.absent(),
          discount: discountChanged ? Value(discount) : const Value.absent(),
          discountType:
              discountChanged ? Value(discountType) : const Value.absent(),
          serviceType:
              serviceTypeChanged ? Value(serviceType) : const Value.absent(),
          orderName: nameChanged ? Value(serverName) : const Value.absent(),
          lastModified: Value(now),
        ));
      }
      // Re-pull the lines when this row is server-authoritative AND something
      // says its CONTENTS moved. Gated rather than unconditional: this poll runs
      // every 20s and getOrderItems is one request per open order.
      //
      // Three signals, because none alone is sufficient:
      //   • no local lines  → the empty-cart bug (order came from another device)
      //   • total changed   → a quantity or price edit
      //   • itemCount /     → an add, a remove, or a swap for a product at the
      //     itemsLastChanged   SAME price, which moves neither total nor count.
      // The last two come from PosOrderDto aggregates; an API that predates them
      // sends itemCount 0 / null, which falls back to the first two checks.
      //
      // 'synced' is load-bearing — a row with unpushed local edits must keep its
      // own lines, per the pull/insertOrReplace rule in handoff §3.
      if (existingByServerId.syncStatus == 'synced') {
        final localItems = await (db.select(db.posOrderItemsTable)
              ..where((t) => t.orderId.equals(existingByServerId.localId)))
            .get();
        final localItemCount = localItems.length;
        final countChanged =
            serverItemCount != null && serverItemCount != localItemCount;
        // Highest server item id this device currently holds. `_pullOrderItems`
        // replaces the line set wholesale and names every pulled row
        // `svri_<serverItemId>`, so this is EXACTLY the server's MAX(Id) as of
        // the last pull — no extra column needed to remember it.
        //
        // `!=` rather than `<`: a pure deletion can LOWER the server's maximum,
        // and that is a change too. A row whose localId isn't `svri_`-shaped
        // (the server sent no id) yields null and forces a refetch, which is the
        // safe direction.
        int? localMaxItemId = 0;
        for (final it in localItems) {
          if (!it.localId.startsWith('svri_')) {
            localMaxItemId = null;
            break;
          }
          final parsed = int.tryParse(it.localId.substring(5));
          if (parsed == null) {
            localMaxItemId = null;
            break;
          }
          if (parsed > localMaxItemId!) localMaxItemId = parsed;
        }
        final lastItemIdChanged =
            lastItemId != null && localMaxItemId != lastItemId;
        // Compare INSTANTS, not DateTime objects. Dart's `==` also requires the
        // same isUtc flag, and Drift reads a dateTime() column back as LOCAL
        // while this value is parsed as UTC — so `!=` was true forever and every
        // poll refetched every open order's lines. Caught by the "settles" leg of
        // the swap test.
        final stampChanged = itemsLastChanged != null &&
            existingByServerId.itemsLastChanged?.millisecondsSinceEpoch !=
                itemsLastChanged.millisecondsSinceEpoch;
        // Persist the stamp only AFTER the comparison above has consumed the old
        // value, and only for a synced row. Writing it earlier would be correct
        // today (existingByServerId is an immutable snapshot) but silently breaks
        // the moment anyone re-reads the row in between.
        if (itemsLastChanged != null && stampChanged) {
          await (db.update(db.posOrdersTable)
                ..where((t) => t.localId.equals(existingByServerId.localId)))
              .write(PosOrdersTableCompanion(
            itemsLastChanged: Value(itemsLastChanged),
          ));
        }

        if (localItemCount == 0 ||
            totalChanged ||
            countChanged ||
            lastItemIdChanged ||
            stampChanged) {
          await _pullOrderItems(
            db,
            companyId,
            existingByServerId.localId,
            id,
            // The server stores no warehouse per order, so re-source the lines
            // from whatever this row already resolved to rather than trusting a
            // value that never came from the server.
            existingByServerId.warehouseId,
            client,
          );
        }
      }
      continue;
    }

    // Case 2: A local UUID row with no serverId exists for the same order
    // (created here, already pushed). Stamp the serverId on it so Case 3 below
    // doesn't materialise a SECOND row for the same order.
    //
    // 🚨 This used to require `syncStatus == 'synced'` — which an offline-created
    // row NEVER is until its push completes. So the one shape this case exists
    // to catch could not match it, and every such order fell through to Case 3
    // and got a twin `svr_<id>` row on the same table. Match on "no serverId yet"
    // instead; that, not the sync status, is what identifies an unadopted row.
    //
    // Scoped by company AND table as well as order name: two devices ringing up
    // offline can both mint "ORD- #001" from their own daily counter, and
    // adopting the wrong one would hand this device another terminal's order.
    if (serverName != null && serverName.isNotEmpty) {
      final candidates = await (db.select(db.posOrdersTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.orderName.equals(serverName))
            ..where((t) => t.status.equals(0))
            ..where((t) => t.serverId.isNull()))
          .get();
      final existingByName = candidates
              .where((r) => r.tableId == tableId)
              .firstOrNull ??
          (candidates.length == 1 ? candidates.first : null);
      if (existingByName != null) {
        await (db.update(db.posOrdersTable)
              ..where((t) => t.localId.equals(existingByName.localId)))
            .write(PosOrdersTableCompanion(
          serverId: Value(id),
          serviceStatus: Value(serviceStatus),
        ));
        continue;
      }
    }

    // Case 3: Genuine server-originated order not yet in local Drift —
    // insert with a deterministic sentinel localId.
    //
    // The warehouse is THIS terminal's, not the server's: neither `PosOrder` nor
    // `PosOrderDto` carries one. The old `?? 1` produced a warehouse the company
    // may not own, and every later save of the order was then rejected as out of
    // stock.
    final warehouseId = fallbackWarehouseId;
    // Restore the booking link locally. `PosOrderDto` cannot carry it — the
    // relation lives on `Booking.PosOrderId` — so without this a reservation's
    // order opened on a second till has no booking attached, and paying it never
    // completes the reservation.
    final bookingId = await db.bookingIdForPosOrder(id);
    await db.into(db.posOrdersTable).insertOnConflictUpdate(
      PosOrdersTableCompanion(
        localId: Value('svr_$id'),
        serverId: Value(id),
        companyId: Value(companyId),
        userId: Value((o['userId'] ?? o['UserId']) as int? ?? 0),
        tableId: Value(tableId),
        customerId: Value(customerId),
        serviceType: Value(serviceType),
        serviceStatus: Value(serviceStatus),
        orderName: Value(serverName),
        bookingId: Value(bookingId),
        openedAt: Value(now),
        status: const Value(0),
        total: Value(total),
        // Was hardcoded 0 — a whole-order discount granted on another till was
        // silently dropped here, and re-saving pushed the 0 back over it.
        discount: Value(discount),
        discountType: Value(discountType),
        warehouseId: Value(warehouseId),
        syncStatus: const Value('synced'),
        lastModified: Value(now),
        itemsLastChanged: Value(itemsLastChanged),
      ),
    );
    // The header alone opens as an empty cart — this order came from another
    // terminal, so its lines only exist server-side.
    await _pullOrderItems(db, companyId, 'svr_$id', id, warehouseId, client);
  }

  // Retire local rows for orders the server no longer reports as open — the
  // order was paid, voided or deleted on ANOTHER terminal.
  //
  // 🚨 This used to be gated on `localId.startsWith('svr_')`, i.e. only orders
  // this device had never created itself. That is precisely the wrong half: an
  // order rung up HERE gets a UUID localId, then a serverId once it pushes, and
  // when another terminal paid or voided it the server stopped returning it —
  // but the `svr_` test skipped it, so it sat in this device's Open Orders list
  // (and kept its table painted occupied) forever. The `svr_` prefix says where
  // the row came from; it says nothing about whether the order is still open.
  //
  // The real safety condition is `syncStatus == 'synced'`: a row with unpushed
  // local work must never be retired on the say-so of a server that has not
  // seen that work yet. Rows with no serverId are likewise untouchable — they
  // were created offline and the server cannot be expected to know them.
  final localOpenRows = await (db.select(db.posOrdersTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.status.equals(0)))
      .get();
  for (final row in localOpenRows) {
    if (row.serverId == null) continue; // never pushed — server can't judge it
    if (openServerIds.contains(row.serverId!)) continue; // still open
    if (row.syncStatus != 'synced') continue; // unpushed local edits win

    if (row.localId.startsWith('svr_')) {
      // Materialised purely by this pull — nothing local to preserve.
      await (db.delete(db.posOrdersTable)
            ..where((t) => t.localId.equals(row.localId)))
          .go();
    } else {
      // Locally-originated: keep the row (reports, refunds and the sales
      // history all reach back into it) but close it, so it leaves the open
      // list and releases its table. Deleting it here would orphan its items.
      await (db.update(db.posOrdersTable)
            ..where((t) => t.localId.equals(row.localId)))
          .write(PosOrdersTableCompanion(
        status: const Value(1),
        closedAt: Value(now),
        lastModified: Value(now),
      ));
    }
  }
}

class OpenOrdersScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMenuPressed;

  const OpenOrdersScreen({super.key, this.onMenuPressed});

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  bool _syncing = false;

  // Free-text filter applied to the order number/name. Empty = show everything.
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pullFromServer());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches open orders from the API and reconciles them into Drift (shared
  /// with the background watcher) so orders created on other devices — and
  /// serviceStatus changes from the KDS — appear in the list.
  Future<void> _pullFromServer() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    if (mounted) setState(() => _syncing = true);

    try {
      // Full push+pull first (documents/voids, products, …) so a void or edit
      // made on another device lands, then the open-orders pull for live status.
      await ref.read(syncStateProvider.notifier).sync(manual: true);
      await syncOpenOrdersToDrift(
        ref.read(appDatabaseProvider),
        company.id,
        fallbackWarehouseId:
            ref.read(cartProvider.notifier).effectiveWarehouseId,
      );
    } catch (_) {
      // Offline or API error — Drift stream already shows local orders.
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        ref.invalidate(openOrdersProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(openOrdersProvider);
    final allUsers = ref.watch(allUsersProvider).value ?? [];
    final allRooms = ref.watch(allRoomsProvider).value ?? [];
    final sym = ref.watch(currencySymbolProvider);
    // Watch settings so the cards recolour if the status palette is edited.
    ref.watch(appSettingsProvider);
    final customStatuses =
        ref.read(appSettingsProvider.notifier).customServiceStatuses;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: Text(AppLocalizations.of(context).openOrders),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const PhosphorIcon(PhosphorIconsRegular.arrowClockwise),
              tooltip: AppLocalizations.of(context).refresh,
              onPressed: _pullFromServer,
            ),
        ],
      ),
      body: Column(
        children: [
          // Show the search bar whenever there's something to search (or a query
          // is active) — keeps the empty-state screen uncluttered otherwise.
          if ((ordersAsync.value?.isNotEmpty ?? false) || _search.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchByOrderStaffTable,
                  prefixIcon: const PhosphorIcon(
                      PhosphorIconsRegular.magnifyingGlass, size: 20),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const PhosphorIcon(PhosphorIconsRegular.x,
                              size: 18),
                          tooltip: AppLocalizations.of(context).actionReset,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ordersAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                separatorBuilder: (_, __) => const Gap(10),
                itemBuilder: (_, __) => const _SkeletonOrderCard(),
              ),
              error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.warning,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
              const Gap(12),
              Text(AppLocalizations.of(context).failedToLoadOrders,
                  style: Theme.of(context).textTheme.titleMedium),
              const Gap(4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ),
              const Gap(16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(openOrdersProvider),
                icon: const PhosphorIcon(PhosphorIconsRegular.arrowClockwise,
                    size: 18),
                label: Text(AppLocalizations.of(context).actionRetry),
              ),
            ],
          ),
        ),
        data: (orders) {
          // Filter by order number/name, staff name or table name
          // (case-insensitive). Done here rather than in the provider so typing
          // never re-queries Drift. Staff/table names are resolved the same way
          // the card does, from the already-watched allUsers/allRooms lists.
          final q = _search.trim().toLowerCase();
          String staffNameFor(dynamic id) => id == null
              ? ''
              : (allUsers
                      .where((u) => u.id == id)
                      .map((u) => u.displayName)
                      .firstOrNull ??
                  '');
          String tableNameFor(dynamic id) => id == null
              ? ''
              : (allRooms.where((t) => t.id == id).map((t) => t.name).firstOrNull ??
                  '');
          final filtered = q.isEmpty
              ? orders
              : orders.where((o) {
                  final number = ((o['number'] ?? '') as String).toLowerCase();
                  final staff =
                      staffNameFor(o['userId'] ?? o['UserId']).toLowerCase();
                  final table = tableNameFor(
                          o['floorPlanTableId'] ?? o['FloorPlanTableId'])
                      .toLowerCase();
                  return number.contains(q) ||
                      staff.contains(q) ||
                      table.contains(q);
                }).toList();

          if (filtered.isEmpty) {
            final searching = q.isNotEmpty;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    searching
                        ? PhosphorIconsRegular.magnifyingGlass
                        : PhosphorIconsRegular.receipt,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.25),
                  ),
                  const Gap(16),
                  Text(
                    searching
                        ? AppLocalizations.of(context)
                            .noOrdersMatchQuery(_search.trim())
                        : AppLocalizations.of(context).noOpenOrders,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Gap(10),
            itemBuilder: (context, i) {
              final o = filtered[i];
              final orderId = (o['id'] ?? o['Id']) as int;
              final orderNumber =
                  (o['number'] ?? o['Number'] ?? 'ORD-$orderId') as String;
              final total =
                  (o['total'] ?? o['Total'] ?? 0.0 as num).toDouble();
              final staffId = o['userId'] ?? o['UserId'];
              final tableId = o['floorPlanTableId'] ?? o['FloorPlanTableId'];
              final warehouseId =
                  ((o['warehouseId'] ?? o['WarehouseId']) as num?)?.toInt() ??
                      ref.read(selectedWarehouseProvider)?.id ??
                      0;

              final staffName = staffId != null
                  ? allUsers
                      .where((u) => u.id == staffId)
                      .map((u) => u.displayName)
                      .firstOrNull
                  : null;
              final tableName = tableId != null
                  ? allRooms
                      .where((t) => t.id == tableId)
                      .map((t) => t.name)
                      .firstOrNull
                  : null;

              final serviceStatus = (o['serviceStatus'] as int?) ?? 0;
              final matched = customStatuses
                  .where((s) => s.id == serviceStatus)
                  .firstOrNull;
              final statusColor =
                  matched?.color ?? ServiceStatusHelper.getColor(serviceStatus);
              final statusLabel =
                  matched?.name ?? ServiceStatusHelper.getLabel(serviceStatus);

              return _OpenOrderCard(
                orderId: orderId,
                localId: (o['localId'] ?? '') as String,
                orderNumber: orderNumber,
                total: total,
                staffName: staffName,
                tableName: tableName,
                warehouseId: warehouseId,
                sym: sym,
                serviceStatus: serviceStatus,
                statusColor: statusColor,
                statusLabel: statusLabel,
              );
            },
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonOrderCard extends StatelessWidget {
  const _SkeletonOrderCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shimmer = cs.onSurface.withValues(alpha: 0.08);

    Widget block(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return Card(
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  block(120, 15),
                  const Gap(8),
                  block(80, 12),
                ],
              ),
            ),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                block(64, 15),
                const Gap(8),
                block(36, 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenOrderCard extends ConsumerStatefulWidget {
  final int orderId;
  final String localId;   // Drift localId — used when orderId == 0 (not yet synced)
  final String orderNumber;
  final double total;
  final String? staffName;
  final String? tableName;
  final int warehouseId;
  final String sym;
  final int serviceStatus;
  final Color statusColor;
  final String statusLabel;

  const _OpenOrderCard({
    required this.orderId,
    required this.localId,
    required this.orderNumber,
    required this.total,
    required this.staffName,
    required this.tableName,
    required this.warehouseId,
    required this.sym,
    required this.serviceStatus,
    required this.statusColor,
    required this.statusLabel,
  });

  @override
  ConsumerState<_OpenOrderCard> createState() => _OpenOrderCardState();
}

class _OpenOrderCardState extends ConsumerState<_OpenOrderCard> {
  bool _loading = false;

  Future<void> _reopen() async {
    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;
    setState(() => _loading = true);
    try {
      bool ok;

      if (widget.orderId == 0) {
        // Local-only order (not yet synced) — load directly from Drift
        // so we never hit the API with id=0 and get a 404.
        ok = await ref
            .read(cartProvider.notifier)
            .loadOrderFromLocal(widget.localId);
      } else {
        // Server-synced order — load via API.
        ok = await ref.read(cartProvider.notifier).loadOrderById(
              ApiClient(),
              company.id,
              widget.orderId,
              widget.warehouseId,
            );
      }

      if (!mounted) return;
      if (ok) {
        // OpenOrdersScreen is a tab inside MainLayout — switch tabs reactively
        // instead of rebuilding MainLayout (which would re-fire its startup
        // cash-in hook). Just point the shared nav index at the POS Menu.
        ref.read(mainNavigationIndexProvider.notifier).state = 0;
      } else {
        showAppSnackbar(
            context, ref, AppLocalizations.of(context).failedToLoadOrder,
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref,
            AppLocalizations.of(context).errorWithMessage(e.toString()),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isReady = widget.serviceStatus == kServiceStatusReady;
    final statusColor = widget.statusColor;

    return Card(
      elevation: 0,
      // Tint the whole card when the kitchen has marked it ready so it stands
      // out in the list; otherwise keep the neutral surface.
      color: isReady
          ? Color.alphaBlend(
              statusColor.withValues(alpha: 0.10), cs.surfaceContainer)
          : cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isReady
              ? statusColor.withValues(alpha: 0.8)
              : statusColor.withValues(alpha: 0.35),
          width: isReady ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _loading ? null : _reopen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Leading status stripe — quick visual scan of order state.
              Container(
                width: 5,
                height: 52,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Leading icon badge, tinted with the status colour.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: statusColor,
                        ),
                      )
                    : Center(
                        child: PhosphorIcon(
                          isReady
                              ? PhosphorIconsRegular.bellRinging
                              : PhosphorIconsRegular.receipt,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
              ),
              const Gap(16),
              // Order info — Expanded prevents right-side overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.orderNumber,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.tableName != null ||
                        widget.staffName != null) ...[
                      const Gap(6),
                      // Inner Row also guarded with Flexible on text nodes
                      Row(
                        children: [
                          if (widget.tableName != null) ...[
                            PhosphorIcon(
                              PhosphorIconsRegular.armchair,
                              size: 13,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                            const Gap(4),
                            Flexible(
                              child: Text(
                                widget.tableName!,
                                style: tt.bodySmall?.copyWith(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.55),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Gap(12),
                          ],
                          if (widget.staffName != null) ...[
                            PhosphorIcon(
                              PhosphorIconsRegular.userCircle,
                              size: 13,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                            const Gap(4),
                            Flexible(
                              child: Text(
                                widget.staffName!,
                                style: tt.bodySmall?.copyWith(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.55),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(12),
              // Trailing total + caret
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${widget.total.toStringAsFixed(2)} ${widget.sym}',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Gap(4),
                  // Status pill — coloured by service status (e.g. green "Ready
                  // to Pay" once the kitchen marks the order done).
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.statusLabel,
                          style: tt.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Gap(2),
                        PhosphorIcon(
                          PhosphorIconsRegular.caretRight,
                          size: 12,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
