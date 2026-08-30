// Two terminals, one till, one session.
//
// 🚨 The reported symptom (2026-08-29): "I couldn't use the session that's open
// on device A from device B." A session was keyed by the TERMINAL's own GUID, so
// every device silently created a register of its own on first open — device B
// could see A's session in the list and never sell into it.
//
// The fix is the REGISTER (Odoo's `pos.config`): a named till that several
// terminals may work at once. `session/register_identity.dart` holds the uid,
// `SyncManager.pullSessions` carries A's session to B stamped with it, and
// `activeSessionProvider` matches on it.
//
// These tests pin the join itself — the query that decides whether B is selling
// into A's session or merely looking at it.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/register_identity.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

const _companyId = 25;
const _frontTill = 'reg-front-till';
const _terrace = 'reg-terrace';

/// The register this simulated terminal is pointed at. `appSettingsProvider` is
/// the real read path for it, so faking the map is the whole of "device B is
/// configured for the front till".
class _SettingsFor extends AppSettingsNotifier {
  _SettingsFor(this.registerUid, this.registerName);
  final String registerUid;
  final String registerName;

  @override
  Map<String, String> build() => {
        ...kSettingDefaults,
        SettingKeys.registerUid: registerUid,
        SettingKeys.registerName: registerName,
      };
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer terminalOn(String registerUid, {String name = 'Front Till'}) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appSettingsProvider.overrideWith(() => _SettingsFor(registerUid, name)),
    ]);
    c.read(selectedCompanyProvider.notifier)
        .update(Company(id: _companyId, name: 'Test'));
    addTearDown(c.dispose);
    return c;
  }

  /// A session as `SyncManager.pullSessions` writes it onto a SECOND terminal:
  /// the opener's `localId`, the register's uid, and `synced` so the pull does
  /// not fight a local edit.
  Future<void> pulledSession({
    String localId = 'sess-from-device-a',
    required String registerUid,
    int status = PosSessionStatus.opened,
    int serverId = 77,
  }) =>
      db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: localId,
              companyId: _companyId,
              userId: 4, // opened by device A's cashier
              openedAt: DateTime.utc(2026, 8, 29, 9),
              lastModified: DateTime.utc(2026, 8, 29, 9),
              serverId: Value(serverId),
              startingCash: const Value(2000),
              posDeviceUid: Value(registerUid),
              posDeviceName: const Value('Front Till'),
              status: Value(status),
              syncStatus: const Value('synced'),
            ),
          );

  Future<ShiftsTableData?> activeOn(ProviderContainer c) {
    c.listen(activeSessionProvider, (_, __) {});
    return c.read(activeSessionProvider.future);
  }

  group('a session opened on device A', () {
    test('is device B\'s ACTIVE session once B works the same register',
        () async {
      await pulledSession(registerUid: _frontTill);

      final b = terminalOn(_frontTill);
      final session = await activeOn(b);

      expect(session, isNotNull,
          reason: 'B must sell into the till it is working, not open a second '
              'session on the same drawer');
      expect(session!.localId, 'sess-from-device-a',
          reason: 'the OPENER\'s localId travels, so every order B rings points '
              'at the same identity A\'s orders do');
      expect(PosSessionStatus.canSell(session.status), isTrue);
    });

    test('stays invisible to a terminal working a DIFFERENT register', () async {
      // The other half of the rule. Two tills with two drawers must not see one
      // another's session, or one register's cash lands in the other's count.
      await pulledSession(registerUid: _frontTill);

      expect(await activeOn(terminalOn(_terrace)), isNull);
    });

    test('a closed session is not active anywhere', () async {
      await pulledSession(
          registerUid: _frontTill, status: PosSessionStatus.closed);

      expect(await activeOn(terminalOn(_frontTill)), isNull);
    });
  });

  group('closing a joined session', () {
    test('is queued for push, even though this terminal never opened it',
        () async {
      // 🚨 `getPendingSessions` requires a non-null `posDeviceUid`. Before the
      // pull carried the register's uid that column was null on every foreign
      // row, so B's close was written locally and never left the device — the
      // session stayed open on the server for ever.
      await pulledSession(registerUid: _frontTill);
      final b = terminalOn(_frontTill);
      final session = (await activeOn(b))!;

      final notifier = b.read(sessionNotifierProvider.notifier);
      await notifier.enterClosingControl(
          localId: session.localId, expectedCash: 2500);
      await notifier.closeSession(
        localId: session.localId,
        closedByUserId: 9, // B's cashier, not A's
        expectedCash: 2500,
        countedCash: 2500,
        closingNote: null,
      );

      final pending = await db.getPendingSessions();
      expect(pending.map((s) => s.localId), contains('sess-from-device-a'));

      final row = pending.firstWhere((s) => s.localId == 'sess-from-device-a');
      expect(row.status, PosSessionStatus.closed);
      expect(row.closedByUserId, 9,
          reason: 'who closed it is the point of asking');
    });

    test('a second terminal cannot open a parallel session on the same till',
        () async {
      // One live session per REGISTER. Two would mean two Z-reports for one
      // drawer, which no count can reconcile afterwards.
      await pulledSession(registerUid: _frontTill);
      final b = terminalOn(_frontTill);

      expect(
        () => b.read(sessionNotifierProvider.notifier).openSession(
              companyId: _companyId,
              userId: 9,
              deviceUid: _frontTill,
              deviceName: 'Front Till',
            ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('the register setting itself', () {
    test('never travels to another terminal', () {
      // The one setting that MUST differ between two devices on one account —
      // cloud-syncing it would drag every terminal onto the same till, which is
      // the opposite of the feature.
      expect(DeviceScopedSettings.isDeviceScoped(SettingKeys.registerUid),
          isTrue);
      expect(DeviceScopedSettings.isDeviceScoped(SettingKeys.registerName),
          isTrue);
    });

    test('unset means "this device on its own", not "broken"', () {
      // The pre-registers behaviour, kept so no existing install has to be
      // migrated or reconfigured.
      final c = terminalOn('', name: '');
      expect(c.read(registerIsExplicitProvider), isFalse);

      final chosen = terminalOn(_frontTill);
      expect(chosen.read(registerIsExplicitProvider), isTrue);
    });
  });
}
