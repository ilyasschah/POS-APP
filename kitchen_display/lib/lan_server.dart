import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'kds_models.dart';

/// Port the Kitchen Display listens on for the paired POS. The POS pushes
/// pairing handshakes and order snapshots here; nothing in this app ever calls
/// the backend API.
const int kKdsPort = 9090;

/// LAN HTTP server for the Kitchen Display. Replaces the old "ping → fetch from
/// backend" model: the POS now pushes everything directly over the local
/// network, so the KDS works with zero internet access.
///
/// Endpoints (all POST unless noted):
///   /pair    { companyId, token, posName, posIp, posPort } → bind to a POS
///   /orders  { orders: [ ... ] }                            → full snapshot replace
///   /unpair  {}                                             → forget the POS
///   /health  (GET)                                          → liveness probe
class KdsLanServer {
  KdsLanServer({
    required this.onPair,
    required this.onOrders,
    required this.onUnpair,
    required this.deviceName,
  });

  final void Function({
    required int companyId,
    required String token,
    required String posName,
    required String posIp,
    required int posPort,
  }) onPair;
  final void Function(List<KitchenOrder> orders) onOrders;
  final void Function() onUnpair;
  final String deviceName;

  HttpServer? _server;
  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, kKdsPort);
      debugPrint('[KDS] LAN server listening on :$kKdsPort');
      _server!.listen(_handle);
    } catch (e) {
      debugPrint('[KDS] failed to bind :$kKdsPort — $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      final path = req.uri.path;

      if (req.method == 'GET' && path == '/health') {
        _json(req, {'status': 'ok', 'deviceName': deviceName});
        return;
      }

      if (req.method != 'POST') {
        req.response.statusCode = HttpStatus.notFound;
        return;
      }

      final data = body.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(body) as Map<String, dynamic>);

      switch (path) {
        case '/pair':
          onPair(
            companyId: (data['companyId'] as num?)?.toInt() ?? 0,
            token: (data['token'] ?? '') as String,
            posName: (data['posName'] ?? 'POS') as String,
            posIp: (data['posIp'] ?? '') as String,
            posPort: (data['posPort'] as num?)?.toInt() ?? 0,
          );
          _json(req, {'status': 'paired', 'deviceName': deviceName});

        case '/orders':
          final raw = (data['orders'] ?? const []) as List<dynamic>;
          final orders = raw
              .map((j) => KitchenOrder.fromJson(j as Map<String, dynamic>))
              .toList();
          onOrders(orders);
          _json(req, {'status': 'ok', 'count': orders.length});

        case '/unpair':
          onUnpair();
          _json(req, {'status': 'unpaired'});

        default:
          req.response.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      debugPrint('[KDS] request error — $e');
      try {
        req.response.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
    } finally {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  void _json(HttpRequest req, Map<String, dynamic> body) {
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }
}

/// Fire-and-forget notification back to the paired POS that an order is ready
/// (the cook tapped DONE). Sent over the LAN to the POS's own listener — no
/// backend API involved, so it works offline. Failures are swallowed: the KDS
/// already removed the ticket locally, and the POS will reconcile on its next
/// order sync if the packet is lost.
Future<void> notifyOrderReady({
  required String posIp,
  required int posPort,
  required String orderRef,
  required String token,
}) async {
  if (posIp.isEmpty || posPort == 0) return;
  try {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3);
    final req = await client.post(posIp, posPort, '/order-ready');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'orderRef': orderRef, 'token': token}));
    final res = await req.close();
    await res.drain<void>();
    client.close(force: true);
  } catch (e) {
    debugPrint('[KDS] order-ready push failed → $posIp:$posPort — $e');
  }
}
