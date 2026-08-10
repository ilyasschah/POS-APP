import 'package:pos_app/app_settings/service_type_model.dart';
import 'package:pos_app/floor_plan/floor_plan_table.dart';

/// The two lookups that decide what a kitchen ticket says about the ORDER, as
/// opposed to its items.
///
/// Extracted out of the menu button so they can be tested: both were previously
/// inline expressions, and both were wrong in a way nothing could catch —
/// a hardcoded English switch for the service type, and a table that reached the
/// kitchen only by accident inside the order number.
abstract final class KitchenTicketData {
  /// The venue's own name for [serviceTypeId].
  ///
  /// 🚨 This used to be `switch (serviceType) { 0 => 'Dine In', 1 => 'Takeaway',
  /// _ => 'Order' }` — hardcoded, English, and ignoring `Pos.CustomServiceTypes`
  /// entirely. It did not even match the shipped defaults ("Dine-In" with a
  /// hyphen), and every type past the first two — Delivery, plus anything the
  /// operator added — printed as the meaningless word "Order". The kitchen
  /// could not tell a delivery from a custom service.
  ///
  /// [fallback] is used only when the id matches no configured type (a stale
  /// order whose service type was later deleted).
  static String serviceLabel(
    List<CustomServiceType> types,
    int serviceTypeId, {
    required String fallback,
  }) {
    for (final t in types) {
      if (t.id == serviceTypeId) {
        final name = t.name.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return fallback;
  }

  /// The table's display name, or null when the order has no table.
  ///
  /// Null — never an empty string or a placeholder — so the caller can omit the
  /// line entirely for takeaway/delivery rather than printing a blank label.
  /// A table id that resolves to nothing (deleted table) is also null: a ticket
  /// saying "Table" with no name is worse than one saying nothing.
  static String? tableName(List<FloorPlanTable> tables, int? tableId) {
    if (tableId == null) return null;
    for (final t in tables) {
      if (t.id == tableId) {
        final name = t.name.trim();
        return name.isEmpty ? null : name;
      }
    }
    return null;
  }
}
