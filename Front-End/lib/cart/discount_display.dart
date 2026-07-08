import 'package:pos_app/database/app_database.dart';

/// A printer-agnostic discount line for receipts & invoices. Decouples the
/// printing layer from Drift's row type while still carrying everything a
/// printed breakdown needs: a human label, the configured-value hint (kept
/// per-line so % and fixed never merge), and the resolved money taken off.
class ReceiptDiscountLine {
  final String label;
  final String? hint; // "10%", "20 MAD", "5 pts"
  final double amount; // resolved currency amount deducted
  const ReceiptDiscountLine({
    required this.label,
    this.hint,
    required this.amount,
  });
}

/// Human label for a stored discount line, by source.
String discountLineLabel(DiscountLinesTableData l) {
  switch (l.source) {
    case DiscountSource.manualItem:
      return l.label ?? 'Item discount';
    case DiscountSource.manualCart:
      return 'Order discount';
    case DiscountSource.promotion:
      return l.label ?? 'Promotion';
    case DiscountSource.customerProfile:
      return 'Customer discount';
    case DiscountSource.loyaltyPoints:
      return l.label ?? 'Loyalty points';
    default:
      return 'Discount';
  }
}

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Plural aggregate label for a source, for reports ("Promotions", "Loyalty
/// points"). Unlike [discountLineLabel] it never uses a row's custom label.
String discountSourceLabelFor(String source) {
  switch (source) {
    case DiscountSource.manualItem:
      return 'Item discounts';
    case DiscountSource.manualCart:
      return 'Order discounts';
    case DiscountSource.promotion:
      return 'Promotions';
    case DiscountSource.customerProfile:
      return 'Customer discounts';
    case DiscountSource.loyaltyPoints:
      return 'Loyalty points';
    default:
      return 'Other discounts';
  }
}

/// The configured-value hint shown beside a line ("10%", "5 pts"), or null when
/// it would just repeat the amount column. A fixed-amount discount's value
/// equals its resolved amount (e.g. "10 MAD" next to "-10.00 MAD"), so we omit
/// it; only a percentage or a points count adds information worth showing.
String? discountLineHint(DiscountLinesTableData l, String sym) {
  if (l.source == DiscountSource.loyaltyPoints) return '${_fmtNum(l.value)} pts';
  if (l.valueType == 0) return '${_fmtNum(l.value)}%';
  return null; // fixed amount — the amount column already shows it
}

/// Converts persisted discount lines into printable receipt lines, ordered by
/// application sequence. Pass [includeLoyalty] = false on a surface that already
/// shows points redemption separately (the cart receipt does), so it isn't
/// double-counted in the breakdown.
List<ReceiptDiscountLine> toReceiptDiscountLines(
  List<DiscountLinesTableData> lines,
  String sym, {
  bool includeLoyalty = true,
}) {
  final sorted = [...lines]..sort((a, b) => a.sequence.compareTo(b.sequence));
  return [
    for (final l in sorted)
      if (includeLoyalty || l.source != DiscountSource.loyaltyPoints)
        ReceiptDiscountLine(
          label: discountLineLabel(l),
          hint: discountLineHint(l, sym),
          amount: l.amount,
        ),
  ];
}
