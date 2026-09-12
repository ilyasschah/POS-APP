// Pins how a finished sync is reported. A change the server REFUSED is always
// shown; a failure the operator asked about is always shown; a BACKGROUND
// failure is shown once, not on every 30-second auto-sync.
//
// Why it exists: this listener used to live inside SyncButton, in the POS
// sidebar DRAWER — which is not built while closed. So a refused tax delete
// was never shown anywhere; the reason lived only in the API log.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/sync/sync_manager.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/sync/sync_outcome_listener.dart';
import 'package:pos_app/sync/sync_provider.dart';

class _FakeSettings extends AppSettingsNotifier {
  _FakeSettings([this.extra = const {}]);
  final Map<String, String> extra;

  @override
  Map<String, String> build() => {...kSettingDefaults, ...extra};
}

class _FakeSyncManager extends Fake implements SyncManager {
  List<String> notices = const [];

  @override
  List<String> get rejectionNotices => notices;
}

class _FakeSyncNotifier extends SyncNotifier {
  bool? manual;

  @override
  bool? get lastRunWasManual => manual;

  void start({required bool isManual}) {
    manual = isManual;
    state = const AsyncLoading();
  }

  void end(AsyncValue<List<String>> outcome) => state = outcome;
}

void main() {
  late _FakeSyncManager manager;
  late _FakeSyncNotifier sync;

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    Map<String, String> settings = const {},
  }) async {
    manager = _FakeSyncManager();
    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWith(() => _FakeSettings(settings)),
        syncManagerProvider.overrideWithValue(manager),
        syncStateProvider.overrideWith(_FakeSyncNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SyncOutcomeListener()),
        ),
      ),
    );
    // Let the notifier's own first build leave loading.
    await tester.pump();
    sync = container.read(syncStateProvider.notifier) as _FakeSyncNotifier;
    return AppLocalizations.of(tester.element(find.byType(SyncOutcomeListener)));
  }

  Future<void> run(
    WidgetTester tester,
    AsyncValue<List<String>> outcome, {
    bool manual = false,
  }) async {
    sync.start(isManual: manual);
    await tester.pump();
    sync.end(outcome);
    await tester.pump();
  }

  // Lets the toast's own timer run out and its entry leave the overlay, so the
  // next assertion sees only what the NEXT run reported.
  Future<void> clearToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
  }

  testWidgets('a change the server refused is shown after a background sync',
      (tester) async {
    await pump(tester);
    manager.notices = [
      'Tax "TVA 20" couldn\'t be deleted — 3 product(s) use it',
    ];

    await run(tester, const AsyncData([]));

    expect(find.textContaining('couldn\'t be deleted'), findsOneWidget);
    await clearToasts(tester);
  });

  testWidgets('a background failure is reported once, not on every run',
      (tester) async {
    await pump(tester);

    await run(tester, const AsyncData(['taxes']));
    expect(find.textContaining('taxes'), findsOneWidget);
    await clearToasts(tester);

    await run(tester, const AsyncData(['taxes']));
    expect(find.textContaining('taxes'), findsNothing);
    await clearToasts(tester);
  });

  testWidgets('a sync the operator asked for always gets its answer',
      (tester) async {
    await pump(tester);

    await run(tester, const AsyncData(['taxes']));
    await clearToasts(tester);

    await run(tester, const AsyncData(['taxes']), manual: true);
    expect(find.textContaining('taxes'), findsOneWidget);
    await clearToasts(tester);
  });

  testWidgets('after a clean run the same failure is news again',
      (tester) async {
    await pump(tester);

    await run(tester, const AsyncData(['taxes']));
    await clearToasts(tester);
    await run(tester, const AsyncData([]));
    await clearToasts(tester);

    await run(tester, const AsyncData(['taxes']));
    expect(find.textContaining('taxes'), findsOneWidget);
    await clearToasts(tester);
  });

  testWidgets('the notifier settling at sign-in is not a sync finishing',
      (tester) async {
    final l = await pump(
      tester,
      settings: {SettingKeys.autoSyncShowNotification: 'true'},
    );
    // No run has started: nothing to report, not even "Sync complete".
    expect(find.text(l.syncComplete), findsNothing);

    await run(tester, const AsyncData([]));
    expect(find.text(l.syncComplete), findsOneWidget);
    await clearToasts(tester);
  });
}
