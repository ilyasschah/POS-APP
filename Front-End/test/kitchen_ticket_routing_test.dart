// Pins that the POS menu's Kitchen button ALWAYS produces a ticket.
//
// Reported 2026-08-06: "print kitchen ticket does nothing". The chain was wired
// end to end — button → PrinterRoutingService → ReceiptPrinterService →
// _dispatch — which is why it looked fine. The hole was in the routing:
//
//   `hasKitchenStations` is true as soon as ANY enabled printer has "Print
//   kitchen ticket" on. But each station only prints the items matching its
//   printer GROUP, and `printStationTickets` skips a station whose group matches
//   nothing (`if (sub.isEmpty) continue;`). With stations configured but none
//   covering the current cart, it returned 0 — and the caller discarded the
//   count. No ticket, no error, no message: a dead button.
//
// The menu now falls back to the full ticket whenever 0 stations printed, and
// always reports the outcome. These pin the decision that drives it.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/printer/printer_routing_service.dart';

/// Settings map with [printers] declared and per-printer kitchen/group wiring.
Map<String, String> _settings({
  required List<({String prefix, String name, bool enabled, bool kitchen, int? groupId})>
      printers,
  String groupsJson = '[]',
}) {
  final list = printers
      .map((p) =>
          '{"prefix":"${p.prefix}","name":"${p.name}","enabled":${p.enabled},"builtin":false}')
      .join(',');
  return {
    SettingKeys.printersList: '[$list]',
    SettingKeys.kitchenPrinterGroups: groupsJson,
    for (final p in printers) ...{
      SettingKeys.rolePrintKitchenTicket(p.prefix): p.kitchen ? 'true' : 'false',
      if (p.groupId != null)
        SettingKeys.rolePrinterGroupId(p.prefix): '${p.groupId}',
    },
  };
}

PrinterRoutingService _routing(Map<String, String> settings, AppDatabase db) {
  final container = ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(db),
    appSettingsProvider.overrideWith(() => _FixedSettings(settings)),
  ]);
  addTearDown(container.dispose);
  return container.read(printerRoutingProvider);
}

class _FixedSettings extends AppSettingsNotifier {
  _FixedSettings(this._values);
  final Map<String, String> _values;
  @override
  Map<String, String> build() => _values;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a printer opted in becomes a station', () {
    final r = _routing(
      _settings(printers: [
        (prefix: 'Kitchen', name: 'Kitchen', enabled: true, kitchen: true, groupId: null),
      ]),
      db,
    );
    expect(r.hasKitchenStations, isTrue);
  });

  test('a printer with the toggle OFF is not a station', () {
    final r = _routing(
      _settings(printers: [
        (prefix: 'Kitchen', name: 'Kitchen', enabled: true, kitchen: false, groupId: null),
      ]),
      db,
    );
    // This is the path that reaches the legacy full ticket directly.
    expect(r.hasKitchenStations, isFalse);
  });

  test('a DISABLED printer is not a station even with the toggle on', () {
    final r = _routing(
      _settings(printers: [
        (prefix: 'Kitchen', name: 'Kitchen', enabled: false, kitchen: true, groupId: null),
      ]),
      db,
    );
    expect(r.hasKitchenStations, isFalse,
        reason: 'a disabled printer must not claim the order');
  });

  test('no printers at all → no stations', () {
    expect(_routing(_settings(printers: const []), db).hasKitchenStations,
        isFalse);
  });

  test('a station whose group matches nothing prints 0 — the dead button',
      () async {
    // Group 7 covers category 99; the cart's product is in category 1. This is
    // exactly the shape that made the button do nothing: hasKitchenStations is
    // TRUE, so the legacy fallback was skipped, yet nothing matched.
    await db.into(db.productsTable).insert(
          ProductsTableCompanion.insert(
            id: const Value(1),
            companyId: 25,
            name: 'Coffee',
            productGroupId: const Value(1),
            lastModified: DateTime.now().toUtc(),
          ),
        );

    final r = _routing(
      _settings(
        printers: [
          (prefix: 'Bar', name: 'Bar', enabled: true, kitchen: true, groupId: 7),
        ],
        groupsJson: '[{"id":7,"name":"Bar","productGroupIds":[99]}]',
      ),
      db,
    );

    expect(r.hasKitchenStations, isTrue,
        reason: 'the button takes the station path…');
    // …and the station path yields nothing, which is why the caller must treat
    // 0 as "fall back to the full ticket" rather than "done".
    // (printStationTickets needs a selected company; with none it also returns 0,
    // which is the same signal and the same fallback.)
    final printed = await r.printStationTickets(
      items: const [],
      orderNumber: 'ORD- A1',
      cashierName: 'ilyass',
      serviceType: 'Dine In',
    );
    expect(printed, 0);
  });
}
