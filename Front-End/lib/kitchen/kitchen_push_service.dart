import 'dart:async';
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

/// The configured Kitchen Display addresses, from the raw CSV setting.
List<String> parseKitchenDisplayIps(String? raw) => (raw ?? '')
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// True while at least one Kitchen Display is paired to this terminal.
///
/// This IS the app's "KDS enabled" flag — there is no separate toggle: pairing
/// adds an IP, unpairing removes it. Everything on the KDS network path gates
/// on this, so a terminal with no display bound opens no listener and sends no
/// requests.
///
/// Derived, so it only notifies when the boolean actually flips — not on every
/// unrelated settings write.
final kitchenDisplaysEnabledProvider = Provider<bool>((ref) {
  final raw = ref.watch(appSettingsProvider)[SettingKeys.kitchenDisplayIps];
  return parseKitchenDisplayIps(raw).isNotEmpty;
});

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

  /// (ip, path) pairs whose last attempt failed and has already been logged.
  ///
  /// A dead tablet is re-POSTed on every cart change, and logging each 3-second
  /// timeout buries everything else in the console. One line per target until
  /// it answers again is enough to diagnose it.
  final Set<String> _loggedFailures = {};

  List<String> _ips() => parseKitchenDisplayIps(
      ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayIps]);

  /// 🚨 THE GATE. Nothing on this path opens a socket to an address that is not
  /// a currently-configured display.
  ///
  /// Unpairing removes the IP from settings, so this also answers "is the KDS
  /// turned off" — an unpaired terminal has an empty list and every check here
  /// fails closed. The teardown POST in [unpair] is the single deliberate
  /// exception, because by definition it targets an address that was just
  /// removed.
  bool _isConfigured(String ip) => _ips().contains(ip);

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
    // Gate first, before any Drift work: with no display paired there is
    // nothing to push to and no reason to build a payload.
    if (!ref.read(kitchenDisplaysEnabledProvider)) return;

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
    if (ip.trim().isEmpty) return;
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

  /// Unpairs a Kitchen Display: forgets it locally, then *best-effort* tells the
  /// tablet to return to its onboarding screen.
  ///
  /// 🚨 The local state is cleared FIRST and unconditionally. The tablet being
  /// unpaired is very often the one that is already off, reimaged, or on
  /// another network — waiting on it, or letting its timeout propagate, would
  /// mean an operator cannot remove a display that no longer exists. A failed
  /// teardown POST is not an error: the POS has already forgotten the device,
  /// and a tablet that never got the message shows a stale order list until
  /// someone re-pairs it, which is the lesser problem by far.
  ///
  /// This is also what stopped the log spam: with the IP gone from settings,
  /// [_isConfigured] fails for it forever after, so no later push can reopen a
  /// socket to a machine nobody is listening on.
  Future<void> unpair(String ip) async {
    final target = ip.trim();
    if (target.isEmpty) return;

    // 1. Forget it locally — settings and its station assignment.
    final settings = ref.read(appSettingsProvider.notifier);
    final remaining = _ips().where((e) => e != target).join(',');
    await settings.set(SettingKeys.kitchenDisplayIps, remaining);

    final groups = parseDisplayGroups(
        ref.read(appSettingsProvider)[SettingKeys.kitchenDisplayGroups]);
    if (groups.remove(target) != null) {
      await settings.set(
          SettingKeys.kitchenDisplayGroups, encodeDisplayGroups(groups));
    }

    _loggedFailures.removeWhere((k) => k.startsWith('$target|'));

    // 2. Tell the tablet, if it happens to be there. Teardown bypasses the
    //    gate — the address it targets was just removed on purpose — and runs
    //    on a short timeout so removing a dead display never hangs the UI.
    await _post(
      target,
      kKdsPort,
      '/unpair',
      '{}',
      teardown: true,
      timeout: const Duration(seconds: 1),
    );
  }

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

  /// One best-effort POST to a display. Never throws.
  ///
  /// [teardown] is the only way past the configured-display gate, and exists
  /// solely for `/unpair`.
  Future<void> _post(
    String ip,
    int port,
    String path,
    String body, {
    bool teardown = false,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // 🚨 State gate. An unpaired (or never-paired) address gets no socket at
    // all — this is what stops a removed tablet being dialled forever.
    if (!teardown && !_isConfigured(ip)) return;

    final key = '$ip|$path';
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = timeout;
      // `connectionTimeout` only bounds the CONNECT; a half-open host can still
      // hang on the response, so the whole exchange is bounded too.
      await () async {
        final req = await client!.post(ip, port, path);
        req.headers.contentType = ContentType.json;
        req.write(body);
        final res = await req.close();
        await res.drain<void>();
      }()
          .timeout(timeout);
      _loggedFailures.remove(key);
    } on SocketException catch (e) {
      _noteFailure(key, teardown, '$ip:$port$path', e);
    } on TimeoutException catch (e) {
      _noteFailure(key, teardown, '$ip:$port$path', e);
    } on HttpException catch (e) {
      _noteFailure(key, teardown, '$ip:$port$path', e);
    } catch (e) {
      _noteFailure(key, teardown, '$ip:$port$path', e);
    } finally {
      client?.close(force: true);
    }
  }

  /// Logs a failed POST **once** per target until it succeeds again, and not at
  /// all for a teardown — an unreachable tablet being unpaired is the expected
  /// case, not a fault worth a line in the log.
  void _noteFailure(String key, bool teardown, String target, Object error) {
    if (teardown) return;
    if (!_loggedFailures.add(key)) return;
    debugPrint('[KDS] $target unreachable — $error '
        '(silenced until it responds again)');
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
