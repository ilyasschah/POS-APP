// The sidebar timer that switched itself on when a REGISTER opened.
//
// Attendance shifts and POS sessions share one `shifts` table on purpose — the
// status ranges (0–1 vs 10–13) are what keep them apart. The separation was
// only ever applied on the session side: every reader in `time_clock_provider`
// selected the company's shift rows with no status filter at all, so opening a
// register wrote a row that the attendance side counted as clocked-in time.
// The visible symptom was the "Today · Xh" badge above User Info appearing with
// nobody clocked in; the expensive one was the same minutes landing in the
// hours report, which is what payroll is read from.
//
// `activeShiftProvider` was never the culprit — it pins `status = 0`, and a
// session is 10–13 — which is exactly why the obvious suspect came up clean.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/shift/shift_provider.dart';
import 'package:pos_app/time_clock/time_clock_provider.dart';

const _companyId = 25;
const _userId = 9;

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    container.read(selectedCompanyProvider.notifier).update(
          Company(id: _companyId, name: 'Test'),
        );
    container.read(currentUserProvider.notifier).setUser(
          User(
            id: _userId,
            companyId: _companyId,
            username: 'cashier',
            accessLevel: 1,
            isEnabled: true,
          ),
        );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  // 🚨 Every read below opens a `container.listen` first. Riverpod tears a
  // provider down the instant a one-off `read` subscription closes, so awaiting
  // a StreamProvider's `.future` on its own races the dispose and the stream
  // never gets to emit. The listeners are closed by `container.dispose()`.

  /// A register opening — status 10, the shape `SessionNotifier.openSession`
  /// writes. Owned by [_userId] because that is the case that breaks: the
  /// person who opened the till is the one whose payroll it lands on.
  Future<void> openRegister({
    String localId = 'sess-1',
    String? deviceUid = 'device-aaa',
    int status = PosSessionStatus.opened,
    required DateTime openedAt,
  }) =>
      db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: localId,
              companyId: _companyId,
              userId: _userId,
              openedAt: openedAt,
              lastModified: openedAt,
              startingCash: const Value(2000),
              posDeviceUid: Value(deviceUid),
              posDeviceName: const Value('POS1'),
              status: Value(status),
              syncStatus: const Value('pending_create'),
            ),
          );

  /// A real clock-in — status 0, no device.
  Future<void> clockIn({
    String localId = 'att-1',
    required DateTime openedAt,
    DateTime? closedAt,
  }) =>
      db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: localId,
              companyId: _companyId,
              userId: _userId,
              openedAt: openedAt,
              lastModified: openedAt,
              closedAt: Value(closedAt),
              status: Value(closedAt == null ? 0 : 1),
              syncStatus: const Value('pending'),
            ),
          );

  /// Today, so the UTC-day window in `todayTotalMinutesProvider` includes it.
  DateTime hoursAgo(int h) =>
      DateTime.now().toUtc().subtract(Duration(hours: h));

  group('the sidebar hours badge', () {
    test('stays at zero when only a register is open', () async {
      await openRegister(openedAt: hoursAgo(3));

      container.listen(todayTotalMinutesProvider, (_, __) {});
      expect(await container.read(todayTotalMinutesProvider.future), 0);
    });

    test('counts a clock-in, and only the clock-in', () async {
      await clockIn(openedAt: hoursAgo(2));
      await openRegister(openedAt: hoursAgo(6));

      container.listen(todayTotalMinutesProvider, (_, __) {});
      final minutes = await container.read(todayTotalMinutesProvider.future);
      // ~120, not ~480. A tolerance because "now" moves between the insert and
      // the read; the point is that the register's six hours are absent.
      expect(minutes, inInclusiveRange(119, 121));
    });

    test('ignores a session pulled from ANOTHER register', () async {
      // 🚨 The reason the filter tests `status`, not `posDeviceUid`.
      // `SyncManager.pullSessions` only carries the uid over for rows this
      // terminal already owns, so another till's session lands with a NULL uid
      // and a uid-based filter would read it as attendance.
      await openRegister(
        localId: 'srvs_77',
        deviceUid: null,
        openedAt: hoursAgo(5),
      );

      container.listen(todayTotalMinutesProvider, (_, __) {});
      expect(await container.read(todayTotalMinutesProvider.future), 0);
    });
  });

  group('the hours report', () {
    test('does not bill a register\'s trading day to whoever opened it',
        () async {
      await db.into(db.usersTable).insert(
            UsersTableCompanion.insert(
              id: const Value(_userId),
              companyId: _companyId,
              name: 'cashier',
              username: const Value('cashier'),
              lastModified: DateTime.now().toUtc(),
            ),
          );
      await openRegister(openedAt: hoursAgo(8));

      final HoursQueryParams params = (
        rangeStart: hoursAgo(48),
        rangeEnd: DateTime.now().toUtc(),
        userId: null,
        companyId: _companyId,
      );
      // No attendance rows at all → the report has nobody to list. A session
      // leaking through would produce one row of eight hours.
      container.listen(hoursReportProvider(params), (_, __) {});
      container.listen(shiftSessionsProvider(params), (_, __) {});
      expect(await container.read(hoursReportProvider(params).future), isEmpty);
      expect(
        await container.read(shiftSessionsProvider(params).future),
        isEmpty,
      );
    });
  });

  group('the shift dashboard', () {
    test('lists clock-ins but not trading periods', () async {
      await clockIn(openedAt: hoursAgo(4), closedAt: hoursAgo(1));
      await openRegister(openedAt: hoursAgo(4));

      container.listen(shiftHistoryProvider, (_, __) {});
      final history = await container.read(shiftHistoryProvider.future);
      expect(history.map((s) => s.localId), ['att-1']);
    });
  });

  group('the discriminator itself', () {
    test('every session status is a session, every shift status is not', () {
      for (final s in [
        PosSessionStatus.openingControl,
        PosSessionStatus.opened,
        PosSessionStatus.closingControl,
        PosSessionStatus.closed,
      ]) {
        expect(PosSessionStatus.isSession(s), isTrue, reason: 'status $s');
      }
      expect(PosSessionStatus.isSession(0), isFalse); // attendance, open
      expect(PosSessionStatus.isSession(1), isFalse); // attendance, closed
      expect(PosSessionStatus.firstStatus, PosSessionStatus.openingControl);
    });
  });
}
