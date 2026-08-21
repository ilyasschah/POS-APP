import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';

/// The company's barcode nomenclature, read from the local cache.
///
/// Deliberately Drift-backed rather than a network call: a scan happens on the
/// keyboard's Enter key and cannot wait on a round trip, and a shop with no
/// connection still weighs sugar. [refreshBarcodeRules] repopulates the cache
/// from the server; until it has ever run, [kDefaultBarcodeRules] stands in so a
/// fresh install can still scan.
final barcodeRulesProvider = StreamProvider<List<BarcodeRule>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  final query = db.select(db.barcodeRulesTable)
    ..where((t) => t.companyId.equals(companyId))
    ..orderBy([
      (t) => OrderingTerm(expression: t.sequence),
      (t) => OrderingTerm(expression: t.id),
    ]);

  return query.watch().map((rows) {
    // An empty cache is not "this company scans nothing" — it is "we have never
    // pulled". Falling back keeps a fresh or offline-first install usable.
    if (rows.isEmpty) return kDefaultBarcodeRules;

    return rows
        .map((r) => BarcodeRule.fromJson({
              'id': r.id,
              'name': r.name,
              'sequence': r.sequence,
              'type': r.type,
              'encoding': r.encoding,
              'pattern': r.pattern,
              'isEnabled': r.isEnabled,
            }))
        .toList();
  });
});

/// The rules as a plain list, for call sites that cannot await a stream —
/// notably the scan handler, which runs synchronously off a text submit.
///
/// Falls back to the shipped defaults while the stream is still loading.
List<BarcodeRule> readBarcodeRules(WidgetRef ref) =>
    ref.read(barcodeRulesProvider).value ?? kDefaultBarcodeRules;

/// Pulls the nomenclature from the server into the local cache.
///
/// Replaces the cached set wholesale inside one transaction: the rules are an
/// ORDERED list where the first match wins, so a half-applied update could
/// silently decode a scale label with the wrong rule. Failures are swallowed —
/// this runs on startup next to the other master-data pulls, and a POS that
/// cannot reach the server must still open with the rules it already had.
Future<void> refreshBarcodeRules(Ref ref) async {
  final companyId = ref.read(selectedCompanyProvider)?.id;
  if (companyId == null) return;

  try {
    final rules = await ApiClient().getBarcodeRules(companyId);

    // An empty response means the server genuinely has no rules for this
    // company. Clearing the cache would leave the POS on the defaults, which is
    // the correct reading of "not configured" — but only ever act on a response
    // we actually received, never on a failed call.
    final db = ref.read(appDatabaseProvider);
    await db.transaction(() async {
      await (db.delete(db.barcodeRulesTable)
            ..where((t) => t.companyId.equals(companyId)))
          .go();

      for (final rule in rules) {
        await db.into(db.barcodeRulesTable).insert(
              BarcodeRulesTableCompanion(
                id: Value(rule.id),
                companyId: Value(companyId),
                name: Value(rule.name),
                sequence: Value(rule.sequence),
                type: Value(typeToApi(rule.type)),
                encoding: Value(encodingToApi(rule.encoding)),
                pattern: Value(rule.pattern),
                isEnabled: Value(rule.isEnabled),
              ),
            );
      }
    });
  } catch (_) {
    // Offline, or a server too old to have the endpoint. The cache keeps
    // whatever it held, and the defaults cover a first run.
  }
}
