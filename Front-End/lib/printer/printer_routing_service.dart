import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/kitchen/printer_group_model.dart';
import 'package:pos_app/printer/printer_config_model.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';

/// Splits an order across the configured **station printers** by printer group.
///
/// A printer becomes a "station" when it has a printer group assigned (its
/// `<prefix>.PrinterGroupId` setting). When an order is sent, each station
/// printer receives a kitchen-style ticket containing ONLY the items whose
/// product category belongs to that station's group — food to the kitchen,
/// drinks to the bar, etc. Reuses the exact same category→group matching the
/// Kitchen Display push uses ([PrinterGroup.productGroupIds] vs a product's
/// `productGroupId`, with the "No category" sentinel for uncategorised items).
class PrinterRoutingService {
  PrinterRoutingService(this.ref);
  final Ref ref;

  /// One kitchen-ticket printer: its settings prefix + the group it serves
  /// (`null` group ⇒ no category filter, prints every item).
  List<({String prefix, PrinterGroup? group})> _stations() {
    final settings = ref.read(appSettingsProvider);
    final printers =
        PrinterConfig.listFromJson(settings[SettingKeys.printersList]);
    final groupById = {
      for (final g
          in PrinterGroup.listFromJson(settings[SettingKeys.kitchenPrinterGroups]))
        g.id: g,
    };
    final out = <({String prefix, PrinterGroup? group})>[];
    for (final p in printers) {
      if (!p.enabled) continue;
      // The "Print kitchen ticket" toggle is what opts a printer in.
      final on = (settings[SettingKeys.rolePrintKitchenTicket(p.prefix)] ?? 'false')
              .toLowerCase() ==
          'true';
      if (!on) continue;
      // Optional category filter. No group ⇒ this printer prints the whole ticket.
      final gid =
          int.tryParse(settings[SettingKeys.rolePrinterGroupId(p.prefix)] ?? '');
      out.add((prefix: p.prefix, group: gid == null ? null : groupById[gid]));
    }
    return out;
  }

  /// True when at least one enabled printer has "Print kitchen ticket" on — i.e.
  /// the Kitchen button should route to stations instead of the legacy single
  /// all-items ticket. (A configured station that matches no item on a given
  /// order simply prints nothing for that order — no fallback in that case.)
  bool get hasKitchenStations => _stations().isNotEmpty;

  /// Prints one kitchen ticket per opted-in printer, each limited to its
  /// category's items (or all items when it has no category). Returns how many
  /// tickets were actually printed.
  Future<int> printStationTickets({
    required List<CartItem> items,
    required String orderNumber,
    required String cashierName,
    required String serviceType,
    String? tableName,
    DateTime? printTime,
    List<List<String>> itemComments = const [],
  }) async {
    final stations = _stations();
    if (stations.isEmpty) return 0;

    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) return 0;

    // productId → its product category (nullable). Authoritative from Drift,
    // same source the KDS push uses.
    final db = ref.read(appDatabaseProvider);
    final products = await (db.select(db.productsTable)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    final categoryOf = {for (final p in products) p.id: p.productGroupId};

    final settings = ref.read(appSettingsProvider);
    final service = ReceiptPrinterService();
    final when = printTime ?? DateTime.now();
    var printed = 0;

    for (final s in stations) {
      // No group ⇒ this printer takes the whole ticket; otherwise only the
      // items whose category is in the group.
      final allowed = s.group?.productGroupIds.toSet();
      final sub = <CartItem>[];
      final subComments = <List<String>>[];
      for (var i = 0; i < items.length; i++) {
        final cat =
            categoryOf[items[i].productId] ?? PrinterGroup.noCategoryId;
        if (allowed == null || allowed.contains(cat)) {
          sub.add(items[i]);
          subComments.add(
              i < itemComments.length ? itemComments[i] : const <String>[]);
        }
      }
      if (sub.isEmpty) continue; // nothing for this station on this order

      final label = s.group == null ? serviceType : '$serviceType · ${s.group!.name}';
      await service.printKitchenTicket(
        orderNumber: orderNumber,
        cashierName: cashierName,
        serviceType: label,
        tableName: tableName,
        printTime: when,
        items: sub,
        itemComments: subComments,
        roleSettings: settings,
        role: s.prefix,
      );
      printed++;
    }
    return printed;
  }
}

final printerRoutingProvider =
    Provider<PrinterRoutingService>((ref) => PrinterRoutingService(ref));
