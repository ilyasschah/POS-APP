/// Sends bytes to a network thermal printer over raw TCP — port 9100.
///
/// ## Why this exists
///
/// On Android there is no other route. `Printing.listPrinters()` has no
/// implementation and `directPrintPdf` reports `directPrint: false`, so every
/// print falls through to `Printing.layoutPdf()` and the **system print
/// dialog** — a modal asking the cashier which printer to use, in the middle of
/// closing a sale. See `printer/printer_platform.dart`.
///
/// Port 9100 ("JetDirect", "RAW") is the lowest common denominator of network
/// printing: the printer prints whatever bytes arrive, in order, with no
/// protocol around them. Every LAN thermal printer speaks it, and it is the
/// same socket the cash-drawer kick already uses — that arm was written first
/// and is the reason this transport was described as half-built.
///
/// ## Failure is loud, and per job
///
/// 🚨 A print that fails must SAY so. The whole reason silent printing is worth
/// having is that nobody is watching the printer; a swallowed socket error
/// means a sale completes, the drawer opens, and no paper comes out — which is
/// exactly the shape of the bug this app already shipped once (`88f314a`).
/// Every failure here throws [NetworkPrinterException] with a sentence naming
/// the address, and the caller decides whether an operator sees it.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// The RAW/JetDirect port. Configurable per printer, but nothing else is
/// normal enough to be worth defaulting to.
const int kDefaultPrinterTcpPort = 9100;

/// How long to wait for the printer to accept a connection.
///
/// Four seconds, matching the drawer. A till on the same LAN answers in
/// milliseconds; anything slower is a printer that is off, asleep or on another
/// subnet, and making the cashier wait longer does not change the answer.
const Duration kPrinterConnectTimeout = Duration(seconds: 4);

/// A print job could not be delivered. [message] is written for an operator.
class NetworkPrinterException implements Exception {
  const NetworkPrinterException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Opens [host]:[port], writes [bytes], waits for them to leave, closes.
///
/// ⚠️ **`flush()` is not optional and `destroy()` alone is a bug.** `Socket.add`
/// buffers; destroying the socket immediately after discards whatever has not
/// been written yet, so a long receipt prints its first few centimetres and
/// stops. Awaiting the flush is what makes a long job whole.
Future<void> sendToNetworkPrinter({
  required String host,
  int port = kDefaultPrinterTcpPort,
  required Uint8List bytes,
  Duration timeout = kPrinterConnectTimeout,
}) async {
  final address = host.trim();
  if (address.isEmpty) {
    throw const NetworkPrinterException(
      'No printer address is set. Enter the printer IP address in Printer '
      'Settings.',
    );
  }
  if (bytes.isEmpty) {
    throw const NetworkPrinterException('Nothing to print.');
  }

  Socket? socket;
  try {
    socket = await Socket.connect(address, port, timeout: timeout);
    socket.add(bytes);
    await socket.flush();
  } on SocketException catch (e) {
    throw NetworkPrinterException(
      'Could not reach the printer at $address:$port — '
      '${e.osError?.message ?? e.message}.',
    );
  } on TimeoutException {
    throw NetworkPrinterException(
      'The printer at $address:$port did not answer within '
      '${timeout.inSeconds} seconds. Check it is switched on and on this '
      'network.',
    );
  } finally {
    socket?.destroy();
  }
}

/// Whether [host] looks like something worth dialling.
///
/// Deliberately permissive: a hostname is as valid as an IP, and a venue that
/// names its printers is not doing anything wrong. This only catches the empty
/// field and the two things that are always a mistake — a scheme, and an
/// address with the port glued on, both of which produce a `SocketException`
/// with a message that blames DNS instead of the typo.
String? printerHostProblem(String host) {
  final h = host.trim();
  if (h.isEmpty) return 'Enter the printer IP address.';
  if (h.contains('://')) {
    return 'Enter just the address, with no http:// in front of it.';
  }
  if (h.contains(':')) {
    // An IPv6 literal is the one legitimate colon, and nothing in this app
    // has ever been handed one; a `192.168.1.50:9100` typo is common.
    return 'Enter the address only — the port goes in its own field.';
  }
  if (h.contains(' ')) return 'An address cannot contain a space.';
  return null;
}
