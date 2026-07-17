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
}
