// The Sessions LIST — the landing screen for POS Session.
//
// Its whole reason to exist is showing every register's sessions, not just this
// one's: on a two-till shop a list built from local rows only would show half
// the history and read as data loss.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/app_date_format.dart';
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

  group('session dates follow the company format', () {
    // 🚨 This test used to assert `Aug 20, 10:16 AM` — a hardcoded English
    // month table and a 12-hour clock baked into `fmtSessionDate`. That WAS the
    // bug: `Application.DateFormat` is a setting, and this list ignored it
    // along with the company's timezone. The assertions are inverted on
    // purpose — what is pinned now is that the format reaches the list, not
    // that one particular shape comes out.
    final at = DateTime.utc(2026, 8, 20, 10, 16);

    test('the chosen pattern is what renders', () {
      expect(
        fmtSessionDate(AppDateFormat('yyyy-MM-dd', timezone: 'Etc/UTC'), at),
        '2026-08-20 10:16',
      );
      expect(
        fmtSessionDate(AppDateFormat('MM/dd/yyyy', timezone: 'Etc/UTC'), at),
        '08/20/2026 10:16',
      );
      expect(
        fmtSessionDate(AppDateFormat('dd/MM/yyyy', timezone: 'Etc/UTC'), at),
        '20/08/2026 10:16',
      );
    });

    test('an opening time is shown in the company timezone', () {
      // A session opened at 23:42 UTC belongs to the NEXT trading day in
      // Casablanca. Getting this wrong files a shift under the wrong date.
      final late = DateTime.utc(2026, 8, 20, 23, 42);
      expect(
        fmtSessionDate(
            AppDateFormat('yyyy-MM-dd', timezone: 'Africa/Casablanca'), late),
        startsWith('2026-08-21'),
      );
    });

    test('midnight and noon still survive the round trip', () {
      // The two the old 12-hour formatter existed to get right; on a 24-hour
      // clock they are unremarkable, which is the point.
      final f = AppDateFormat('dd/MM/yyyy', timezone: 'Etc/UTC');
      expect(fmtSessionDate(f, DateTime.utc(2026, 8, 19, 0, 30)),
          '19/08/2026 00:30');
      expect(fmtSessionDate(f, DateTime.utc(2026, 8, 19, 12, 0)),
          '19/08/2026 12:00');
    });
  });
}
