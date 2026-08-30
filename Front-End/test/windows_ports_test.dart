// The port pickers used to offer a written-down COM1–COM10 plus LPT1–LPT3.
// These tests pin the two properties that replaced it: the list is a union of
// what the machine reported, and a saved port is kept only when the machine
// stopped reporting it.
//
// The registry read itself is exercised by `dart run tool/probe_ports.dart` on
// a real Windows box — a unit test cannot assert what hardware a machine has.
// Everything that carries judgement is in [mergePortLists], which is pure.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/utils/windows_ports.dart';

void main() {
  group('comparePortNames', () {
    test('orders COM2 before COM10, not after it', () {
      final ports = ['COM10', 'COM2', 'COM1']..sort(comparePortNames);
      expect(ports, ['COM1', 'COM2', 'COM10']);
    });

    test('groups by prefix, so every COM precedes every LPT', () {
      final ports = ['LPT1', 'COM9', 'COM11']..sort(comparePortNames);
      expect(ports, ['COM9', 'COM11', 'LPT1']);
    });

    test('falls back to a plain compare for a name it cannot parse', () {
      final ports = ['COM3', 'ttyUSB0', 'COM1']..sort(comparePortNames);
      expect(ports.first, 'COM1');
      expect(ports.contains('ttyUSB0'), isTrue);
    });
  });

  group('normalizePortName', () {
    test('trims and upper-cases so one port cannot appear twice', () {
      expect(normalizePortName('  com2 '), 'COM2');
      expect(normalizePortName('COM2'), 'COM2');
      expect(normalizePortName('   '), '');
    });
  });

  group('mergePortLists', () {
    test('unions the sources and de-duplicates across them', () {
      // The device map and libserialport overlap; neither is a superset.
      final ports = mergePortLists(detected: [
        ['COM1', 'COM2'],
        ['COM2', 'COM5'],
      ]);
      expect(ports, ['COM1', 'COM2', 'COM5']);
    });

    test('a port differing only in case or padding is one port', () {
      final ports = mergePortLists(detected: [
        ['COM3'],
        [' com3 '],
      ]);
      expect(ports, ['COM3']);
    });

    test('no sources reported anything -> empty, never a default list', () {
      // The whole point: an empty answer must survive to the UI. Substituting
      // COM1–COM4 here is the bug this file exists to prevent.
      expect(mergePortLists(detected: const []), isEmpty);
      expect(mergePortLists(detected: [const [], const []]), isEmpty);
    });

    test('a saved port the machine still reports is not duplicated', () {
      final ports = mergePortLists(
        detected: [
          ['COM1', 'COM4']
        ],
        saved: 'COM4',
      );
      expect(ports, ['COM1', 'COM4']);
    });

    test('a saved port the machine no longer reports is kept, and goes first',
        () {
      // An unplugged display must not silently re-point at another device.
      final ports = mergePortLists(
        detected: [
          ['COM1']
        ],
        saved: 'COM7',
      );
      expect(ports, ['COM7', 'COM1']);
    });

    test('a saved port is matched case-insensitively before being folded in',
        () {
      final ports = mergePortLists(
        detected: [
          ['COM1']
        ],
        saved: 'com1',
      );
      expect(ports, ['COM1']);
    });

    test('no saved value and nothing detected stays empty', () {
      expect(mergePortLists(detected: const [], saved: ''), isEmpty);
      expect(mergePortLists(detected: const [], saved: '   '), isEmpty);
      expect(mergePortLists(detected: const [], saved: null), isEmpty);
    });
  });

  group('WindowsPorts', () {
    test('reads the device map without throwing, and returns only port names',
        () {
      // Runs on whatever machine CI or the developer is on: the ASSERTION is
      // that nothing is invented, not that any particular port exists.
      final serial = WindowsPorts.serial();
      final parallel = WindowsPorts.parallel();

      if (!Platform.isWindows) {
        expect(serial, isEmpty);
        expect(parallel, isEmpty);
        return;
      }

      for (final port in serial) {
        expect(port, matches(RegExp(r'^COM\d+$')),
            reason: 'the device map yielded something that is not a COM port');
      }
      for (final port in parallel) {
        expect(port, matches(RegExp(r'^LPT\d+$')),
            reason: 'the device map yielded something that is not an LPT port');
      }
      expect(serial.toSet().length, serial.length, reason: 'duplicate COM');
      expect(parallel.toSet().length, parallel.length, reason: 'duplicate LPT');
    });

    test('a missing key is an empty list, not an exception', () {
      // PARALLEL PORTS does not exist on a machine with no parallel port,
      // which is most of them. That must read as "none", never as a failure
      // the caller papers over with a default.
      expect(() => WindowsPorts.parallel(), returnsNormally);
    });
  });
}
