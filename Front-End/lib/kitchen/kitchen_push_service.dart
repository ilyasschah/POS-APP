import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/kitchen/printer_group_model.dart';

/// Port the paired Kitchen Display tablets listen on.
const int kKdsPort = 9090;

/// Port THIS POS listens on for "order ready" callbacks from a paired KDS.
/// Sent inside the pairing handshake so the KDS knows where to call back.
const int kPosListenerPort = 9091;

/// Orders at this serviceStatus (or higher) are "ready/done" and are excluded
/// from kitchen pushes — mirrors `kServiceStatusReady` on the POS open-orders
/// side and the KDS DONE action.
const int _kServiceStatusReady = 3;

/// Pushes order data to paired Kitchen Display tablets over the LAN and sends
/// the pairing handshake. The KDS no longer talks to the backend at all — this
/// service is the only thing that feeds it, so it works fully offline (any
/// device on the same Wi-Fi) and online alike.
class KitchenSyncService {
  KitchenSyncService(this.ref);
  final Ref ref;

  List<String> _ips() {
    final raw = ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayIps];
    return (raw ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Deterministic per-company pairing token — enough for V1 mutual
  /// identification (both sides hold the same value; the KDS echoes it back on
  /// /order-ready). Not a security boundary; the LAN is the trust boundary.
  String _token(int companyId) => 'pos-company-$companyId';

  /// Rebuilds the kitchen-order snapshot from local Drift and pushes it to every
  /// paired KDS (full-replace semantics, so adds/edits/removals all sync). Each
  /// display only receives the items whose product category belongs to one of
  /// its assigned printer groups — so the food station never sees the drinks.
  /// A display with no assigned group receives everything (single-station).
  /// Best-effort and fire-and-forget per device — an offline/unreachable tablet
  /// never blocks the POS.
  Future<void> push() async {
    final ips = _ips();
    if (ips.isEmpty) return;
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return;

    try {
      final settings = ref.read(appSettingsProvider);
      final printerGroups =
          PrinterGroup.listFromJson(settings[SettingKeys.kitchenPrinterGroups]);
      final displayGroups =
          parseDisplayGroups(settings[SettingKeys.kitchenDisplayGroups]);

      final orders = await _loadKitchenOrders(companyId);

      for (final ip in ips) {
        final assignedIds = displayGroups[ip] ?? const <int>[];
        // null ⇒ no filter (receive all). Otherwise the union of category ids
        // across this display's assigned printer groups.
        Set<int>? allowed;
        if (assignedIds.isNotEmpty) {
          allowed = {
            for (final g in printerGroups)
              if (assignedIds.contains(g.id)) ...g.productGroupIds,
          };
        }
        final payload = _serializeForDisplay(orders, allowed);
        // Always POST (even an empty list) so the display clears routed-away
        // or completed orders under full-replace semantics.
        _post(ip, kKdsPort, '/orders', jsonEncode({'orders': payload}));
      }
    } catch (e) {
      debugPrint('[KDS] push failed — $e');
    }
  }

  /// Sends the pairing handshake to a single KDS IP, then immediately pushes the
  /// current orders so the freshly-bound tablet is populated.
  Future<void> pair(String ip) async {
    final company = ref.read(selectedCompanyProvider);
    final companyId = company?.id ?? 0;
    final selfIp = await _selfIp();

    final body = jsonEncode({
      'companyId': companyId,
      'token': _token(companyId),
      'posName': company?.name ?? 'POS',
      'posIp': selfIp,
      'posPort': kPosListenerPort,
    });
    _post(ip, kKdsPort, '/pair', body);
    await push();
  }

  /// Tells a KDS to forget this POS (returns it to the onboarding screen).
  void unpair(String ip) => _post(ip, kKdsPort, '/unpair', '{}');

  // ── Payload construction ──────────────────────────────────────────────────

  /// Loads open kitchen orders from Drift into an intermediate shape that keeps
  /// each item's product category id, so [_serializeForDisplay] can filter per
  /// display without re-querying.
  Future<List<_KOrder>> _loadKitchenOrders(int companyId) async {
    final db = ref.read(appDatabaseProvider);

    final orders = await (db.select(db.posOrdersTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.status.equals(0))
          ..where((t) => t.serviceStatus.isSmallerThanValue(_kServiceStatusReady)))
        .get();
    if (orders.isEmpty) return const [];

    // Name + category lookups — one query each, then resolve in memory.
    final products = await (db.select(db.productsTable)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    final productNames = {for (final p in products) p.id: p.name};
    final productGroupOf = {for (final p in products) p.id: p.productGroupId};

    final tables = await (db.select(db.floorPlanTablesTable)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    final tableNames = {for (final t in tables) t.id: t.name};

    final result = <_KOrder>[];
    for (final o in orders) {
      final items = await (db.select(db.posOrderItemsTable)
            ..where((t) => t.orderId.equals(o.localId)))
          .get();

      result.add(_KOrder(
        meta: {
          // The POS's own reference; the KDS echoes it back on "ready".
          'orderRef': o.serverId?.toString() ?? o.localId,
          'number': o.orderName ?? 'ORD',
          'tableName': o.tableId != null ? tableNames[o.tableId] : null,
          'serviceType': o.serviceType,
          'serviceStatus': o.serviceStatus,
          'dateCreated': o.openedAt.toIso8601String(),
        },
        items: items
            .map((it) => _KItem(
                  // null category → noCategoryId (0) so it matches a printer
                  // group that explicitly includes "No category".
                  groupId: productGroupOf[it.productId] ?? PrinterGroup.noCategoryId,
                  json: {
                    'id': it.productId,
                    'productName': productNames[it.productId] ??
                        'Product #${it.productId}',
                    'quantity': it.quantity,
                    'comment': it.comment,
                  },
                ))
            .toList(),
      ));
    }
    return result;
  }

  /// Filters each order's items to those allowed for one display. `allowed`
  /// null ⇒ keep everything. Orders left with no items are dropped.
  List<Map<String, dynamic>> _serializeForDisplay(
    List<_KOrder> orders,
    Set<int>? allowed,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final o in orders) {
      final items = (allowed == null
              ? o.items
              : o.items.where((i) => allowed.contains(i.groupId)))
          .map((i) => i.json)
          .toList();
      if (items.isEmpty) continue;
      out.add({...o.meta, 'items': items});
    }
    return out;
  }

  // ── Networking ────────────────────────────────────────────────────────────

  /// First non-loopback IPv4 of this device — sent to the KDS so it can call
  /// back. Returns '' if it can't be resolved (the KDS then can't reach us, but
  /// pairing + order push still work).
  Future<String> _selfIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '';
  }

  Future<void> _post(String ip, int port, String path, String body) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3)
        ..idleTimeout = const Duration(seconds: 3);
      final req = await client.post(ip, port, path);
      req.headers.contentType = ContentType.json;
      req.write(body);
      final res = await req.close();
      await res.drain<void>();
      client.close(force: true);
    } catch (e) {
      debugPrint('[KDS] POST $path → $ip:$port failed — $e');
    }
  }
}

final kitchenSyncProvider =
    Provider<KitchenSyncService>((ref) => KitchenSyncService(ref));

/// Intermediate order shape: the wire `meta` plus items that still carry their
/// product category id, so the snapshot can be filtered per display.
class _KOrder {
  final Map<String, dynamic> meta;
  final List<_KItem> items;
  const _KOrder({required this.meta, required this.items});
}

class _KItem {
  final int groupId;
  final Map<String, dynamic> json;
  const _KItem({required this.groupId, required this.json});
}
