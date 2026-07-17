// Pins double-booking prevention.
//
// The overlap rule is the half-open test `newStart < existingEnd && newEnd >
// existingStart`, which deliberately lets back-to-back sittings touch: a
// booking ending at 20:00 does not clash with one starting at 20:00. Using >=
// there would reject every consecutive sitting, so the boundary is pinned below
// in both directions.
//
// The resource is chosen by `resourceMode`, not by "whatever field is filled
// in": a salon books a person and may leave tables unset, a restaurant books
// the space. Both branches are covered, including that each ignores the other's
// collisions.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // 2026-07-20, 19:00 → 20:30 on table 1, staff 7.
  final start = DateTime(2026, 7, 20, 19);
  final end = DateTime(2026, 7, 20, 20, 30);

  Future<int> seed({
    List<int> tableIds = const [1],
    int? userId = 7,
    DateTime? from,
    DateTime? to,
    int status = 1,
    String syncStatus = 'synced',
    String name = 'Existing',
  }) async {
    final id = await db.upsertBookingLocal(
      companyId: 1,
      userId: userId,
      reservationName: name,
      tableIds: tableIds,
      startTime: from ?? start,
      endTime: to ?? end,
      status: status,
    );
    if (syncStatus != 'synced') {
      await (db.update(db.bookingsTable)..where((t) => t.id.equals(id))).write(
        BookingsTableCompanion(syncStatus: Value(syncStatus)),
      );
    }
    return id;
  }

  Future<List<BookingsTableData>> check({
    required DateTime from,
    required DateTime to,
    BookingResource resource = BookingResource.table,
    Set<int> ids = const {1},
    int? exclude,
  }) => db.findConflictingBookings(
    companyId: 1,
    start: from,
    end: to,
    resource: resource,
    resourceIds: ids,
    excludeBookingId: exclude,
  );

  group('table mode', () {
    test('an overlapping booking on the same table clashes', () async {
      await seed();
      final clashes = await check(
        from: DateTime(2026, 7, 20, 20), // starts inside the existing window
        to: DateTime(2026, 7, 20, 21),
      );
      expect(clashes, hasLength(1));
    });

    test('a booking fully containing an existing one clashes', () async {
      await seed();
      final clashes = await check(
        from: DateTime(2026, 7, 20, 18),
        to: DateTime(2026, 7, 20, 22),
      );
      expect(clashes, hasLength(1));
    });

    test('a different table does not clash', () async {
      await seed(tableIds: [2]);
      expect(await check(from: start, to: end), isEmpty);
    });

    test('a clash on ANY table of a multi-table booking counts', () async {
      await seed(tableIds: [4, 5, 6]);
      // Booking tables 6 and 7: 6 is taken.
      expect(await check(from: start, to: end, ids: {6, 7}), hasLength(1));
    });

    test('another company\'s booking does not clash', () async {
      await db.upsertBookingLocal(
        companyId: 2,
        reservationName: 'Other co',
        tableIds: const [1],
        startTime: start,
        endTime: end,
      );
      expect(await check(from: start, to: end), isEmpty);
    });
  });

  group('the half-open boundary', () {
    test('a booking starting exactly as another ends does NOT clash', () async {
      await seed(); // 19:00–20:30
      final clashes = await check(
        from: DateTime(2026, 7, 20, 20, 30), // begins on the dot
        to: DateTime(2026, 7, 20, 22),
      );
      expect(clashes, isEmpty, reason: 'back-to-back sittings must be allowed');
    });

    test('a booking ending exactly as another starts does NOT clash', () async {
      await seed(); // 19:00–20:30
      final clashes = await check(
        from: DateTime(2026, 7, 20, 18),
        to: DateTime(2026, 7, 20, 19), // ends on the dot
      );
      expect(clashes, isEmpty);
    });

    test('one minute of genuine overlap DOES clash', () async {
      await seed(); // 19:00–20:30
      final clashes = await check(
        from: DateTime(2026, 7, 20, 20, 29),
        to: DateTime(2026, 7, 20, 22),
      );
      expect(clashes, hasLength(1));
    });
  });

  group('staff mode', () {
    test('the same staff double-booked clashes', () async {
      await seed(userId: 7, tableIds: const []);
      final clashes = await check(
        from: start,
        to: end,
        resource: BookingResource.staff,
        ids: {7},
      );
      expect(clashes, hasLength(1));
    });

    test('a different staff member does not clash', () async {
      await seed(userId: 9);
      final clashes = await check(
        from: start,
        to: end,
        resource: BookingResource.staff,
        ids: {7},
      );
      expect(clashes, isEmpty);
    });

    test('staff mode ignores a table collision', () async {
      // Same table, but a different person: a salon books the person.
      await seed(tableIds: const [1], userId: 9);
      final clashes = await check(
        from: start,
        to: end,
        resource: BookingResource.staff,
        ids: {7},
      );
      expect(clashes, isEmpty);
    });

    test('table mode ignores a staff collision', () async {
      // Same person, different table: a restaurant books the space.
      await seed(tableIds: const [2], userId: 7);
      expect(await check(from: start, to: end, ids: {1}), isEmpty);
    });

    test('no staff selected reserves nothing', () async {
      await seed(userId: 7);
      final clashes = await check(
        from: start,
        to: end,
        resource: BookingResource.staff,
        ids: const {},
      );
      expect(clashes, isEmpty);
    });
  });

  group('what does not reserve a resource', () {
    test('editing a booking does not collide with itself', () async {
      final id = await seed();
      // Same slot, same table — this IS the row being edited.
      expect(await check(from: start, to: end, exclude: id), isEmpty);
    });

    test('a No Show does not block the slot', () async {
      await seed(status: 5);
      expect(await check(from: start, to: end), isEmpty);
    });

    test('a Completed booking does not block the slot', () async {
      await seed(status: 4);
      expect(await check(from: start, to: end), isEmpty);
    });

    test('a booking deleted offline does not block the slot', () async {
      await seed(syncStatus: 'pending_delete');
      expect(await check(from: start, to: end), isEmpty);
    });

    test('Scheduled, Arrived and In Service all reserve it', () async {
      for (final status in [1, 2, 3]) {
        await db.delete(db.bookingsTable).go();
        await seed(status: status);
        expect(
          await check(from: start, to: end),
          hasLength(1),
          reason: 'status $status must hold the table',
        );
      }
    });
  });
}
