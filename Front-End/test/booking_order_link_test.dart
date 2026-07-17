// Pins the booking <-> order link maintenance the sync layer relies on:
//
// 1. remapOrderBookingId — an order started from a not-yet-synced booking holds
//    the booking's TEMP (negative) id. When the booking push swaps temp -> real,
//    every order pointing at the temp id must be repointed, or the reverse link
//    (openOrderForBookingProvider) breaks: "Start Service" reappears (duplicate
//    order) and paying can never complete the booking. It also returns the
//    affected rows so the caller can late-link any that already reached the
//    server (they synced WITHOUT a bookingId, since temp ids are never sent).
//
// 2. unlinkBookingPosOrder — voiding a booking's order must clear the local
//    posOrderId mirror (matching the server's UnlinkPosOrder), so a dead order
//    id can't keep driving the "Open Order" button.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedOrder(
    String localId, {
    int? bookingId,
    int? serverId,
  }) async {
    final now = DateTime.now().toUtc();
    await db.into(db.posOrdersTable).insert(
          PosOrdersTableCompanion(
            localId: Value(localId),
            serverId: Value(serverId),
            companyId: const Value(1),
            userId: const Value(1),
            serviceType: const Value(0),
            warehouseId: const Value(1),
            bookingId: Value(bookingId),
            openedAt: Value(now),
            lastModified: Value(now),
          ),
        );
  }

  Future<PosOrdersTableData> readOrder(String localId) =>
      (db.select(db.posOrdersTable)..where((t) => t.localId.equals(localId)))
          .getSingle();

  group('remapOrderBookingId', () {
    test('repoints temp booking ids and leaves other orders alone', () async {
      await seedOrder('a', bookingId: -1);
      await seedOrder('b', bookingId: -1);
      await seedOrder('other', bookingId: 42);
      await seedOrder('none');

      final affected = await db.remapOrderBookingId(-1, 500);

      expect(affected.map((o) => o.localId).toSet(), {'a', 'b'});
      expect((await readOrder('a')).bookingId, 500);
      expect((await readOrder('b')).bookingId, 500);
      expect((await readOrder('other')).bookingId, 42);
      expect((await readOrder('none')).bookingId, isNull);
    });

    test('returns empty when nothing references the temp id', () async {
      await seedOrder('x', bookingId: 42);
      expect(await db.remapOrderBookingId(-9, 500), isEmpty);
      expect((await readOrder('x')).bookingId, 42);
    });

    test('surfaces the already-synced order so it can be late-linked',
        () async {
      await seedOrder('unsynced', bookingId: -1);
      await seedOrder('synced', bookingId: -1, serverId: 777);

      final affected = await db.remapOrderBookingId(-1, 500);

      final syncedOnes = affected.where((o) => o.serverId != null).toList();
      expect(syncedOnes, hasLength(1));
      expect(syncedOnes.single.serverId, 777);
    });
  });

  group('unlinkBookingPosOrder', () {
    test('clears the forward mirror on void', () async {
      await db.into(db.bookingsTable).insert(
            BookingsTableCompanion(
              id: const Value(9),
              companyId: const Value(1),
              reservationName: const Value('Ilyass'),
              startTime: Value(DateTime(2026, 7, 20, 19)),
              endTime: Value(DateTime(2026, 7, 20, 20, 30)),
              status: const Value(3),
              posOrderId: const Value(777),
              lastModified: Value(DateTime.now().toUtc()),
              syncStatus: const Value('synced'),
            ),
          );

      await db.unlinkBookingPosOrder(9);

      final row = await (db.select(db.bookingsTable)
            ..where((t) => t.id.equals(9)))
          .getSingle();
      expect(row.posOrderId, isNull);
      // Status is the caller's concern (void rolls it to Arrived separately) —
      // unlink itself must not touch it.
      expect(row.status, 3);
    });
  });
}
