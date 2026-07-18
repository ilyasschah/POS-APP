// Pins liveBookingForTable, the selector the floor-plan tap uses to decide
// whether a FREE table is actually held by a reservation right now (and, if so,
// which one to open so the order inherits that guest's customer instead of
// Walk-in).
//
// "Live" means: the booking lists this table, its status is Scheduled/Arrived/
// InService (1-3, NOT Completed 4 or NoShow 5), and `at` falls within the
// [startTime, endTime] window. When sittings overlap, the earliest-starting one
// is chosen so the result is deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/bookings/booking_model.dart';
import 'package:pos_app/bookings/bookings_provider.dart';

void main() {
  final at = DateTime(2026, 7, 20, 19, 30);

  Booking booking({
    required int id,
    List<int> tableIds = const [1],
    int status = 1,
    int? customerId = 42,
    DateTime? from,
    DateTime? to,
  }) {
    return Booking(
      id: id,
      customerId: customerId,
      reservationName: 'B$id',
      tableIds: tableIds,
      status: status,
      startTime: from ?? DateTime(2026, 7, 20, 19),
      endTime: to ?? DateTime(2026, 7, 20, 20, 30),
    );
  }

  test('returns null when nothing holds the table', () {
    expect(liveBookingForTable(const [], 1, at), isNull);
    expect(liveBookingForTable([booking(id: 1, tableIds: [2])], 1, at), isNull);
  });

  test('ignores non-live statuses (completed / no-show)', () {
    expect(liveBookingForTable([booking(id: 1, status: 4)], 1, at), isNull);
    expect(liveBookingForTable([booking(id: 1, status: 5)], 1, at), isNull);
  });

  test('ignores bookings whose window does not contain the moment', () {
    final past = booking(
      id: 1,
      from: DateTime(2026, 7, 20, 17),
      to: DateTime(2026, 7, 20, 18),
    );
    expect(liveBookingForTable([past], 1, at), isNull);
  });

  test('returns the live booking, carrying its customer', () {
    final b = liveBookingForTable([booking(id: 9, customerId: 7)], 1, at);
    expect(b, isNotNull);
    expect(b!.id, 9);
    expect(b.customerId, 7);
  });

  test('resolves overlaps to the earliest-starting booking', () {
    final later = booking(id: 2, from: DateTime(2026, 7, 20, 19, 15));
    final earlier = booking(id: 1, from: DateTime(2026, 7, 20, 19));
    // Order in the list must not matter.
    expect(liveBookingForTable([later, earlier], 1, at)!.id, 1);
    expect(liveBookingForTable([earlier, later], 1, at)!.id, 1);
  });

  test('hasLiveBookingForTable agrees with the selector', () {
    expect(hasLiveBookingForTable([booking(id: 1)], 1, at), isTrue);
    expect(hasLiveBookingForTable([booking(id: 1, status: 4)], 1, at), isFalse);
  });

  // The "occupied on create" rule: a booking holds its tables regardless of
  // time, until it's Completed/No-Show/deleted. This is what marks a table
  // Reserved on the floor plan and hides it from the transfer + booking pickers.
  group('tablesHeldByBookings (time-independent)', () {
    // A window entirely in the past — proves holding does NOT depend on time.
    final pastFrom = DateTime(2020, 1, 1, 10);
    final pastTo = DateTime(2020, 1, 1, 12);

    test('holds tables of active bookings even outside their window', () {
      final held = tablesHeldByBookings([
        booking(id: 1, tableIds: [3], from: pastFrom, to: pastTo),
      ]);
      expect(held, {3});
    });

    test('releases Completed (4) and No-Show (5) bookings', () {
      expect(tablesHeldByBookings([booking(id: 1, tableIds: [3], status: 4)]),
          isEmpty);
      expect(tablesHeldByBookings([booking(id: 1, tableIds: [3], status: 5)]),
          isEmpty);
    });

    test('unions and de-dupes multi-table bookings', () {
      final held = tablesHeldByBookings([
        booking(id: 1, tableIds: [1, 2]),
        booking(id: 2, tableIds: [2, 3], status: 2),
      ]);
      expect(held, {1, 2, 3});
    });

    test('heldBookingForTable returns the reservation regardless of time', () {
      final b = heldBookingForTable(
        [booking(id: 9, tableIds: [3], customerId: 59, from: pastFrom, to: pastTo)],
        3,
      );
      expect(b?.id, 9);
      expect(b?.customerId, 59);
      // A completed booking no longer holds it.
      expect(
        heldBookingForTable([booking(id: 9, tableIds: [3], status: 4)], 3),
        isNull,
      );
    });
  });
}
