import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/kitchen/kitchen_push_service.dart';

/// serviceStatus the POS stamps on an order once a paired KDS reports it ready.
/// Matches `kServiceStatusReady` used by the open-orders badge/colour code.
const int _kServiceStatusReady = 3;

/// Small LAN listener the POS runs so paired Kitchen Displays can report an
/// order as ready WITHOUT either side touching the backend API. The KDS POSTs
/// `/order-ready { orderRef }`; we flip the matching local order's
/// serviceStatus to 3, which the Drift-backed `readyOrdersCountProvider`
/// instantly turns into the POS menu badge.
class PosKitchenServer {
  PosKitchenServer(this.ref);
  final Ref ref;

  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, kPosListenerPort);
      debugPrint('[POS] kitchen listener on :$kPosListenerPort');
      _server!.listen(_handle);
    } catch (e) {
      debugPrint('[POS] failed to bind :$kPosListenerPort — $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      if (req.method == 'POST' && req.uri.path == '/order-ready') {
        final data = body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(body) as Map<String, dynamic>;
        final orderRef = (data['orderRef'] ?? '').toString();
        if (orderRef.isNotEmpty) await _markReady(orderRef);
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));
      } else if (req.method == 'GET' && req.uri.path == '/health') {
        req.response
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode({'status': 'ok'}));
      } else {
        req.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      debugPrint('[POS] kitchen listener error — $e');
      try {
        req.response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
    } finally {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  /// `orderRef` is the POS's own reference echoed back by the KDS: a serverId
  /// (numeric string) or a local UUID. Match on whichever applies.
  Future<void> _markReady(String orderRef) async {
    final db = ref.read(appDatabaseProvider);
    final serverId = int.tryParse(orderRef);

    final companion = PosOrdersTableCompanion(
      serviceStatus: const Value(_kServiceStatusReady),
      lastModified: Value(DateTime.now().toUtc()),
    );

    if (serverId != null) {
      await (db.update(db.posOrdersTable)
            ..where((t) => t.serverId.equals(serverId)))
          .write(companion);
    }
    // Always try the localId too (covers not-yet-synced orders).
    await (db.update(db.posOrdersTable)
          ..where((t) => t.localId.equals(orderRef)))
        .write(companion);

    // Offline-first: the local Drift row is authoritative. We do NOT call the
    // backend from here. The "don't downgrade a ready order" guard in
    // syncOpenOrdersToDrift keeps this at 3 even when a later pull reports the
    // server's stale 2, and the status reaches the backend through the normal
    // order sync when the order is checked out / pushed — no ad-hoc API call.
  }
}

/// Kept alive for the post-login session by a `ref.watch` in MainLayout; the
/// listener is torn down on logout via `ref.onDispose`.
final posKitchenServerProvider = Provider<PosKitchenServer>((ref) {
  final server = PosKitchenServer(ref);
  server.start();
  ref.onDispose(server.stop);
  return server;
});
