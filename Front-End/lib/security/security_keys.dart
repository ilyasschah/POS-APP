/// Canonical key names as configured in the database SecurityKey table.
///
/// Use these constants in every [SecurityGuard.guard] call so that a key
/// rename in the DB only requires updating one line here, not hunting down
/// raw strings across the codebase.
///
/// Level semantics (set by the admin in UsersScreen):
///   0 = Cashier-accessible  (both Cashier and Admin may enter)
///   1 = Admin-only          (only Admin may enter)
abstract final class SecurityKeys {
  // ── Main sidebar ──────────────────────────────────────────────────────────
  static const management     = 'Management';
  static const salesHistory   = 'SalesHistory';
  static const openOrders     = 'Order.All';
  static const endOfDay       = 'BusinessDay.Close';
  static const cashMovement   = 'CashMovement';
  static const creditPayments = 'CreditPayments';
  static const settings       = 'Settings';
  static const loyaltyCards   = 'Management.LoyaltyCards';
  static const shiftManagement = 'ShiftManagement';
  static const bookings        = 'Bookings';
  static const bookingHistory  = 'Bookings.History';
  static const floorPlanView   = 'FloorPlans.View';
  static const userProfile     = 'UserProfile';

  // ── Management sub-screens reached outside the management tab list ─────────
  static const warehouses      = 'Management.Warehouses';
  static const currencies      = 'Management.Currencies';
  static const countries       = 'Management.Countries';

  // ── Sales-floor / document actions (hard-blocked for cashiers w/o the rule)─
  static const orderVoid       = 'Order.Void';
  static const orderItemVoid   = 'Order.Item.Void';
  static const orderTransfer   = 'Order.Transfer';
  static const applyDiscount   = 'Payment.Discount';
  static const taxOverride     = 'Payment.TaxOverride';
  static const refund          = 'Refund';
  static const invoicesDelete  = 'Invoices.Delete';
  static const reprintReceipt  = 'SalesHistory.Receipt';
  static const floorPlanDesign = 'FloorPlans.Design';
}
