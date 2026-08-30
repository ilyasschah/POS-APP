// The transport that makes silent printing possible on a tablet.
//
// A real socket is used here — a loopback server standing in for the printer —
// because the two things worth proving are that the bytes arrive INTACT and
// IN ORDER, and a mock of `Socket` proves neither.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/printer/network_printer.dart';

void main() {
  group('delivery', () {
    late ServerSocket server;
    late List<int> received;
    late Completer<void> gotBytes;

    setUp(() async {
      received = <int>[];
      gotBytes = Completer<void>();
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) {
        socket.listen(
          received.addAll,
          onDone: () {
            if (!gotBytes.isCompleted) gotBytes.complete();
            socket.destroy();
          },
        );
      });
    });

    tearDown(() => server.close());

    test('the bytes arrive exactly as sent', () async {
      final job = Uint8List.fromList([0x1B, 0x40, 0x41, 0x42, 0x1D, 0x56, 0x01]);
      await sendToNetworkPrinter(
        host: server.address.address,
        port: server.port,
        bytes: job,
      );
      await gotBytes.future.timeout(const Duration(seconds: 5));
      expect(received, job);
    });

    test('🚨 a long job arrives WHOLE — flush, not just destroy', () async {
      // `Socket.add` buffers. Destroying the socket without awaiting the flush
      // discards whatever has not gone out yet, so a long receipt prints its
      // first few centimetres and stops — which reads as a printer running out
      // of paper rather than as a bug.
      final job = Uint8List.fromList(
        List<int>.generate(200000, (i) => i % 251),
      );
      await sendToNetworkPrinter(
        host: server.address.address,
        port: server.port,
        bytes: job,
      );
      await gotBytes.future.timeout(const Duration(seconds: 10));
      expect(received.length, job.length);
      expect(received, orderedEquals(job));
    });

    test('a non-default port is honoured', () async {
      // The server is on an ephemeral port, so this passing at all proves the
      // port argument is used rather than 9100 being hardcoded.
      expect(server.port, isNot(kDefaultPrinterTcpPort));
      await sendToNetworkPrinter(
        host: server.address.address,
        port: server.port,
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await gotBytes.future.timeout(const Duration(seconds: 5));
      expect(received, [1, 2, 3]);
    });
  });

  group('failure is loud', () {
    test('an unreachable printer names the address', () async {
      // Port 1 on loopback: nothing listens, and the connection is refused
      // immediately rather than timing out.
      try {
        await sendToNetworkPrinter(
          host: '127.0.0.1',
          port: 1,
          bytes: Uint8List.fromList([1]),
        );
        fail('an unreachable printer should throw');
      } on NetworkPrinterException catch (e) {
        expect(e.message, contains('127.0.0.1:1'));
        expect(e.message.toLowerCase(), contains('could not reach'));
      }
    });

    test('an empty address asks for one instead of dialling nothing', () async {
      expect(
        () => sendToNetworkPrinter(host: '   ', bytes: Uint8List.fromList([1])),
        throwsA(isA<NetworkPrinterException>()),
      );
    });

    test('an empty job is refused rather than opening a pointless socket',
        () async {
      expect(
        () => sendToNetworkPrinter(host: '127.0.0.1', bytes: Uint8List(0)),
        throwsA(isA<NetworkPrinterException>()),
      );
    });
  });

  group('address validation', () {
    test('accepts an IP and a hostname alike', () {
      // A venue that names its printers is not doing anything wrong.
      expect(printerHostProblem('192.168.1.50'), isNull);
      expect(printerHostProblem('kitchen-printer'), isNull);
      expect(printerHostProblem('  10.0.0.7  '), isNull);
    });

    test('catches the port glued onto the address', () {
      // The commonest typo, and a SocketException for it blames DNS.
      expect(printerHostProblem('192.168.1.50:9100'), contains('port'));
    });

    test('catches a pasted URL', () {
      expect(printerHostProblem('http://192.168.1.50'), contains('http://'));
    });

    test('catches an empty field and a space', () {
      expect(printerHostProblem(''), isNotNull);
      expect(printerHostProblem('   '), isNotNull);
      expect(printerHostProblem('192.168.1.50 '), isNull, reason: 'trimmed');
      expect(printerHostProblem('192.168 .1.50'), contains('space'));
    });
  });
}
