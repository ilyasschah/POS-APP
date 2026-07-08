import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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
/// doesn't need touching. `id` falls back to `0` for pending rows; tapping
/// one will fail in `_reopen` (still calls `loadOrderById` on the server)
/// — acceptable V1: pending orders are visible in the list, reopen needs
/// a sync to land first.
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
      await syncOpenOrdersToDrift(db, companyId);
    } catch (_) {
      // Offline or transient API error — local Drift state stays as-is.
    }
  }

  tick(); // immediate first pull so the badge is fresh on login
  final timer = Timer.periodic(const Duration(seconds: 20), (_) => tick());
  ref.onDispose(timer.cancel);
});

/// Fetches open orders from the API and reconciles them into the local Drift
/// `pos_orders` table. Shared by the Open Orders screen's manual refresh and
/// the background [kitchenStatusWatcherProvider]. Three cases:
///   1. Row already exists by serverId → patch its serviceStatus/total/table
///      so KDS "ready" updates (and edits from other devices) land locally.
///   2. A local-UUID row matches by order name → stamp its serverId.
///   3. Brand-new server order → insert with a `svr_<id>` sentinel localId.
/// Finally, sentinel rows for orders no longer open on the server are removed.
Future<void> syncOpenOrdersToDrift(AppDatabase db, int companyId) async {
  final orders = await ApiClient().getAllPosOrders(companyId);
  final now = DateTime.now().toUtc();

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

    // Case 1: Already in Drift matched by serverId — patch the volatile fields
    // (serviceStatus is the whole point: that's how a KDS "ready" reaches POS).
    final existingByServerId = await (db.select(db.posOrdersTable)
          ..where((t) => t.serverId.equals(id)))
        .getSingleOrNull();
    if (existingByServerId != null) {
      // Don't let a server pull DOWNGRADE a locally-set "ready" (3). The KDS
      // marked it done over the LAN; the backend may not have caught up yet
      // (offline, or mid-flight). Keep it at 3 until the order leaves the open
      // list (status != 0 → it won't be returned here at all).
      final keepReady =
          existingByServerId.serviceStatus == kServiceStatusReady &&
              serviceStatus < kServiceStatusReady;
      final effectiveStatus =
          keepReady ? kServiceStatusReady : serviceStatus;
      if (existingByServerId.serviceStatus != effectiveStatus ||
          existingByServerId.total != total ||
          existingByServerId.tableId != tableId) {
        await (db.update(db.posOrdersTable)
              ..where((t) => t.localId.equals(existingByServerId.localId)))
            .write(PosOrdersTableCompanion(
          serviceStatus: Value(effectiveStatus),
          total: Value(total),
          tableId: Value(tableId),
          lastModified: Value(now),
        ));
      }
      continue;
    }

    // Case 2: A local UUID row with no serverId exists for the same order name
    // (created offline, just pushed by BatchSync). Stamp the serverId on it so
    // it won't appear as a duplicate after the next pull.
    if (serverName != null && serverName.isNotEmpty) {
      final existingByName = await (db.select(db.posOrdersTable)
            ..where((t) => t.orderName.equals(serverName))
            ..where((t) => t.status.equals(0))
            ..where((t) => t.syncStatus.equals('synced'))
            ..limit(1))
          .getSingleOrNull();
      if (existingByName != null && existingByName.serverId == null) {
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
    await db.into(db.posOrdersTable).insertOnConflictUpdate(
      PosOrdersTableCompanion(
        localId: Value('svr_$id'),
        serverId: Value(id),
        companyId: Value(companyId),
        userId: Value((o['userId'] ?? o['UserId']) as int? ?? 0),
        tableId: Value(tableId),
        serviceType: Value((o['serviceType'] ?? o['ServiceType']) as int? ?? 0),
        serviceStatus: Value(serviceStatus),
        orderName: Value(serverName),
        openedAt: Value(now),
        status: const Value(0),
        total: Value(total),
        discount: const Value(0),
        warehouseId: Value((o['warehouseId'] ?? o['WarehouseId']) as int? ?? 1),
        syncStatus: const Value('synced'),
        lastModified: Value(now),
      ),
    );
  }

  // Remove sentinel rows for orders that are no longer open on the server.
  final svrRows = await (db.select(db.posOrdersTable)
        ..where((t) => t.companyId.equals(companyId))
        ..where((t) => t.status.equals(0)))
      .get();
  for (final row in svrRows) {
    if (row.localId.startsWith('svr_') &&
        row.serverId != null &&
        !openServerIds.contains(row.serverId!)) {
      await (db.delete(db.posOrdersTable)
            ..where((t) => t.localId.equals(row.localId)))
          .go();
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
      await syncOpenOrdersToDrift(ref.read(appDatabaseProvider), company.id);
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
        title: const Text('Open Orders'),
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
              tooltip: 'Refresh',
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
                  hintText: 'Search by order, staff or table',
                  prefixIcon: const PhosphorIcon(
                      PhosphorIconsRegular.magnifyingGlass, size: 20),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const PhosphorIcon(PhosphorIconsRegular.x,
                              size: 18),
                          tooltip: 'Clear',
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
              Text('Failed to load orders',
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
                label: const Text('Retry'),
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
                        ? 'No orders match "${_search.trim()}"'
                        : 'No open orders',
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
        showAppSnackbar(context, ref, 'Failed to load order.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, ref, 'Error: $e', isError: true);
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
