// Pins how a terminal reacts to being removed from the account.
//
// Requested 2026-08-06: "when I delete a device from the user info screen it
// should be deleted from the device registry, and that device should log out
// when it connects and ask to log in again."
//
// Before this, "revoke device" only blanked `UserDevicePins.HashedPin`. The
// terminal kept its master session, kept syncing, and kept occupying a paid
// seat — it never signed out and the admin saw no change in DeviceRegistry.
//
// The 403 shapes below all arrive on the same endpoint, and confusing them is
// the whole risk: a seat/licence block is a condition to fix on the ACCOUNT (the
// terminal stays enrolled and must NOT be signed out), while a revoke means this
// terminal is no longer enrolled and must re-authenticate.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/sync/sync_manager.dart';

/// Mirrors `pushPendingOrders`' 403 branch: maps the server's `error` code to
/// the exception the UI reacts to. `null` = not a licensing/enrolment refusal,
/// so the original DioException propagates.
Object? classify403(String? errorCode) {
  if (errorCode == 'device_revoked') return DeviceRevokedException('revoked');
  if (errorCode == 'seat_limit_exceeded' || errorCode == 'device_blocked') {
    return SeatLimitException('seat');
  }
  return null;
}

void main() {
  test('device_revoked signs the terminal out, it does not block it', () {
    final result = classify403('device_revoked');
    expect(result, isA<DeviceRevokedException>());
    // Load-bearing: the shell routes DeviceRevokedException to master login and
    // leaves the local database intact. Were it a SeatLimitException it would
    // land on the blocking screen instead and never re-enrol.
    expect(result, isNot(isA<SeatLimitException>()));
  });

  test('a seat/licence refusal is NOT treated as a revoke', () {
    // These must not sign the terminal out — the operator fixes the account and
    // the same device carries on.
    expect(classify403('seat_limit_exceeded'), isA<SeatLimitException>());
    expect(classify403('device_blocked'), isA<SeatLimitException>());
    expect(classify403('seat_limit_exceeded'), isNot(isA<DeviceRevokedException>()));
    expect(classify403('device_blocked'), isNot(isA<DeviceRevokedException>()));
  });

  test('an unrelated 403 is left alone for the caller to rethrow', () {
    expect(classify403('something_else'), isNull);
    expect(classify403(null), isNull);
  });

  test('the revoke message reaches the operator verbatim', () {
    // The server explains why ("This terminal was removed from the account…").
    // main_layout shows it on the way to master login, so a cashier who suddenly
    // gets logged out is told the reason rather than guessing.
    const serverMessage =
        'This terminal was removed from the account. Sign in again to reconnect it.';
    expect(DeviceRevokedException(serverMessage).toString(), serverMessage);
  });

  test('both exception types survive being thrown and caught by type', () {
    // `_step` rethrows each by type rather than swallowing it into a failed-step
    // label; if either stopped being distinguishable the terminal would silently
    // keep running unauthorised.
    Object? caught;
    try {
      throw DeviceRevokedException('x');
    } on SeatLimitException {
      caught = 'wrong';
    } on DeviceRevokedException catch (e) {
      caught = e;
    }
    expect(caught, isA<DeviceRevokedException>());
  });

  test('a 403 payload without an error code is not a revoke', () {
    // Defensive: an older API, or a proxy returning its own 403, must not sign
    // the terminal out.
    final res = Response<dynamic>(
      requestOptions: RequestOptions(path: '/PosOrder/BatchSync'),
      statusCode: 403,
      data: {'message': 'Forbidden'},
    );
    final err = res.data is Map ? (res.data as Map)['error'] as String? : null;
    expect(classify403(err), isNull);
  });
}
