// Verifies the v39 "full schema clone" migration applied: the 13 new tables
// exist and sample new columns were added to existing tables. Opening the real
// AppDatabase runs the v38->v39 onUpgrade migration on the actual (encrypted) DB.
//   flutter test integration_test/schema_clone_test.dart -d <deviceId>
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pos_app/database/app_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('v39 schema clone: new tables + columns present', (tester) async {
    final db = AppDatabase();

    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final tables = rows.map((r) => (r.data['name'] as String).toLowerCase()).toSet();
    debugPrint('SCHEMA total tables=${tables.length}');

    const newTables = [
      'counters', 'countries', 'currencies', 'document_item_expiration_dates',
      'document_item_taxes', 'fiscal_items', 'pos_printer_selections',
      'pos_printer_selection_settings', 'pos_printer_settings', 'pos_voids',
      'templates', 'user_device_pins', 'z_report_payment_summaries',
    ];
    for (final t in newTables) {
      expect(tables.contains(t), isTrue, reason: 'missing new table: $t');
    }

    Future<Set<String>> cols(String table) async {
      final r = await db.customSelect("PRAGMA table_info('$table')").get();
      return r.map((e) => (e.data['name'] as String).toLowerCase()).toSet();
    }

    final companies = await cols('companies');
    for (final c in ['postal_code', 'country_id', 'email', 'time_zone_id']) {
      expect(companies.contains(c), isTrue, reason: 'companies missing $c');
    }
    final users = await cols('users');
    for (final c in ['password', 'access_level']) {
      expect(users.contains(c), isTrue, reason: 'users missing $c');
    }
    final zr = await cols('z_reports');
    for (final c in ['grand_total', 'total_tax', 'taxable_total']) {
      expect(zr.contains(c), isTrue, reason: 'z_reports missing $c');
    }

    debugPrint('SCHEMA clone verified: all 13 new tables + sample columns present');
    await db.close();
  });
}
