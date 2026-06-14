import 'dart:io';

import 'package:flutter/material.dart';

import 'kds_models.dart';
import 'kds_storage.dart';
import 'kitchen_screen.dart';
import 'lan_server.dart';
import 'onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitchenDisplayApp());
}

class KitchenDisplayApp extends StatelessWidget {
  const KitchenDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitchen Display',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const RootScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Owns the device's whole lifecycle: runs the LAN server, holds the pairing
/// record + the current order snapshot, and swaps between the onboarding and
/// kitchen screens. Everything is local — there is no backend API client.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final KdsStorage _storage = KdsStorage();
  KdsLanServer? _server;

  PairingInfo _pairing = PairingInfo.empty;
  List<KitchenOrder> _orders = [];

  String _deviceName = '…';
  String _deviceIp = '…';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _deviceName = _resolveDeviceName();
    await _resolveDeviceIp();

    _pairing = await _storage.loadPairing();
    _orders = await _storage.loadOrders();

    _server = KdsLanServer(
      deviceName: _deviceName,
      onPair: _handlePair,
      onOrders: _handleOrders,
      onUnpair: _handleUnpair,
    );
    await _server!.start();

    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  String _resolveDeviceName() {
    try {
      final h = Platform.localHostname;
      return h.isNotEmpty ? h : 'Kitchen Display';
    } catch (_) {
      return 'Kitchen Display';
    }
  }

  Future<void> _resolveDeviceIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            _deviceIp = addr.address;
            return;
          }
        }
      }
    } catch (_) {}
  }

  // ── LAN server callbacks (run on the main isolate) ────────────────────────

  void _handlePair({
    required int companyId,
    required String token,
    required String posName,
    required String posIp,
    required int posPort,
  }) {
    () async {
      final info = await _storage.savePairing(
        companyId: companyId,
        token: token,
        posName: posName,
        posIp: posIp,
        posPort: posPort,
      );
      if (mounted) setState(() => _pairing = info);
    }();
  }

  void _handleOrders(List<KitchenOrder> orders) {
    _orders = orders;
    _storage.saveOrders(orders);
    if (mounted) setState(() {});
  }

  void _handleUnpair() {
    () async {
      await _storage.clearPairing();
      if (mounted) {
        setState(() {
          _pairing = PairingInfo.empty;
          _orders = [];
        });
      }
    }();
  }

  void _markReady(KitchenOrder order) {
    // Optimistically drop the ticket and tell the paired POS it's ready.
    setState(() => _orders =
        _orders.where((o) => o.orderRef != order.orderRef).toList());
    _storage.saveOrders(_orders);
    notifyOrderReady(
      posIp: _pairing.posIp,
      posPort: _pairing.posPort,
      orderRef: order.orderRef,
      token: _pairing.token,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF546E7A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!_pairing.paired) {
      return OnboardingScreen(
        deviceName: _deviceName,
        ipAddress: _deviceIp,
        port: kKdsPort,
      );
    }

    return KitchenScreen(
      orders: _orders,
      posName: _pairing.posName.isEmpty ? 'POS' : _pairing.posName,
      onMarkReady: _markReady,
      onUnpair: _handleUnpair,
    );
  }
}
