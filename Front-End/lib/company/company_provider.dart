import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/currency/country_model.dart';
import 'package:pos_app/database/database_provider.dart';

// The currently selected company
class SelectedCompanyNotifier extends Notifier<Company?> {
  @override
  Company? build() => null;

  void update(Company company) {
    state = company;
  }

  void updateLogo(String base64Logo) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(logo: base64Logo);
  }
}

final selectedCompanyProvider =
    NotifierProvider<SelectedCompanyNotifier, Company?>(
        () => SelectedCompanyNotifier());

/// Streams the active company's full row from the Drift `companies` cache.
/// Re-emits whenever pullCompany updates the row (e.g. logo refresh), so
/// receipts and headers reflect the latest cached branding without any
/// manual `ref.invalidate` plumbing.
///
/// Emits `null` while no company is selected OR before the first sync has
/// populated the cache — callers should treat null as "fall back to the
/// lightweight `selectedCompanyProvider` value."
final companyDetailProvider = StreamProvider.autoDispose<Company?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final selectedId = ref.watch(selectedCompanyProvider)?.id;
  if (selectedId == null) return Stream.value(null);

  final query = db.select(db.companiesTable)
    ..where((t) => t.id.equals(selectedId));

  return query
      .watchSingleOrNull()
      .map((row) => row == null ? null : Company.fromDrift(row));
});

// Fetch all companies for the selection screen
final allCompaniesProvider = FutureProvider<List<Company>>((ref) async {
  final dio = createDio();
  final response = await dio.get('/Company/GetAll');
  return (response.data as List).map((j) => Company.fromJson(j)).toList();
});

/// Offline-first: countries stream from the local Drift cache (kept fresh by
/// `SyncManager.pullCountries`). Countries are global reference data (no company
/// scoping), so no companyId filter. `id` maps from `serverId` to match the
/// server-side `Company.countryId` / customer country FKs.
final countriesProvider = StreamProvider<List<Country>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.countriesTable).watch().map(
        (rows) => rows
            .map((r) => Country(id: r.serverId ?? 0, name: r.name, code: r.code))
            .toList(),
      );
});
