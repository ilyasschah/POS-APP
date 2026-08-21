import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a scan came from.
///
/// 🚨 The distinction is a permission, not a label. A HARDWARE scan is ambient
/// input — the cashier may be looking at Documents while a colleague waves a
/// product past the scanner — so it may only act on the screen that is actually
/// in front of someone. A SIMULATED scan is an explicit instruction typed by a
/// developer into the debug panel, and refusing to deliver it because the POS
/// tab is not in front would make the tool useless exactly when it is needed.
enum ScanSource { hardware, simulated }

class Scan {
  const Scan(this.code, this.source);

  final String code;
  final ScanSource source;
}

/// Every barcode that reaches the app, from any source, on one stream.
///
/// 🚨 One bus for both the wedge and the simulator, deliberately: a simulated
/// scan that travelled its own path would prove nothing about the real one. The
/// producers (the global key listener, the debug panel) know nothing about the
/// screens, and the screens know nothing about the producers — they share a
/// string and a provenance flag.
class ScanBus {
  final _controller = StreamController<Scan>.broadcast();

  Stream<Scan> get stream => _controller.stream;

  /// Whether any screen is currently able to receive a scan.
  bool get hasListener => _controller.hasListener;

  void emit(String barcode, {ScanSource source = ScanSource.simulated}) {
    final code = barcode.trim();
    if (code.isEmpty || _controller.isClosed) return;
    _controller.add(Scan(code, source));
  }

  void dispose() => _controller.close();
}

final scanBusProvider = Provider<ScanBus>((ref) {
  final bus = ScanBus();
  ref.onDispose(bus.dispose);
  return bus;
});
