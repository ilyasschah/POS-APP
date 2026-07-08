import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/currency/currency_model.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/database/database_provider.dart';

/// Offline-first: currencies stream from the local Drift cache (kept fresh by
/// `SyncManager.pullCurrencies`), so dropdowns are populated even offline.
/// `id` maps from `serverId` so it matches server-side currency FKs.
final currenciesProvider = StreamProvider<List<Currency>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.currenciesTable).watch().map(
        (rows) => rows
            .map((r) => Currency(id: r.serverId ?? 0, name: r.name, code: r.code))
            .toList(),
      );
});

final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(appSettingsProvider)[SettingKeys.currencySymbol] ?? '\$';
});
