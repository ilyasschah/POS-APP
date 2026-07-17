// Guards the data-layer transition behind "a booking's order is paid -> the
// reservation becomes Completed". The checkout dialog calls
// setBookingStatusLocal(bookingId, 4) after banking the sale; this pins that a
// synced In-Service booking flips to Completed AND is re-queued for push, so the
// server's /Bookings/UpdateStatus is issued on the next sync. Before this, the
// booking sat at In Service (status 3) forever after payment.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Seeds a server-originated (synced) booking already In Service (status 3).
  Future<void> seedInService(int id) async {
    await db.into(db.bookingsTable).insert(
          BookingsTableCompanion(
            id: Value(id),
            companyId: const Value(1),
            reservationName: const Value('Ilyass'),
            startTime: Value(DateTime(2026, 7, 20, 19)),
            endTime: Value(DateTime(2026, 7, 20, 20, 30)),
            status: const Value(3), // In Service
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<BookingsTableData> read(int id) => (db.select(db.bookingsTable)
        ..where((t) => t.id.equals(id)))
      .getSingle();

  test('paying a booking flips it to Completed and queues the push', () async {
    await seedInService(7);

    await db.setBookingStatusLocal(7, 4); // 4 = Completed

    final row = await read(7);
    expect(row.status, 4);
    expect(row.syncStatus, 'pending_update');
  });

  test('a never-synced (temp) booking stays pending_create', () async {
    await db.into(db.bookingsTable).insert(
          BookingsTableCompanion(
            id: const Value(-1),
            companyId: const Value(1),
            reservationName: const Value('Temp'),
            startTime: Value(DateTime(2026, 7, 20, 19)),
            endTime: Value(DateTime(2026, 7, 20, 20, 30)),
            status: const Value(3),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('pending_create'),
          ),
        );

    await db.setBookingStatusLocal(-1, 4);

    final row = await read(-1);
    expect(row.status, 4);
    // Must not downgrade a create still waiting to be pushed to an update.
    expect(row.syncStatus, 'pending_create');
  });
}
