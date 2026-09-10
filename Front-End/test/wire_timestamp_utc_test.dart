// Timestamps crossing the wire must carry their timezone — in BOTH directions.
//
// The bug this pins, found on two real tills on 2026-09-09: the same receipt
// showed 22:12 on the terminal that rang it up and 21:12 on the other one, and
// the owner dashboard agreed with neither.
//
// One cause, two opposite symptoms, because NOTHING on the wire said what zone
// a timestamp was in:
//
//  • PULL. EF materialises SQL Server `datetime2` as DateTimeKind.Unspecified,
//    and System.Text.Json writes that with no marker: "2026-09-09T21:15:22.797".
//    `DateTime.parse` reads a string like that as LOCAL, so the old
//    `DateTime.parse(x).toUtc()` SUBTRACTED the device's offset — a sale made at
//    22:15 in Casablanca was stored on every other till as 21:15.
//    (Verified against document 199: server 21:15:22.797Z, device A's copy
//    20:15:22Z.)
//
//  • PUSH. Drift reconstructs DateTimes in LOCAL time, so
//    `row.openedAt.toIso8601String()` produced "2026-09-09T22:26:37.000" — the
//    wall clock, no zone — and the API stored it as UTC. Every session this
//    device opened was recorded an hour in the FUTURE.
//    (Verified against session 29: device 21:26:37Z, server 22:26:37Z.)
//
// The two cancelled out for the device that wrote the row, which is exactly why
// this survived so long: it only showed up on the SECOND terminal and in the
// cloud.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/sync/sync_manager.dart';

void main() {
  group('a timestamp from the server', () {
    test('with no zone marker is UTC, not local', () {
      // THE regression. Under the old parse this came back an hour early on any
      // device east of Greenwich, and an hour late west of it.
      final parsed = SyncManager.parseServerDate('2026-09-09T21:15:22.797');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed.toIso8601String(), '2026-09-09T21:15:22.797Z');
    });

    test('with a Z is honoured as written', () {
      final parsed = SyncManager.parseServerDate('2026-09-09T21:15:22.797Z');

      expect(parsed!.toIso8601String(), '2026-09-09T21:15:22.797Z');
    });

    test('with an explicit offset is converted, not ignored', () {
      // +01:00 is Casablanca. 22:15 there IS 21:15 UTC.
      final parsed = SyncManager.parseServerDate('2026-09-09T22:15:22.797+01:00');

      expect(parsed!.toIso8601String(), '2026-09-09T21:15:22.797Z');
    });

    test('a negative offset is not mistaken for the date\'s dashes', () {
      // The naive "does it contain a '-'?" test says yes for EVERY ISO date.
      final parsed = SyncManager.parseServerDate('2026-09-09T16:15:22.797-05:00');

      expect(parsed!.toIso8601String(), '2026-09-09T21:15:22.797Z');
    });

    test('a date with no time is left alone', () {
      final parsed = SyncManager.parseServerDate('2026-09-09');

      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 9);
      expect(parsed.day, 9);
    });

    test('null, empty and rubbish return null rather than throwing', () {
      // A pull must never die on one malformed row.
      expect(SyncManager.parseServerDate(null), isNull);
      expect(SyncManager.parseServerDate(''), isNull);
      expect(SyncManager.parseServerDate('not a date'), isNull);
      expect(SyncManager.parseServerDate(42), isNull);
    });
  });

  group('a timestamp going to the server', () {
    test('a local DateTime is converted and marked', () {
      // What Drift hands back: a LOCAL DateTime. The old code shipped its wall
      // clock with no marker and the server filed it as UTC.
      final local = DateTime(2026, 9, 9, 22, 26, 37);
      final wire = SyncManager.isoUtc(local);

      expect(wire, endsWith('Z'));
      expect(DateTime.parse(wire).toUtc(), local.toUtc());
    });

    test('a UTC DateTime survives untouched', () {
      final utc = DateTime.utc(2026, 9, 9, 21, 26, 37);

      expect(SyncManager.isoUtc(utc), '2026-09-09T21:26:37.000Z');
    });
  });

  group('the round trip', () {
    test('an instant survives push then pull unchanged', () {
      // The property that actually matters: whatever the device's zone, the
      // instant that comes back is the instant that went out.
      final instant = DateTime.now();

      final returned = SyncManager.parseServerDate(SyncManager.isoUtc(instant));

      expect(returned, isNotNull);
      expect(
        returned!.millisecondsSinceEpoch,
        instant.millisecondsSinceEpoch,
        reason: 'a sale must not move in time by crossing the wire',
      );
    });

    test('a server that still sends no marker round-trips too', () {
      // The API is fixed to send Z, but an old build in the field is not. A
      // zone-less string means UTC, so the value it round-trips to is the same.
      const asOldServerSendsIt = '2026-09-09T21:26:37.000';

      final parsed = SyncManager.parseServerDate(asOldServerSendsIt)!;

      expect(SyncManager.isoUtc(parsed), '2026-09-09T21:26:37.000Z');
    });
  });
}
