// A cash movement that could not be pushed because the till was OFFLINE has to
// stay queued. Anything else loses money quietly.
//
// The failure this pins is a real one, recovered from device A's SQLite on
// 2026-09-09:
//
//   local_id     3add609a-…      amount 200      type 'opening'
//   sync_status  'failed'        server_id NULL
//   sync_error   DioException [connection error] … connection refused …
//
// The register was opened offline with a 200 DH float. The first sync attempt
// hit a refused connection, the push marked the row 'failed' — and because
// getPendingCashMovements only ever selects 'pending', nothing ever looked at it
// again. Every sale around it synced. The drawer's own opening movement simply
// was not on the server, so it was missing from the Z-report and from the second
// till sharing that register, while the session's own StartingCash still read
// 200 and hid the hole.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';

const int _companyId = 37;
const int _userId = 22;

Future<String> _queueMovement(
  AppDatabase db, {
  required String localId,
  required double amount,
  String type = 'opening',
  String syncStatus = 'pending',
  int? serverId,
}) async {
  await db.into(db.startingCashTable).insert(
        StartingCashTableCompanion.insert(
          localId: localId,
          companyId: _companyId,
          userId: _userId,
          amount: amount,
          type: type,
          createdAt: DateTime.now().toUtc(),
          syncStatus: Value(syncStatus),
          serverId: Value(serverId),
        ),
      );
  return localId;
}

Future<List<String>> _pendingIds(AppDatabase db) async =>
    (await db.getPendingCashMovements()).map((m) => m.localId).toList();

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a transient failure keeps the movement queued for the next sync', () async {
    await _queueMovement(db, localId: 'offline-float', amount: 200);

    await db.markCashMovementRetryable(
      'offline-float',
      'DioException [connection error]: connection refused',
    );

    expect(await _pendingIds(db), contains('offline-float'),
        reason: 'the till was offline — that is the one failure retrying fixes');
  });

  test('the reason is kept, so the sync panel can say why it is still queued', () async {
    await _queueMovement(db, localId: 'offline-float', amount: 200);

    await db.markCashMovementRetryable('offline-float', 'connection refused');

    final row = (await db.getPendingCashMovements())
        .firstWhere((m) => m.localId == 'offline-float');
    expect(row.syncError, 'connection refused');
    expect(row.syncStatus, 'pending');
  });

  test('a server REJECTION stops retrying', () async {
    // The opposite case, and why the terminal state still exists: the request
    // reached the server and it said no. Looping on that forever helps nobody.
    await _queueMovement(db, localId: 'rejected', amount: 50);

    await db.markCashMovementFailed('rejected', 'Session is already closed.');

    expect(await _pendingIds(db), isNot(contains('rejected')));
  });

  test('a failed movement is invisible to the pusher — the trap itself', () async {
    // Pinning the mechanism, not just the policy: 'failed' is a dead end, which
    // is exactly why marking a transient error with it lost the float.
    await _queueMovement(db,
        localId: 'stranded', amount: 200, syncStatus: 'failed');

    expect(await _pendingIds(db), isEmpty);
  });

  test('a synced movement is never pushed twice', () async {
    await _queueMovement(db,
        localId: 'already-there', amount: 200, syncStatus: 'synced', serverId: 12);

    expect(await _pendingIds(db), isEmpty);
  });

  group('the one-time recovery of already-stranded movements', () {
    // Shipping the fix is not enough on its own: the rows that were stranded
    // before it are still sitting at 'failed', and nothing would ever look at
    // them again. Schema v67 re-queues them — but ONLY those the server never
    // accepted, because re-posting an accepted opening float would add a second
    // one and inflate expected cash.
    Future<void> runRecovery(AppDatabase db) => db.customStatement(
          "UPDATE starting_cash SET sync_status = 'pending' "
          "WHERE sync_status = 'failed' AND server_id IS NULL",
        );

    test('re-queues a movement the server never got', () async {
      await _queueMovement(db,
          localId: 'never-arrived', amount: 200, syncStatus: 'failed');

      await runRecovery(db);

      expect(await _pendingIds(db), contains('never-arrived'));
    });

    test('leaves one the server DID accept alone', () async {
      // A server id is the proof it landed. Re-queueing this would post the
      // float a second time.
      await _queueMovement(db,
          localId: 'landed',
          amount: 200,
          syncStatus: 'failed',
          serverId: 12);

      await runRecovery(db);

      expect(await _pendingIds(db), isNot(contains('landed')));
    });

    test('does not disturb movements already synced', () async {
      await _queueMovement(db,
          localId: 'fine', amount: 20, type: 'out', syncStatus: 'synced', serverId: 13);

      await runRecovery(db);

      final row = await (db.select(db.startingCashTable)
            ..where((t) => t.localId.equals('fine')))
          .getSingle();
      expect(row.syncStatus, 'synced');
    });
  });
}
