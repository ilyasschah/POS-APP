// The Sessions LIST — the landing screen for POS Session.
//
// Its whole reason to exist is showing every register's sessions, not just this
// one's: on a two-till shop a list built from local rows only would show half
// the history and read as data loss.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_list_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.utc(2026, 8, 20, 10, 16);

  Future<ShiftsTableData> insert({
    required String localId,
    String? uid,
    String? deviceName,
    int? serverId,
    int status = PosSessionStatus.opened,
    double opening = 5000,
    double? ending,
    double? expected,
  }) async {
    await db.into(db.shiftsTable).insert(
          ShiftsTableCompanion.insert(
            localId: localId,
            companyId: 25,
            userId: 9,
            openedAt: now,
            lastModified: now,
            serverId: Value(serverId),
            posDeviceUid: Value(uid),
            posDeviceName: Value(deviceName),
            startingCash: Value(opening),
            actualEndingCash: Value(ending),
            expectedCash: Value(expected),
            status: Value(status),
            syncStatus: const Value('synced'),
          ),
        );
    return (db.select(db.shiftsTable)
          ..where((t) => t.localId.equals(localId)))
        .getSingle();
  }

  group('what belongs in the list', () {
    test("this device's own session and ANOTHER register's both appear",
        () async {
      await insert(localId: 'mine', uid: 'device-a', deviceName: 'POS1');
      await insert(
          localId: 'srvs_86', deviceName: 'POS 2', serverId: 86,
          status: PosSessionStatus.closed);

      final rows = await (db.select(db.shiftsTable)).get();
      final sessions = rows
          .where((r) => r.posDeviceUid != null || r.posDeviceName != null)
          .toList();
      expect(sessions.length, 2);
    });

    test('an attendance shift is excluded', () async {
      // Same table, different concept — it has neither a device uid nor a name.
      await db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: 'clock-in',
              companyId: 25,
              userId: 9,
              openedAt: now,
              lastModified: now,
              status: const Value(0),
            ),
          );
      final rows = await (db.select(db.shiftsTable)).get();
      final sessions = rows
          .where((r) => r.posDeviceUid != null || r.posDeviceName != null)
          .toList();
      expect(sessions, isEmpty);
    });
  });

  group('the Session ID column', () {
    test('is register + padded number, matching Odoo', () async {
      final s = await insert(
          localId: 'x', uid: 'device-a', deviceName: 'POS1', serverId: 89);
      expect(sessionDisplayId(s), 'POS1/00089');
    });

    test('falls back to the short local id before a number exists', () async {
      // 🚨 An offline session HAS an identity before it is given a number.
      // Showing nothing would make a real session look unsaved.
      final s = await insert(
          localId: 'abcdef12-3456', uid: 'device-a', deviceName: 'POS1');
      expect(sessionDisplayId(s), 'POS1/abcdef12');
      expect(sessionDisplayId(s), isNot(contains('null')));
    });

    test('survives a missing register name', () async {
      final s = await insert(localId: 'y', uid: 'device-a', serverId: 7);
      expect(sessionDisplayId(s), '#00007');
    });
  });

  group('the money columns map to Odoo\'s', () {
    test('Theoretical Closing is our expected cash', () async {
      // Odoo's name, our number — the same figure the closing dialog shows.
      final s = await insert(
          localId: 'z',
          uid: 'device-a',
          deviceName: 'POS1',
          serverId: 89,
          opening: 5000,
          expected: 5167.89);
      expect(s.expectedCash, 5167.89);
      expect(s.startingCash, 5000);
    });

    test('an open session has no ending balance yet', () async {
      final s = await insert(localId: 'open', uid: 'device-a');
      expect(s.actualEndingCash, isNull,
          reason: 'the drawer has not been counted — not the same as zero');
    });
  });

  test('dates render in the list format', () {
    expect(fmtSessionDate(DateTime(2026, 8, 20, 10, 16)), 'Aug 20, 10:16 AM');
    expect(fmtSessionDate(DateTime(2026, 8, 19, 15, 5)), 'Aug 19, 3:05 PM');
    // Midnight and noon are the two the 12-hour clock usually gets wrong.
    expect(fmtSessionDate(DateTime(2026, 8, 19, 0, 30)), 'Aug 19, 12:30 AM');
    expect(fmtSessionDate(DateTime(2026, 8, 19, 12, 0)), 'Aug 19, 12:00 PM');
  });
}
