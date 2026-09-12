// Cash in / cash out must be stamped with the session that was trading.
//
// 🚨 The reported symptom (2026-09-12): the opening float landed on session 33,
// but the cash in and cash out recorded a minute later reached the server with
// SessionId NULL — so the closing count and the Z report both showed
// "Entrée de caisse +0.00 / Sortie de caisse -0.00".
//
// The cash screens read `activeSessionRowProvider`, a second copy of the
// active-session query that nothing kept alive. `ref.read(...).value` at Save
// built it fresh, got AsyncLoading, and wrote `sessionLocalId: null` — while the
// session gate, reading the live original, had just approved the entry.
//
// The screens now watch the one provider in build() and AWAIT it at Save.
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
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/session/session_summary_provider.dart';

const _companyId = 37;
const _register = 'reg-front-till';

class _Settings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {
        ...kSettingDefaults,
        SettingKeys.registerUid: _register,
        SettingKeys.registerName: 'Front Till',
      };
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A terminal with the cash screen open: the screen watches the active
  /// session in build(), which is this listener.
  ProviderContainer cashScreenOpen() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appSettingsProvider.overrideWith(_Settings.new),
    ]);
    c.read(selectedCompanyProvider.notifier)
        .update(Company(id: _companyId, name: 'Test'));
    addTearDown(c.dispose);
    c.listen(activeSessionProvider, (_, __) {});
    return c;
  }

  Future<void> openSession(String localId) =>
      db.into(db.shiftsTable).insert(
            ShiftsTableCompanion.insert(
              localId: localId,
              companyId: _companyId,
              userId: 22,
              openedAt: DateTime.utc(2026, 9, 12, 11, 55),
              lastModified: DateTime.utc(2026, 9, 12, 11, 55),
              startingCash: const Value(100),
              posDeviceUid: const Value(_register),
              status: const Value(PosSessionStatus.opened),
            ),
          );

  test('the summary screens and the gate read ONE active-session provider', () {
    // A second copy of the query is what went stale. If this ever becomes a
    // separate provider again, the cash screens can disagree with the gate.
    expect(identical(activeSessionRowProvider, activeSessionProvider), isTrue);
  });

  test('Save gets the open session, not an unloaded placeholder', () async {
    await openSession('sess-33');
    final c = cashScreenOpen();

    // What Save does, right after the screen opened.
    final session = await c.read(activeSessionProvider.future);

    expect(session?.localId, 'sess-33');
  });

  test('no open session is an honest null', () async {
    final c = cashScreenOpen();

    expect(await c.read(activeSessionProvider.future), isNull);
  });
}
