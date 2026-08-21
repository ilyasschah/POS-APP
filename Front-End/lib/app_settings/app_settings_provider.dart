import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/device_theme_mode_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/service_type_model.dart';
import 'package:pos_app/app_settings/service_status_model.dart';
import 'package:pos_app/app_settings/booking_settings_model.dart';
import 'package:pos_app/sync/sync_provider.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';
import 'package:pos_app/settings/settings_provider.dart';

/// Streamed from Drift instead of fetched per build. The previous FutureProvider
/// hit `/ApplicationProperties/GetAll` and silently swallowed errors — but
/// Riverpod 3's automatic retry timer kept re-scheduling the failed fetch in
/// the background. With multiple offline-failing FutureProviders, two retry
/// timers could race and trip the "Only one task can be scheduled at a time"
/// assertion in ProviderScope.
///
/// Drift streams don't fail and don't retry, so the storm dies. The SyncManager
/// keeps the rows fresh via `pullAppProperties` whenever network returns.
final rawAppPropertiesProvider = StreamProvider.autoDispose<List<AppProperty>>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.appPropertiesTable)
    ..where((t) => t.companyId.equals(companyId));

  return query.watch().map((rows) => rows.map(AppProperty.fromDrift).toList());
});

class AppSettingsNotifier extends Notifier<Map<String, String>> {
  // Optimistic writes survive build() re-runs triggered by rawAppPropertiesProvider
  // reloads, preventing theme/setting flashes when any setting is saved.
  final Map<String, String> _pendingOverrides = {};

  @override
  Map<String, String> build() {
    final map = Map<String, String>.from(kSettingDefaults);

    // In Riverpod 3.x, setting `state` inside a fireImmediately listener during
    // build() violates the "one task at a time" scheduler rule. Use ref.watch so
    // Riverpod re-runs build() whenever the async source resolves, instead.
    final rawProps = ref.watch(rawAppPropertiesProvider);
    rawProps.whenData((props) {
      for (final p in props) {
        // A device-scoped key arriving from the cloud was set on ANOTHER
        // terminal. Keep it only if it is usable here — a `D:\…` backup path, a
        // Windows print-queue name or a `COM2` on an Android tablet is worse
        // than no value at all, because every consumer then acts on it and
        // fails. Dropping it falls through to the platform-neutral default.
        if (DeviceScopedSettings.isDeviceScoped(p.name)) {
          final usable = DeviceScopedSettings.sanitizeInherited(p.name, p.value);
          if (usable == null) continue;
          map[p.name] = usable;
          continue;
        }
        map[p.name] = p.value;
      }
    });

    // Carry a pre-rename default-tax configuration over to the new key. Done
    // against the RAW rows, not `map`, because kSettingDefaults has already
    // seeded the new key with '' — so "is it empty?" cannot tell an untouched
    // install from an operator who deliberately deselected every tax. The
    // presence of a row can: once the new key has one, it is authoritative,
    // empty or not, and deselecting stops resurrecting the legacy value.
    //
    // Read-only migration on purpose. SyncManager._migrateRenamedSettingKeys
    // does the durable write; this exists so a till that is offline (or never
    // pulls again) keeps its default tax from the very first frame.
    rawProps.whenData((props) {
      final hasNewRow = props.any(
        (p) => p.name == SettingKeys.defaultTaxRateIds,
      );
      if (hasNewRow) return;
      for (final p in props) {
        if (p.name == SettingKeys.legacyDefaultTaxRateIds &&
            p.value.trim().isNotEmpty) {
          map[SettingKeys.defaultTaxRateIds] = p.value;
          break;
        }
      }
    });

    // This terminal's own hardware/filesystem choices outrank anything the
    // cloud carries for the same key — that is the whole point of the layer.
    map.addAll(DeviceScopedSettings.overrides);

    // Re-apply any optimistic writes so the theme/settings don't flash back to
    // defaults while rawAppPropertiesProvider is reloading after a save.
    map.addAll(_pendingOverrides);

    return map;
  }

  String get(String key) => state[key] ?? kSettingDefaults[key] ?? '';

  bool getBool(String key) => get(key).toLowerCase() == 'true';

  bool get serviceTypeEnabled => getBool(SettingKeys.featureServiceTypeEnabled);

  bool get serviceStatusEnabled =>
      getBool(SettingKeys.featureServiceStatusEnabled);

  List<CustomServiceType> get customServiceTypes =>
      CustomServiceType.listFromJson(get(SettingKeys.customServiceTypes));

  List<CustomServiceStatus> get customServiceStatuses =>
      CustomServiceStatus.listFromJson(get(SettingKeys.customServiceStatuses));

  BookingSettingsModel get bookingSettings =>
      BookingSettingsModel.fromJsonStr(get(SettingKeys.bookingSettings));

  Future<void> setBookingSettings(BookingSettingsModel value) =>
      set(SettingKeys.bookingSettings, value.toJsonStr());

  // Tracks the futures of in-flight [set] calls so callers (e.g. the settings
  // "Save & Restart" teardown) can wait for them to fully settle before they
  // mutate/invalidate other providers. Without this, a fire-and-forget save's
  // tail (its Drift write → watched-stream re-emit → this notifier's rebuild)
  // could be scheduled in the same tick as the teardown, tripping Riverpod 3's
  // "Only one task can be scheduled at a time" scheduler assertion.
  final Set<Future<void>> _inFlightWrites = {};

  /// Awaits every in-flight [set] (and any follow-up writes they enqueue), then
  /// yields one microtask so the resulting provider rebuild flushes too. Errors
  /// are swallowed — this is a "settle", not a save.
  Future<void> settle() async {
    while (_inFlightWrites.isNotEmpty) {
      await Future.wait(
        _inFlightWrites.map((f) => f.catchError((_) {})).toList(),
      );
    }
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> set(String key, String value) {
    final future = _set(key, value);
    _inFlightWrites.add(future);
    future.whenComplete(() => _inFlightWrites.remove(future));
    return future;
  }

  Future<void> _set(String key, String value) async {
    _pendingOverrides[key] = value;
    state = {...state, key: value};

    // ⚠️ ORDER IS LOAD-BEARING: the side effects below must run BEFORE the
    // device-scoped early return. `Application.Api.BaseUrl` is device-scoped
    // *and* needs `setApiBaseUrl()` to take effect without a restart — returning
    // first would persist the new endpoint while the running app kept dialling
    // the old one, which is precisely the "why is it still talking to the wrong
    // server" class of bug this whole area is about.

    // Cache theme to SharedPreferences for instant 0ms booting.
    // MUST go through the device notifiers, not setString directly: MyApp reads
    // deviceAccentColorProvider / deviceThemeModeProvider FIRST and only falls
    // back to the cloud setting, so a raw write updates the disk but leaves the
    // notifier holding its old value — the app then keeps rendering the previous
    // theme until the next launch. The notifiers write the same keys.
    if (key == SettingKeys.themeAccentColor) {
      await ref.read(deviceAccentColorProvider.notifier).set(value);
    } else if (key == SettingKeys.themeMode) {
      await ref.read(deviceThemeModeProvider.notifier).set(value);
    } else if (key == SettingKeys.apiBaseUrl) {
      // Per-device connection setting: persist locally + apply immediately so the
      // next createDio() targets the new endpoint (it's not cloud-synced).
      ref.read(sharedPreferencesProvider).setString(kApiBaseUrlPrefKey, value);
      setApiBaseUrl(value);
    }

    // Per-terminal keys stop here: local prefs only, never
    // /ApplicationProperties/*. Pushing a printer queue name, a `D:\` backup
    // path — or this terminal's API endpoint — to the cloud is what sent one
    // machine's settings to every other one.
    if (DeviceScopedSettings.isDeviceScoped(key)) {
      await DeviceScopedSettings.set(
        ref.read(sharedPreferencesProvider),
        key,
        value,
      );
      return;
    }

    final company = ref.read(selectedCompanyProvider);
    if (company == null) return;

    final dio = createDio();
    final db = ref.read(appDatabaseProvider);
    final props = ref.read(rawAppPropertiesProvider).value ?? [];
    final existing = _findProp(props, key);
    // A row only counts as a real server property when it has a positive id.
    // A negative id means it's a temp row we wrote offline for a brand-new key
    // that the server hasn't acknowledged yet.
    final hasServerRow = existing != null && existing.id > 0;
    final rowId = hasServerRow ? existing.id : _tempIdForKey(company.id, key);

    // Optimistic Drift write for BOTH existing and new keys, so the value
    // persists across restart offline-first (the previous code only wrote the
    // Drift row for already-synced keys, so brand-new keys like
    // App.DefaultScreen vanished on restart). New keys get a deterministic
    // temp negative id; pullAppProperties swaps it for the real server id.
    //
    // Stamp `lastModified` with `now.toUtc()` so the next pullAppProperties
    // sees local > server and respects the user's just-made change.
    await db
        .into(db.appPropertiesTable)
        .insertOnConflictUpdate(
          AppPropertiesTableCompanion(
            id: Value(rowId),
            companyId: Value(company.id),
            name: Value(key),
            value: Value(value),
            lastModified: Value(DateTime.now().toUtc()),
            // Pending until the server confirms; the sync engine pushes any
            // 'pending' row on reconnect (handles offline edits too).
            syncStatus: const Value('pending'),
          ),
        );

    try {
      if (hasServerRow) {
        await dio.patch(
          '/ApplicationProperties/Update',
          queryParameters: {'companyId': company.id},
          data: {'id': existing.id, 'newValue': value},
        );
        // Server accepted the edit — clear the pending flag.
        await (db.update(
          db.appPropertiesTable,
        )..where((t) => t.id.equals(rowId))).write(
          const AppPropertiesTableCompanion(syncStatus: Value('synced')),
        );
      } else {
        await dio.post(
          '/ApplicationProperties/Add',
          queryParameters: {'companyId': company.id},
          data: {'name': key, 'value': value},
        );
        // Pull so the row lands in Drift with the server-assigned id; the pull
        // also removes our temp row for this key. Best-effort.
        try {
          await ref.read(syncManagerProvider).pullAppProperties(company.id);
        } catch (_) {
          /* deferred to next sync */
        }
      }
    } on DioException catch (e) {
      // Two cases where we KEEP the local value (offline-first):
      //   • No response → offline. The Drift row (syncStatus 'pending') and the
      //     optimistic value survive; pushPendingAppProperties retries later.
      //   • A brand-new key the server rejected. Destroying a setting the user
      //     just created (e.g. a printer group) because the server hiccuped is
      //     data loss — keep it local + pending and let the sync engine retry.
      //     The local row already carries the correct value, so when
      //     pushPendingAppProperties succeeds it swaps in the real server id.
      if (e.response == null || !hasServerRow) return;

      // A genuine edit to an EXISTING server row was rejected — the server copy
      // is authoritative, so roll back to it.
      _pendingOverrides.remove(key);
      state = {...state, key: existing.value};
      await db
          .into(db.appPropertiesTable)
          .insertOnConflictUpdate(
            AppPropertiesTableCompanion(
              id: Value(existing.id),
              companyId: Value(company.id),
              name: Value(key),
              value: Value(existing.value),
              lastModified: Value(DateTime.now().toUtc()),
              syncStatus: const Value('synced'),
            ),
          );
    }
  }

  /// Deterministic negative id for an offline-only (not-yet-synced) property row.
  /// Derived from (companyId, key) so re-setting the same key updates one row,
  /// never collides with positive server ids, AND never collides across companies
  /// on the `app_properties.id` primary key. (A key-only id threw a UNIQUE
  /// constraint — and, via insertOnConflictUpdate here, could have silently
  /// overwritten another company's row — when a 2nd company seeded the same key.)
  /// MUST stay identical to `SyncManager._seedMissingAppPropertyDefaults` so a
  /// seed + a later edit of the same (company, key) resolve to the same row.
  int _tempIdForKey(int companyId, String key) =>
      -((Object.hash(companyId, key) & 0x7fffffff) + 1);

  Future<void> setBool(String key, bool value) =>
      set(key, value ? 'true' : 'false');

  AppProperty? _findProp(List<AppProperty> props, String key) {
    try {
      return props.firstWhere((p) => p.name == key);
    } catch (_) {
      return null;
    }
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, Map<String, String>>(
      () => AppSettingsNotifier(),
    );
