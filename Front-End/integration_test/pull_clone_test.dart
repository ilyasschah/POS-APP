// Verifies the v39 schema-clone PULLS populate the local mirror tables from the
// live API (cloud -> local). Requires the backend reachable at the app's base
// URL and company #18 (Speedsoft) present.
//   flutter test integration_test/pull_clone_test.dart -d windows
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/sync/sync_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('v39 pulls populate the new mirror tables from cloud',
      (tester) async {
    const companyId = 18;
    final db = AppDatabase();
    final sm = SyncManager(db: db, dio: createDio(), authStorage: AuthStorage());

    await sm.pullCountries(companyId);
    await sm.pullCurrencies(companyId);
    await sm.pullCounters(companyId);
    await sm.pullFiscalItems(companyId);
    await sm.pullTemplates(companyId);
    await sm.pullPosVoids(companyId);
    await sm.pullPosPrinterSelections(companyId);
    await sm.pullPosPrinterSelectionSettings(companyId);
    await sm.pullPosPrinterSettings(companyId);
    await sm.pullUserDevicePins(companyId);
    await sm.pullDocumentItemTaxes(companyId);
    await sm.pullDocumentItemExpirationDates(companyId);
    await sm.pullZReportPaymentSummaries(companyId);

    Future<int> count(String table) async {
      final r =
          await db.customSelect('SELECT count(*) AS c FROM $table').getSingle();
      return r.data['c'] as int;
    }

    for (final t in [
      'countries', 'currencies', 'counters', 'fiscal_items', 'templates',
      'pos_voids', 'pos_printer_selections', 'pos_printer_selection_settings',
      'pos_printer_settings', 'user_device_pins', 'document_item_taxes',
      'document_item_expiration_dates', 'z_report_payment_summaries',
    ]) {
      debugPrint('PULL $t=${await count(t)}');
    }

    // Assertions against known seeded data for company #18 / global tables.
    expect(await count('countries'), 69, reason: 'global countries');
    expect(await count('currencies'), greaterThan(0), reason: 'global currencies');
    expect(await count('pos_printer_selections'), 3,
        reason: 'seeded printer selections');
    expect(await count('pos_printer_selection_settings'), 3,
        reason: 'seeded selection settings');
    expect(await count('pos_printer_settings'), 1, reason: 'seeded printer settings');
    expect(await count('user_device_pins'), greaterThan(0),
        reason: 'linked device pin');

    debugPrint('PULL clone verified: cloud rows landed in local mirror tables');
    await db.close();
  });
}
