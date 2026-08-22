import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/database/device_key_service.dart';
import 'package:pos_app/database/restore_service.dart';
import 'package:pos_app/document/document_type_constants.dart';

part 'app_database.g.dart';

// ============================================================================
// MASTER DATA — server-assigned `id` is the PK. `lastModified` is the per-row
// watermark we compare against `modifiedAfter` on delta pulls.
// ============================================================================

@TableIndex(name: 'idx_products_group_id', columns: {#productGroupId})
@TableIndex(name: 'idx_products_barcode',  columns: {#barcode})
class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  RealColumn get price => real().withDefault(const Constant(0))();
  RealColumn get cost => real().withDefault(const Constant(0))();
  TextColumn get barcode => text().nullable()();
  IntColumn get productGroupId => integer().nullable()();
  BoolColumn get isService => boolean().withDefault(const Constant(false))();
  TextColumn get colorHex => text().nullable()();

  // Plan constraint: images live on disk, NEVER as BlobColumn.
  // Holds the absolute file path returned by ImageCacheService.
  TextColumn get localImagePath => text().nullable()();

  // ---- Schema v2 additions (Phase 3.5) ----
  // Every new column is nullable OR has a default so the onUpgrade migration
  // (m.addColumn) succeeds on existing rows without backfill SQL.
  TextColumn get code => text().nullable()();
  IntColumn get plu => integer().nullable()();
  TextColumn get measurementUnit => text().nullable()();
  TextColumn get description => text().nullable()();
  RealColumn get markup => real().nullable()();
  IntColumn get rank => integer().withDefault(const Constant(0))();
  IntColumn get currencyId => integer().nullable()();
  IntColumn get ageRestriction => integer().nullable()();
  RealColumn get lastPurchasePrice => real().nullable()();
  DateTimeColumn get dateCreated => dateTime().nullable()();
  DateTimeColumn get dateUpdated => dateTime().nullable()();
  BoolColumn get isPriceChangeAllowed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isUsingDefaultQuantity =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isTaxInclusivePrice =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get lastModified => dateTime()();

  // ---- Schema v12 additions ----
  // Offline CRUD queue: 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  // ---- Schema v61 additions: sell by weight ----
  // Id into the hardcoded UnitOfMeasure catalog (lib/uom/unit_of_measure.dart).
  // Defaults to 1 (pieces), which converts 1:1 and so cannot disturb the stock
  // figures an existing install already holds.
  IntColumn get uomId => integer().withDefault(const Constant(1))();

  // Sold by weight — drives the POS scale/keypad flow and the Price button.
  BoolColumn get isToWeigh => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
  BlobColumn get image => blob().nullable()();
  TextColumn get color => text().nullable()();
}

class TaxesTable extends Table {
  @override
  String get tableName => 'taxes';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  RealColumn get rate => real()();

  // ---- Schema v2 additions (Phase 3.5) ----
  TextColumn get code => text().nullable()();
  BoolColumn get isFixed => boolean().withDefault(const Constant(false))();
  BoolColumn get isTaxOnTotal => boolean().withDefault(const Constant(true))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  DateTimeColumn get lastModified => dateTime()();

  // ---- Schema v40: offline-first CRUD ----
  // Drives the local-write outbox: 'synced' | 'pending_create' |
  // 'pending_update' | 'pending_delete'. Offline-created rows use a temp
  // negative id until pushPendingTaxOps swaps in the server id.
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class FloorPlansTable extends Table {
  @override
  String get tableName => 'floor_plans';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('Transparent'))();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FloorPlanTablesTable extends Table {
  @override
  String get tableName => 'floor_plan_tables';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  IntColumn get floorPlanId => integer()();
  TextColumn get name => text()();
  RealColumn get positionX => real()();
  RealColumn get positionY => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  BoolColumn get isRound => boolean().withDefault(const Constant(false))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastModified => dateTime()();
  // Offline CRUD queue: 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  // pending_create rows hold a temp negative id until the server assigns the real one.
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Forwarding addresses for floor-plan tables that were created offline.
///
/// A table created offline holds a temp negative id until sync assigns the real
/// one. Rows already referencing it are rewritten in the same transaction (see
/// [AppDatabase.remapFloorPlanTableRefs]) — but the in-memory cart holds that id
/// too, and it is NOT a row: tapping a table writes nothing, the order is only
/// materialised at checkout. A cart opened before the sync would therefore
/// persist a dead id afterwards. This table keeps the temp→real link so a late
/// writer can still resolve it — see [AppDatabase.resolveFloorPlanTableId].
class FloorPlanTableIdMapTable extends Table {
  @override
  String get tableName => 'floor_plan_table_id_map';

  IntColumn get tempId => integer()();
  IntColumn get realId => integer()();
  IntColumn get companyId => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tempId};
}

class UsersTable extends Table {
  @override
  String get tableName => 'users';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  // Combined display name kept for backward compat with old rows that
  // predate the firstName/lastName/username/email columns (added v18).
  TextColumn get name => text()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get username => text().nullable()();
  TextColumn get email => text().nullable()();

  // Plan rule: only ever store the hash. The C# /Users/GetAll endpoint
  // must serve `pinHash`, NEVER the raw password.
  TextColumn get pinHash => text().nullable()();

  IntColumn get role => integer().withDefault(const Constant(0))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get password => text().nullable()();
  IntColumn get accessLevel => integer().nullable()();
}

class AppPropertiesTable extends Table {
  @override
  String get tableName => 'app_properties';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();

  /// 'synced' once the server has the current value; 'pending' after an offline
  /// edit so the sync engine knows to push it on reconnect.
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PHASE 3.6 — REMAINING MASTER ENTITIES (schema v4)
// These were originally deferred. Adding them so the offline POS screen
// doesn't hang on the four still-API-backed providers.
// ============================================================================

class SecurityKeysTable extends Table {
  @override
  String get tableName => 'security_keys';

  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  // 0 = Cashier-accessible, 1 = Admin-only (matches server SecurityKey.Level)
  IntColumn get level => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {companyId, name};
}

class ProductGroupsTable extends Table {
  @override
  String get tableName => 'product_groups';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  IntColumn get parentGroupId => integer().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('Transparent'))();
  IntColumn get rank => integer().withDefault(const Constant(0))();
  // Disk-cached icon path. ImageSyncHelper writes the file under
  // <docs>/group_images/<id>.jpg during pullProductGroups; nothing else
  // touches binary data.
  TextColumn get localImagePath => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get color => text().nullable()();
  BlobColumn get image => blob().nullable()();
}

class PaymentTypesTable extends Table {
  @override
  String get tableName => 'payment_types';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  BoolColumn get isCustomerRequired =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isFiscal => boolean().withDefault(const Constant(false))();
  BoolColumn get isSlipRequired =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isChangeAllowed =>
      boolean().withDefault(const Constant(false))();
  IntColumn get ordinal => integer().withDefault(const Constant(0))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isQuickPayment =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get openCashDrawer =>
      boolean().withDefault(const Constant(false))();
  TextColumn get shortcutKey => text().nullable()();
  BoolColumn get markAsPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastModified => dateTime()();

  // ---- Schema v41: offline-first CRUD (see TaxesTable.syncStatus) ----
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomersTable extends Table {
  @override
  String get tableName => 'customers';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get code => text().nullable()();
  TextColumn get name => text()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get postalCode => text().nullable()();
  TextColumn get city => text().nullable()();
  IntColumn get countryId => integer().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isCustomer => boolean().withDefault(const Constant(true))();
  BoolColumn get isSupplier => boolean().withDefault(const Constant(false))();
  IntColumn get dueDatePeriod => integer().nullable()();
  TextColumn get streetName => text().nullable()();
  TextColumn get additionalStreetName => text().nullable()();
  TextColumn get buildingNumber => text().nullable()();
  TextColumn get plotIdentification => text().nullable()();
  TextColumn get citySubdivisionName => text().nullable()();
  BoolColumn get isTaxExempt => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastModified => dateTime()();
  // Offline CRUD queue: 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  DateTimeColumn get dateCreated => dateTime().nullable()();
  DateTimeColumn get dateUpdated => dateTime().nullable()();
}

/// Single-row-per-id cache so receipts render with the real company name,
/// address, tax number, phone, and logo when offline. Lean schema — only
/// the fields the receipt printer / receipt header actually use. Logo lives
/// on disk via ImageSyncHelper (Phase 1 "images on disk, never in SQLite"
/// rule) — `localLogoPath` is the absolute file path.
class CompaniesTable extends Table {
  @override
  String get tableName => 'companies';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get localLogoPath => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get postalCode => text().nullable()();
  TextColumn get city => text().nullable()();
  IntColumn get countryId => integer().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  BlobColumn get logo => blob().nullable()();
  TextColumn get bankAccountNumber => text().nullable()();
  TextColumn get bankDetails => text().nullable()();
  TextColumn get streetName => text().nullable()();
  TextColumn get additionalStreetName => text().nullable()();
  TextColumn get buildingNumber => text().nullable()();
  TextColumn get plotIdentification => text().nullable()();
  TextColumn get citySubdivisionName => text().nullable()();
  TextColumn get countrySubentity => text().nullable()();
  TextColumn get timeZoneId => text().nullable()();

  // ---- Schema v43: offline-first edits ('synced' | 'pending_update') ----
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
}

/// Per-product comment suggestions (e.g. "no onions", "extra cheese") used
/// by the menu grid's tap dialog. Pulled in bulk via /ProductComments/GetAll.
class ProductCommentsTable extends Table {
  @override
  String get tableName => 'product_comments';

  IntColumn get id => integer()();          // positive = server id; negative = temp local id
  IntColumn get companyId => integer()();
  IntColumn get productId => integer()();
  TextColumn get comment => text()();
  DateTimeColumn get lastModified => dateTime()();
  // 'synced' | 'pending_create' | 'pending_delete'. pending_create rows use a
  // negative temp id until pushPendingProductCommentOps swaps in the server id.
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class PromotionsTable extends Table {
  @override
  String get tableName => 'promotions';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  IntColumn get daysOfWeek => integer().withDefault(const Constant(127))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get startDate => dateTime().nullable()();
  TextColumn get startTime => text().nullable()(); // "HH:mm:ss"
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get endTime => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PromotionItemsTable extends Table {
  @override
  String get tableName => 'promotion_items';

  IntColumn get id => integer()();          // positive = server id; negative = temp local id
  IntColumn get promotionId => integer()();
  IntColumn get productId => integer()();
  IntColumn get discountType => integer().withDefault(const Constant(0))();
  IntColumn get priceType => integer().withDefault(const Constant(0))();
  RealColumn get value => real().withDefault(const Constant(0))();
  BoolColumn get isConditional => boolean().withDefault(const Constant(false))();
  RealColumn get quantity => real().withDefault(const Constant(1))();
  IntColumn get conditionType => integer().withDefault(const Constant(0))();
  RealColumn get quantityLimit => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
  IntColumn get uid => integer().nullable()();
  IntColumn get companyId => integer().nullable()();
}

// ============================================================================
// TRANSACTION DATA — created offline-first. `localId` (UUID v4) is the PK so
// the row is referenceable BEFORE the server assigns `serverId`. `syncStatus`
// drives the push pipeline: pending → synced | failed.
// ============================================================================

@TableIndex(name: 'idx_pos_orders_sync_status', columns: {#syncStatus})
@TableIndex(name: 'idx_pos_orders_status',      columns: {#status})
class PosOrdersTable extends Table {
  @override
  String get tableName => 'pos_orders';

  TextColumn get localId => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  IntColumn get tableId => integer().nullable()();
  IntColumn get serviceType => integer()();
  IntColumn get serviceStatus => integer().withDefault(const Constant(0))();
  TextColumn get orderName => text().nullable()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  RealColumn get total => real().nullable()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  // 0 = Percentage, 1 = Fixed — mirrors CartState.manualCartDiscountType.
  IntColumn get discountType => integer().withDefault(const Constant(0))();
  IntColumn get warehouseId => integer()();

  // ---- Schema v3 (Phase 4) — checkout finalisation fields ----
  // Required by Phase 5 to POST the completed order to /PosOrder/Checkout.
  // Nullable so the migration succeeds on existing v2 rows (none exist yet
  // in practice — pos_orders is brand-new — but the constraint keeps the
  // upgrade path correct for any draft rows that slipped in).
  IntColumn get paymentTypeId => integer().nullable()();
  RealColumn get amountPaid => real().nullable()();
  IntColumn get customerId => integer().nullable()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get syncError => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {localId};
  TextColumn get number => text().nullable()();
  IntColumn get floorPlanTableId => integer().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get dateCreated => dateTime().nullable()();

  // ---- Schema v54 — the booking this order was opened from ----
  // Local-only mirror of the server's one-directional Booking.PosOrderId link,
  // which can't be used offline: it holds a server int, and an order created
  // offline has no server id until it syncs. Without these, a saved order lost
  // its booking entirely — the bookings screen kept offering "Start Service"
  // (creating a SECOND order) and reopening from the floor plan dropped the
  // booking header down to the bare table name.
  //
  // Deliberately NOT pushed: the BatchSync payload is built field-by-field and
  // the server still links booking→order itself from the checkout request, so
  // these stay a local concern.
  IntColumn get bookingId => integer().nullable()();
  IntColumn get bookingStaffId => integer().nullable()();

  /// Newest line's server-side DateCreated, mirrored from
  /// `PosOrderDto.ItemsLastChanged`. Written only by [syncOpenOrdersToDrift] so
  /// it can tell that another terminal edited this order's CONTENTS in a way
  /// that moves neither `total` nor the item count (e.g. swapping a product for
  /// one at the same price). Null on locally-created orders and on any row
  /// pulled from an API build that predates the field.
  DateTimeColumn get itemsLastChanged => dateTime().nullable()();
  /// The POS session this belongs to, by the session's CLIENT localId.
  ///
  /// 🚨 The localId, never the server id. A sale rung up offline belongs to a
  /// session that may itself not have reached the server yet, so the only
  /// stable handle at write time is the client UUID — exactly why
  /// `pos_order_items.orderId` references `pos_orders.localId`. The push
  /// resolves it to a server session id; the local row keeps the UUID.
  TextColumn get sessionLocalId => text().nullable()();

}

@TableIndex(name: 'idx_pos_order_items_order_id', columns: {#orderId})
class PosOrderItemsTable extends Table {
  @override
  String get tableName => 'pos_order_items';

  TextColumn get localId => text()();
  TextColumn get orderId =>
      text().references(PosOrdersTable, #localId, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  IntColumn get discountType => integer().withDefault(const Constant(0))();
  RealColumn get taxRate => real().withDefault(const Constant(0))();
  // JSON-encoded per-item applied taxes: [{"id":1,"amount":2.50}]
  // Null when the item has no taxes. Used by SyncManager to populate
  // CheckoutItemDto.Taxes so DocumentItemTax rows are created server-side.
  TextColumn get taxesJson => text().nullable()();
  TextColumn get comment => text().nullable()();
  IntColumn get warehouseId => integer()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {localId};
  IntColumn get posOrderId => integer().nullable()();
  IntColumn get roundNumber => integer().nullable()();
  RealColumn get price => real().nullable()();
  BoolColumn get isLocked => boolean().nullable()();
  BoolColumn get isFeatured => boolean().nullable()();
  IntColumn get voidedBy => integer().nullable()();
  DateTimeColumn get dateCreated => dateTime().nullable()();
  TextColumn get bundle => text().nullable()();
  IntColumn get discountAppliedType => integer().nullable()();
  IntColumn get companyId => integer().nullable()();
  // The per-item discount as the operator ENTERED it (value + type: 10 + 0 = "10%")
  // while `discount` holds the resolved per-unit money. Null = not recorded → the
  // cart falls back to `discount`. Carries the input form across tills for an OPEN
  // order, where discount_lines don't cross until checkout.
  RealColumn get discountInputValue => real().nullable()();
  IntColumn get discountInputType => integer().nullable()();

  /// Whether [unitPrice] already CONTAINS this line's taxes, pinned from the
  /// product at the moment the order was parked.
  ///
  /// Deliberately stored rather than re-read from the product on reopen: an
  /// admin editing the product's tax mode must not silently reprice an order
  /// that is already sitting on a table. Null = a row written before this
  /// column existed → the cart falls back to `true`, matching the
  /// `Product.IsTaxInclusivePrice` default on both databases.
  BoolColumn get isTaxInclusive => boolean().nullable()();
}

// Offline tax breakdown — one row per item × tax-rate per saved order.
// Populated inside saveOpenOrder so the receipt and sync paths have itemised
// tax amounts without re-computing them from CartItem state.
@TableIndex(name: 'idx_pos_order_item_taxes_order_id', columns: {#orderId})
class PosOrderItemTaxesTable extends Table {
  @override
  String get tableName => 'pos_order_item_taxes';

  TextColumn get localId => text()();
  TextColumn get orderId =>
      text().references(PosOrdersTable, #localId, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer()();
  IntColumn get taxRateId => integer()();
  RealColumn get taxAmount => real()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {localId};
  IntColumn get posOrderItemId => integer().nullable()();
  IntColumn get taxId => integer().nullable()();
  IntColumn get companyId => integer().nullable()();
}

/// Local mirror of the server's `StartingCash` table (cash in / out).
/// Named to match the SQL Server entity; the physical SQLite table follows
/// the local snake_case convention (`starting_cash`).
class StartingCashTable extends Table {
  @override
  String get tableName => 'starting_cash';

  TextColumn get localId => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'in' | 'out'
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Server Z-report number (mirrors `StartingCash.ZReportNumber`). NULL while
  /// the entry is active/unfinalized; once a Z-report is generated the server
  /// stamps this and the next pull hides the row from the active list.
  IntColumn get zReportNumber => integer().nullable()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
  TextColumn get description => text().nullable()();
  IntColumn get startingCashType => integer().nullable()();
  DateTimeColumn get dateCreated => dateTime().nullable()();
  /// The POS session this belongs to, by the session's CLIENT localId.
  ///
  /// 🚨 The localId, never the server id. A sale rung up offline belongs to a
  /// session that may itself not have reached the server yet, so the only
  /// stable handle at write time is the client UUID — exactly why
  /// `pos_order_items.orderId` references `pos_orders.localId`. The push
  /// resolves it to a server session id; the local row keeps the UUID.
  TextColumn get sessionLocalId => text().nullable()();

}

class ZReportsTable extends Table {
  @override
  String get tableName => 'z_reports';

  TextColumn get localId => text()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  RealColumn get totalSales => real()();
  RealColumn get totalCashIn => real()();
  RealColumn get totalCashOut => real()();
  TextColumn get paymentBreakdownJson => text()(); // serialized JSON map
  DateTimeColumn get closedAt => dateTime()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
  IntColumn get number => integer().nullable()();
  IntColumn get fromDocumentId => integer().nullable()();
  IntColumn get toDocumentId => integer().nullable()();
  DateTimeColumn get dateCreated => dateTime().nullable()();
  RealColumn get totalReturns => real().nullable()();
  RealColumn get discountsGranted => real().nullable()();
  RealColumn get taxableTotal => real().nullable()();
  RealColumn get totalTax => real().nullable()();
  RealColumn get grandTotal => real().nullable()();
  // v53. The report is closed over documents that may never have been synced,
  // so the server-int range above ([fromDocumentId]/[toDocumentId]) cannot be
  // filled offline. These hold the device-local answer instead: how many
  // documents were closed, and the `YY-CCC-NNNNNN` number range they span.
  IntColumn get documentCount => integer().nullable()();
  TextColumn get fromDocumentNumber => text().nullable()();
  TextColumn get toDocumentNumber => text().nullable()();
}

/// One Close-Register snapshot, aggregated from the local DB by
/// [AppDatabase.aggregateUnreportedForZReport]. Every figure is derived from the
/// same document set, so the printed slip reconciles:
/// `taxableTotal + totalTax == totalSales - totalReturns`.
class ZReportAggregates {
  final int documentCount;
  /// Device-local `YY-CCC-NNNNNN` range; null when no document carried a number.
  final String? fromDocumentNumber;
  final String? toDocumentNumber;
  final double totalSales;
  final double totalReturns;
  final double discountsGranted;
  final double taxableTotal;
  final double totalTax;
  /// What actually hit the drawer: the summed tender, refunds already netted.
  final double grandTotal;

  const ZReportAggregates({
    required this.documentCount,
    required this.fromDocumentNumber,
    required this.toDocumentNumber,
    required this.totalSales,
    required this.totalReturns,
    required this.discountsGranted,
    required this.taxableTotal,
    required this.totalTax,
    required this.grandTotal,
  });

  static const empty = ZReportAggregates(
    documentCount: 0,
    fromDocumentNumber: null,
    toDocumentNumber: null,
    totalSales: 0,
    totalReturns: 0,
    discountsGranted: 0,
    taxableTotal: 0,
    totalTax: 0,
    grandTotal: 0,
  );
}

// ============================================================================
// STOCKS — local mirror of server Stock rows.
// Pulled during every master-data sync and deducted locally at checkout so
// the UI shows accurate quantities even while offline.
// ============================================================================

class StocksTable extends Table {
  @override
  String get tableName => 'stocks';

  IntColumn get id => integer()();              // server-assigned id
  IntColumn get productId => integer()();
  IntColumn get warehouseId => integer()();
  IntColumn get companyId => integer()();
  RealColumn get quantity =>
      real().withDefault(const Constant(0))();
  DateTimeColumn get lastModified => dateTime()();
  // Offline-first CRUD: 'synced' | 'pending_create' | 'pending_update' |
  // 'pending_delete'. pending_create rows use a negative temp id until the
  // server assigns a real one.
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PENDING VOIDS — offline queue for voided orders.
// When a cashier voids an order offline the PosOrder row is deleted locally
// and the void details are queued here. SyncManager pushes the queue to
// POST /PosVoids/Add and DELETE /PosOrder/Delete when connectivity returns.
// ============================================================================

class PendingVoidsTable extends Table {
  @override
  String get tableName => 'pending_voids';

  TextColumn get localId => text()();            // UUID — local PK
  IntColumn get serverOrderId => integer()();    // server PosOrder.Id
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  TextColumn get orderNumber => text()();
  IntColumn get warehouseId => integer()();
  // JSON-encoded list of void items (same shape as the /PosVoids/Add params).
  TextColumn get itemsJson => text()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get voidedAt => dateTime()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {localId};
}

// ============================================================================
// DOCUMENTS — offline sales receipts.
// Created locally at checkout; serverId + number filled in after BatchSync
// confirms the server Document was created.  Pulled from server on every
// sync so documents from other devices appear in local history.
// ============================================================================

class DocumentsTable extends Table {
  @override
  String get tableName => 'documents';

  TextColumn get localId => text()();              // UUID — local PK (= PosOrder localId)
  IntColumn get serverId => integer().nullable()(); // server Document.Id — null until synced
  IntColumn get companyId => integer()();
  IntColumn get documentTypeId => integer().withDefault(const Constant(2))(); // 2 = Sales
  TextColumn get number => text().nullable()();    // server-assigned document number
  IntColumn get userId => integer()();
  IntColumn get warehouseId => integer()();
  RealColumn get total => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  IntColumn get discountType => integer().withDefault(const Constant(0))();
  IntColumn get customerId => integer().nullable()();
  TextColumn get orderNumber => text().nullable()();
  IntColumn get serviceType => integer().withDefault(const Constant(0))();
  IntColumn get paidStatus => integer().withDefault(const Constant(1))(); // 1=paid, 0=unpaid
  // True when paidStatus was changed locally (offline-first toggle in the
  // document editor) and still needs pushing to the server. Cleared by
  // SyncManager.pushPendingPaidStatus once the PATCH succeeds.
  BoolColumn get paidStatusDirty =>
      boolean().withDefault(const Constant(false))();
  // Editable header fields kept locally so the offline-first manual editor can
  // round-trip them (display on reopen + push to /Document on sync).
  DateTimeColumn get stockDate => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get internalNote => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get referenceDocumentNumber => text().nullable()();
  // Refund-only (document_type_id 4): retained so SyncManager.pushPendingRefundOps
  // can rebuild the /Document/Refund payload from the local rows — the refund
  // outbox now lives entirely in Drift (no shared_preferences queue).
  BoolColumn get isBlind => boolean().withDefault(const Constant(false))();
  IntColumn get approvedByUserId => integer().nullable()();
  BoolColumn get discountApplyRule =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get date => dateTime()();
  // 'pending' until BatchSync confirms Document on server; 'synced' after.
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastModified => dateTime()();

  @override
  Set<Column> get primaryKey => {localId};
  BoolColumn get isClockedOut => boolean().nullable()();
  DateTimeColumn get dateCreated => dateTime().nullable()();
  DateTimeColumn get dateUpdated => dateTime().nullable()();
  /// The POS session this belongs to, by the session's CLIENT localId.
  ///
  /// 🚨 The localId, never the server id. A sale rung up offline belongs to a
  /// session that may itself not have reached the server yet, so the only
  /// stable handle at write time is the client UUID — exactly why
  /// `pos_order_items.orderId` references `pos_orders.localId`. The push
  /// resolves it to a server session id; the local row keeps the UUID.
  TextColumn get sessionLocalId => text().nullable()();

}

class DocumentItemsTable extends Table {
  @override
  String get tableName => 'document_items';

  TextColumn get localId => text()();
  // FK → documents.localId; cascade so deleting a Document removes its items.
  TextColumn get documentId =>
      text().references(DocumentsTable, #localId,
          onDelete: KeyAction.cascade)();
  // server DocumentItem.Id — null until the editor-added item is pushed.
  IntColumn get serverId => integer().nullable()();
  IntColumn get productId => integer()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();              // price incl. tax
  RealColumn get priceBeforeTax => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  IntColumn get discountType => integer().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get taxAmount => real().withDefault(const Constant(0))();
  // Selected tax for offline-first editor items; pushed to /DocumentItemTaxes.
  IntColumn get taxId => integer().nullable()();
  RealColumn get taxRate => real().withDefault(const Constant(0))();
  DateTimeColumn get expirationDate => dateTime().nullable()();
  // Checkout items use 'synced' implicitly (pushed with their order). Editor
  // items use: 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'.
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {localId};
  RealColumn get expectedQuantity => real().nullable()();
  RealColumn get price => real().nullable()();
  RealColumn get productCost => real().nullable()();
  RealColumn get priceBeforeTaxAfterDiscount => real().nullable()();
  RealColumn get priceAfterDiscount => real().nullable()();
  RealColumn get totalAfterDocumentDiscount => real().nullable()();
  BoolColumn get discountApplyRule => boolean().nullable()();
  IntColumn get companyId => integer().nullable()();
}

class PaymentsTable extends Table {
  @override
  String get tableName => 'payments';

  TextColumn get localId => text()();
  // server Payment.Id — null until the standalone payment is pushed, or for
  // checkout payments that travel inside the order BatchSync. Set when a
  // server payment is pulled or a local 'pending_create' is confirmed.
  IntColumn get serverId => integer().nullable()();
  // FK → documents.localId
  TextColumn get documentId =>
      text().references(DocumentsTable, #localId,
          onDelete: KeyAction.cascade)();
  IntColumn get paymentTypeId => integer()();
  RealColumn get amount => real()();
  IntColumn get userId => integer()();
  DateTimeColumn get date => dateTime()();
  // Non-null once the payment belongs to a closed Z-report — such payments are
  // locked (cannot be edited or deleted) in the document editor.
  IntColumn get zReportId => integer().nullable()();
  // Checkout payments inserted by insertOfflineDocument use 'pending' (pushed
  // with their order). Editor-added payments use the standalone CRUD states:
  // 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'.
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {localId};
  DateTimeColumn get dateCreated => dateTime().nullable()();
  IntColumn get companyId => integer().nullable()();
  /// The POS session this belongs to, by the session's CLIENT localId.
  ///
  /// 🚨 The localId, never the server id. A sale rung up offline belongs to a
  /// session that may itself not have reached the server yet, so the only
  /// stable handle at write time is the client UUID — exactly why
  /// `pos_order_items.orderId` references `pos_orders.localId`. The push
  /// resolves it to a server session id; the local row keeps the UUID.
  TextColumn get sessionLocalId => text().nullable()();

}

/// Discrete origin of a [DiscountLinesTable] row. Stored as text in
/// `discount_lines.source` so reports can filter ("how much promo this month")
/// and receipts can label each deduction by where it came from.
class DiscountSource {
  static const manualItem = 'manual_item';        // per-product manual discount
  static const manualCart = 'manual_cart';        // whole-order manual discount
  static const promotion = 'promotion';           // active promotion on a product
  static const customerProfile = 'customer_profile'; // customer's saved discount
  static const loyaltyPoints = 'loyalty_points';  // points redeemed for money off

  static const all = [
    manualItem,
    manualCart,
    promotion,
    customerProfile,
    loyaltyPoints,
  ];

  /// Sources applied to the WHOLE order — they are NOT baked into any item's
  /// stored total (unlike [manualItem] and [promotion], which are reflected in
  /// each item's price/total). The document total subtracts only these on top
  /// of the item subtotal; subtracting an item-baked source here double-counts.
  ///
  /// Use this instead of `itemLocalId == null`: pulled-back lines all come back
  /// with a null itemLocalId (the server keys by ProductId), so the column is
  /// not a reliable item-vs-order discriminator — the source is.
  static const orderLevel = <String>{manualCart, customerProfile, loyaltyPoints};
}

// ============================================================================
// DISCOUNT LINES — one normalized row per applied discount, so every source
// (manual item / manual cart / promotion / customer profile / loyalty points)
// is recorded discretely instead of being squeezed into the single header/item
// `discount` slot. Percentages are NEVER summed: each line keeps its own
// [value] + [valueType] for display ("10%" / "−20 MAD"); only the resolved
// [amount] (company currency) is additive. Offline-first: written locally with
// a pending `sync_status`, pushed alongside its parent order/document.
// ============================================================================
class DiscountLinesTable extends Table {
  @override
  String get tableName => 'discount_lines';

  TextColumn get localId => text()();              // UUID — local PK
  IntColumn get companyId => integer()();
  // Parent links. A checkout shares one localId across the order AND the
  // document, so a single line can point at both. At least one is set.
  TextColumn get orderLocalId => text().nullable()();
  TextColumn get documentLocalId => text().nullable()();
  // Set for an item-level discount (matches a pos_order_items / document_items
  // localId); null for a whole-order/document-level discount.
  TextColumn get itemLocalId => text().nullable()();
  // One of [DiscountSource]. Drives reports + receipt labelling.
  TextColumn get source => text()();
  // promotionId / customerId / loyaltyCardId / productId — for traceability.
  IntColumn get sourceRefId => integer().nullable()();
  // Configured value as entered (e.g. 10) and its type: 0 = %, 1 = fixed.
  RealColumn get value => real().withDefault(const Constant(0))();
  IntColumn get valueType => integer().withDefault(const Constant(0))();
  // The resolved money actually taken off, in company currency. The ONLY field
  // that may be summed across lines.
  RealColumn get amount => real().withDefault(const Constant(0))();
  // Application order, so the stacking sequence can be replayed exactly.
  IntColumn get sequence => integer().withDefault(const Constant(0))();
  // Optional display label for receipts (promo name, "Loyalty points", …).
  TextColumn get label => text().nullable()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastModified => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
}

// ============================================================================
// BARCODES — per-product barcode list.
// Seeded from /Barcodes/GetByProductId when the product editor opens.
// Adds and deletes are written locally first with a pending syncStatus so
// they appear immediately in the UI and SyncManager pushes them on next sync.
// ============================================================================

// ============================================================================
// BARCODE RULES — the company's barcode nomenclature.
// Cached locally because the POS has to decode a scale label while offline: a
// scan cannot wait on a round trip, and a shop with no connection still weighs
// sugar. Read-only on this side — the settings screen edits it through the API
// and the next pull overwrites the cache, so there is no syncStatus column.
// ============================================================================
class BarcodeRulesTable extends Table {
  @override
  String get tableName => 'barcode_rules';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();

  /// Ascending evaluation order — first match wins.
  IntColumn get sequence => integer()();

  /// 'Unit' | 'Weighted' | 'Priced' | 'Discounted'.
  TextColumn get type => text()();

  /// 'Any' | 'Ean13' | 'UpcA'.
  TextColumn get encoding => text()();

  TextColumn get pattern => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class BarcodesTable extends Table {
  @override
  String get tableName => 'barcodes';

  TextColumn get localId => text()();           // UUID — local PK
  IntColumn get serverId => integer().nullable()(); // null until synced
  IntColumn get productId => integer()();
  IntColumn get companyId => integer()();
  TextColumn get value => text()();
  // 'synced' | 'pending_create' | 'pending_delete'
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {localId};
}

// ============================================================================
// CUSTOMER DISCOUNTS — per-customer discount rules.
// Cached locally so the edit form works offline. syncStatus drives the push
// pipeline for CRUD ops the same way as products/customers.
// ============================================================================

@TableIndex(name: 'idx_customer_discounts_customer_id', columns: {#customerId})
class CustomerDiscountsTable extends Table {
  @override
  String get tableName => 'customer_discounts';

  IntColumn get id => integer()();            // positive = server id; negative = temp local id
  IntColumn get companyId => integer()();
  IntColumn get customerId => integer()();
  IntColumn get type => integer().withDefault(const Constant(0))();   // 0=percentage, 1=fixed
  IntColumn get uid => integer().withDefault(const Constant(0))();
  RealColumn get value => real().withDefault(const Constant(0))();
  DateTimeColumn get lastModified => dateTime()();
  // 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// LOYALTY CARDS — per-customer points cards, offline-first.
// `id` is positive (server-assigned) once synced; negative while pending_create.
// `syncStatus` drives pushPendingLoyaltyCardOps in SyncManager.
// ============================================================================

@TableIndex(name: 'idx_loyalty_cards_customer_id', columns: {#customerId})
@TableIndex(name: 'idx_loyalty_cards_sync_status', columns: {#syncStatus})
class LoyaltyCardsTable extends Table {
  @override
  String get tableName => 'loyalty_cards';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  IntColumn get customerId => integer()();
  TextColumn get cardNumber => text().nullable()();
  RealColumn get points => real().withDefault(const Constant(0))();
  DateTimeColumn get lastModified => dateTime()();
  // 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TIME CLOCK ENTRIES — offline-first employee attendance tracking.
// Completely separate from cash drawer / shift management.
// One row = one clock-in event. clockOutTime is null while the employee is
// still clocked in.  syncStatus drives pushPendingTimeClockEntries.
// ============================================================================

@TableIndex(name: 'idx_time_clock_user_id',    columns: {#userId})
@TableIndex(name: 'idx_time_clock_sync_status', columns: {#syncStatus})
class TimeClockEntriesTable extends Table {
  @override
  String get tableName => 'time_clock_entries';

  TextColumn get localId => text()();               // UUID — local PK
  IntColumn get serverId => integer().nullable()(); // null until synced
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  DateTimeColumn get clockInTime => dateTime()();
  DateTimeColumn get clockOutTime => dateTime().nullable()();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
  DateTimeColumn get lastModified => dateTime().nullable()();
}

// ============================================================================
// SHIFTS — offline-first cashier shift tracking.
// One row per shift. status: 0=Open, 1=Closed.
// syncStatus drives pushPendingShifts in SyncManager.
// ============================================================================

@TableIndex(name: 'idx_shifts_company_status', columns: {#companyId, #status})
class ShiftsTable extends Table {
  @override
  String get tableName => 'shifts';

  TextColumn get localId => text()();           // UUID — local PK
  IntColumn get serverId => integer().nullable()(); // null until synced
  IntColumn get companyId => integer()();
  IntColumn get userId => integer()();
  RealColumn get startingCash => real().withDefault(const Constant(0))();
  RealColumn get actualEndingCash => real().nullable()();
  IntColumn get status => integer().withDefault(const Constant(0))(); // 0=Open, 1=Closed
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  DateTimeColumn get lastModified => dateTime()();

  /// Distinguishes the station's master cash-drawer shift (true) from bare
  /// per-employee attendance sessions (false). Lets many servers clock in for
  /// hours simultaneously on one station without colliding with the single
  /// drawer shift. Local-only differentiation flag.
  BoolColumn get isDrawerShift =>
      boolean().withDefault(const Constant(false))();

  // ── POS SESSION (schema v58) ───────────────────────────────────────────
  // A row with `posDeviceUid != null` is a POS SESSION — the trading period of
  // one register. A row without it is an attendance shift, untouched by all of
  // this. Same discriminator the backend uses (`Shift.PosDeviceId != null`).
  //
  // 🚨 The DEVICE UID is stored, not the server's PosDevice.Id, and that is the
  // whole point: a session opened with no connectivity has never seen a server
  // id, and the terminal's GUID is something it always knows. The server maps
  // uid → PosDevice on push.
  TextColumn get posDeviceUid => text().nullable()();

  /// The register's display name ("POS1"). Stored on the row rather than looked
  /// up, because the session list shows OTHER devices' sessions too and this
  /// terminal only knows its own name.
  TextColumn get posDeviceName => text().nullable()();

  // Session status reuses `status` with PosSessionStatus values 10–13, kept
  // deliberately disjoint from the attendance 0/1 in the same column so no
  // query can confuse a closed shift with a trading register.
  IntColumn get closedByUserId => integer().nullable()();
  RealColumn get expectedCash => real().nullable()();
  RealColumn get cashDifference => real().nullable()();
  TextColumn get closingNote => text().nullable()();

  /// Free text from the Opening Control screen.
  TextColumn get openingNote => text().nullable()();
  BoolColumn get forceClosed => boolean().withDefault(const Constant(false))();
  IntColumn get forceClosedByUserId => integer().nullable()();
  TextColumn get forceCloseReason => text().nullable()();

  /// A sale belonging to this session reached the server after it closed.
  BoolColumn get hasLateArrivals =>
      boolean().withDefault(const Constant(false))();

  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
}

// ============================================================================
// BOOKINGS — reservations / appointments. Pulled from the server with a
// FULL-REPLACE strategy each sync (the calendar must reflect deletes and the
// dataset is small). Reads stream from here so the calendar renders offline;
// writes still go through the API then trigger a re-pull, mirroring the
// floor-plan provider pattern. `tableIdsJson` holds the assigned floor-plan
// table id list as a JSON array.
// ============================================================================

/// What a booking reserves, for [AppDatabase.findConflictingBookings].
///
/// Maps from `BookingSettingsModel.resourceMode`, which has THREE values: both
/// 'table' and 'room' reserve floor-plan tables and collapse to [table] here —
/// they are the same physical thing under two labels — while 'staff' reserves a
/// person.
enum BookingResource { table, staff }

@TableIndex(name: 'idx_bookings_company_start', columns: {#companyId, #startTime})
class BookingsTable extends Table {
  @override
  String get tableName => 'bookings';

  IntColumn get id => integer()();              // server-assigned id
  IntColumn get companyId => integer()();
  IntColumn get customerId => integer().nullable()();
  IntColumn get userId => integer().nullable()();
  TextColumn get reservationName => text().withDefault(const Constant(''))();
  TextColumn get tableIdsJson => text().withDefault(const Constant('[]'))();
  IntColumn get documentId => integer().nullable()();
  IntColumn get posOrderId => integer().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get guestCount => integer().withDefault(const Constant(1))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get lastModified => dateTime()();
  // Offline-first queue: 'synced' | 'pending_create' | 'pending_update' |
  // 'pending_delete'. pending_create rows use a temp NEGATIVE id until the
  // server assigns the real one (mirrors warehouses/taxes).
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // Legacy/unused column kept to avoid a destructive table-recreation
  // migration; real table membership lives in [tableIdsJson].
  TextColumn get tableIds => text().nullable()();
}

// ============================================================================
// WAREHOUSES — offline-first stock locations. Pulled from the server and also
// created/edited/deleted locally with a `syncStatus` queue (pending_create uses
// a temp NEGATIVE id until the server assigns a real one — same pattern as
// products/customers).
// ============================================================================

class WarehousesTable extends Table {
  @override
  String get tableName => 'warehouses';

  IntColumn get id => integer()();              // positive = server id; negative = temp local
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  DateTimeColumn get lastModified => dateTime()();
  // 'synced' | 'pending_create' | 'pending_update' | 'pending_delete'
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  TextColumn get syncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// PENDING STOCK OPS — offline queue for the stock reassign/revoke that happens
// when a warehouse holding stock is deleted. `operation`: 'delete' | 'move'.
// `stockId` is always a server id (we only mutate already-synced stock rows
// here). SyncManager drains this via pushPendingStockOps BEFORE pullStocks.
// ============================================================================

class PendingStockOpsTable extends Table {
  @override
  String get tableName => 'pending_stock_ops';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()();          // 'delete' | 'move'
  IntColumn get companyId => integer()();
  IntColumn get stockId => integer()();          // server Stock.Id
  IntColumn get targetWarehouseId => integer().nullable()(); // move: destination
  RealColumn get quantity => real().nullable()();            // move: newQuantity
  IntColumn get productId => integer().nullable()();         // move: newProductId
}

// ============================================================================
// SYNC METADATA — one row per entity; holds the watermark we send as
// `modifiedAfter` on the next delta pull.
// ============================================================================

class SyncMetaTable extends Table {
  @override
  String get tableName => 'sync_meta';

  // Renamed from `entityName` — Drift's TableInfo base class already exposes
  // `entityName` (the SQL table name), and a column getter with the same name
  // is a hard override conflict.
  TextColumn get entity => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}

// ============================================================================
// PENDING USER & SECURITY-KEY OPS — offline write queue.
// Rows are written when toggle / edit / security-key changes hit a network
// error. SyncManager drains this table via pushPendingUserOps() on every sync.
// 'operation' values: 'toggle_user' | 'update_user' | 'update_security_key'
// ============================================================================

class PendingUserOpsTable extends Table {
  @override
  String get tableName => 'pending_user_ops';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()();
  IntColumn get companyId => integer()();
  TextColumn get payload => text()(); // JSON-encoded op params
}

// ============================================================================
// DOCUMENT TYPES & CATEGORIES — pull-only master data that drives the document
// editor's "Select document type" picker. Cached locally so a document can be
// created entirely offline. DocumentType is global; DocumentCategory is
// company-scoped.
// ============================================================================

class DocumentTypesTable extends Table {
  @override
  String get tableName => 'document_types';

  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  IntColumn get documentCategoryId => integer().nullable()();
  // Mirrors the server's DocumentType.StockDirection so the app can reason about
  // a type's inventory direction offline (0 = none, 1 = add, 2 = deduct).
  IntColumn get stockDirection => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastModified => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  IntColumn get editorType => integer().nullable()();
  TextColumn get printTemplate => text().nullable()();
  IntColumn get priceType => integer().nullable()();
  TextColumn get languageKey => text().nullable()();
}

class DocumentCategoriesTable extends Table {
  @override
  String get tableName => 'document_categories';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  DateTimeColumn get lastModified => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  TextColumn get languageKey => text().nullable()();
}

// Per-product stock-control rule (reorder point, low-stock warning). The
// backend only exposes GetByProductId (no bulk pull), so this is cached lazily:
// the provider reads here and a background fetch upserts the row when online.
class StockControlsTable extends Table {
  @override
  String get tableName => 'stock_controls';

  IntColumn get productId => integer()();           // PK — one rule per product
  IntColumn get companyId => integer()();
  IntColumn get serverId => integer().nullable()();
  RealColumn get reorderPoint => real().withDefault(const Constant(0))();
  RealColumn get preferredQuantity => real().withDefault(const Constant(0))();
  BoolColumn get isLowStockWarningEnabled =>
      boolean().withDefault(const Constant(true))();
  RealColumn get lowStockWarningQuantity =>
      real().withDefault(const Constant(0))();
  // Optional preferred supplier for reordering (products-screen rules editor).
  IntColumn get customerId => integer().nullable()();
  DateTimeColumn get lastModified => dateTime().nullable()();
  // Offline-first CRUD state. 'synced' for pulled rows; pending_* for local
  // edits awaiting push. (serverId stays null for a pending_create until synced.)
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {productId};
}

// Per-product tax assignment (productId ↔ taxId). Cached so the product editor
// shows/sets the assigned tax offline. Pull-seeded by pullProductTaxes; edits
// queue via syncStatus and push to /ProductTaxes/Add+Delete.
class ProductTaxesTable extends Table {
  @override
  String get tableName => 'product_taxes';

  IntColumn get productId => integer()();
  IntColumn get taxId => integer()();
  IntColumn get companyId => integer()();
  // 'synced' | 'pending_create' | 'pending_delete'
  TextColumn get syncStatus =>
      text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {productId, taxId};
}

// Void reasons — pull-only master data so the void dialog (during checkout)
// and the admin list work offline.
class VoidReasonsTable extends Table {
  @override
  String get tableName => 'void_reasons';

  IntColumn get id => integer()();
  IntColumn get companyId => integer()();
  TextColumn get name => text()();
  IntColumn get rank => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastModified => dateTime().nullable()();

  // ---- Schema v42: offline-first CRUD (see TaxesTable.syncStatus) ----
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
  DateTimeColumn get dateCreated => dateTime().nullable()();
}

// ============================================================================
// DATABASE
// ============================================================================

// ===== Schema-clone v39: full mirror of remaining online tables =====
class CountersTable extends Table {
  @override
  String get tableName => 'counters';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get value => integer()();
  IntColumn get companyId => integer()();
}

/// DEVICE-LOCAL document-number counters. Never synced (the server-pulled
/// `counters` table is full-replaced on every sync, so it can't hold a local
/// sequence). One row per (companyId + document-type code); `value` is the last
/// issued sequence. Drives offline document numbers of the form
/// `<DeviceName>-<DocTypeCode>-<Seq>` so every sale/refund gets a stable,
/// collision-free, scannable number the moment it's created — fully offline.
class LocalDocCountersTable extends Table {
  @override
  String get tableName => 'local_doc_counters';

  // "<companyId>:<docTypeCode>" e.g. "18:200"
  TextColumn get key => text()();
  IntColumn get value => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}

class CountriesTable extends Table {
  @override
  String get tableName => 'countries';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
}

class CurrenciesTable extends Table {
  @override
  String get tableName => 'currencies';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
}

class DocumentItemExpirationDatesTable extends Table {
  @override
  String get tableName => 'document_item_expiration_dates';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentItemId => integer()();
  DateTimeColumn get expirationDate => dateTime()();
  IntColumn get companyId => integer()();
}

class DocumentItemTaxesTable extends Table {
  @override
  String get tableName => 'document_item_taxes';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentItemId => integer()();
  IntColumn get taxId => integer()();
  RealColumn get amount => real()();
  IntColumn get companyId => integer()();
}

class FiscalItemsTable extends Table {
  @override
  String get tableName => 'fiscal_items';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get plu => integer()();
  TextColumn get name => text()();
  TextColumn get vat => text()();
  IntColumn get companyId => integer()();
}

class PosPrinterSettingsTable extends Table {
  @override
  String get tableName => 'pos_printer_settings';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get printerName => text()();
  IntColumn get paperWidth => integer()();
  TextColumn get header => text().nullable()();
  TextColumn get footer => text().nullable()();
  IntColumn get feedLines => integer()();
  BoolColumn get cutPaper => boolean()();
  BoolColumn get printBitmap => boolean()();
  BoolColumn get openCashDrawer => boolean()();
  TextColumn get cashDrawerCommand => text().nullable()();
  IntColumn get headerAlignment => integer()();
  IntColumn get footerAlignment => integer()();
  BoolColumn get isFormattingEnabled => boolean()();
  IntColumn get printerType => integer()();
  IntColumn get numberOfCopies => integer()();
  IntColumn get codePage => integer()();
  IntColumn get characterSet => integer()();
  IntColumn get companyId => integer()();
}

class PosVoidsTable extends Table {
  @override
  String get tableName => 'pos_voids';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get orderNumber => text()();
  IntColumn get userId => integer().nullable()();
  TextColumn get userName => text()();
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text()();
  IntColumn get roundNumber => integer()();
  RealColumn get quantity => real()();
  RealColumn get price => real()();
  RealColumn get discount => real()();
  IntColumn get discountType => integer()();
  RealColumn get total => real()();
  BoolColumn get isConfirmed => boolean()();
  TextColumn get reason => text().nullable()();
  IntColumn get voidedBy => integer().nullable()();
  TextColumn get voidedByName => text().nullable()();
  TextColumn get bundle => text().nullable()();
  DateTimeColumn get dateCreated => dateTime()();
  DateTimeColumn get dateVoided => dateTime()();
  IntColumn get companyId => integer()();
}

class TemplatesTable extends Table {
  @override
  String get tableName => 'templates';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get value => text()();
  IntColumn get companyId => integer()();
}

class UserDevicePinsTable extends Table {
  @override
  String get tableName => 'user_device_pins';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get userId => integer()();
  IntColumn get companyId => integer()();
  TextColumn get deviceId => text()();
  TextColumn get hashedPin => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class ZReportPaymentSummariesTable extends Table {
  @override
  String get tableName => 'z_report_payment_summaries';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get zReportId => integer()();
  IntColumn get paymentTypeId => integer()();
  RealColumn get totalAmount => real()();
}

@DriftDatabase(
  tables: [
    CountersTable,
    LocalDocCountersTable,
    CountriesTable,
    CurrenciesTable,
    DocumentItemExpirationDatesTable,
    DocumentItemTaxesTable,
    FiscalItemsTable,
    PosPrinterSettingsTable,
    PosVoidsTable,
    TemplatesTable,
    UserDevicePinsTable,
    ZReportPaymentSummariesTable,
    SecurityKeysTable,
    PendingUserOpsTable,
    ProductsTable,
    TaxesTable,
    FloorPlansTable,
    FloorPlanTablesTable,
    FloorPlanTableIdMapTable,
    UsersTable,
    AppPropertiesTable,
    ProductGroupsTable,
    PaymentTypesTable,
    CustomersTable,
    PromotionsTable,
    PromotionItemsTable,
    ProductCommentsTable,
    CompaniesTable,
    PosOrdersTable,
    PosOrderItemsTable,
    PosOrderItemTaxesTable,
    StartingCashTable,
    ZReportsTable,
    SyncMetaTable,
    StocksTable,
    PendingVoidsTable,
    DocumentsTable,
    DocumentItemsTable,
    PaymentsTable,
    BarcodesTable,
  BarcodeRulesTable,
    CustomerDiscountsTable,
    LoyaltyCardsTable,
    TimeClockEntriesTable,
    ShiftsTable,
    BookingsTable,
    WarehousesTable,
    PendingStockOpsTable,
    DocumentTypesTable,
    DocumentCategoriesTable,
    VoidReasonsTable,
    StockControlsTable,
    ProductTaxesTable,
    DiscountLinesTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Backs the DB with a caller-supplied executor (an in-memory
  /// `NativeDatabase` in tests) instead of the on-disk, encrypted, real one.
  /// Lets order save/resume be exercised against actual SQLite.
  AppDatabase.forTesting(super.executor) : super();

  /// The schema this build understands, readable WITHOUT opening a database.
  ///
  /// Restore validation needs it before Drift is touched: a backup whose
  /// `user_version` is higher came from a newer build, and Drift migrates
  /// forward only, so opening it here would corrupt it.
  static const int expectedSchemaVersion = 61;

  @override
  int get schemaVersion => expectedSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v57: pin whether the line's unitPrice includes its tax, so a parked
          // order reprices identically when reopened even if the product's tax
          // mode is edited meanwhile. Existing rows get NULL → treated as
          // tax-inclusive, which is the Product default on both DBs and how
          // every product in the catalogue is actually configured.
          // v58: POS sessions. Every column is nullable or defaulted, so an
          // existing install upgrades with no backfill: attendance shifts keep
          // `posDeviceUid = NULL` and behave exactly as before, and every
          // pre-session order/document/payment keeps `sessionLocalId = NULL`.
          // v60: the register's name on the session row, so the list can show
          // sessions from every device.
          // v61: sell by weight. Both columns are defaulted, so existing rows
          // upgrade with no backfill — every product starts as pieces and not
          // weighed, exactly how it behaved before. The next master-data pull
          // brings the server's real values, including the units the backend
          // migration derived from the legacy MeasurementUnit text.
          if (from < 61) {
            await m.addColumn(productsTable, productsTable.uomId);
            await m.addColumn(productsTable, productsTable.isToWeigh);
            await m.createTable(barcodeRulesTable);
          }

          if (from < 60) {
            await m.addColumn(shiftsTable, shiftsTable.posDeviceName);
          }

          // v59: the Opening Control note (Odoo parity).
          if (from < 59) {
            await m.addColumn(shiftsTable, shiftsTable.openingNote);
          }

          if (from < 58) {
            await m.addColumn(shiftsTable, shiftsTable.posDeviceUid);
            await m.addColumn(shiftsTable, shiftsTable.closedByUserId);
            await m.addColumn(shiftsTable, shiftsTable.expectedCash);
            await m.addColumn(shiftsTable, shiftsTable.cashDifference);
            await m.addColumn(shiftsTable, shiftsTable.closingNote);
            await m.addColumn(shiftsTable, shiftsTable.forceClosed);
            await m.addColumn(shiftsTable, shiftsTable.forceClosedByUserId);
            await m.addColumn(shiftsTable, shiftsTable.forceCloseReason);
            await m.addColumn(shiftsTable, shiftsTable.hasLateArrivals);
            await m.addColumn(posOrdersTable, posOrdersTable.sessionLocalId);
            await m.addColumn(documentsTable, documentsTable.sessionLocalId);
            await m.addColumn(paymentsTable, paymentsTable.sessionLocalId);
            await m.addColumn(
                startingCashTable, startingCashTable.sessionLocalId);
          }

          if (from < 57) {
            await m.addColumn(
                posOrderItemsTable, posOrderItemsTable.isTaxInclusive);
          }

          // v56: carry the manual item-discount INPUT (10% vs a fixed amount) on
          // the order line so it survives an OPEN order crossing to another till,
          // where discount_lines don't reach until checkout. Existing rows get
          // NULL and fall back to the resolved money, exactly as before.
          if (from < 56) {
            await m.addColumn(
                posOrderItemsTable, posOrderItemsTable.discountInputValue);
            await m.addColumn(
                posOrderItemsTable, posOrderItemsTable.discountInputType);
          }

          // v55: the newest line's server timestamp, mirrored from
          // PosOrderDto.ItemsLastChanged. Lets syncOpenOrdersToDrift notice that
          // ANOTHER terminal swapped a line for one at the same price — an edit
          // that moves neither the order total nor its item count. Existing rows
          // get NULL and simply re-pull their lines once.
          if (from < 55) {
            await customStatement(
                'ALTER TABLE pos_orders ADD COLUMN items_last_changed INTEGER');
          }

          // v54: remember which booking (and its assigned staff) an order was
          // opened from, so the link survives a save/reopen offline. Existing
          // rows correctly get NULL — they are ordinary non-booking orders.
          if (from < 54) {
            await customStatement(
                'ALTER TABLE pos_orders ADD COLUMN booking_id INTEGER');
            await customStatement(
                'ALTER TABLE pos_orders ADD COLUMN booking_staff_id INTEGER');
          }

          // v53: the Z-report's document range/count, computed at Close Register
          // from the local DB. The pre-existing server-int columns can't be
          // filled offline (an unsynced document has no server id), so the
          // report records the device-local number range instead.
          if (from < 53) {
            await customStatement(
                'ALTER TABLE z_reports ADD COLUMN document_count INTEGER');
            await customStatement(
                'ALTER TABLE z_reports ADD COLUMN from_document_number TEXT');
            await customStatement(
                'ALTER TABLE z_reports ADD COLUMN to_document_number TEXT');
            // Existing rows never had a number written (the UI mistook the
            // server id for one), so they would now all render as "#0". Give
            // them the per-company sequence their close order implies — the
            // same 1-based scheme the server numbers by. Best effort: the true
            // number was never recorded locally, so this cannot be recovered,
            // only reconstructed.
            await customStatement(
              'UPDATE z_reports SET number = ('
              '  SELECT COUNT(*) FROM z_reports AS prior'
              '  WHERE prior.company_id = z_reports.company_id'
              '    AND (prior.closed_at < z_reports.closed_at'
              '      OR (prior.closed_at = z_reports.closed_at'
              '          AND prior.local_id <= z_reports.local_id))'
              ') WHERE number IS NULL',
            );
          }

          // v52: temp→real forwarding addresses for offline-created floor plan
          // tables, so a cart holding a temp id across a sync can still resolve
          // it at checkout. See [FloorPlanTableIdMapTable].
          if (from < 52) {
            await m.createTable(floorPlanTableIdMapTable);
          }

          // v51: floor plan tables become offline-first (add/move/rename/delete
          // while offline, pushed on sync) — needs a sync queue. Mirrors v48's
          // bookings migration; pending_create rows use a temp negative id.
          if (from < 51) {
            await customStatement(
                "ALTER TABLE floor_plan_tables ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                "ALTER TABLE floor_plan_tables ADD COLUMN sync_error TEXT");
          }

          // v50: the legacy PosPrinterSelection subsystem was removed (fully
          // superseded by the PrinterConfig + app_properties scheme, and read by
          // nothing). Drop its two now-orphaned tables so upgraded installs stop
          // carrying dead schema. Referenced by raw name on purpose — the Drift
          // table classes no longer exist. IF EXISTS keeps it idempotent for
          // installs that never had them.
          if (from < 50) {
            await customStatement(
                'DROP TABLE IF EXISTS pos_printer_selection_settings');
            await customStatement(
                'DROP TABLE IF EXISTS pos_printer_selections');
          }

          // v49: refunds become fully offline-first via the Drift outbox (the
          // shared_preferences refund queue is gone). Store the two refund-only
          // fields the /Document/Refund push needs so pushPendingRefundOps can
          // rebuild the payload from the local rows.
          if (from < 49) {
            await customStatement(
                "ALTER TABLE documents ADD COLUMN is_blind "
                "INTEGER NOT NULL DEFAULT 0");
            await customStatement(
                "ALTER TABLE documents ADD COLUMN approved_by_user_id INTEGER");
          }

          // v48: bookings become offline-first (create/update/status/delete
          // while offline, pushed on sync) — needs a sync queue. pending_create
          // rows use a temp negative id until the server assigns the real one.
          if (from < 48) {
            await customStatement(
                "ALTER TABLE bookings ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                "ALTER TABLE bookings ADD COLUMN sync_error TEXT");
          }

          // v47: normalized discount_lines table — one row per applied discount
          // (manual item/cart, promotion, customer profile, loyalty points) so
          // each source is stored discretely instead of merged into a single
          // discount slot. See [DiscountLinesTable].
          if (from < 47) {
            await m.createTable(discountLinesTable);
          }

          // v46: product comments become offline-first (create/delete with a
          // temp id while offline, pushed on sync) — needs a sync_status column.
          if (from < 46) {
            await customStatement(
                "ALTER TABLE product_comments ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // v45: Backfill legacy refunds that were created before refunds
          // inherited the original sale's customer/order. Copy customer_id and
          // order_number from the referenced sale (document_type_id 2). Local
          // display fix only — leaves sync_status untouched so it isn't re-pushed.
          if (from < 45) {
            await customStatement('''
              UPDATE documents
              SET customer_id = COALESCE(customer_id, (
                    SELECT s.customer_id FROM documents s
                    WHERE s.number = documents.reference_document_number
                      AND s.company_id = documents.company_id
                      AND s.document_type_id = 2
                    LIMIT 1)),
                  order_number = COALESCE(order_number, (
                    SELECT s.order_number FROM documents s
                    WHERE s.number = documents.reference_document_number
                      AND s.company_id = documents.company_id
                      AND s.document_type_id = 2
                    LIMIT 1))
              WHERE document_type_id = 4
                AND reference_document_number IS NOT NULL
                AND (customer_id IS NULL OR order_number IS NULL)
            ''');
          }

          // v44: device-local document-number counters (offline numbering).
          if (from < 44) {
            await m.createTable(localDocCountersTable);
          }

          // v43: Offline-first edits for the company record (update-only).
          if (from < 43) {
            await customStatement(
                "ALTER TABLE companies ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // v42: Offline-first CRUD for void reasons — same pattern as taxes.
          if (from < 42) {
            await customStatement(
                "ALTER TABLE void_reasons ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // v41: Offline-first CRUD for payment types — same pattern as taxes.
          if (from < 41) {
            await customStatement(
                "ALTER TABLE payment_types ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // v40: Offline-first CRUD for tax rates — sync_status drives the
          // local-write outbox so creates/edits/deletes show instantly and
          // push on reconnect (mirrors products/customers). Was pull-only.
          if (from < 40) {
            await customStatement(
                "ALTER TABLE taxes ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // ===== -> v39: full schema clone of remaining online tables =====
          if (from < 39) {
            await m.createTable(countersTable);
            await m.createTable(countriesTable);
            await m.createTable(currenciesTable);
            await m.createTable(documentItemExpirationDatesTable);
            await m.createTable(documentItemTaxesTable);
            await m.createTable(fiscalItemsTable);
            await m.createTable(posPrinterSettingsTable);
            await m.createTable(posVoidsTable);
            await m.createTable(templatesTable);
            await m.createTable(userDevicePinsTable);
            await m.createTable(zReportPaymentSummariesTable);

            await m.addColumn(bookingsTable, bookingsTable.tableIds);
            await m.addColumn(companiesTable, companiesTable.postalCode);
            await m.addColumn(companiesTable, companiesTable.city);
            await m.addColumn(companiesTable, companiesTable.countryId);
            await m.addColumn(companiesTable, companiesTable.email);
            await m.addColumn(companiesTable, companiesTable.phoneNumber);
            await m.addColumn(companiesTable, companiesTable.logo);
            await m.addColumn(companiesTable, companiesTable.bankAccountNumber);
            await m.addColumn(companiesTable, companiesTable.bankDetails);
            await m.addColumn(companiesTable, companiesTable.streetName);
            await m.addColumn(companiesTable, companiesTable.additionalStreetName);
            await m.addColumn(companiesTable, companiesTable.buildingNumber);
            await m.addColumn(companiesTable, companiesTable.plotIdentification);
            await m.addColumn(companiesTable, companiesTable.citySubdivisionName);
            await m.addColumn(companiesTable, companiesTable.countrySubentity);
            await m.addColumn(companiesTable, companiesTable.timeZoneId);
            await m.addColumn(customersTable, customersTable.dateCreated);
            await m.addColumn(customersTable, customersTable.dateUpdated);
            await m.addColumn(documentsTable, documentsTable.isClockedOut);
            await m.addColumn(documentsTable, documentsTable.dateCreated);
            await m.addColumn(documentsTable, documentsTable.dateUpdated);
            await m.addColumn(documentCategoriesTable, documentCategoriesTable.languageKey);
            await m.addColumn(documentItemsTable, documentItemsTable.expectedQuantity);
            await m.addColumn(documentItemsTable, documentItemsTable.price);
            await m.addColumn(documentItemsTable, documentItemsTable.productCost);
            await m.addColumn(documentItemsTable, documentItemsTable.priceBeforeTaxAfterDiscount);
            await m.addColumn(documentItemsTable, documentItemsTable.priceAfterDiscount);
            await m.addColumn(documentItemsTable, documentItemsTable.totalAfterDocumentDiscount);
            await m.addColumn(documentItemsTable, documentItemsTable.discountApplyRule);
            await m.addColumn(documentItemsTable, documentItemsTable.companyId);
            await m.addColumn(documentTypesTable, documentTypesTable.editorType);
            await m.addColumn(documentTypesTable, documentTypesTable.printTemplate);
            await m.addColumn(documentTypesTable, documentTypesTable.priceType);
            await m.addColumn(documentTypesTable, documentTypesTable.languageKey);
            await m.addColumn(paymentsTable, paymentsTable.dateCreated);
            await m.addColumn(paymentsTable, paymentsTable.companyId);
            await m.addColumn(posOrdersTable, posOrdersTable.number);
            await m.addColumn(posOrdersTable, posOrdersTable.floorPlanTableId);
            await m.addColumn(posOrdersTable, posOrdersTable.dueDate);
            await m.addColumn(posOrdersTable, posOrdersTable.dateCreated);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.posOrderId);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.roundNumber);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.price);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.isLocked);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.isFeatured);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.voidedBy);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.dateCreated);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.bundle);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.discountAppliedType);
            await m.addColumn(posOrderItemsTable, posOrderItemsTable.companyId);
            await m.addColumn(posOrderItemTaxesTable, posOrderItemTaxesTable.posOrderItemId);
            await m.addColumn(posOrderItemTaxesTable, posOrderItemTaxesTable.taxId);
            await m.addColumn(posOrderItemTaxesTable, posOrderItemTaxesTable.companyId);
            await m.addColumn(productsTable, productsTable.image);
            await m.addColumn(productsTable, productsTable.color);
            await m.addColumn(productGroupsTable, productGroupsTable.color);
            await m.addColumn(productGroupsTable, productGroupsTable.image);
            await m.addColumn(promotionItemsTable, promotionItemsTable.uid);
            await m.addColumn(promotionItemsTable, promotionItemsTable.companyId);
            await m.addColumn(startingCashTable, startingCashTable.description);
            await m.addColumn(startingCashTable, startingCashTable.startingCashType);
            await m.addColumn(startingCashTable, startingCashTable.dateCreated);
            await m.addColumn(timeClockEntriesTable, timeClockEntriesTable.lastModified);
            await m.addColumn(usersTable, usersTable.password);
            await m.addColumn(usersTable, usersTable.accessLevel);
            await m.addColumn(voidReasonsTable, voidReasonsTable.dateCreated);
            await m.addColumn(zReportsTable, zReportsTable.number);
            await m.addColumn(zReportsTable, zReportsTable.fromDocumentId);
            await m.addColumn(zReportsTable, zReportsTable.toDocumentId);
            await m.addColumn(zReportsTable, zReportsTable.dateCreated);
            await m.addColumn(zReportsTable, zReportsTable.totalReturns);
            await m.addColumn(zReportsTable, zReportsTable.discountsGranted);
            await m.addColumn(zReportsTable, zReportsTable.taxableTotal);
            await m.addColumn(zReportsTable, zReportsTable.totalTax);
            await m.addColumn(zReportsTable, zReportsTable.grandTotal);
          }
          // v1 -> v2: Phase 3.5 schema bump — full admin field coverage for
          // Products and Taxes so the admin screens can stream from Drift.
          // Each addColumn targets either a nullable column or one with a
          // default, so existing rows remain valid without backfill.
          if (from < 2) {
            await m.addColumn(productsTable, productsTable.code);
            await m.addColumn(productsTable, productsTable.plu);
            await m.addColumn(productsTable, productsTable.measurementUnit);
            await m.addColumn(productsTable, productsTable.description);
            await m.addColumn(productsTable, productsTable.markup);
            await m.addColumn(productsTable, productsTable.rank);
            await m.addColumn(productsTable, productsTable.currencyId);
            await m.addColumn(productsTable, productsTable.ageRestriction);
            await m.addColumn(productsTable, productsTable.lastPurchasePrice);
            await m.addColumn(productsTable, productsTable.dateCreated);
            await m.addColumn(productsTable, productsTable.dateUpdated);
            await m.addColumn(
                productsTable, productsTable.isPriceChangeAllowed);
            await m.addColumn(
                productsTable, productsTable.isUsingDefaultQuantity);
            await m.addColumn(
                productsTable, productsTable.isTaxInclusivePrice);
            await m.addColumn(productsTable, productsTable.isEnabled);

            await m.addColumn(taxesTable, taxesTable.code);
            await m.addColumn(taxesTable, taxesTable.isFixed);
            await m.addColumn(taxesTable, taxesTable.isTaxOnTotal);
            await m.addColumn(taxesTable, taxesTable.isEnabled);

            // After adding columns, the next master-data pull repopulates
            // them with real values. Until then admin screens see defaults.
          }

          // v2 -> v3: Phase 4 — offline checkout finalisation fields on
          // pos_orders. These travel with the order on the next BatchSync push.
          if (from < 3) {
            await m.addColumn(posOrdersTable, posOrdersTable.paymentTypeId);
            await m.addColumn(posOrdersTable, posOrdersTable.amountPaid);
            await m.addColumn(posOrdersTable, posOrdersTable.customerId);
          }

          // v3 -> v4: Emergency Phase 3.6 — the four master entities that
          // were left API-backed (ProductGroups, PaymentTypes, Customers,
          // Promotions). createTable is safe even when the table already
          // exists thanks to Drift's IF NOT EXISTS, but onUpgrade only runs
          // from < new, so first-launch installs hit onCreate instead and
          // skip this branch.
          if (from < 4) {
            await m.createTable(productGroupsTable);
            await m.createTable(paymentTypesTable);
            await m.createTable(customersTable);
            await m.createTable(promotionsTable);
          }

          // v4 -> v5: Company offline cache. Single-row-per-company lean
          // schema so receipts render with real branding (name/address/tax
          // number/phone/logo) when offline.
          //
          // DROP IF EXISTS handles a quirk of this migration's history:
          // an earlier draft of v5 shipped a different (20-field) schema.
          // If a dev machine already ran that draft, we recreate the table
          // with the lean shape. Cache loss is fine — pullCompany refills
          // it on the next sync.
          if (from < 5) {
            await customStatement('DROP TABLE IF EXISTS companies');
            await m.createTable(companiesTable);
          }

          // v5 -> v6: Phase 3.9 — disk cache for product group icons. Same
          // pattern as Product.localImagePath; ImageSyncHelper writes under
          // `group_images/<id>.jpg` during pullProductGroups.
          if (from < 6) {
            await m.addColumn(
                productGroupsTable, productGroupsTable.localImagePath);
          }

          // v6 -> v7: ProductComments offline cache — the per-product
          // "extra cheese / no onions" suggestion list, used by the tap
          // dialog. New table only, no existing data to migrate.
          if (from < 7) {
            await m.createTable(productCommentsTable);
          }

          // v7 -> v8: Stocks offline cache so local inventory is checked and
          // deducted at checkout even without a network connection.
          // pullStocks() re-seeds this on the next successful sync.
          if (from < 8) {
            await m.createTable(stocksTable);
          }

          // v8 -> v9: Pending voids queue — offline void support.
          if (from < 9) {
            await m.createTable(pendingVoidsTable);
          }

          // v9 -> v10: Offline documents, items, and payments.
          // Documents are created locally at checkout and pulled from the
          // server on every sync so history is always available offline.
          if (from < 10) {
            await m.createTable(documentsTable);
            await m.createTable(documentItemsTable);
            await m.createTable(paymentsTable);
          }

          // v10 -> v11: Per-item offline tax and discount-type storage.
          // taxesJson holds [{"id":1,"amount":2.50}] so SyncManager can
          // populate CheckoutItemDto.Taxes on BatchSync, creating
          // DocumentItemTax rows server-side.
          // discountType was hardcoded to 0 in BatchSync — now persisted.
          if (from < 11) {
            await customStatement(
                'ALTER TABLE pos_order_items ADD COLUMN discount_type INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE pos_order_items ADD COLUMN taxes_json TEXT');
          }

          // v11 -> v12: Offline product CRUD queue.
          // syncStatus tracks pending creates/updates/deletes so SyncManager
          // can push them to the server when connectivity returns.
          // pending_create rows use a negative temp id until server confirms.
          if (from < 12) {
            await customStatement(
                "ALTER TABLE products ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                'ALTER TABLE products ADD COLUMN sync_error TEXT');
          }

          // v12 -> v13: Offline barcode CRUD.
          // Barcodes are written locally first (pending_create / pending_delete)
          // and pushed to /Barcodes/Add+Delete on the next sync.
          if (from < 13) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS barcodes (
                local_id TEXT NOT NULL PRIMARY KEY,
                server_id INTEGER,
                product_id INTEGER NOT NULL,
                company_id INTEGER NOT NULL,
                value TEXT NOT NULL,
                sync_status TEXT NOT NULL DEFAULT 'synced'
              )
            ''');
          }

          // v14: Promotions become offline-first.
          // sync_status/sync_error drive the push pipeline for CRUD ops.
          // promotion_items stores per-product discount config so
          // activePromotionsProvider can apply discounts offline.
          // v15: Product groups become offline-first (create/update/delete).
          if (from < 15) {
            await customStatement(
                "ALTER TABLE product_groups ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                'ALTER TABLE product_groups ADD COLUMN sync_error TEXT');
          }

          if (from < 14) {
            await customStatement(
                "ALTER TABLE promotions ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                'ALTER TABLE promotions ADD COLUMN sync_error TEXT');
            await customStatement('''
              CREATE TABLE IF NOT EXISTS promotion_items (
                id INTEGER NOT NULL PRIMARY KEY,
                promotion_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                discount_type INTEGER NOT NULL DEFAULT 0,
                price_type INTEGER NOT NULL DEFAULT 0,
                value REAL NOT NULL DEFAULT 0,
                is_conditional INTEGER NOT NULL DEFAULT 0,
                quantity REAL NOT NULL DEFAULT 1,
                condition_type INTEGER NOT NULL DEFAULT 0,
                quantity_limit REAL NOT NULL DEFAULT 0
              )
            ''');
          }

          // v16: Security keys offline cache.
          // Pulled from /SecurityKeys/GetAll on every master-data sync so
          // SecurityGuard can enforce RBAC without a network round-trip.
          if (from < 16) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS security_keys (
                company_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                level INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (company_id, name)
              )
            ''');
          }

          // v17: Pending user / security-key ops queue.
          // Written when toggle-user, edit-user, or update-security-key fails
          // due to no connectivity. SyncManager drains it on next online sync.
          if (from < 17) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS pending_user_ops (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                operation TEXT NOT NULL,
                company_id INTEGER NOT NULL,
                payload TEXT NOT NULL
              )
            ''');
          }

          // v18: Full user fields — email, username, firstName, lastName.
          // These were missing from the original schema; all are nullable so
          // existing rows stay valid. pullUsers + seedUsersFromApiProvider
          // populate them on the next sync.
          if (from < 18) {
            await customStatement(
                'ALTER TABLE users ADD COLUMN first_name TEXT');
            await customStatement(
                'ALTER TABLE users ADD COLUMN last_name TEXT');
            await customStatement(
                'ALTER TABLE users ADD COLUMN username TEXT');
            await customStatement('ALTER TABLE users ADD COLUMN email TEXT');
          }

          // v19: Performance indexes.
          // onCreate already applies them via m.createAll(); onUpgrade must
          // create them explicitly for existing installations.
          if (from < 19) {
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_products_group_id'
                ' ON products (product_group_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_products_barcode'
                ' ON products (barcode)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_pos_orders_sync_status'
                ' ON pos_orders (sync_status)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_pos_orders_status'
                ' ON pos_orders (status)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_pos_order_items_order_id'
                ' ON pos_order_items (order_id)');
          }

          // v20: Customers become offline-first; customer discounts are cached
          // locally so the edit form and POS discount lookup work offline.
          if (from < 20) {
            await customStatement(
                "ALTER TABLE customers ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                'ALTER TABLE customers ADD COLUMN sync_error TEXT');
            await customStatement('''
              CREATE TABLE IF NOT EXISTS customer_discounts (
                id INTEGER NOT NULL PRIMARY KEY,
                company_id INTEGER NOT NULL,
                customer_id INTEGER NOT NULL,
                type INTEGER NOT NULL DEFAULT 0,
                uid INTEGER NOT NULL DEFAULT 0,
                value REAL NOT NULL DEFAULT 0.0,
                last_modified INTEGER NOT NULL DEFAULT 0,
                sync_status TEXT NOT NULL DEFAULT 'synced',
                sync_error TEXT
              )
            ''');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_customer_discounts_customer_id'
                ' ON customer_discounts (customer_id)');
          }

          // v21: Loyalty cards — offline-first customer points cards.
          // Negative temp IDs are used for pending_create rows.
          if (from < 21) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS loyalty_cards (
                id INTEGER NOT NULL PRIMARY KEY,
                company_id INTEGER NOT NULL,
                customer_id INTEGER NOT NULL,
                card_number TEXT,
                points REAL NOT NULL DEFAULT 0,
                last_modified INTEGER NOT NULL,
                sync_status TEXT NOT NULL DEFAULT 'synced',
                sync_error TEXT
              )
            ''');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_loyalty_cards_customer_id'
                ' ON loyalty_cards (customer_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_loyalty_cards_sync_status'
                ' ON loyalty_cards (sync_status)');
          }

          // v22: Dual-discount persistence.
          //  • pos_orders gains a discount_type column so the cart-level
          //    discount type (0=%, 1=Fixed) survives save/reload.
          //  • pos_order_item_taxes stores offline per-item tax breakdowns
          //    so receipts and sync don't need to recompute them.
          if (from < 22) {
            await customStatement(
                'ALTER TABLE pos_orders'
                ' ADD COLUMN discount_type INTEGER NOT NULL DEFAULT 0');
            await customStatement('''
              CREATE TABLE IF NOT EXISTS pos_order_item_taxes (
                local_id TEXT NOT NULL PRIMARY KEY,
                order_id TEXT NOT NULL
                  REFERENCES pos_orders(local_id) ON DELETE CASCADE,
                product_id INTEGER NOT NULL,
                tax_rate_id INTEGER NOT NULL,
                tax_amount REAL NOT NULL,
                sync_status TEXT NOT NULL DEFAULT 'pending'
              )
            ''');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_pos_order_item_taxes_order_id'
                ' ON pos_order_item_taxes (order_id)');
          }

          // v25: Rename the local cash table `cash_movements` → `starting_cash`
          // so it mirrors the server's StartingCash table. Data is preserved by
          // a plain table rename. Guarded so the migration is safe whether or
          // not the old table exists (it was previously created only via
          // createAll on fresh installs).
          if (from < 25) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('cash_movements', 'starting_cash')",
            ).get();
            final names =
                existing.map((r) => r.read<String>('name')).toSet();
            if (names.contains('cash_movements') &&
                !names.contains('starting_cash')) {
              await customStatement(
                  'ALTER TABLE cash_movements RENAME TO starting_cash');
            } else if (!names.contains('starting_cash')) {
              await customStatement('''
                CREATE TABLE IF NOT EXISTS starting_cash (
                  local_id TEXT NOT NULL PRIMARY KEY,
                  server_id INTEGER,
                  company_id INTEGER NOT NULL,
                  user_id INTEGER NOT NULL,
                  amount REAL NOT NULL,
                  type TEXT NOT NULL,
                  note TEXT,
                  created_at INTEGER NOT NULL,
                  sync_status TEXT NOT NULL DEFAULT 'pending',
                  sync_error TEXT
                )
              ''');
            }
          }

          // v26: Link cash entries to their Z-report. `z_report_number` is NULL
          // while the entry is active; once finalized the active Cash In/Out
          // list filters it out. Runs AFTER v25 so `starting_cash` exists.
          if (from < 26) {
            await customStatement(
                'ALTER TABLE starting_cash ADD COLUMN z_report_number INTEGER');
          }

          // v27: Differentiate per-employee attendance sessions (0) from the
          // station's master cash-drawer shift (1) so concurrent clock-ins on
          // one station never collide with the drawer shift.
          if (from < 27) {
            await customStatement(
                'ALTER TABLE shifts ADD COLUMN is_drawer_shift '
                'INTEGER NOT NULL DEFAULT 0');
          }

          // v28: Track per-setting sync state so an offline edit of an existing
          // app property is pushed to the server on reconnect. Existing rows
          // default to 'synced' (they came from the server).
          if (from < 28) {
            await customStatement(
                "ALTER TABLE app_properties ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // v29: Offline bookings cache. Reservations are pulled (full replace)
          // each sync so the calendar renders offline. New table only — no
          // existing data to migrate.
          if (from < 29) {
            await m.createTable(bookingsTable);
          }

          // v30: Offline-first warehouses + the stock-op queue used when a
          // warehouse with stock is deleted. New tables only.
          if (from < 30) {
            await m.createTable(warehousesTable);
            await m.createTable(pendingStockOpsTable);
          }

          // v31: Offline-first paid-status + payments for the document editor.
          //  • documents.paid_status_dirty flags a locally-toggled paid status
          //    that SyncManager pushes to /Document/Update on reconnect.
          //  • payments gains server_id + z_report_id and reuses the standard
          //    sync_status states so editor add/edit/delete work offline and
          //    are reconciled with /Payments/* on sync.
          if (from < 31) {
            await customStatement(
                'ALTER TABLE documents ADD COLUMN paid_status_dirty '
                'INTEGER NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE payments ADD COLUMN server_id INTEGER');
            await customStatement(
                'ALTER TABLE payments ADD COLUMN z_report_id INTEGER');
          }

          // v32: Offline-first manual document editor. document_items gains the
          // per-item sync fields (server id, tax selection, expiration, sync
          // state) so header + items can be created/edited/deleted offline and
          // pushed via /Document + /DocumentItems on reconnect. Documents reuse
          // their existing sync_status with the manual states pending_create /
          // pending_update / pending_delete (checkout keeps pending → synced).
          if (from < 32) {
            await customStatement(
                'ALTER TABLE document_items ADD COLUMN server_id INTEGER');
            await customStatement(
                'ALTER TABLE document_items ADD COLUMN price_before_tax '
                'REAL NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE document_items ADD COLUMN tax_id INTEGER');
            await customStatement(
                'ALTER TABLE document_items ADD COLUMN tax_rate '
                'REAL NOT NULL DEFAULT 0');
            await customStatement(
                'ALTER TABLE document_items ADD COLUMN expiration_date INTEGER');
            await customStatement(
                "ALTER TABLE document_items ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
            // Editable header fields persisted for offline round-tripping.
            await customStatement(
                'ALTER TABLE documents ADD COLUMN stock_date INTEGER');
            await customStatement(
                'ALTER TABLE documents ADD COLUMN due_date INTEGER');
            await customStatement(
                'ALTER TABLE documents ADD COLUMN internal_note TEXT');
            await customStatement(
                'ALTER TABLE documents ADD COLUMN note TEXT');
            await customStatement(
                'ALTER TABLE documents ADD COLUMN reference_document_number TEXT');
            await customStatement(
                'ALTER TABLE documents ADD COLUMN discount_apply_rule '
                'INTEGER NOT NULL DEFAULT 1');
          }

          // v33: Cache document types + categories locally so the editor's
          // "Select document type" picker — and therefore offline document
          // creation — works without a network connection. Pull-only master
          // data seeded by SyncManager.pullDocumentTypes/Categories.
          if (from < 33) {
            await m.createTable(documentTypesTable);
            await m.createTable(documentCategoriesTable);
          }

          // v34: Cache void reasons locally so the checkout void dialog and the
          // admin list work offline. Pull-only, seeded by pullVoidReasons.
          if (from < 34) {
            await m.createTable(voidReasonsTable);
          }

          // v35: Lazy cache of per-product stock-control rules so the stock
          // screen reads them offline (refreshed from GetByProductId online).
          if (from < 35) {
            await m.createTable(stockControlsTable);
          }

          // v36: Offline-first CRUD for stocks + stock controls — sync_status
          // drives the local-write queue so adjustments/rules survive offline
          // and push on reconnect (mirrors warehouses).
          if (from < 36) {
            await customStatement(
                "ALTER TABLE stocks ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
            await customStatement(
                "ALTER TABLE stock_controls ADD COLUMN sync_status "
                "TEXT NOT NULL DEFAULT 'synced'");
          }

          // v37: ProductTaxes offline cache + stock_controls preferred supplier.
          if (from < 37) {
            await customStatement(
                'ALTER TABLE stock_controls ADD COLUMN customer_id INTEGER');
            await m.createTable(productTaxesTable);
          }

          // v38: document_types — drop the unused warehouse_id mirror and add
          // stock_direction (server inventory direction). Pull-only master data,
          // so a drop + recreate is safe; pullDocumentTypes re-seeds it.
          if (from < 38) {
            await customStatement('DROP TABLE IF EXISTS document_types');
            await m.createTable(documentTypesTable);
          }

          // v24: Employee Time Clock — offline-first attendance tracking.
          // Completely isolated from cash drawer / shift management.
          // One row per clock-in event; clockOutTime null while clocked in.
          if (from < 24) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS time_clock_entries (
                local_id TEXT NOT NULL PRIMARY KEY,
                server_id INTEGER,
                company_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                clock_in_time INTEGER NOT NULL,
                clock_out_time INTEGER,
                sync_status TEXT NOT NULL DEFAULT 'pending',
                sync_error TEXT
              )
            ''');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_time_clock_user_id'
                ' ON time_clock_entries (user_id)');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_time_clock_sync_status'
                ' ON time_clock_entries (sync_status)');
          }

          // v23: Offline-first shift management.
          // One row per cashier shift. status 0=Open, 1=Closed.
          // SyncManager pushes pending rows via /api/shifts/batchsync.
          if (from < 23) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS shifts (
                local_id TEXT NOT NULL PRIMARY KEY,
                server_id INTEGER,
                company_id INTEGER NOT NULL,
                user_id INTEGER NOT NULL,
                starting_cash REAL NOT NULL DEFAULT 0,
                actual_ending_cash REAL,
                status INTEGER NOT NULL DEFAULT 0,
                opened_at INTEGER NOT NULL,
                closed_at INTEGER,
                last_modified INTEGER NOT NULL,
                sync_status TEXT NOT NULL DEFAULT 'pending',
                sync_error TEXT
              )
            ''');
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_shifts_company_status'
                ' ON shifts (company_id, status)');
          }
        },
        beforeOpen: (details) async {
          // Enforce FK constraints (off by default in SQLite).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Persists a completed offline order and its line items in a single
  /// transaction. Either both inserts succeed or neither does — so a partial
  /// failure can never leave a header row with no items (or vice versa).
  ///
  /// Caller is responsible for setting `localId` on the order and `orderId`
  /// on each item to the matching UUID, plus `syncStatus = 'pending'` so
  /// Phase 5's push picks the row up.
  Future<void> insertOfflineOrder(
    PosOrdersTableCompanion order,
    List<PosOrderItemsTableCompanion> items,
  ) {
    return transaction(() async {
      await into(posOrdersTable).insert(order);
      if (items.isNotEmpty) {
        await batch((b) {
          b.insertAll(posOrderItemsTable, items);
        });
      }
    });
  }

  /// Completes an existing open order that was loaded from the server and paid
  /// offline. Updates the header row in place and replaces its items so the row
  /// reflects the final paid state. The caller sets syncStatus = 'pending' so
  /// BatchSync pushes the completion to the server on the next sync.
  Future<void> completeExistingOrder(
    String localId,
    PosOrdersTableCompanion orderUpdate,
    List<PosOrderItemsTableCompanion> newItems,
  ) {
    return transaction(() async {
      await (update(posOrdersTable)..where((t) => t.localId.equals(localId)))
          .write(orderUpdate);
      await (delete(posOrderItemsTable)
            ..where((t) => t.orderId.equals(localId)))
          .go();
      if (newItems.isNotEmpty) {
        await batch((b) {
          b.insertAll(posOrderItemsTable, newItems);
        });
      }
    });
  }

  // ==========================================================================
  // PHASE 5 — PUSH SYNC HELPERS
  // ==========================================================================

  /// Checks local stock and deducts quantities for a completed checkout.
  ///
  /// Returns `(success: true)` when every item was deducted.
  /// Returns `(success: false, message: '...')` when a product is out of stock
  /// and [allowNegative] is false — the caller should show a blocking dialog.
  ///
  /// Service products (isService = true) are always skipped.
  /// Products with no local stock record are skipped (treated as untracked).
  Future<({bool success, String? message})> deductStockForCheckout({
    required List<({
      int productId,
      double quantity,
      int warehouseId,
      bool isService,
      String productName,
    })> items,
    required bool allowNegative,
  }) async {
    // Pre-flight: check all items before touching any stock row.
    if (!allowNegative) {
      for (final item in items) {
        if (item.isService) continue;
        final stock = await (select(stocksTable)
              ..where((t) => t.productId.equals(item.productId))
              ..where((t) => t.warehouseId.equals(item.warehouseId))
              ..limit(1))
            .getSingleOrNull();
        if (stock == null) continue; // untracked product — allow
        if (stock.quantity < item.quantity) {
          return (
            success: false,
            message:
                '${item.productName} is out of stock '
                '(available: ${stock.quantity.toStringAsFixed(2)}, '
                'needed: ${item.quantity.toStringAsFixed(2)}).',
          );
        }
      }
    }

    // Deduct pass — runs only when the pre-flight passed (or allowNegative).
    await transaction(() async {
      for (final item in items) {
        if (item.isService) continue;
        final stock = await (select(stocksTable)
              ..where((t) => t.productId.equals(item.productId))
              ..where((t) => t.warehouseId.equals(item.warehouseId))
              ..limit(1))
            .getSingleOrNull();
        if (stock == null) continue;
        await (update(stocksTable)..where((t) => t.id.equals(stock.id))).write(
          StocksTableCompanion(
            quantity: Value(stock.quantity - item.quantity),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
      }
    });

    return (success: true, message: null);
  }

  // ─── Documents / Payments ─────────────────────────────────────────────────

  /// Saves a completed sale to local SQLite in a single atomic transaction:
  /// Document header + line items + payment record.
  /// The Document localId MUST equal the PosOrder localId so sync_manager
  /// can call [linkDocumentToServer] by the same key after BatchSync.
  Future<void> insertOfflineDocument({
    required DocumentsTableCompanion document,
    required List<DocumentItemsTableCompanion> items,
    required PaymentsTableCompanion payment,
  }) {
    return transaction(() async {
      await into(documentsTable).insert(document);
      if (items.isNotEmpty) {
        await batch((b) { b.insertAll(documentItemsTable, items); });
      }
      await into(paymentsTable).insert(payment);
    });
  }

  /// Attaches sales that predate session stamping to the session that rang
  /// them up, and reports how many rows it repaired.
  ///
  /// 🚨 Local linkage ONLY: `sync_status` and `last_modified` are deliberately
  /// left alone, so a repair never re-queues a document the server already has.
  /// The rows are matched narrowly — same company, no session yet, inside the
  /// session's own window, and numbered with this register's prefix — because
  /// the local database also holds documents pulled from OTHER tills, and
  /// absorbing one of those into this drawer would invent takings.
  ///
  /// Idempotent: a second run matches nothing and writes nothing.
  Future<int> attachOrphanSalesToSession({
    required String sessionLocalId,
    required int companyId,
    required DateTime from,
    required DateTime to,
    required String numberPrefix,
  }) async {
    final like = '$numberPrefix-%';
    return transaction(() async {
      final orphans = await (select(documentsTable)
            ..where((t) =>
                t.companyId.equals(companyId) &
                t.sessionLocalId.isNull() &
                t.number.like(like) &
                t.date.isBiggerOrEqualValue(from) &
                t.date.isSmallerOrEqualValue(to)))
          .get();
      if (orphans.isEmpty) return 0;

      final ids = orphans.map((d) => d.localId).toList();
      var repaired = 0;

      repaired += await (update(documentsTable)
            ..where((t) => t.localId.isIn(ids)))
          .write(DocumentsTableCompanion(
              sessionLocalId: Value(sessionLocalId)));

      // The payments follow their document: they were taken at the till that
      // raised it, in the session that owned that till at the time.
      repaired += await (update(paymentsTable)
            ..where((t) =>
                t.documentId.isIn(ids) & t.sessionLocalId.isNull()))
          .write(PaymentsTableCompanion(
              sessionLocalId: Value(sessionLocalId)));

      // The pos_order shares its document's localId (checkout mints one UUID
      // for both), so match on that rather than on the number prefix — the
      // prefix alone has no time bound and would sweep up every sale this
      // register has ever made into whichever session was repaired first.
      repaired += await (update(posOrdersTable)
            ..where((t) =>
                t.localId.isIn(ids) & t.sessionLocalId.isNull()))
          .write(PosOrdersTableCompanion(
              sessionLocalId: Value(sessionLocalId)));

      return repaired;
    });
  }

  /// Called after BatchSync succeeds: stamps the server Document.Id onto the
  /// locally-created Document and flips syncStatus to 'synced'.
  Future<void> linkDocumentToServer(String localId, int documentServerId) {
    return transaction(() async {
      await (update(documentsTable)
            ..where((t) => t.localId.equals(localId)))
          .write(DocumentsTableCompanion(
        serverId:    Value(documentServerId),
        syncStatus:  const Value('synced'),
        lastModified: Value(DateTime.now().toUtc()),
      ));
      // The checkout payment travelled to the server inside the order's
      // BatchSync (created by CheckoutPosOrderCommand), so once the document is
      // linked its 'pending' payment is already on the server — flip it to
      // 'synced' so it doesn't sit pending forever. Editor-added payments use
      // 'pending_create' and are left for pushPendingPayments.
      await (update(paymentsTable)
            ..where((t) => t.documentId.equals(localId))
            ..where((t) => t.syncStatus.equals('pending')))
          .write(const PaymentsTableCompanion(syncStatus: Value('synced')));
    });
  }

  /// Heals checkout payments that are still 'pending' even though their document
  /// already synced (e.g. created before this reconcile existed, or whose order
  /// row was deleted right after sync so [linkDocumentToServer] never re-ran).
  /// A 'pending' payment under a synced document is, by definition, already on
  /// the server — it was posted by CheckoutPosOrderCommand. Run each sync.
  Future<void> reconcileSyncedCheckoutPayments() => customStatement(
        "UPDATE payments SET sync_status = 'synced' "
        "WHERE sync_status = 'pending' AND document_id IN "
        "(SELECT local_id FROM documents WHERE sync_status = 'synced' "
        "AND server_id IS NOT NULL)",
      );

  /// Returns all Documents for a company ordered newest-first.
  /// Used by the Sales History screen — reads local SQLite, no network needed.
  Future<List<DocumentsTableData>> getDocuments({
    required int companyId,
    DateTime? from,
    DateTime? to,
    int? userId,
    int? customerId,
  }) {
    final query = select(documentsTable)
      ..where((t) => t.companyId.equals(companyId))
      ..where((t) => t.syncStatus.equals('pending_delete').not());
    if (from != null) query.where((t) => t.date.isBiggerOrEqualValue(from));
    if (to   != null) query.where((t) => t.date.isSmallerOrEqualValue(to));
    if (userId   != null) query.where((t) => t.userId.equals(userId));
    if (customerId != null) query.where((t) => t.customerId.equals(customerId));
    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  /// Returns the first Document that references [originalNumber], or null if the
  /// receipt has not been refunded yet. Backs the offline double-refund lock —
  /// works for locally-created refunds (still 'pending') and ones pulled from
  /// another device. Only refund documents carry a referenceDocumentNumber that
  /// points at a sales receipt, so matching on it alone is sufficient (the pull
  /// can't recover documentTypeId from GetSalesHistory, so we don't filter on it).
  Future<DocumentsTableData?> findRefundByReference({
    required int companyId,
    required String originalNumber,
  }) =>
      (select(documentsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.referenceDocumentNumber.equals(originalNumber))
            ..where((t) => t.syncStatus.equals('pending_delete').not())
            ..limit(1))
          .getSingleOrNull();

  /// Returns all line items for a given Document localId.
  Future<List<DocumentItemsTableData>> getDocumentItems(String documentLocalId) =>
      (select(documentItemsTable)
            ..where((t) => t.documentId.equals(documentLocalId)))
          .get();

  /// Returns all Payments for a given Document localId.
  Future<List<PaymentsTableData>> getPayments(String documentLocalId) =>
      (select(paymentsTable)
            ..where((t) => t.documentId.equals(documentLocalId)))
          .get();

  /// Resolves a Document row by its server id. Used by the editor to map the
  /// server-id it holds back to the local UUID that Drift writes key on.
  Future<DocumentsTableData?> getDocumentByServerId(int serverId) =>
      (select(documentsTable)
            ..where((t) => t.serverId.equals(serverId))
            ..limit(1))
          .getSingleOrNull();

  Future<DocumentsTableData?> getDocumentByLocalId(String localId) =>
      (select(documentsTable)
            ..where((t) => t.localId.equals(localId))
            ..limit(1))
          .getSingleOrNull();

  /// Ensures a local Document row exists for a server-side document so the
  /// offline-first paid-status and payments writes have a row to attach to.
  /// Returns the existing localId when one is already present (keyed by
  /// serverId); otherwise inserts a 'srv_<serverId>' sentinel. Never touches
  /// line items.
  Future<String> ensureLocalDocumentForServer({
    required int serverId,
    required int companyId,
    required int userId,
    required int warehouseId,
    required int documentTypeId,
    required String? number,
    required double total,
    required int paidStatus,
    required DateTime date,
  }) async {
    final existing = await getDocumentByServerId(serverId);
    if (existing != null) return existing.localId;
    final localId = 'srv_$serverId';
    await into(documentsTable).insertOnConflictUpdate(
      DocumentsTableCompanion(
        localId: Value(localId),
        serverId: Value(serverId),
        companyId: Value(companyId),
        documentTypeId: Value(documentTypeId),
        userId: Value(userId),
        warehouseId: Value(warehouseId),
        number: Value(number),
        total: Value(total),
        paidStatus: Value(paidStatus),
        date: Value(date),
        syncStatus: const Value('synced'),
        lastModified: Value(DateTime.now().toUtc()),
      ),
    );
    return localId;
  }

  /// Offline-first paid-status write. Drift is the source of truth for the
  /// documents list, so this persists the toggle immediately and flags the row
  /// for a server push. Marking Unpaid mirrors the backend by clearing applied
  /// payments locally.
  Future<void> setLocalPaidStatus(String docLocalId, int newStatus) {
    return transaction(() async {
      await (update(documentsTable)
            ..where((t) => t.localId.equals(docLocalId)))
          .write(DocumentsTableCompanion(
        paidStatus: Value(newStatus),
        paidStatusDirty: const Value(true),
        lastModified: Value(DateTime.now().toUtc()),
      ));
      if (newStatus == 0) {
        await (delete(paymentsTable)
              ..where((t) => t.documentId.equals(docLocalId)))
            .go();
      }
    });
  }

  /// Repoints every local row that referenced a floor-plan table's temp negative
  /// id at the real server id it was just assigned.
  ///
  /// Always call this in the SAME transaction as the id swap: if the swap
  /// committed but this didn't, the references would point at an id that exists
  /// nowhere and the table assignment would be silently lost.
  ///
  /// Two holders, each storing the id differently:
  ///  • `pos_orders.tableId` — a plain column, so a direct UPDATE. NOTE: it is
  ///    `tableId`, NOT the similarly-named `floorPlanTableId` on the same table —
  ///    that one is dead (nothing writes it; `CartState.floorPlanTableId` is
  ///    persisted into `tableId`). Remapping the wrong column would silently
  ///    update zero rows.
  ///  • `bookings.tableIdsJson` — a JSON array, so decode → swap → encode.
  ///    Matched in Dart, not via a SQL LIKE: `[12]` LIKE '%1%' would happily
  ///    match an unrelated table 1.
  Future<void> remapFloorPlanTableRefs(
    int tempId,
    int realId,
    int companyId,
  ) async {
    // Leave a forwarding address first: rewriting existing rows only covers what
    // is already persisted, and the open cart isn't.
    await into(floorPlanTableIdMapTable).insertOnConflictUpdate(
      FloorPlanTableIdMapTableCompanion(
        tempId: Value(tempId),
        realId: Value(realId),
        companyId: Value(companyId),
        createdAt: Value(DateTime.now().toUtc()),
      ),
    );

    await (update(posOrdersTable)..where((o) => o.tableId.equals(tempId)))
        .write(PosOrdersTableCompanion(tableId: Value(realId)));

    final bookingRows = await (select(bookingsTable)
          ..where((b) => b.companyId.equals(companyId)))
        .get();
    for (final b in bookingRows) {
      final ids = (jsonDecode(b.tableIdsJson) as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList();
      if (!ids.contains(tempId)) continue;
      final remapped = [for (final i in ids) i == tempId ? realId : i];
      await (update(bookingsTable)..where((x) => x.id.equals(b.id))).write(
        BookingsTableCompanion(tableIdsJson: Value(jsonEncode(remapped))),
      );
    }
  }

  /// Resolves a floor-plan table id that may be a stale temp id.
  ///
  /// Call this on ANY path that persists a table id sourced from in-memory state
  /// (checkout, save-open-order): the cart can hold a temp id from before a sync,
  /// and it is the last writer, so it would otherwise overwrite a correctly
  /// remapped row with the dead value.
  ///
  /// Non-negative ids (and null) pass through untouched — a real server id is
  /// never in the map, so this costs one indexed PK lookup only in the offline
  /// case. An unresolvable temp id returns **null** rather than the dead id: an
  /// order with no table is recoverable, one pointing at a nonexistent table is
  /// a dangling reference the server would reject.
  Future<int?> resolveFloorPlanTableId(int? tableId) async {
    if (tableId == null || tableId >= 0) return tableId;
    final row = await (select(floorPlanTableIdMapTable)
          ..where((t) => t.tempId.equals(tableId)))
        .getSingleOrNull();
    return row?.realId;
  }

  /// Recomputes a document's paid status from its live (non-deleted) payments
  /// and persists it (flagged dirty so SyncManager PATCHes it to the server).
  /// 0 = Unpaid, 1 = Paid, 2 = Partial. Unlike [setLocalPaidStatus] this NEVER
  /// deletes payments — it only reflects them — so it's safe to call after every
  /// payment add / edit / delete. Documents with a non-positive total (refunds,
  /// credit notes) are left untouched; their status is owned by their own flow.
  /// Returns the resulting status (the current one if left unchanged).
  Future<int> recomputePaidStatus(String docLocalId) async {
    final doc = await (select(documentsTable)
          ..where((t) => t.localId.equals(docLocalId))
          ..limit(1))
        .getSingleOrNull();
    if (doc == null) return 0;
    if (doc.total <= 0) return doc.paidStatus;

    final payments = await (select(paymentsTable)
          ..where((t) => t.documentId.equals(docLocalId))
          ..where((t) => t.syncStatus.equals('pending_delete').not()))
        .get();
    final paid = payments.fold<double>(0, (s, p) => s + p.amount);

    // 0.005 tolerance keeps two-decimal currency rounding from reading a fully
    // settled balance as "Partial".
    final int status = paid <= 0.005
        ? 0
        : (paid >= doc.total - 0.005 ? 1 : 2);

    if (status != doc.paidStatus) {
      await (update(documentsTable)..where((t) => t.localId.equals(docLocalId)))
          .write(DocumentsTableCompanion(
        paidStatus: Value(status),
        paidStatusDirty: const Value(true),
        lastModified: Value(DateTime.now().toUtc()),
      ));
    }
    return status;
  }

  /// Live payments for a document, newest-last, hiding soft-deleted rows.
  Stream<List<PaymentsTableData>> watchPayments(String docLocalId) =>
      (select(paymentsTable)
            ..where((t) => t.documentId.equals(docLocalId))
            ..where((t) => t.syncStatus.equals('pending_delete').not())
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .watch();

  /// Inserts an editor-added payment locally with a 'pending_create' status.
  Future<void> insertLocalPayment(PaymentsTableCompanion payment) =>
      into(paymentsTable).insert(payment);

  /// Edits a payment's amount offline-first. A never-synced row stays
  /// 'pending_create'; an already-synced row is flagged 'pending_update'.
  Future<void> editLocalPayment({
    required String localId,
    required double amount,
    required String currentSyncStatus,
  }) {
    final next =
        currentSyncStatus == 'pending_create' ? 'pending_create' : 'pending_update';
    return (update(paymentsTable)..where((t) => t.localId.equals(localId)))
        .write(PaymentsTableCompanion(
      amount: Value(amount),
      syncStatus: Value(next),
    ));
  }

  /// Deletes a payment offline-first. A row that never reached the server is
  /// removed outright; one with a server id is soft-deleted ('pending_delete')
  /// so the pusher can issue /Payments/Delete on the next sync.
  Future<void> deleteLocalPayment({
    required String localId,
    required int? serverId,
  }) {
    if (serverId == null) {
      return (delete(paymentsTable)..where((t) => t.localId.equals(localId)))
          .go();
    }
    return (update(paymentsTable)..where((t) => t.localId.equals(localId)))
        .write(const PaymentsTableCompanion(syncStatus: Value('pending_delete')));
  }

  /// Replaces the server-synced payment rows for a document with a fresh server
  /// snapshot, preserving any local unsynced edits (pending_*). Called when the
  /// editor opens online so the cache reflects payments made on other devices.
  Future<void> reconcileServerPayments(
    String docLocalId,
    List<PaymentsTableCompanion> serverRows,
  ) {
    return transaction(() async {
      // Keep local pending edits keyed by their server id out of the wipe.
      final pendingRows = await (select(paymentsTable)
            ..where((t) => t.documentId.equals(docLocalId))
            ..where((t) => t.syncStatus.equals('pending_update') |
                t.syncStatus.equals('pending_delete')))
          .get();
      final lockedServerIds =
          pendingRows.map((r) => r.serverId).whereType<int>().toSet();

      // 🚨 `sessionLocalId` is DEVICE knowledge — the server does not return it,
      // so a snapshot rebuilt from the API carries null. Without this map, just
      // OPENING a document (the editor refreshes its payments from the server)
      // wiped the link between the payment and the session whose drawer took
      // the money: the payment vanished from the session's Payments tab AND
      // dropped out of its takings, quietly shrinking expected cash.
      final existing = await (select(paymentsTable)
            ..where((t) => t.documentId.equals(docLocalId)))
          .get();
      final sessionByServerId = <int, String>{
        for (final row in existing)
          if (row.serverId != null && row.sessionLocalId != null)
            row.serverId!: row.sessionLocalId!,
      };

      // Wipe everything that is server-authoritative (synced) or a legacy
      // checkout 'pending' row — the snapshot supersedes them. pending_create /
      // pending_update / pending_delete rows survive.
      await (delete(paymentsTable)
            ..where((t) => t.documentId.equals(docLocalId))
            ..where((t) =>
                t.syncStatus.equals('synced') | t.syncStatus.equals('pending')))
          .go();

      for (final row in serverRows) {
        if (row.serverId.present &&
            lockedServerIds.contains(row.serverId.value)) {
          continue; // a local pending edit owns this server id
        }
        // Carry the session link across the wipe unless the caller set one.
        final preserved = row.serverId.present
            ? sessionByServerId[row.serverId.value]
            : null;
        final toInsert = (row.sessionLocalId.present || preserved == null)
            ? row
            : row.copyWith(sessionLocalId: Value(preserved));
        await into(paymentsTable)
            .insert(toInsert, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ── Sync getters / markers for offline-first paid status + payments ────────

  Future<List<DocumentsTableData>> getPaidStatusDirtyDocuments(int companyId) =>
      (select(documentsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.paidStatusDirty.equals(true))
            ..where((t) => t.serverId.isNotNull()))
          .get();

  Future<void> clearPaidStatusDirty(String docLocalId) =>
      (update(documentsTable)..where((t) => t.localId.equals(docLocalId)))
          .write(const DocumentsTableCompanion(paidStatusDirty: Value(false)));

  Future<List<PaymentsTableData>> getPaymentsBySyncStatus(String status) =>
      (select(paymentsTable)..where((t) => t.syncStatus.equals(status))).get();

  Future<void> markPaymentSynced(String localId, int? serverId) =>
      (update(paymentsTable)..where((t) => t.localId.equals(localId)))
          .write(PaymentsTableCompanion(
        serverId: serverId == null ? const Value.absent() : Value(serverId),
        syncStatus: const Value('synced'),
      ));

  Future<void> hardDeletePayment(String localId) =>
      (delete(paymentsTable)..where((t) => t.localId.equals(localId))).go();

  // ─── Offline-first MANUAL document editor (header + items) ─────────────────

  /// Inserts a brand-new editor document. The caller sets localId (UUID) and
  /// syncStatus 'pending_create'.
  Future<void> createManualDocument(DocumentsTableCompanion doc) =>
      into(documentsTable).insert(doc);

  /// Writes header fields for an editor document and queues a server push.
  /// A document that was never synced stays 'pending_create'; an already-synced
  /// one becomes 'pending_update'. `total` is optional (recomputed from items).
  Future<void> updateManualDocumentHeader(
    String localId,
    DocumentsTableCompanion fields,
  ) async {
    final current = await getDocumentByLocalId(localId);
    final next = current?.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(documentsTable)..where((t) => t.localId.equals(localId)))
        .write(fields.copyWith(
      syncStatus: Value(next),
      lastModified: Value(DateTime.now().toUtc()),
    ));
  }

  /// Persists the recomputed document total without changing its sync intent
  /// beyond flagging it for push.
  Future<void> setDocumentTotalLocal(String localId, double total) async {
    final current = await getDocumentByLocalId(localId);
    final next = current?.syncStatus == 'pending_create'
        ? 'pending_create'
        : current?.syncStatus == 'synced'
            ? 'pending_update'
            : (current?.syncStatus ?? 'pending_update');
    await (update(documentsTable)..where((t) => t.localId.equals(localId)))
        .write(DocumentsTableCompanion(
      total: Value(total),
      syncStatus: Value(next),
      lastModified: Value(DateTime.now().toUtc()),
    ));
  }

  /// Erases every row this terminal holds, leaving the schema intact.
  ///
  /// 🚨 Called when the server reports that this terminal's company has been
  /// **deleted in the admin portal**. Until this existed, revocation only ran
  /// `AuthStorage.unlinkDevice()` — which clears the JWT, the lease and the
  /// cached company id, and touches **nothing in Drift**. So every product,
  /// price, customer, order, document, payment and setting of the deleted
  /// company stayed on disk in `pos_app.sqlite` indefinitely: still readable,
  /// still copied into every nightly backup, and still there if the terminal was
  /// later re-linked to a *different* company. Deleting a tenant has to mean its
  /// data is gone from the terminals too, not just from the server.
  ///
  /// A **full** wipe rather than a `WHERE company_id = ?` sweep, deliberately:
  ///  * a terminal is linked to exactly one company at a time (`AuthStorage`
  ///    stores a single company id), so there is no second tenant to preserve;
  ///  * many child tables (`pos_order_items`, `document_items`, `payments`,
  ///    `discount_lines`, `pos_order_item_taxes`…) key off a parent's **localId**
  ///    and carry no `company_id` at all — a scoped sweep would leave them behind
  ///    as permanent orphans, which is the exact failure being fixed;
  ///  * the reference mirrors (`countries`, `currencies`, `document_types`,
  ///    `document_categories`) are re-pulled on the next sync at no cost.
  ///
  /// ⚠️ This destroys unsynced local work. That is correct here and only here:
  /// the company no longer exists server-side, so a pending sale has nowhere
  /// left to go. **Never call this for a sign-out, a seat release, or a lease
  /// expiry** — those terminals must keep their data.
  Future<void> purgeAllLocalData() async {
    await transaction(() async {
      // FKs are declared with cascades; clearing children first keeps the order
      // irrelevant and avoids depending on `PRAGMA foreign_keys` being on.
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  /// Deletes an editor document offline-first. A never-synced document (and its
  /// items, via cascade) is removed outright; a synced one is soft-deleted
  /// ('pending_delete') so the pusher can DELETE it on the next sync.
  Future<void> deleteDocumentLocal(String localId) async {
    final current = await getDocumentByLocalId(localId);
    if (current == null) return;
    // Drop the document's discount breakdown either way — the document is going
    // away, and the server cascades its own DiscountLine rows when the delete
    // syncs (DiscountLine→Document FK is ON DELETE CASCADE).
    await purgeDiscountLinesFor(localId);
    if (current.serverId == null && current.syncStatus != 'synced') {
      await (delete(documentsTable)..where((t) => t.localId.equals(localId)))
          .go();
      return;
    }
    await (update(documentsTable)..where((t) => t.localId.equals(localId)))
        .write(const DocumentsTableCompanion(syncStatus: Value('pending_delete')));
  }

  Future<List<DocumentsTableData>> getDocumentsBySyncStatus(
    int companyId,
    String status,
  ) =>
      (select(documentsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals(status)))
          .get();

  /// Live, active (non-deleted) items for a document — drives the editor list.
  Stream<List<DocumentItemsTableData>> watchDocumentItems(String docLocalId) =>
      (select(documentItemsTable)
            ..where((t) => t.documentId.equals(docLocalId))
            ..where((t) => t.syncStatus.equals('pending_delete').not()))
          .watch();

  /// Active items for a document (excludes soft-deleted) — used to recompute the
  /// document total.
  Future<List<DocumentItemsTableData>> getActiveDocumentItems(
          String docLocalId) =>
      (select(documentItemsTable)
            ..where((t) => t.documentId.equals(docLocalId))
            ..where((t) => t.syncStatus.equals('pending_delete').not()))
          .get();

  Future<void> insertDocumentItemLocal(DocumentItemsTableCompanion item) =>
      into(documentItemsTable).insert(item);

  /// Keeps the single `manual_item` discount line for an editor document item in
  /// step with its discount, so the offline "Discounts by source" report counts
  /// item discounts entered in the manual editor (checkout already records its
  /// own). Resolves the parent doc from the item row and self-gates: it is a
  /// NO-OP for checkout/POS documents (orderNumber set) — their discount lines
  /// are written at checkout and reconciled from the server, so writing here
  /// would double-count after a pull. Replaces any existing manual_item line for
  /// [itemLocalId], then inserts a fresh `pending` one when [amount] > 0.
  Future<void> syncManualItemDiscountLine({
    required String itemLocalId,
    required int companyId,
    required int productId,
    required double value,
    required int valueType,
    required double amount,
  }) async {
    final item = await (select(documentItemsTable)
          ..where((t) => t.localId.equals(itemLocalId))
          ..limit(1))
        .getSingleOrNull();
    if (item == null) return;
    final doc = await getDocumentByLocalId(item.documentId);
    if (doc == null) return;
    if (doc.orderNumber != null && doc.orderNumber!.isNotEmpty) return;
    await transaction(() async {
      await (delete(discountLinesTable)
            ..where((t) => t.itemLocalId.equals(itemLocalId))
            ..where((t) => t.source.equals(DiscountSource.manualItem)))
          .go();
      if (amount <= 0) return;
      await into(discountLinesTable).insert(DiscountLinesTableCompanion(
        localId: Value(const Uuid().v4()),
        companyId: Value(companyId),
        documentLocalId: Value(item.documentId),
        itemLocalId: Value(itemLocalId),
        source: const Value(DiscountSource.manualItem),
        sourceRefId: Value(productId),
        value: Value(value),
        valueType: Value(valueType),
        amount: Value(double.parse(amount.toStringAsFixed(4))),
        sequence: const Value(0),
        syncStatus: const Value('pending'),
        lastModified: Value(DateTime.now().toUtc()),
      ));
    });
  }

  /// Edits an item offline-first. A never-synced row stays 'pending_create';
  /// a synced row becomes 'pending_update'.
  Future<void> updateDocumentItemLocal(
    String localId,
    DocumentItemsTableCompanion fields,
  ) async {
    final current = await (select(documentItemsTable)
          ..where((t) => t.localId.equals(localId))
          ..limit(1))
        .getSingleOrNull();
    final next = current?.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(documentItemsTable)..where((t) => t.localId.equals(localId)))
        .write(fields.copyWith(syncStatus: Value(next)));
  }

  /// Deletes an item offline-first. A never-synced row is removed; a synced one
  /// is soft-deleted ('pending_delete').
  Future<void> deleteDocumentItemLocal(String localId) async {
    final current = await (select(documentItemsTable)
          ..where((t) => t.localId.equals(localId))
          ..limit(1))
        .getSingleOrNull();
    if (current == null) return;
    // Drop the item's manual_item discount line so the offline "Discounts by
    // source" report doesn't keep counting a removed item. Manual docs only —
    // checkout docs' lines are server-managed (a pull would re-add them anyway).
    final doc = await getDocumentByLocalId(current.documentId);
    if (doc != null && (doc.orderNumber == null || doc.orderNumber!.isEmpty)) {
      await (delete(discountLinesTable)
            ..where((t) => t.itemLocalId.equals(localId))
            ..where((t) => t.source.equals(DiscountSource.manualItem)))
          .go();
    }
    if (current.serverId == null && current.syncStatus != 'synced') {
      await (delete(documentItemsTable)
            ..where((t) => t.localId.equals(localId)))
          .go();
      return;
    }
    await (update(documentItemsTable)..where((t) => t.localId.equals(localId)))
        .write(const DocumentItemsTableCompanion(
            syncStatus: Value('pending_delete')));
  }

  Future<List<DocumentItemsTableData>> getDocumentItemsBySyncStatus(
          String status) =>
      (select(documentItemsTable)..where((t) => t.syncStatus.equals(status)))
          .get();

  Future<void> markDocumentItemSynced(String localId, int? serverId) =>
      (update(documentItemsTable)..where((t) => t.localId.equals(localId)))
          .write(DocumentItemsTableCompanion(
        serverId: serverId == null ? const Value.absent() : Value(serverId),
        syncStatus: const Value('synced'),
      ));

  Future<void> hardDeleteDocumentItem(String localId) =>
      (delete(documentItemsTable)..where((t) => t.localId.equals(localId)))
          .go();

  // ─── Document types / categories (pull-only master data) ───────────────────

  Stream<List<DocumentTypesTableData>> watchDocumentTypes() =>
      select(documentTypesTable).watch();

  Stream<List<DocumentCategoriesTableData>> watchDocumentCategories(
          int companyId) =>
      (select(documentCategoriesTable)
            ..where((t) => t.companyId.equals(companyId)))
          .watch();

  Future<void> upsertDocumentTypes(
          List<DocumentTypesTableCompanion> rows) async =>
      batch((b) => b.insertAllOnConflictUpdate(documentTypesTable, rows));

  Future<void> upsertDocumentCategories(
          List<DocumentCategoriesTableCompanion> rows) async =>
      batch((b) => b.insertAllOnConflictUpdate(documentCategoriesTable, rows));

  // ─── Void reasons (pull-only master data) ──────────────────────────────────

  Stream<List<VoidReasonsTableData>> watchVoidReasons(int companyId) =>
      (select(voidReasonsTable)
            ..where((t) => t.companyId.equals(companyId))
            // Hide rows tombstoned offline (pending server delete queued).
            ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
            ..orderBy([(t) => OrderingTerm.asc(t.rank)]))
          .watch();

  /// Full-replace the SYNCED void reasons for a company (small dataset; mirrors
  /// server deletes that a delta pull would miss). Locally-pending rows
  /// (create/update/delete not yet pushed) are preserved — local changes win.
  Future<void> replaceVoidReasons(
          int companyId, List<VoidReasonsTableCompanion> rows) =>
      transaction(() async {
        final pendingIds =
            (await (select(voidReasonsTable)
                      ..where((t) => t.companyId.equals(companyId))
                      ..where((t) => t.syncStatus.isNotIn(['synced'])))
                    .get())
                .map((r) => r.id)
                .toSet();

        await (delete(voidReasonsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where((t) => t.syncStatus.equals('synced')))
            .go();

        final toInsert =
            rows.where((r) => !pendingIds.contains(r.id.value)).toList();
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(voidReasonsTable, toInsert,
              mode: InsertMode.insertOrReplace));
        }
      });

  // ─── Offline-first VOID REASON CRUD (mirrors taxes) ────────────────────────

  Future<int> _nextVoidReasonTempId() async {
    final row = await (selectOnly(voidReasonsTable)
          ..addColumns([voidReasonsTable.id.min()]))
        .getSingleOrNull();
    final min = row?.read(voidReasonsTable.id.min());
    return ((min != null && min < 0) ? min : 0) - 1;
  }

  /// Offline-first upsert. Null [id] creates with a temp id (pending_create);
  /// otherwise updates in place (keeping pending_create across edits).
  Future<int> saveVoidReasonLocal({
    int? id,
    required int companyId,
    required String name,
    required int rank,
  }) async {
    if (id == null) {
      final tempId = await _nextVoidReasonTempId();
      await into(voidReasonsTable).insert(
        VoidReasonsTableCompanion(
          id: Value(tempId),
          companyId: Value(companyId),
          name: Value(name),
          rank: Value(rank),
          lastModified: Value(DateTime.now().toUtc()),
          syncStatus: const Value('pending_create'),
        ),
      );
      return tempId;
    }

    final existing = await (select(voidReasonsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final nextStatus = existing?.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(voidReasonsTable)..where((t) => t.id.equals(id))).write(
      VoidReasonsTableCompanion(
        name: Value(name),
        rank: Value(rank),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(nextStatus),
      ),
    );
    return id;
  }

  /// Temp row hard-deleted; real row tombstoned for the next sync push.
  Future<void> deleteVoidReasonLocal(int id) async {
    if (id < 0) {
      await (delete(voidReasonsTable)..where((t) => t.id.equals(id))).go();
    } else {
      await (update(voidReasonsTable)..where((t) => t.id.equals(id))).write(
        const VoidReasonsTableCompanion(syncStatus: Value('pending_delete')),
      );
    }
  }

  // ─── Offline-first COMPANY edit (update-only; logo stays online) ───────────

  /// Writes the My Company field edits to the local cache and marks the row
  /// pending_update; pushPendingCompanyOps pushes /Company/Update on next sync.
  /// Does not touch the logo (handled separately by the online upload path).
  Future<void> saveCompanyLocal({
    required int id,
    required String name,
    int? countryId,
    String? taxNumber,
    String? postalCode,
    String? city,
    String? email,
    String? phoneNumber,
    String? bankAccountNumber,
    String? bankDetails,
    String? streetName,
    String? additionalStreetName,
    String? buildingNumber,
    String? plotIdentification,
    String? citySubdivisionName,
    String? countrySubentity,
  }) async {
    await (update(companiesTable)..where((t) => t.id.equals(id))).write(
      CompaniesTableCompanion(
        name: Value(name),
        countryId: Value(countryId),
        taxNumber: Value(taxNumber),
        postalCode: Value(postalCode),
        city: Value(city),
        email: Value(email),
        phone: Value(phoneNumber),
        bankAccountNumber: Value(bankAccountNumber),
        bankDetails: Value(bankDetails),
        streetName: Value(streetName),
        additionalStreetName: Value(additionalStreetName),
        buildingNumber: Value(buildingNumber),
        plotIdentification: Value(plotIdentification),
        citySubdivisionName: Value(citySubdivisionName),
        countrySubentity: Value(countrySubentity),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: const Value('pending_update'),
      ),
    );
  }

  /// Upserts a Document + items + payment pulled from the server.
  /// localId is fabricated as 'srv_<serverId>' for server-originated rows.
  Future<void> upsertServerDocument({
    required DocumentsTableCompanion document,
    required List<DocumentItemsTableCompanion> items,
    List<PaymentsTableCompanion> payments = const [],
  }) {
    return transaction(() async {
      await into(documentsTable).insertOnConflictUpdate(document);
      // Replace items — simpler than diffing for server-pulled data.
      await (delete(documentItemsTable)
            ..where((t) => t.documentId.equals(document.localId.value)))
          .go();
      if (items.isNotEmpty) {
        await batch((b) { b.insertAll(documentItemsTable, items); });
      }
      await replaceServerPayments(document.localId.value, payments);
    });
  }

  /// Replaces the SERVER-OWNED payments of a document, leaving local work alone.
  ///
  /// 🚨 There was no payment pull at all — `payments` had a push and nothing
  /// else — so a sale rung up on one terminal reached every other one with zero
  /// payment rows. Sales history showed "N/A" in the Paiement column, and far
  /// worse, the Z-report's breakdown-by-payment-type and the credit screen read
  /// the same table, so **each till only ever counted its own sales**.
  ///
  /// ⚠️ Only `synced` rows are replaced. A payment still queued here
  /// (`pending`, `pending_create/update/delete`) is owned by the pusher until it
  /// lands; deleting it would drop money the server has not seen yet — the same
  /// rule as every other pull (handoff §3).
  Future<void> replaceServerPayments(
    String documentLocalId,
    List<PaymentsTableCompanion> payments,
  ) async {
    final localPending = await (select(paymentsTable)
          ..where((t) => t.documentId.equals(documentLocalId))
          ..where((t) => t.syncStatus.equals('synced').not()))
        .get();
    // A pulled payment that this device is already holding as a pending edit
    // must not be re-inserted underneath that edit.
    final heldServerIds =
        localPending.map((p) => p.serverId).whereType<int>().toSet();

    await (delete(paymentsTable)
          ..where((t) => t.documentId.equals(documentLocalId))
          ..where((t) => t.syncStatus.equals('synced')))
        .go();

    for (final p in payments) {
      final sid = p.serverId.present ? p.serverId.value : null;
      if (sid != null && heldServerIds.contains(sid)) continue;
      await into(paymentsTable).insertOnConflictUpdate(p);
    }
  }

  /// Queues a voided order for server sync and deletes the local open-order row.
  /// Items cascade-delete via the FK. The caller should also restore local
  /// stock quantities (via deductStockForCheckout with negative quantities or
  /// a dedicated helper) so the UI reflects the freed inventory immediately.
  ///
  /// Refuses (throws [UnbankedCheckoutException]) when the order is still the
  /// carrier for an unbanked checkout — see [assertNotUnbankedCarrier]. A void
  /// only ever targets an OPEN order, which has no document, so this cannot fire
  /// in a normal flow; it is here because deleting that row is the one action
  /// that permanently strands a paid sale.
  Future<void> queueVoidAndDeleteOrder({
    required String localId,
    required int serverOrderId,
    required int companyId,
    required int userId,
    required String orderNumber,
    required int warehouseId,
    required String itemsJson,
    String? reason,
  }) async {
    await assertNotUnbankedCarrier(localId);
    return transaction(() async {
      await into(pendingVoidsTable).insert(
        PendingVoidsTableCompanion(
          localId:       Value(const Uuid().v4()),
          serverOrderId: Value(serverOrderId),
          companyId:     Value(companyId),
          userId:        Value(userId),
          orderNumber:   Value(orderNumber),
          warehouseId:   Value(warehouseId),
          itemsJson:     Value(itemsJson),
          reason:        Value(reason),
          voidedAt:      Value(DateTime.now().toUtc()),
        ),
      );
      // Delete the open-order row (cascade removes its items too).
      await (delete(posOrdersTable)
            ..where((t) => t.localId.equals(localId)))
          .go();
      // discount_lines link by local id with no FK cascade, so remove them
      // explicitly — a voided order leaves no discount records behind.
      await purgeDiscountLinesFor(localId);
    });
  }

  /// Returns all pending voids that haven't been synced to the server yet.
  Future<List<PendingVoidsTableData>> getPendingVoids() =>
      (select(pendingVoidsTable)
            ..where((t) => t.syncStatus.equals('pending')))
          .get();

  /// Marks a void as synced after the server confirms both the PosVoid records
  /// and the PosOrder deletion were processed successfully.
  Future<void> markVoidSynced(String localId) =>
      (update(pendingVoidsTable)..where((t) => t.localId.equals(localId)))
          .write(const PendingVoidsTableCompanion(
        syncStatus: Value('synced'),
      ));

  // ─── The `pos_orders` carrier rule (backlog item 33) ───────────────────────
  //
  // 🚨 A completed offline sale is carried to the server BY ITS `pos_orders`
  // ROW. The Document + Payment are created server-side as a side effect of
  // `/PosOrder/BatchSync`, which is why `pushPendingDocuments` /
  // `pushPendingPayments` deliberately skip `'pending'` rows (pushing them there
  // too would double-create every sale — see `lib/sync/sync_status.dart`).
  //
  // The consequence: delete the order row before the push lands and NO code path
  // on the client can ever send that sale again. It sits in Sync Status as a
  // number that counts down forever while the takings are, in practice, gone.
  // That happened on a live terminal on 2026-08-15.
  //
  // Two defences, both below: nothing in the app removes a carrier row while its
  // checkout is unbanked, and anything already orphaned (a hand-run DELETE in a
  // DB tool can't be prevented) is rebuilt from the document it left behind.

  /// True when [orderLocalId] is still the only carrier for an unbanked
  /// checkout: a SALES document exists under the same local id, has never been
  /// stamped with a `serverId`, and is still `'pending'`.
  ///
  /// Refunds are excluded on purpose — they reach the server through
  /// `pushPendingRefundOps` (`/Document/Refund`), not through an order row, so
  /// they are never stranded by one going missing.
  Future<bool> isUnbankedCheckoutCarrier(String orderLocalId) async {
    final doc = await (select(documentsTable)
          ..where((t) => t.localId.equals(orderLocalId))
          ..where((t) => t.documentTypeId.equals(DocumentTypes.sales))
          ..where((t) => t.serverId.isNull())
          ..where((t) => t.syncStatus.equals('pending'))
          ..limit(1))
        .getSingleOrNull();
    return doc != null;
  }

  /// Throws [UnbankedCheckoutException] if removing [orderLocalId] would strand
  /// a paid sale. Called by every app-side path that deletes a `pos_orders` row
  /// for a reason OTHER than "the server has it now".
  Future<void> assertNotUnbankedCarrier(String orderLocalId) async {
    if (await isUnbankedCheckoutCarrier(orderLocalId)) {
      throw UnbankedCheckoutException(orderLocalId);
    }
  }

  /// Deletes a local order row and its discount lines, refusing if that would
  /// strand an unbanked sale. Items cascade via the FK; `discount_lines` link by
  /// local id with no cascade, so they are purged explicitly.
  ///
  /// For orders the app discards deliberately (void of a never-pushed order).
  Future<void> deleteLocalOrder(String localId) async {
    await assertNotUnbankedCarrier(localId);
    await transaction(() async {
      await (delete(posOrdersTable)..where((t) => t.localId.equals(localId)))
          .go();
      await purgeDiscountLinesFor(localId);
    });
  }

  /// Deletes a completed order and its items from local SQLite after the
  /// server confirms the Document + Payment were created. Items are removed
  /// automatically by the CASCADE FK on `pos_order_items.order_id`.
  ///
  /// Returns false — and keeps the row — when the checkout is still unbanked.
  /// The normal push path stamps the document `synced` (`linkDocumentToServer`)
  /// immediately before calling this, so a refusal means the caller got its
  /// ordering wrong, not that the operator did something. Deliberately logged
  /// rather than thrown: this runs inside the per-result loop of
  /// `pushPendingOrders`, where a throw would be swallowed anyway.
  Future<bool> deleteCompletedOrder(String localId) async {
    if (await isUnbankedCheckoutCarrier(localId)) {
      debugPrint(
          'deleteCompletedOrder: refused for $localId — its checkout document '
          'is still pending, deleting the order would strand the sale.');
      return false;
    }
    await (delete(posOrdersTable)..where((t) => t.localId.equals(localId)))
        .go();
    return true;
  }

  /// Sales documents that are `'pending'`, have no `serverId`, and whose
  /// carrier `pos_orders` row no longer exists — i.e. paid sales that no push
  /// path can reach. Cheap enough to run at the start of every sync.
  ///
  /// Scoped to [companyId]: rebuilding a carrier queues it for the push that is
  /// running right now, and that push banks every pending order against the
  /// company being synced.
  Future<List<DocumentsTableData>> findStrandedCheckouts(int companyId) async {
    final candidates = await (select(documentsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.documentTypeId.equals(DocumentTypes.sales))
          ..where((t) => t.syncStatus.equals('pending'))
          ..where((t) => t.serverId.isNull()))
        .get();
    if (candidates.isEmpty) return const [];

    final carried = (await (selectOnly(posOrdersTable)
              ..addColumns([posOrdersTable.localId])
              ..where(posOrdersTable.localId
                  .isIn(candidates.map((d) => d.localId).toList())))
            .get())
        .map((r) => r.read(posOrdersTable.localId)!)
        .toSet();

    return candidates.where((d) => !carried.contains(d.localId)).toList();
  }

  /// Rebuilds the missing `pos_orders` carrier for a stranded checkout from the
  /// document it left behind, so the ordinary BatchSync push banks the sale.
  ///
  /// Rebuilding was chosen over a new "ingest a finished offline sale" endpoint
  /// precisely because it reuses the proven server path: stock movement, loyalty
  /// and the Z-report all keep behaving exactly as they do for a normal sale
  /// instead of being re-implemented (which is how totals drift).
  ///
  /// Fidelity notes, all deliberate:
  ///  * `pos_order_items` that OUTLIVED their header (a DB tool with
  ///    `foreign_keys` off leaves them behind) are kept as-is — they carry the
  ///    per-tax amounts, the kitchen comment and the per-item warehouse, which
  ///    the document lines do not.
  ///  * Rebuilt from `document_items`, a multi-tax line collapses to the single
  ///    `taxId` the document stored, carrying the whole `taxAmount`. The money
  ///    is exact; only the per-tax attribution is approximate.
  ///  * `tableId` is left null. Occupancy is derived from OPEN orders, and this
  ///    one is closed — re-pointing it at a table would re-occupy it.
  ///
  /// ⚠️ If the original push actually reached the server and only its response
  /// was lost, replaying creates a duplicate (with a fresh number — the server
  /// renumbers on collision, backlog item 30). That trade is taken knowingly:
  /// `Document` carries no client id, so same-sale and different-sale are
  /// indistinguishable server-side, and a visible duplicate an operator can void
  /// is recoverable where a lost sale is not.
  Future<StrandedRepairOutcome> rebuildOrderForStrandedCheckout(
    String documentLocalId,
  ) {
    return transaction(() async {
      final doc = await (select(documentsTable)
            ..where((t) => t.localId.equals(documentLocalId)))
          .getSingleOrNull();
      if (doc == null ||
          doc.serverId != null ||
          doc.syncStatus != 'pending' ||
          doc.documentTypeId != DocumentTypes.sales) {
        return StrandedRepairOutcome.skipped;
      }

      final carrier = await (select(posOrdersTable)
            ..where((t) => t.localId.equals(documentLocalId)))
          .getSingleOrNull();
      if (carrier != null) return StrandedRepairOutcome.skipped;

      final survivingItems = await (select(posOrderItemsTable)
            ..where((t) => t.orderId.equals(documentLocalId)))
          .get();
      final docItems = await (select(documentItemsTable)
            ..where((t) => t.documentId.equals(documentLocalId)))
          .get();
      // The payment is what the checkout actually took, and BatchSync banks the
      // sale against it. Without one there is nothing to infer it from —
      // guessing a payment type would mis-state the drawer and the Z-report, so
      // such a document is surfaced for a human instead.
      final payments = await (select(paymentsTable)
            ..where((t) => t.documentId.equals(documentLocalId)))
          .get();
      if ((survivingItems.isEmpty && docItems.isEmpty) || payments.isEmpty) {
        return StrandedRepairOutcome.unrecoverable;
      }

      await into(posOrdersTable).insert(
        PosOrdersTableCompanion.insert(
          localId: documentLocalId,
          companyId: doc.companyId,
          userId: doc.userId,
          serviceType: doc.serviceType,
          openedAt: doc.date,
          warehouseId: doc.warehouseId,
          lastModified: DateTime.now().toUtc(),
          closedAt: Value(doc.date),
          status: const Value(1), // completed sale, awaiting upload
          total: Value(doc.total),
          discount: Value(doc.discount),
          discountType: Value(doc.discountType),
          customerId: Value(doc.customerId),
          orderName: Value(doc.orderNumber),
          // Carried verbatim so the server keeps the number already printed on
          // the customer's receipt (it only reissues on a real collision).
          number: Value(doc.number),
          paymentTypeId: Value(payments.first.paymentTypeId),
          amountPaid:
              Value(payments.fold<double>(0, (sum, p) => sum + p.amount)),
          syncStatus: const Value('pending'),
        ),
      );

      if (survivingItems.isEmpty) {
        await batch((b) {
          b.insertAll(
            posOrderItemsTable,
            docItems.map((di) => PosOrderItemsTableCompanion(
                  // The SAME line id the document item carries: BatchSync echoes
                  // each created DocumentItem's server id back keyed by it, so
                  // the local document_items row still gets stamped.
                  localId: Value(di.localId),
                  orderId: Value(documentLocalId),
                  productId: Value(di.productId),
                  quantity: Value(di.quantity),
                  unitPrice: Value(di.unitPrice),
                  discount: Value(di.discount),
                  discountType: Value(di.discountType),
                  taxRate: Value(di.taxRate),
                  taxesJson: Value(di.taxId == null
                      ? null
                      : jsonEncode([
                          {'id': di.taxId, 'amount': di.taxAmount}
                        ])),
                  warehouseId: Value(doc.warehouseId),
                  syncStatus: const Value('pending'),
                )),
          );
        });
      }

      return StrandedRepairOutcome.rebuilt;
    });
  }

  /// Parks an unrecoverable stranded checkout (and its payment) at `failed` so
  /// Sync Status shows it as needing attention instead of counting it as
  /// pending work that will never complete.
  Future<void> markStrandedCheckoutFailed(String documentLocalId) {
    return transaction(() async {
      await (update(documentsTable)
            ..where((t) => t.localId.equals(documentLocalId)))
          .write(const DocumentsTableCompanion(syncStatus: Value('failed')));
      await (update(paymentsTable)
            ..where((t) => t.documentId.equals(documentLocalId))
            ..where((t) => t.syncStatus.equals('pending')))
          .write(const PaymentsTableCompanion(syncStatus: Value('failed')));
    });
  }

  /// Upserts an open (status=0) order and replaces its items atomically.
  /// Used by the offline-first SAVE button — creates a new local row the
  /// first time and updates it on every subsequent re-save.
  Future<void> saveOpenOrder(
    PosOrdersTableCompanion order,
    List<PosOrderItemsTableCompanion> newItems, {
    List<PosOrderItemTaxesTableCompanion> itemTaxes = const [],
  }) {
    return transaction(() async {
      await into(posOrdersTable).insertOnConflictUpdate(order);

      await (delete(posOrderItemsTable)
            ..where((t) => t.orderId.equals(order.localId.value)))
          .go();
      if (newItems.isNotEmpty) {
        await batch((b) {
          b.insertAll(posOrderItemsTable, newItems);
        });
      }

      await (delete(posOrderItemTaxesTable)
            ..where((t) => t.orderId.equals(order.localId.value)))
          .go();
      if (itemTaxes.isNotEmpty) {
        await batch((b) {
          b.insertAll(posOrderItemTaxesTable, itemTaxes);
        });
      }
    });
  }

  /// Stamps the server-assigned id on a row mid-sync without flipping
  /// syncStatus to 'synced' yet. Lets pushPendingOpenOrders record the
  /// server id after `POST /PosOrder/Create` succeeds but before
  /// `POST /PosOrderItem/BulkAdd` completes, so a crash between the two
  /// steps restarts at the item-add phase rather than re-creating the header.
  Future<void> setServerId(String localId, int serverId) {
    return (update(posOrdersTable)..where((t) => t.localId.equals(localId)))
        .write(PosOrdersTableCompanion(serverId: Value(serverId)));
  }

  /// Returns every COMPLETED (status=1) pending order together with its items.
  /// Used by SyncManager.pushPendingOrders → BatchSync.
  Future<List<PosOrderWithItems>> getPendingOrders() async {
    final orders = await (select(posOrdersTable)
          ..where((t) => t.syncStatus.equals('pending'))
          ..where((t) => t.status.equals(1)))
        .get();

    if (orders.isEmpty) return const [];

    final result = <PosOrderWithItems>[];
    for (final order in orders) {
      final items = await (select(posOrderItemsTable)
            ..where((t) => t.orderId.equals(order.localId)))
          .get();
      result.add(PosOrderWithItems(order: order, items: items));
    }
    return result;
  }

  /// Returns every OPEN (status=0) pending order together with its items.
  /// Used by SyncManager.pushPendingOpenOrders to create/update orders on the
  /// server without going through BatchSync (which is for completed orders).
  Future<List<PosOrderWithItems>> getPendingOpenOrders() async {
    final orders = await (select(posOrdersTable)
          ..where((t) => t.syncStatus.equals('pending'))
          ..where((t) => t.status.equals(0)))
        .get();

    if (orders.isEmpty) return const [];

    final result = <PosOrderWithItems>[];
    for (final order in orders) {
      final items = await (select(posOrderItemsTable)
            ..where((t) => t.orderId.equals(order.localId)))
          .get();
      result.add(PosOrderWithItems(order: order, items: items));
    }
    return result;
  }

  /// Stamp the row with the server-assigned id and flip the status. Called
  /// after a successful BatchSync result. Items are flipped too so failed-
  /// retry queries don't surface them again.
  Future<void> markOrderSynced(String localId, int serverId) {
    return transaction(() async {
      final now = DateTime.now().toUtc();
      await (update(posOrdersTable)
            ..where((t) => t.localId.equals(localId)))
          .write(PosOrdersTableCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
        syncError: const Value(null),
        lastModified: Value(now),
      ));
      await (update(posOrderItemsTable)
            ..where((t) => t.orderId.equals(localId)))
          .write(const PosOrderItemsTableCompanion(
        syncStatus: Value('synced'),
      ));
    });
  }

  /// The open local row for a server order id, or null.
  ///
  /// `.get().firstOrNull`, never `getSingleOrNull()` — that throws on a
  /// duplicate serverId, and a caller in a UI action would surface it as an
  /// opaque failure (see the open-order pull, where exactly that killed sync).
  Future<PosOrdersTableData?> getOpenOrderByServerId(int serverId) =>
      (select(posOrdersTable)
            ..where((t) => t.serverId.equals(serverId))
            ..where((t) => t.status.equals(0))
            ..limit(1))
          .get()
          .then((r) => r.firstOrNull);

  /// Moves an open order's LOCAL row to another table.
  ///
  /// 🚨 The Transfer dialog updated the server (`/PosOrder/Update`) and the
  /// in-memory cart, and wrote **nothing to Drift** — so the old table stayed
  /// occupied and the order appeared on BOTH: floor-plan occupancy is derived
  /// from local open `pos_orders.tableId` (see §3 — `floor_plan_tables.status`
  /// is a dead column), and that row still pointed at the origin.
  ///
  /// Worse for a row with unpushed edits: the open-order pull deliberately will
  /// not overwrite a `pending` row's `tableId`, so the stale table survived the
  /// next poll AND the eventual push sent it back — dragging the server order
  /// to the table it had just been moved off.
  ///
  /// [orderName] is written alongside because the transfer renames the order
  /// after its destination table; leaving the two to disagree is what let the
  /// name-matching branch of the pull adopt the wrong row.
  ///
  /// The row keeps its current `syncStatus`: if it was `pending` it still has
  /// work to push, and if it was `synced` the server has already been told.
  Future<void> moveOrderToTable({
    required String localId,
    required int? tableId,
    String? orderName,
    int? userId,
  }) {
    return (update(posOrdersTable)..where((t) => t.localId.equals(localId)))
        .write(PosOrdersTableCompanion(
      tableId: Value(tableId),
      orderName: orderName == null ? const Value.absent() : Value(orderName),
      userId: userId == null ? const Value.absent() : Value(userId),
      lastModified: Value(DateTime.now().toUtc()),
    ));
  }

  /// The booking that owns server order [posOrderId], or null.
  ///
  /// 🚨 This is the ONLY way a second terminal can recover the link. The
  /// relation is stored on `Booking.PosOrderId` — `PosOrder` has no BookingId
  /// column and `PosOrderDto` therefore cannot carry one — so an order pulled by
  /// `syncOpenOrdersToDrift` arrives with no booking attached. Without this
  /// lookup, opening a reservation's order on another till lost its booking, and
  /// paying it never completed the reservation.
  Future<int?> bookingIdForPosOrder(int posOrderId) async {
    final row = await (select(bookingsTable)
          ..where((t) => t.posOrderId.equals(posOrderId))
          ..limit(1))
        .get()
        .then((r) => r.firstOrNull);
    return row?.id;
  }

  /// Sets a booking's forward link to its now-synced order (the reverse
  /// pos_orders.bookingId already exists). The row stays 'synced' — the server
  /// was just updated by the order push — so this only keeps the local
  /// mirror consistent until the next booking pull re-reconciles it.
  Future<void> linkBookingPosOrder(int bookingId, int posOrderId) {
    return (update(bookingsTable)..where((t) => t.id.equals(bookingId)))
        .write(BookingsTableCompanion(posOrderId: Value(posOrderId)));
  }

  /// Clears the local forward link when a booking's order is voided, mirroring
  /// the server's UnlinkPosOrder so the stale order id can't drive "Open Order".
  Future<void> unlinkBookingPosOrder(int bookingId) {
    return (update(bookingsTable)..where((t) => t.id.equals(bookingId)))
        .write(const BookingsTableCompanion(posOrderId: Value(null)));
  }

  /// Repoints orders at a booking's real server id after its offline temp id
  /// (negative) is swapped by the booking push. Without this, an order started
  /// from a not-yet-synced booking keeps the dead temp id — the reverse link
  /// breaks, "Start Service" reappears (duplicate-order risk), and paying can
  /// never complete the booking. Returns the affected orders so the caller can
  /// late-link any that already reached the server.
  Future<List<PosOrdersTableData>> remapOrderBookingId(
      int tempId, int realId) async {
    final affected = await (select(posOrdersTable)
          ..where((t) => t.bookingId.equals(tempId)))
        .get();
    if (affected.isEmpty) return const [];
    await (update(posOrdersTable)..where((t) => t.bookingId.equals(tempId)))
        .write(PosOrdersTableCompanion(bookingId: Value(realId)));
    return affected;
  }

  /// Returns orders parked at terminal `failed` whose recorded reason is an
  /// INFRASTRUCTURE fault, and flips them back to `pending` so the next push
  /// picks them up. Returns how many were requeued.
  ///
  /// 🚨 `failed` has no retry path anywhere — the push queries select `pending`
  /// only. That is correct for a business rejection, and data loss for a server
  /// fault: on 2026-08-06 a **completed, paid sale** was stranded permanently
  /// because the API was restarted before a migration was applied and BatchSync
  /// answered "Invalid column name 'DiscountInputValue'". The push path no
  /// longer marks such failures terminal; this heals rows stranded before that
  /// fix shipped, and any future one that slips through.
  ///
  /// Matching is on the same signatures as `SyncManager._isRetryableServerError`
  /// — narrow on purpose, so a genuinely rejected order is never re-pushed in a
  /// loop.
  Future<int> requeueInfrastructureFailedOrders() async {
    const signatures = [
      'invalid column name',
      'invalid object name',
      'timeout',
      // SQL Server's Win32Exception 258 says "timed out", not "timeout".
      'timed out',
      'deadlock',
      'transport',
      'connection',
      'pre-login',
      'temporarily unable',
    ];
    final failed = await (select(posOrdersTable)
          ..where((t) => t.syncStatus.equals('failed')))
        .get();

    var requeued = 0;
    for (final row in failed) {
      final reason = (row.syncError ?? '').toLowerCase();
      if (!signatures.any(reason.contains)) continue;
      await (update(posOrdersTable)
            ..where((t) => t.localId.equals(row.localId)))
          .write(const PosOrdersTableCompanion(
        syncStatus: Value('pending'),
      ));
      requeued++;
    }
    return requeued;
  }

  /// Record a failure on the order header. The row stays in the DB and the
  /// user can retry it from the Failed Syncs screen (planned).
  Future<void> markOrderFailed(String localId, String errorMessage) {
    return (update(posOrdersTable)
          ..where((t) => t.localId.equals(localId)))
        .write(PosOrdersTableCompanion(
      syncStatus: const Value('failed'),
      syncError: Value(errorMessage),
      lastModified: Value(DateTime.now().toUtc()),
    ));
  }

  /// Records why an order's push didn't go through *without* flipping it out of
  /// 'pending' — so the next sync still retries it (the cause may be transient,
  /// e.g. out of stock or a not-yet-synced product) while the Sync Status panel
  /// can surface the reason instead of it living only in a debugPrint.
  Future<void> setOrderSyncError(String localId, String errorMessage) {
    return (update(posOrdersTable)
          ..where((t) => t.localId.equals(localId)))
        .write(PosOrdersTableCompanion(syncError: Value(errorMessage)));
  }

  // ─── Discount lines (normalized per-discount records) ─────────────────────
  // One row per applied discount; see [DiscountLinesTable] / [DiscountSource].
  // A checkout shares one localId across the order + document, so write-time
  // helpers accept either link and the replace helpers clear by either.

  /// Replaces all discount lines for an order (and/or its document) in one
  /// transaction, then inserts [lines]. Matches on order OR document local id so
  /// it works whether the caller knows one link or both. Pass an empty [lines]
  /// list to simply clear them.
  Future<void> replaceDiscountLines({
    String? orderLocalId,
    String? documentLocalId,
    required List<DiscountLinesTableCompanion> lines,
  }) async {
    assert(orderLocalId != null || documentLocalId != null,
        'replaceDiscountLines needs an order or document local id');
    await transaction(() async {
      final del = delete(discountLinesTable)
        ..where((t) {
          Expression<bool>? pred;
          if (orderLocalId != null) {
            pred = t.orderLocalId.equals(orderLocalId);
          }
          if (documentLocalId != null) {
            final d = t.documentLocalId.equals(documentLocalId);
            pred = pred == null ? d : pred | d;
          }
          return pred!;
        });
      await del.go();
      if (lines.isNotEmpty) {
        await batch((b) => b.insertAll(discountLinesTable, lines));
      }
    });
  }

  /// All discount lines attached to an order, in application order.
  Future<List<DiscountLinesTableData>> getDiscountLinesForOrder(
          String orderLocalId) =>
      (select(discountLinesTable)
            ..where((t) => t.orderLocalId.equals(orderLocalId))
            ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
          .get();

  /// All discount lines attached to a document, in application order.
  Future<List<DiscountLinesTableData>> getDiscountLinesForDocument(
          String documentLocalId) =>
      (select(discountLinesTable)
            ..where((t) => t.documentLocalId.equals(documentLocalId))
            ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
          .get();

  /// Replaces the *synced* discount lines of a document with [lines] pulled from
  /// the server (multi-device mirror). Locally-pending lines are preserved so an
  /// edit not yet pushed isn't clobbered by an older server snapshot.
  Future<void> replacePulledDiscountLines(
      String documentLocalId, List<DiscountLinesTableCompanion> lines) async {
    await transaction(() async {
      await (delete(discountLinesTable)
            ..where((t) => t.documentLocalId.equals(documentLocalId))
            ..where((t) => t.syncStatus.equals('synced')))
          .go();
      if (lines.isNotEmpty) {
        await batch((b) => b.insertAll(discountLinesTable, lines));
      }
    });
  }

  /// Removes every discount line tied to a sale's [localId] — matching EITHER
  /// link, since a checkout shares one localId across its order and document.
  /// Call this whenever an order or document is deleted so no discount records
  /// are ever left orphaned. (Server-side rows are cascade-deleted by the
  /// DiscountLine→Document FK when the document delete syncs.)
  Future<void> purgeDiscountLinesFor(String localId) =>
      (delete(discountLinesTable)
            ..where((t) =>
                t.orderLocalId.equals(localId) |
                t.documentLocalId.equals(localId)))
          .go();

  /// Marks every discount line for an order as synced — called after its sale
  /// pushes successfully (the server persisted the matching DiscountLine rows).
  Future<void> markDiscountLinesSynced(String orderLocalId) =>
      (update(discountLinesTable)
            ..where((t) => t.orderLocalId.equals(orderLocalId)))
          .write(const DiscountLinesTableCompanion(syncStatus: Value('synced')));

  /// Discount lines still pending push (offline outbox), oldest first.
  Future<List<DiscountLinesTableData>> getPendingDiscountLines(int companyId) =>
      (select(discountLinesTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals('pending')))
          .get();

  /// Sums discount amounts by `source` over [from]..[to] (by document date),
  /// for sales reporting. Returns source → total currency deducted. Joins to
  /// `documents` so only finalized sales count (parked-order drafts, which have
  /// no document yet, are excluded). The amount is the resolved money figure, so
  /// % and fixed lines aggregate correctly without ever being mixed.
  Future<Map<String, double>> discountTotalsBySource(
      int companyId, DateTime from, DateTime to) async {
    final amountSum = discountLinesTable.amount.sum();
    final query = selectOnly(discountLinesTable).join([
      innerJoin(
        documentsTable,
        documentsTable.localId.equalsExp(discountLinesTable.documentLocalId),
      ),
    ])
      ..addColumns([discountLinesTable.source, amountSum])
      ..where(documentsTable.companyId.equals(companyId) &
          documentsTable.date.isBetweenValues(from, to))
      ..groupBy([discountLinesTable.source]);

    final rows = await query.get();
    return {
      for (final r in rows)
        (r.read(discountLinesTable.source) ?? ''): (r.read(amountSum) ?? 0),
    };
  }

  /// Local Z-report history for a company, newest-first. Offline-first source
  /// for the End-of-Day "History" tab.
  Future<List<ZReportsTableData>> getZReportHistory(int companyId) =>
      (select(zReportsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..orderBy([(t) => OrderingTerm.desc(t.closedAt)]))
          .get();

  /// All cached stocks for a company — offline-first source for the stock list.
  /// Soft-deleted rows (pending_delete) are hidden so they vanish immediately.
  Future<List<StocksTableData>> getStocksForCompany(int companyId) =>
      (select(stocksTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals('pending_delete').not()))
          .get();

  // ─── Offline-first PRODUCT TAXES (per-product tax assignment) ──────────────

  /// Active (non-deleted) tax assignments for a product.
  Future<List<ProductTaxesTableData>> getProductTaxes(int productId) =>
      (select(productTaxesTable)
            ..where((t) => t.productId.equals(productId))
            ..where((t) => t.syncStatus.equals('pending_delete').not()))
          .get();

  // ─── Offline-first PRODUCT COMMENT CRUD (mirrors taxes/void reasons) ───────

  /// Next temp (negative) id, distinct from any server id, for an offline create.
  Future<int> _nextProductCommentTempId() async {
    final row = await (selectOnly(productCommentsTable)
          ..addColumns([productCommentsTable.id.min()]))
        .getSingleOrNull();
    final min = row?.read(productCommentsTable.id.min());
    return ((min != null && min < 0) ? min : 0) - 1;
  }

  /// Offline-first create. Writes the comment locally with a temp id +
  /// pending_create so the menu's modifier popup sees it instantly (online or
  /// offline); pushPendingProductCommentOps later POSTs it and swaps in the
  /// server id. Returns the temp id. [productId] may itself be a temp product id
  /// (offline-created product) — remapProductId repoints it before the push.
  Future<int> createProductCommentLocal({
    required int companyId,
    required int productId,
    required String comment,
  }) async {
    final tempId = await _nextProductCommentTempId();
    await into(productCommentsTable).insert(
      ProductCommentsTableCompanion(
        id: Value(tempId),
        companyId: Value(companyId),
        productId: Value(productId),
        comment: Value(comment),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: const Value('pending_create'),
      ),
    );
    return tempId;
  }

  /// Upserts a comment pulled from the server as 'synced'. Used by
  /// [pullProductComments]; never overwrites a row the user is locally deleting.
  Future<void> upsertSyncedProductComment({
    required int id,
    required int companyId,
    required int productId,
    required String comment,
    required DateTime lastModified,
  }) =>
      into(productCommentsTable).insertOnConflictUpdate(
        ProductCommentsTableCompanion(
          id: Value(id),
          companyId: Value(companyId),
          productId: Value(productId),
          comment: Value(comment),
          lastModified: Value(lastModified),
          syncStatus: const Value('synced'),
        ),
      );

  /// Offline-first delete. A never-synced row (temp/pending_create) is removed
  /// outright; a server-known row is flagged pending_delete so the push issues
  /// the server DELETE. Reads exclude pending_delete, so it disappears at once.
  Future<void> deleteProductCommentLocal(int id) async {
    final row = await (select(productCommentsTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    if (row.syncStatus == 'pending_create' || row.id < 0) {
      await (delete(productCommentsTable)..where((t) => t.id.equals(id))).go();
    } else {
      await (update(productCommentsTable)..where((t) => t.id.equals(id))).write(
        const ProductCommentsTableCompanion(syncStatus: Value('pending_delete')),
      );
    }
  }

  /// Hard-remove (used by the push after the server delete/create swap).
  Future<void> hardDeleteProductComment(int id) =>
      (delete(productCommentsTable)..where((t) => t.id.equals(id))).go();

  /// Local comments still needing a server push.
  Future<List<ProductCommentsTableData>> getPendingProductComments(
          int companyId) =>
      (select(productCommentsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.isIn(['pending_create', 'pending_delete'])))
          .get();

  /// Server ids the user has locally flagged for deletion — [pullProductComments]
  /// skips these so an incremental pull can't resurrect them before the push.
  Future<Set<int>> pendingDeleteProductCommentIds(int companyId) async {
    final rows = await (select(productCommentsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.syncStatus.equals('pending_delete')))
        .get();
    return rows.map((r) => r.id).toSet();
  }

  /// Changes a product's single assigned tax offline-first: removes the old
  /// assignment and adds the new one (either may be null = none).
  Future<void> setProductTaxLocal({
    required int companyId,
    required int productId,
    required int? oldTaxId,
    required int? newTaxId,
  }) async {
    if (oldTaxId == newTaxId) return;
    await transaction(() async {
      if (oldTaxId != null) {
        final row = await (select(productTaxesTable)
              ..where((t) => t.productId.equals(productId))
              ..where((t) => t.taxId.equals(oldTaxId)))
            .getSingleOrNull();
        if (row != null) {
          if (row.syncStatus == 'pending_create') {
            // Never synced — just drop it.
            await (delete(productTaxesTable)
                  ..where((t) => t.productId.equals(productId))
                  ..where((t) => t.taxId.equals(oldTaxId)))
                .go();
          } else {
            await (update(productTaxesTable)
                  ..where((t) => t.productId.equals(productId))
                  ..where((t) => t.taxId.equals(oldTaxId)))
                .write(const ProductTaxesTableCompanion(
                    syncStatus: Value('pending_delete')));
          }
        }
      }
      if (newTaxId != null) {
        await into(productTaxesTable).insertOnConflictUpdate(
          ProductTaxesTableCompanion(
            productId: Value(productId),
            taxId: Value(newTaxId),
            companyId: Value(companyId),
            syncStatus: const Value('pending_create'),
          ),
        );
      }
    });
  }

  Future<List<ProductTaxesTableData>> getProductTaxesBySyncStatus(
          int companyId, String status) =>
      (select(productTaxesTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals(status)))
          .get();

  Future<void> markProductTaxSynced(int productId, int taxId) =>
      (update(productTaxesTable)
            ..where((t) => t.productId.equals(productId))
            ..where((t) => t.taxId.equals(taxId)))
          .write(const ProductTaxesTableCompanion(syncStatus: Value('synced')));

  Future<void> hardDeleteProductTax(int productId, int taxId) =>
      (delete(productTaxesTable)
            ..where((t) => t.productId.equals(productId))
            ..where((t) => t.taxId.equals(taxId)))
          .go();

  /// Cascades a product's temp→real id swap to every product-keyed local table
  /// so offline-created taxes / stock rules / barcodes / stock rows push with
  /// the real product id. Called inside pushPendingProductOps' create swap.
  Future<void> remapProductId(int tempId, int realId) async {
    await (update(barcodesTable)..where((t) => t.productId.equals(tempId)))
        .write(BarcodesTableCompanion(productId: Value(realId)));
    await (update(productTaxesTable)..where((t) => t.productId.equals(tempId)))
        .write(ProductTaxesTableCompanion(productId: Value(realId)));
    await (update(stockControlsTable)..where((t) => t.productId.equals(tempId)))
        .write(StockControlsTableCompanion(productId: Value(realId)));
    await (update(stocksTable)..where((t) => t.productId.equals(tempId)))
        .write(StocksTableCompanion(productId: Value(realId)));
    // Offline-created comments on an offline product must push with the real
    // product id, else /ProductComments/Add 400s on an unknown productId.
    await (update(productCommentsTable)
          ..where((t) => t.productId.equals(tempId)))
        .write(ProductCommentsTableCompanion(productId: Value(realId)));
    // Promotion built offline that targets an offline product: /Promotions/Add
    // sends items[].productId, so repoint it before pushPendingPromotionOps.
    await (update(promotionItemsTable)
          ..where((t) => t.productId.equals(tempId)))
        .write(PromotionItemsTableCompanion(productId: Value(realId)));
    // Queued stock move/reassign whose newProductId is an offline product.
    await (update(pendingStockOpsTable)
          ..where((t) => t.productId.equals(tempId)))
        .write(PendingStockOpsTableCompanion(productId: Value(realId)));
    // Transactional references: an offline product sold/added in an offline
    // order or document must repoint at the real id, otherwise BatchSync /
    // document push 400s on a productId the server never saw.
    await (update(posOrderItemsTable)..where((t) => t.productId.equals(tempId)))
        .write(PosOrderItemsTableCompanion(productId: Value(realId)));
    await (update(documentItemsTable)..where((t) => t.productId.equals(tempId)))
        .write(DocumentItemsTableCompanion(productId: Value(realId)));

    // Queued offline voids store their items as a JSON blob, so a column UPDATE
    // can't reach the temp productId inside. Rewrite each pending blob in place
    // (runs during the product push, before pushPendingVoids sends them).
    final pendingVoids = await (select(pendingVoidsTable)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    for (final v in pendingVoids) {
      final decoded = jsonDecode(v.itemsJson);
      if (decoded is! List) continue;
      var changed = false;
      for (final item in decoded) {
        if (item is Map && item['productId'] == tempId) {
          item['productId'] = realId;
          changed = true;
        }
      }
      if (changed) {
        await (update(pendingVoidsTable)
              ..where((t) => t.localId.equals(v.localId)))
            .write(PendingVoidsTableCompanion(itemsJson: Value(jsonEncode(decoded))));
      }
    }
  }

  /// Cascade a payment-type id swap (temp → real) to every row that references
  /// it, so an offline-created payment type used in an offline sale doesn't
  /// leave the order/payment pointing at a dead temp id ("Unknown" + stuck).
  Future<void> remapPaymentTypeId(int tempId, int realId) async {
    await (update(paymentsTable)..where((t) => t.paymentTypeId.equals(tempId)))
        .write(PaymentsTableCompanion(paymentTypeId: Value(realId)));
    await (update(posOrdersTable)..where((t) => t.paymentTypeId.equals(tempId)))
        .write(PosOrdersTableCompanion(paymentTypeId: Value(realId)));
  }

  /// Cascade a product-group id swap (temp → real) to products assigned to an
  /// offline-created group, so the product push doesn't reference a dead group.
  Future<void> remapProductGroupId(int tempId, int realId) async {
    await (update(productsTable)
          ..where((t) => t.productGroupId.equals(tempId)))
        .write(ProductsTableCompanion(productGroupId: Value(realId)));
  }

  // ─── Offline document numbering ────────────────────────────────────────────

  /// Atomically issues the next device-local document number of the form
  /// `<DeviceName>-<DocTypeCode>-<NNNNNN>` for the given company + document type
  /// (e.g. `CAISSE1-200-000045`). Fully offline; the device-name prefix makes it
  /// collision-free across terminals, and it never changes once issued. The
  /// counter is per (company, doc-type) and lives in a device-local table the
  /// sync never touches.
  Future<String> nextDocumentNumber({
    required int companyId,
    required String deviceName,
    required String docTypeCode,
  }) async {
    final key = '$companyId:$docTypeCode';
    final seq = await transaction(() async {
      final row = await (select(localDocCountersTable)
            ..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      final next = (row?.value ?? 0) + 1;
      await into(localDocCountersTable).insertOnConflictUpdate(
        LocalDocCountersTableCompanion(key: Value(key), value: Value(next)),
      );
      return next;
    });
    final prefix = _sanitizeDevicePrefix(deviceName);
    return '$prefix-$docTypeCode-${seq.toString().padLeft(6, '0')}';
  }

  /// Pushes the device-local counter PAST the highest number already issued
  /// under this terminal's prefix, and reports how many numbers it skipped
  /// (0 = already ahead, nothing written).
  ///
  /// 🚨 The counter lives in a device-local table the sync never touches, so it
  /// ROLLS BACK with a restore while the cloud keeps every number the dead
  /// terminal had already issued. The till then re-issues `POS1-200-000007` for
  /// a completely different sale — which is how two unrelated sales end up
  /// sharing a number and colliding on `UQ_Document_Number_PerCompany`.
  ///
  /// Run after every document pull, so both halves are covered: numbers the
  /// cloud already holds, and (after a restore) numbers sitting in the restored
  /// backup itself. The server-side renumber (backlog item 30) stays as the
  /// safety net — this is the first line of defence.
  Future<int> advanceLocalDocumentCounter({
    required int companyId,
    required String deviceName,
    required String docTypeCode,
  }) async {
    final prefix = '${_sanitizeDevicePrefix(deviceName)}-$docTypeCode-';
    final rows = await (select(documentsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.number.like('$prefix%')))
        .get();

    // Match the trailing digit run only — a hand-typed number sharing the
    // prefix ("POS1-200-000007-2") must not be read as a sequence value.
    final pattern = RegExp('^${RegExp.escape(prefix)}([0-9]+)\$');
    var highest = 0;
    for (final r in rows) {
      final m = pattern.firstMatch(r.number ?? '');
      final seq = m == null ? null : int.tryParse(m.group(1)!);
      if (seq != null && seq > highest) highest = seq;
    }
    if (highest == 0) return 0;

    final key = '$companyId:$docTypeCode';
    return transaction(() async {
      final row = await (select(localDocCountersTable)
            ..where((t) => t.key.equals(key)))
          .getSingleOrNull();
      final current = row?.value ?? 0;
      if (current >= highest) return 0;
      await into(localDocCountersTable).insertOnConflictUpdate(
        LocalDocCountersTableCompanion(key: Value(key), value: Value(highest)),
      );
      return highest - current;
    });
  }

  static String _sanitizeDevicePrefix(String name) {
    final cleaned = name.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (cleaned.isEmpty) return 'POS';
    return cleaned.length > 12 ? cleaned.substring(0, 12) : cleaned;
  }

  /// Removes rows that reference a temp (negative) productId for which **no
  /// product row exists** — orphans left by an interrupted/abandoned offline
  /// product create. The server has no such product, so these can never sync;
  /// retrying them forever just spams 400s (barcodes, stock controls) and leaves
  /// a sale stuck at "(Pending sync)".
  ///
  /// Safe + idempotent: a temp-id reference whose product row still exists
  /// locally (pending_create, not yet pushed) is preserved — only true orphans
  /// are purged. Run at the start of each sync.
  Future<int> purgeOrphanedTempRefs() async {
    // Temp product ids that still have a product row → keep anything pointing
    // at them. With none, every temp reference is an orphan (isNotIn([]) → true).
    final liveTempProductIds =
        (await (selectOnly(productsTable)
                  ..addColumns([productsTable.id])
                  ..where(productsTable.id.isSmallerThanValue(0)))
                .get())
            .map((r) => r.read(productsTable.id)!)
            .toList();

    var removed = 0;

    // 1. Orphan product-keyed config rows.
    removed += await (delete(barcodesTable)
          ..where((t) =>
              t.productId.isSmallerThanValue(0) &
              t.productId.isNotIn(liveTempProductIds)))
        .go();
    removed += await (delete(stockControlsTable)
          ..where((t) =>
              t.productId.isSmallerThanValue(0) &
              t.productId.isNotIn(liveTempProductIds)))
        .go();
    removed += await (delete(stocksTable)
          ..where((t) =>
              t.productId.isSmallerThanValue(0) &
              t.productId.isNotIn(liveTempProductIds)))
        .go();
    removed += await (delete(productTaxesTable)
          ..where((t) =>
              t.productId.isSmallerThanValue(0) &
              t.productId.isNotIn(liveTempProductIds)))
        .go();

    // 2. Orphan offline sales: any pending order whose item references an orphan
    //    temp product is unrecoverable (the product it sold no longer exists) →
    //    discard the whole local sale (order + its document/payment/items).
    final orphanOrderIds =
        (await (selectOnly(posOrderItemsTable)
                  ..addColumns([posOrderItemsTable.orderId])
                  ..where(posOrderItemsTable.productId.isSmallerThanValue(0) &
                      posOrderItemsTable.productId
                          .isNotIn(liveTempProductIds)))
                .get())
            .map((r) => r.read(posOrderItemsTable.orderId)!)
            .toSet();

    for (final localId in orphanOrderIds) {
      await (delete(posOrderItemsTable)
            ..where((t) => t.orderId.equals(localId)))
          .go();
      await (delete(posOrdersTable)..where((t) => t.localId.equals(localId)))
          .go();
      // insertOfflineDocument keys the document on the same localId.
      await (delete(documentItemsTable)
            ..where((t) => t.documentId.equals(localId)))
          .go();
      await (delete(paymentsTable)..where((t) => t.documentId.equals(localId)))
          .go();
      removed += await (delete(documentsTable)
            ..where((t) => t.localId.equals(localId)))
          .go();
    }

    return removed;
  }

  // ─── Offline-first TAX CRUD (mirrors the products/warehouses pattern) ──────

  /// Next negative temp id for an offline-created tax row.
  Future<int> _nextTaxTempId() async {
    final row = await (selectOnly(taxesTable)
          ..addColumns([taxesTable.id.min()]))
        .getSingleOrNull();
    final min = row?.read(taxesTable.id.min());
    return ((min != null && min < 0) ? min : 0) - 1;
  }

  /// Offline-first upsert of a tax rate. A null [id] creates a new row with a
  /// temp negative id (pending_create); a non-null id updates in place. A row
  /// that is still pending_create keeps that status across edits, so its first
  /// push to the server is always a create — never an update on an id the
  /// server has never seen. Returns the row id (temp id for new rows).
  Future<int> saveTaxLocal({
    int? id,
    required int companyId,
    required String name,
    required double rate,
    String? code,
    required bool isFixed,
    required bool isTaxOnTotal,
    required bool isEnabled,
  }) async {
    if (id == null) {
      final tempId = await _nextTaxTempId();
      await into(taxesTable).insert(
        TaxesTableCompanion(
          id: Value(tempId),
          companyId: Value(companyId),
          name: Value(name),
          rate: Value(rate),
          code: Value(code),
          isFixed: Value(isFixed),
          isTaxOnTotal: Value(isTaxOnTotal),
          isEnabled: Value(isEnabled),
          lastModified: Value(DateTime.now().toUtc()),
          syncStatus: const Value('pending_create'),
        ),
      );
      return tempId;
    }

    final existing = await (select(taxesTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final nextStatus = existing?.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(taxesTable)..where((t) => t.id.equals(id))).write(
      TaxesTableCompanion(
        name: Value(name),
        rate: Value(rate),
        code: Value(code),
        isFixed: Value(isFixed),
        isTaxOnTotal: Value(isTaxOnTotal),
        isEnabled: Value(isEnabled),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(nextStatus),
      ),
    );
    return id;
  }

  /// Offline-first delete. A never-synced temp row is hard-deleted; a real row
  /// is tombstoned (pending_delete) so the next sync issues the server delete.
  Future<void> deleteTaxLocal(int id) async {
    if (id < 0) {
      await (delete(taxesTable)..where((t) => t.id.equals(id))).go();
    } else {
      await (update(taxesTable)..where((t) => t.id.equals(id))).write(
        const TaxesTableCompanion(syncStatus: Value('pending_delete')),
      );
    }
  }

  /// Cascade a tax id swap (temp → real) to product-tax assignments so their
  /// pending pushes reference the real id.
  Future<void> remapTaxId(int tempId, int realId) async {
    await (update(productTaxesTable)..where((t) => t.taxId.equals(tempId)))
        .write(ProductTaxesTableCompanion(taxId: Value(realId)));
  }

  // ─── Offline-first BOOKINGS CRUD (mirrors taxes/warehouses) ────────────────

  /// Next negative temp id for an offline-created booking row.
  Future<int> _nextBookingTempId() async {
    final row = await (selectOnly(bookingsTable)
          ..addColumns([bookingsTable.id.min()]))
        .getSingleOrNull();
    final min = row?.read(bookingsTable.id.min());
    return ((min != null && min < 0) ? min : 0) - 1;
  }

  /// Active bookings that would collide with [start]–[end] on [resourceIds].
  /// An empty result means the slot is free. Fully offline — the local
  /// `bookings` table is authoritative for the calendar.
  ///
  /// Overlap is the standard half-open test: `newStart < existingEnd &&
  /// newEnd > existingStart`. Two bookings that merely *touch* — one ending
  /// exactly as the next begins — do not collide, which is what back-to-back
  /// sittings need.
  ///
  /// The time window is filtered in SQL, but the resource match is done in Dart
  /// on purpose: a booking's tables live in `tableIdsJson` (a JSON *list* — one
  /// booking can hold several tables), which SQLite can't index into here. The
  /// time filter narrows the set to the few bookings sharing that window first,
  /// so the in-Dart pass stays trivial.
  ///
  /// Status matters: No Show (5) never occupied the resource and Completed (4)
  /// has released it, so neither may block a new booking. Only Scheduled (1),
  /// Arrived (2) and In Service (3) reserve it — the same set
  /// `hasLiveBookingForTable` treats as holding a table.
  Future<List<BookingsTableData>> findConflictingBookings({
    required int companyId,
    required DateTime start,
    required DateTime end,
    required BookingResource resource,
    required Set<int> resourceIds,
    int? excludeBookingId,
  }) async {
    // No resource selected (e.g. staff mode with nobody assigned) reserves
    // nothing, so nothing can clash with it.
    if (resourceIds.isEmpty) return const [];

    final query = select(bookingsTable)
      ..where((t) => t.companyId.equals(companyId))
      // Tombstoned rows are already gone from the calendar; they must not
      // reserve anything either.
      ..where((t) => t.syncStatus.isNotIn(const ['pending_delete']))
      ..where((t) => t.status.isIn(const [1, 2, 3]))
      ..where((t) => t.startTime.isSmallerThanValue(end))
      ..where((t) => t.endTime.isBiggerThanValue(start));
    if (excludeBookingId != null) {
      // Editing: a booking must never be found colliding with itself.
      query.where((t) => t.id.isNotValue(excludeBookingId));
    }

    final rows = await query.get();
    return rows.where((row) {
      switch (resource) {
        case BookingResource.staff:
          return row.userId != null && resourceIds.contains(row.userId);
        case BookingResource.table:
          final ids = (jsonDecode(row.tableIdsJson) as List<dynamic>)
              .map((e) => (e as num).toInt());
          return ids.any(resourceIds.contains);
      }
    }).toList();
  }

  /// Offline-first upsert of a booking. A null [id] creates a row with a temp
  /// negative id (pending_create); a non-null id updates in place, keeping
  /// pending_create if the row was never synced (so its first push is always a
  /// create). Returns the row id (temp id for new rows).
  Future<int> upsertBookingLocal({
    int? id,
    required int companyId,
    int? customerId,
    int? userId,
    required String reservationName,
    List<int> tableIds = const [],
    int? documentId,
    int? posOrderId,
    required DateTime startTime,
    required DateTime endTime,
    int guestCount = 1,
    int status = 1,
    String? note,
  }) async {
    final idsJson = jsonEncode(tableIds);
    if (id == null) {
      final tempId = await _nextBookingTempId();
      await into(bookingsTable).insert(
        BookingsTableCompanion(
          id: Value(tempId),
          companyId: Value(companyId),
          customerId: Value(customerId),
          userId: Value(userId),
          reservationName: Value(reservationName),
          tableIdsJson: Value(idsJson),
          documentId: Value(documentId),
          posOrderId: Value(posOrderId),
          startTime: Value(startTime),
          endTime: Value(endTime),
          guestCount: Value(guestCount),
          status: Value(status),
          note: Value(note),
          lastModified: Value(DateTime.now().toUtc()),
          syncStatus: const Value('pending_create'),
        ),
      );
      return tempId;
    }

    final existing = await (select(
      bookingsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    final nextStatus = existing?.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(bookingsTable)..where((t) => t.id.equals(id))).write(
      BookingsTableCompanion(
        customerId: Value(customerId),
        userId: Value(userId),
        reservationName: Value(reservationName),
        tableIdsJson: Value(idsJson),
        documentId: Value(documentId),
        posOrderId: Value(posOrderId),
        startTime: Value(startTime),
        endTime: Value(endTime),
        guestCount: Value(guestCount),
        status: Value(status),
        note: Value(note),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(nextStatus),
      ),
    );
    return id;
  }

  /// Offline-first status change. Keeps a pending_create row as a create;
  /// otherwise marks pending_update so the next sync pushes the new status.
  Future<void> setBookingStatusLocal(int id, int status) async {
    final existing = await (select(
      bookingsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;
    final nextStatus = existing.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(bookingsTable)..where((t) => t.id.equals(id))).write(
      BookingsTableCompanion(
        status: Value(status),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(nextStatus),
      ),
    );
  }

  /// Offline-first delete. A never-synced temp row is hard-deleted; a real row
  /// is tombstoned (pending_delete) so the next sync issues the server delete.
  Future<void> deleteBookingLocal(int id) async {
    if (id < 0) {
      await (delete(bookingsTable)..where((t) => t.id.equals(id))).go();
    } else {
      await (update(bookingsTable)..where((t) => t.id.equals(id))).write(
        const BookingsTableCompanion(syncStatus: Value('pending_delete')),
      );
    }
  }

  // ─── Offline-first PAYMENT TYPE CRUD (mirrors taxes) ───────────────────────

  /// Next negative temp id for an offline-created payment type.
  Future<int> _nextPaymentTypeTempId() async {
    final row = await (selectOnly(paymentTypesTable)
          ..addColumns([paymentTypesTable.id.min()]))
        .getSingleOrNull();
    final min = row?.read(paymentTypesTable.id.min());
    return ((min != null && min < 0) ? min : 0) - 1;
  }

  /// Offline-first upsert of a payment type. Null [id] creates with a temp id
  /// (pending_create); otherwise updates in place (keeping pending_create across
  /// edits so the first push is a create). Returns the row id.
  Future<int> savePaymentTypeLocal({
    int? id,
    required int companyId,
    required String name,
    String? code,
    required int ordinal,
    String? shortcutKey,
    required bool isEnabled,
    required bool isQuickPayment,
    required bool isCustomerRequired,
    required bool isChangeAllowed,
    required bool markAsPaid,
    required bool openCashDrawer,
    required bool isFiscal,
    required bool isSlipRequired,
  }) async {
    if (id == null) {
      final tempId = await _nextPaymentTypeTempId();
      await into(paymentTypesTable).insert(
        PaymentTypesTableCompanion(
          id: Value(tempId),
          companyId: Value(companyId),
          name: Value(name),
          code: Value(code),
          ordinal: Value(ordinal),
          shortcutKey: Value(shortcutKey),
          isEnabled: Value(isEnabled),
          isQuickPayment: Value(isQuickPayment),
          isCustomerRequired: Value(isCustomerRequired),
          isChangeAllowed: Value(isChangeAllowed),
          markAsPaid: Value(markAsPaid),
          openCashDrawer: Value(openCashDrawer),
          isFiscal: Value(isFiscal),
          isSlipRequired: Value(isSlipRequired),
          lastModified: Value(DateTime.now().toUtc()),
          syncStatus: const Value('pending_create'),
        ),
      );
      return tempId;
    }

    final existing = await (select(paymentTypesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final nextStatus = existing?.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';
    await (update(paymentTypesTable)..where((t) => t.id.equals(id))).write(
      PaymentTypesTableCompanion(
        name: Value(name),
        code: Value(code),
        ordinal: Value(ordinal),
        shortcutKey: Value(shortcutKey),
        isEnabled: Value(isEnabled),
        isQuickPayment: Value(isQuickPayment),
        isCustomerRequired: Value(isCustomerRequired),
        isChangeAllowed: Value(isChangeAllowed),
        markAsPaid: Value(markAsPaid),
        openCashDrawer: Value(openCashDrawer),
        isFiscal: Value(isFiscal),
        isSlipRequired: Value(isSlipRequired),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(nextStatus),
      ),
    );
    return id;
  }

  /// Offline-first delete: temp row hard-deleted, real row tombstoned
  /// (pending_delete) for the next sync push.
  Future<void> deletePaymentTypeLocal(int id) async {
    if (id < 0) {
      await (delete(paymentTypesTable)..where((t) => t.id.equals(id))).go();
    } else {
      await (update(paymentTypesTable)..where((t) => t.id.equals(id))).write(
        const PaymentTypesTableCompanion(syncStatus: Value('pending_delete')),
      );
    }
  }

  /// Upserts a server-pulled product-tax row without clobbering local edits.
  Future<void> upsertSyncedProductTax(ProductTaxesTableCompanion row) async {
    final existing = await (select(productTaxesTable)
          ..where((t) => t.productId.equals(row.productId.value))
          ..where((t) => t.taxId.equals(row.taxId.value)))
        .getSingleOrNull();
    if (existing != null && existing.syncStatus != 'synced') return;
    await into(productTaxesTable).insertOnConflictUpdate(row);
  }

  // ─── Offline-first STOCK CRUD (mirrors the warehouses pattern) ─────────────

  /// Next negative temp id for an offline-created stock row.
  Future<int> _nextStockTempId() async {
    final row = await (selectOnly(stocksTable)
          ..addColumns([stocksTable.id.min()]))
        .getSingleOrNull();
    final min = row?.read(stocksTable.id.min());
    return ((min != null && min < 0) ? min : 0) - 1;
  }

  /// Adds a stock row offline-first (negative temp id, pending_create).
  Future<void> addStockLocal({
    required int companyId,
    required int productId,
    required int warehouseId,
    required double quantity,
  }) async {
    final tempId = await _nextStockTempId();
    await into(stocksTable).insert(StocksTableCompanion(
      id: Value(tempId),
      productId: Value(productId),
      warehouseId: Value(warehouseId),
      companyId: Value(companyId),
      quantity: Value(quantity),
      lastModified: Value(DateTime.now().toUtc()),
      syncStatus: const Value('pending_create'),
    ));
  }

  /// Updates a stock row offline-first. A never-synced (temp) row keeps
  /// 'pending_create'; a synced row becomes 'pending_update'.
  Future<void> updateStockLocal({
    required int id,
    required int productId,
    required int warehouseId,
    required double quantity,
  }) async {
    final cur = await (select(stocksTable)..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    final next =
        cur?.syncStatus == 'pending_create' ? 'pending_create' : 'pending_update';
    await (update(stocksTable)..where((t) => t.id.equals(id))).write(
      StocksTableCompanion(
        productId: Value(productId),
        warehouseId: Value(warehouseId),
        quantity: Value(quantity),
        lastModified: Value(DateTime.now().toUtc()),
        syncStatus: Value(next),
      ),
    );
  }

  /// Deletes a stock row offline-first. A never-synced row is removed outright;
  /// a synced row is soft-deleted ('pending_delete') for the pusher.
  Future<void> deleteStockLocal(int id) async {
    final cur = await (select(stocksTable)..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (cur == null) return;
    if (id < 0 || cur.syncStatus == 'pending_create') {
      await (delete(stocksTable)..where((t) => t.id.equals(id))).go();
      return;
    }
    await (update(stocksTable)..where((t) => t.id.equals(id)))
        .write(const StocksTableCompanion(syncStatus: Value('pending_delete')));
  }

  Future<List<StocksTableData>> getStocksBySyncStatus(
          int companyId, String status) =>
      (select(stocksTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals(status)))
          .get();

  /// Swaps a temp-id stock row for its real server id (and marks it synced).
  Future<void> replaceStockTempId(int tempId, int serverId) =>
      transaction(() async {
        final row = await (select(stocksTable)..where((t) => t.id.equals(tempId)))
            .getSingleOrNull();
        if (row == null) return;
        await (delete(stocksTable)..where((t) => t.id.equals(tempId))).go();
        await into(stocksTable).insertOnConflictUpdate(
          row.toCompanion(true).copyWith(
                id: Value(serverId),
                syncStatus: const Value('synced'),
              ),
        );
      });

  Future<void> markStockSynced(int id) =>
      (update(stocksTable)..where((t) => t.id.equals(id)))
          .write(const StocksTableCompanion(syncStatus: Value('synced')));

  Future<void> hardDeleteStock(int id) =>
      (delete(stocksTable)..where((t) => t.id.equals(id))).go();

  // ─── Offline-first STOCK CONTROL CRUD ──────────────────────────────────────

  /// Saves a per-product stock-control rule offline-first. New rules become
  /// 'pending_create'; edits to a synced rule become 'pending_update'.
  Future<void> saveStockControlLocal({
    required int companyId,
    required int productId,
    required double reorderPoint,
    required double preferredQuantity,
    required bool isLowStockWarningEnabled,
    required double lowStockWarningQuantity,
    int? customerId,
  }) async {
    final existing = await getStockControl(productId);
    final next = (existing?.serverId == null) ? 'pending_create' : 'pending_update';
    await into(stockControlsTable).insertOnConflictUpdate(StockControlsTableCompanion(
      productId: Value(productId),
      companyId: Value(companyId),
      serverId: Value(existing?.serverId),
      reorderPoint: Value(reorderPoint),
      preferredQuantity: Value(preferredQuantity),
      isLowStockWarningEnabled: Value(isLowStockWarningEnabled),
      lowStockWarningQuantity: Value(lowStockWarningQuantity),
      customerId: Value(customerId),
      lastModified: Value(DateTime.now().toUtc()),
      syncStatus: Value(next),
    ));
  }

  /// Deletes a stock-control rule offline-first.
  Future<void> deleteStockControlLocal(int productId) async {
    final existing = await getStockControl(productId);
    if (existing == null) return;
    if (existing.serverId == null) {
      await (delete(stockControlsTable)..where((t) => t.productId.equals(productId)))
          .go();
      return;
    }
    await (update(stockControlsTable)..where((t) => t.productId.equals(productId)))
        .write(const StockControlsTableCompanion(
            syncStatus: Value('pending_delete')));
  }

  Future<List<StockControlsTableData>> getStockControlsBySyncStatus(
          int companyId, String status) =>
      (select(stockControlsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals(status)))
          .get();

  Future<void> markStockControlSynced(int productId, int? serverId) =>
      (update(stockControlsTable)..where((t) => t.productId.equals(productId)))
          .write(StockControlsTableCompanion(
        serverId: serverId == null ? const Value.absent() : Value(serverId),
        syncStatus: const Value('synced'),
      ));

  Future<void> hardDeleteStockControl(int productId) =>
      (delete(stockControlsTable)..where((t) => t.productId.equals(productId)))
          .go();

  /// Upserts a server-pulled stock-control row without clobbering local edits.
  Future<void> upsertSyncedStockControl(StockControlsTableCompanion row) async {
    final pid = row.productId.value;
    final existing = await getStockControl(pid);
    if (existing != null && existing.syncStatus != 'synced') return; // keep local edit
    await into(stockControlsTable).insertOnConflictUpdate(row);
  }
}

/// Pairs a pos_orders row with its line items. Plain Dart so callers
/// (SyncManager, future Failed Syncs screen) don't need Drift internals.
class PosOrderWithItems {
  final PosOrdersTableData order;
  final List<PosOrderItemsTableData> items;

  const PosOrderWithItems({required this.order, required this.items});
}

/// Outcome of [AppDatabase.rebuildOrderForStrandedCheckout].
enum StrandedRepairOutcome {
  /// A carrier `pos_orders` row was rebuilt — the next BatchSync push banks it.
  rebuilt,

  /// Nothing to do: the document already has a carrier, or is no longer
  /// stranded (adopted / synced in the meantime). Idempotency case.
  skipped,

  /// Cannot be replayed: the lines and/or the payment are gone too, so there is
  /// no faithful sale left to send. Parked at `failed` for manual review rather
  /// than counted as pending forever.
  unrecoverable,
}

/// Thrown when the app is about to delete a `pos_orders` row that is still the
/// only carrier for an unbanked checkout — see
/// [AppDatabase.rebuildOrderForStrandedCheckout] for why that strands the sale.
class UnbankedCheckoutException implements Exception {
  const UnbankedCheckoutException(this.orderLocalId);
  final String orderLocalId;

  @override
  String toString() =>
      'This sale has not reached the cloud yet, so its order row cannot be '
      'removed ($orderLocalId). Sync first, then try again.';
}

// ============================================================================
// PHASE 7 — CASH MOVEMENT + Z-REPORT OFFLINE QUEUE HELPERS
// Mounted as a Dart extension so the AppDatabase class stays readable. All
// of these helpers follow the same contract as the order queue:
//   - insertOffline* generates the UUID if the caller didn't supply one and
//     forces syncStatus='pending' / serverId=null so the row is picked up by
//     the next sync push.
//   - getPending* returns rows where syncStatus='pending'.
//   - mark*Synced flips the row to 'synced' and stamps the serverId.
//   - mark*Failed records the error and flips to 'failed' for retry.
// ============================================================================
extension OfflineQueueHelpers on AppDatabase {
  // ---------------- CASH MOVEMENTS ----------------

  Future<void> insertOfflineCashMovement(
      StartingCashTableCompanion movement) async {
    final localId = movement.localId.present && movement.localId.value.isNotEmpty
        ? movement.localId.value
        : const Uuid().v4();

    await into(startingCashTable).insert(
      movement.copyWith(
        localId: Value(localId),
        serverId: const Value(null),
        syncStatus: const Value('pending'),
        syncError: const Value(null),
      ),
    );
  }

  Future<List<StartingCashTableData>> getPendingCashMovements() {
    return (select(startingCashTable)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
  }

  Future<void> markCashMovementSynced(String localId, int serverId) {
    return (update(startingCashTable)
          ..where((t) => t.localId.equals(localId)))
        .write(StartingCashTableCompanion(
      serverId: Value(serverId),
      syncStatus: const Value('synced'),
      syncError: const Value(null),
    ));
  }

  Future<void> markCashMovementFailed(String localId, String errorMessage) {
    return (update(startingCashTable)
          ..where((t) => t.localId.equals(localId)))
        .write(StartingCashTableCompanion(
      syncStatus: const Value('failed'),
      syncError: Value(errorMessage),
    ));
  }

  /// Map of every locally-known server `id` → whether it's *really* finalized
  /// (has a real, server-assigned Z-report number). The optimistic placeholder
  /// (-1) counts as NOT finalized so the pull-sync overwrites it with the
  /// authoritative server number. The pull also uses this to skip re-inserting
  /// rows it already has.
  Future<Map<int, bool>> getStartingCashFinalizationByServerId() async {
    final query = selectOnly(startingCashTable)
      ..addColumns([startingCashTable.serverId, startingCashTable.zReportNumber])
      ..where(startingCashTable.serverId.isNotNull());
    final rows = await query.get();
    return {
      for (final r in rows)
        r.read(startingCashTable.serverId)!: () {
          final z = r.read(startingCashTable.zReportNumber);
          return z != null && z != optimisticZReportPlaceholder;
        }(),
    };
  }

  /// Inserts server-originated cash rows pulled from /StartingCash. Each row
  /// is already `synced` (it lives on the server). New UUID local ids never
  /// collide, so insertOrIgnore is just a belt-and-braces guard.
  Future<void> insertSyncedStartingCash(
      List<StartingCashTableCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAll(startingCashTable, rows,
        mode: InsertMode.insertOrIgnore));
  }

  /// Stamps Z-report numbers onto already-local rows (keyed by server id) once
  /// the server has finalized them — this is what makes finalized entries drop
  /// off the active list on the next sync.
  Future<void> applyStartingCashZReportNumbers(
      Map<int, int> zReportByServerId) async {
    if (zReportByServerId.isEmpty) return;
    await batch((b) {
      zReportByServerId.forEach((serverId, zNumber) {
        b.update(
          startingCashTable,
          StartingCashTableCompanion(zReportNumber: Value(zNumber)),
          where: (t) => t.serverId.equals(serverId),
        );
      });
    });
  }

  /// Placeholder used to mark a cash row as locally finalized *before* the
  /// server has assigned a real sequential Z-report number. Treated as
  /// "not yet finalized" by the pull-sync so the server value overwrites it.
  static const int optimisticZReportPlaceholder = -1;

  /// Optimistic local finalization: stamps the placeholder Z-report number on
  /// every still-active cash row for [companyId] in one atomic transaction, so
  /// they drop out of `watchTodayStartingCash` instantly — no network wait.
  /// The next pull reconciles each row with the server's real Z-report number.
  Future<void> optimisticallyFinalizeActiveStartingCash(int companyId) async {
    await transaction(() async {
      await (update(startingCashTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.zReportNumber.isNull()))
          .write(const StartingCashTableCompanion(
        zReportNumber: Value(optimisticZReportPlaceholder),
      ));
    });
  }

  /// Watches today's *active* cash movements for [companyId], newest first —
  /// the offline-first source for the Cash In/Out entries list. Rows already
  /// linked to a Z-report (`zReportNumber` not null) are filtered out at the
  /// engine level so finalized entries vanish without any in-memory scanning.
  Stream<List<StartingCashTableData>> watchTodayStartingCash(int companyId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return (select(startingCashTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.zReportNumber.isNull())
          ..where((t) => t.createdAt.isBiggerOrEqualValue(startOfDay))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // ---------------- Z-REPORTS ----------------

  Future<void> insertOfflineZReport(ZReportsTableCompanion report) async {
    final localId = report.localId.present && report.localId.value.isNotEmpty
        ? report.localId.value
        : const Uuid().v4();

    await into(zReportsTable).insert(
      report.copyWith(
        localId: Value(localId),
        serverId: const Value(null),
        syncStatus: const Value('pending'),
        syncError: const Value(null),
      ),
    );
  }

  Future<List<ZReportsTableData>> getPendingZReports() {
    return (select(zReportsTable)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
  }

  /// [serverNumber] is the server's own per-company Z sequence number, which is
  /// authoritative across devices. Left null when the response didn't carry one,
  /// in which case the device-local number issued at close time stands.
  Future<void> markZReportSynced(String localId, int serverId,
      {int? serverNumber}) {
    return (update(zReportsTable)
          ..where((t) => t.localId.equals(localId)))
        .write(ZReportsTableCompanion(
      serverId: Value(serverId),
      number: serverNumber == null ? const Value.absent() : Value(serverNumber),
      syncStatus: const Value('synced'),
      syncError: const Value(null),
    ));
  }

  Future<void> markZReportFailed(String localId, String errorMessage) {
    return (update(zReportsTable)
          ..where((t) => t.localId.equals(localId)))
        .write(ZReportsTableCompanion(
      syncStatus: const Value('failed'),
      syncError: Value(errorMessage),
    ));
  }

  // ─── Unreported payments (offline Z-report aggregation) ────────────────────

  /// Payments not yet assigned to a Z-report, scoped to a company via their
  /// parent document. Drives the offline `unreportedPaymentsProvider` and the
  /// Close-Register aggregation.
  Future<List<PaymentsTableData>> getUnreportedPayments(int companyId) async {
    final q = select(paymentsTable).join([
      innerJoin(documentsTable,
          documentsTable.localId.equalsExp(paymentsTable.documentId)),
    ])
      ..where(documentsTable.companyId.equals(companyId))
      ..where(paymentsTable.zReportId.isNull())
      ..where(paymentsTable.syncStatus.equals('pending_delete').not());
    final rows = await q.get();
    return rows.map((r) => r.readTable(paymentsTable)).toList();
  }

  /// Stamps the optimistic placeholder Z-report id on every still-unreported
  /// payment for a company so they drop out of the unreported list immediately
  /// when the register is closed offline.
  Future<void> assignUnreportedPaymentsToZReport(int companyId) async {
    final docRows = await (selectOnly(documentsTable)
          ..addColumns([documentsTable.localId])
          ..where(documentsTable.companyId.equals(companyId)))
        .get();
    final docIds =
        docRows.map((r) => r.read(documentsTable.localId)!).toList();
    if (docIds.isEmpty) return;
    await (update(paymentsTable)
          ..where((t) => t.documentId.isIn(docIds))
          ..where((t) => t.zReportId.isNull()))
        .write(const PaymentsTableCompanion(
            zReportId: Value(optimisticZReportPlaceholder)));
  }

  /// Aggregates everything the Z-report reports on, in one pass over the local
  /// DB. Scope = the documents behind the still-unreported payments — the exact
  /// set [getUnreportedPayments] returns — so the totals and the tender
  /// breakdown always describe the same sales.
  ///
  /// Call this BEFORE [assignUnreportedPaymentsToZReport]: that stamps the
  /// placeholder id and empties the set. The result must be persisted onto the
  /// z_reports row, because nothing records which payments belonged to which
  /// report — once stamped, the scope is unrecoverable.
  Future<ZReportAggregates> aggregateUnreportedForZReport(int companyId) async {
    final payments = await getUnreportedPayments(companyId);
    if (payments.isEmpty) return ZReportAggregates.empty;

    // Refund payments are stored negative, so this nets to the real drawer take.
    final grandTotal = payments.fold<double>(0, (s, p) => s + p.amount);
    final docIds = payments.map((p) => p.documentId).toSet().toList();

    final docs = await (select(documentsTable)
          ..where((t) => t.localId.isIn(docIds)))
        .get();
    final items = await (select(documentItemsTable)
          ..where((t) => t.documentId.isIn(docIds))
          ..where((t) => t.syncStatus.equals('pending_delete').not()))
        .get();
    final lines = await (select(discountLinesTable)
          ..where((t) => t.documentLocalId.isIn(docIds)))
        .get();

    double totalSales = 0;
    double totalReturns = 0;
    for (final d in docs) {
      // Classify by type, never by the stored sign: a refund total is negative
      // locally but positive once pulled back from the server.
      if (d.documentTypeId == DocumentTypes.refund) {
        totalReturns += d.total.abs();
      } else {
        totalSales += d.total;
      }
    }

    // Refund items carry no taxAmount (refund_service doesn't write one), so a
    // return reduces the taxable base without reversing its tax.
    final totalTax = items.fold<double>(0, (s, i) => s + i.taxAmount);
    // `amount` is the resolved money figure — the only discount-line field that
    // may be summed, since % and fixed lines mix freely once resolved.
    final discountsGranted = lines.fold<double>(0, (s, l) => s + l.amount);

    // Zero-padded NNNNNN suffix ⇒ lexicographic order is issue order.
    final numbers = docs
        .map((d) => d.number)
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort();

    return ZReportAggregates(
      documentCount: docs.length,
      fromDocumentNumber: numbers.isEmpty ? null : numbers.first,
      toDocumentNumber: numbers.isEmpty ? null : numbers.last,
      totalSales: totalSales,
      totalReturns: totalReturns,
      discountsGranted: discountsGranted,
      taxableTotal: totalSales - totalReturns - totalTax,
      totalTax: totalTax,
      grandTotal: grandTotal,
    );
  }

  /// The next device-local Z-report number for a company. The server keeps its
  /// own per-company sequence and [SyncManager.pushPendingZReports] overwrites
  /// this with the authoritative one, but a cashier closing offline still needs
  /// a number on today's slip.
  Future<int> nextLocalZReportNumber(int companyId) async {
    final maxNumber = zReportsTable.number.max();
    final row = await (selectOnly(zReportsTable)
          ..addColumns([maxNumber])
          ..where(zReportsTable.companyId.equals(companyId)))
        .getSingle();
    return (row.read(maxNumber) ?? 0) + 1;
  }

  /// Active (unfinalized) cash movements for a company — used to total cash
  /// in/out into the offline Z-report.
  Future<List<StartingCashTableData>> getActiveStartingCash(int companyId) =>
      (select(startingCashTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.zReportNumber.isNull()))
          .get();

  // ─── Stock-control rules (lazy offline cache) ──────────────────────────────

  Future<StockControlsTableData?> getStockControl(int productId) =>
      (select(stockControlsTable)
            ..where((t) => t.productId.equals(productId))
            ..limit(1))
          .getSingleOrNull();

  Future<void> upsertStockControl(StockControlsTableCompanion row) =>
      into(stockControlsTable).insertOnConflictUpdate(row);

  /// All active (non-deleted) stock-control rules for a company — offline-first
  /// source for evaluating low-stock / reorder status across the stock list.
  Future<List<StockControlsTableData>> getStockControlsForCompany(
          int companyId) =>
      (select(stockControlsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals('pending_delete').not()))
          .get();

  // ---------------- SHIFTS ----------------

  Future<void> insertOfflineShift(ShiftsTableCompanion shift) async {
    final localId = shift.localId.present && shift.localId.value.isNotEmpty
        ? shift.localId.value
        : const Uuid().v4();
    await into(shiftsTable).insert(
      shift.copyWith(localId: Value(localId)),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<ShiftsTableData>> getPendingShifts() {
    return (select(shiftsTable)
          ..where((t) => t.syncStatus.equals('pending'))
          // Attendance shifts only. POS sessions live in this table too but
          // push through `pushPendingSessions` on their own endpoint — sending
          // one to /Shifts/BatchSync would create a device-less shift with no
          // session semantics at all.
          ..where((t) => t.posDeviceUid.isNull()))
        .get();
  }

  /// POS sessions waiting to reach the server.
  ///
  /// Selected on `pending_create` — the GENERIC-pusher family. Sessions are
  /// created by a direct POST, not as a side effect of BatchSync, so writing
  /// them as plain `'pending'` would put them in the checkout-artifact family
  /// and they would never be pushed at all (see `lib/sync/sync_status.dart`).
  Future<List<ShiftsTableData>> getPendingSessions() {
    return (select(shiftsTable)
          ..where((t) => t.posDeviceUid.isNotNull())
          ..where((t) => t.syncStatus.equals('pending_create')))
        .get();
  }

  /// Stamps the server id on a session and marks it synced. The session's
  /// `localId` is NOT touched — every order, payment and cash movement points
  /// at it, and rewriting those links is exactly what this design avoids.
  Future<void> markSessionSynced(String localId, int serverId) {
    return (update(shiftsTable)..where((t) => t.localId.equals(localId)))
        .write(ShiftsTableCompanion(
      serverId: Value(serverId),
      syncStatus: const Value('synced'),
    ));
  }

  Future<ShiftsTableData?> getActiveShift(int companyId) {
    return (select(shiftsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.status.equals(0))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<ShiftsTableData>> getShiftHistory(int companyId) {
    return (select(shiftsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.desc(t.openedAt)]))
        .get();
  }

  Future<void> markShiftSynced(String localId, int serverId) {
    return (update(shiftsTable)..where((t) => t.localId.equals(localId)))
        .write(ShiftsTableCompanion(
      serverId: Value(serverId),
      syncStatus: const Value('synced'),
      syncError: const Value(null),
    ));
  }

  Future<void> markShiftFailed(String localId, String errorMessage) {
    return (update(shiftsTable)..where((t) => t.localId.equals(localId)))
        .write(ShiftsTableCompanion(
      syncStatus: const Value('failed'),
      syncError: Value(errorMessage),
    ));
  }

  // ---------------- TIME CLOCK ----------------

  Future<void> insertClockIn(TimeClockEntriesTableCompanion entry) async {
    final localId = entry.localId.present && entry.localId.value.isNotEmpty
        ? entry.localId.value
        : const Uuid().v4();
    await into(timeClockEntriesTable).insert(
      entry.copyWith(localId: Value(localId)),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Finds the most recent open entry (clockOutTime == null) for [userId].
  Future<TimeClockEntriesTableData?> getActiveClockEntry(int userId) {
    return (select(timeClockEntriesTable)
          ..where((t) => t.userId.equals(userId))
          ..where((t) => t.clockOutTime.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.clockInTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> clockOut(String localId, DateTime clockOutTime) {
    return (update(timeClockEntriesTable)
          ..where((t) => t.localId.equals(localId)))
        .write(TimeClockEntriesTableCompanion(
      clockOutTime: Value(clockOutTime),
      syncStatus: const Value('pending'),
      syncError: const Value(null),
    ));
  }

  Future<List<TimeClockEntriesTableData>> getPendingTimeClockEntries() {
    return (select(timeClockEntriesTable)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
  }

  Future<void> markTimeClockEntrySynced(String localId, int serverId) {
    return (update(timeClockEntriesTable)
          ..where((t) => t.localId.equals(localId)))
        .write(TimeClockEntriesTableCompanion(
      serverId: Value(serverId),
      syncStatus: const Value('synced'),
      syncError: const Value(null),
    ));
  }

  Future<void> markTimeClockEntryFailed(String localId, String errorMessage) {
    return (update(timeClockEntriesTable)
          ..where((t) => t.localId.equals(localId)))
        .write(TimeClockEntriesTableCompanion(
      syncStatus: const Value('failed'),
      syncError: Value(errorMessage),
    ));
  }
}

/// Pillar 3 (SQLCipher hardware-bound encryption) master switch.
///
/// TEMPORARILY **false** while verifying offline-first behaviour by inspecting
/// the local DB with standard tools (DBeaver / LINQPad). When false the DB is
/// opened as plaintext and any previously-encrypted file is decrypted in place
/// (data preserved). Flip back to **true** to restore encryption — on the next
/// launch the plaintext DB is re-encrypted automatically.
/// See docs/offline-first-audit.md → "Pillar 3 temporarily disabled".
const bool kPillar3Encryption = false;

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // The sqlite3 native-assets hook (see pubspec `hooks.user_defines`) bundles
    // a prebuilt SQLCipher library and resolves it for us — no manual library
    // loading / Android workaround needed.
    // ⚠️ FIRST, before anything opens the file: swap in a database the operator
    // staged for restore. Drift holds the live file open for the whole session
    // and Windows will not let an open file be replaced, so a restore can only
    // ever happen here — in the gap between process start and the first open.
    // A no-op when nothing is staged, which is every normal boot.
    await RestoreService.applyStagedRestore();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pos_app.sqlite'));

    // Pillar 3: hardware-bound key, derived (never hardcoded) per device.
    final key = await DeviceKeyService().getDatabaseKey();

    if (kPillar3Encryption) {
      // One-time: encrypt a pre-existing PLAINTEXT database in place so upgrading
      // terminals keep their offline data instead of starting empty.
      await _encryptLegacyDbIfNeeded(file, key);

      // NOTE: a plain (same-isolate) NativeDatabase is required for SQLCipher —
      // the key must be applied in `setup`, which the background-isolate variant
      // can't carry. The big initial product/image seed therefore runs on the
      // main isolate; acceptable for the security guarantee.
      return NativeDatabase(
        file,
        logStatements: false, // flip to true while debugging
        setup: (rawDb) {
          // Fail loudly if we somehow linked plain SQLite (no cipher) — better
          // than silently writing an unencrypted database.
          final cipher = rawDb.select('PRAGMA cipher_version;');
          if (cipher.isEmpty) {
            throw StateError(
                'SQLCipher not available — the local database would be unencrypted.');
          }
          rawDb.execute("PRAGMA key = '$key';");
          // Touch the schema so a wrong key fails here (deterministic), not later.
          rawDb.execute('SELECT count(*) FROM sqlite_master;');
        },
      );
    }

    // ── Pillar 3 TEMPORARILY DISABLED (offline-first verification) ──────────
    // Decrypt any existing encrypted DB back to plaintext so it opens in
    // DBeaver / LINQPad while we confirm the offline-first writes look right.
    // Flip kPillar3Encryption back to true to restore encryption.
    await _decryptDbIfNeeded(file, key);
    return NativeDatabase(file, logStatements: false);
  });
}

/// If [file] is an existing *unencrypted* SQLite database, rewrite it as a
/// SQLCipher-encrypted database keyed with [hexKey], preserving all data. A
/// missing file (fresh install) or an already-encrypted file is left untouched.
Future<void> _encryptLegacyDbIfNeeded(File file, String hexKey) async {
  if (!file.existsSync()) return; // fresh install → created encrypted by setup

  // Step 1: is the file plaintext? Probe a read without a key — a plaintext DB
  // reads fine, an already-encrypted one throws "file is not a database".
  Database? probe;
  bool isPlaintext;
  try {
    probe = sqlite3.open(file.path);
    probe.select('SELECT count(*) FROM sqlite_master;');
    isPlaintext = true;
  } on SqliteException {
    isPlaintext = false; // unreadable unkeyed → already encrypted, nothing to do
  } finally {
    probe?.close();
  }
  if (!isPlaintext) return;

  // Step 2: plaintext → export into a new encrypted file, then swap it in.
  final encPath = '${file.path}.enc';
  final encFile = File(encPath);
  Database? src;
  try {
    if (encFile.existsSync()) encFile.deleteSync();
    src = sqlite3.open(file.path);
    // Preserve Drift's schema version: sqlcipher_export copies tables + data but
    // NOT `PRAGMA user_version`, so without this the encrypted DB would report
    // version 0 and Drift would re-run onCreate over an already-populated DB
    // ("table/index already exists"). Carry the version onto the encrypted copy.
    final userVersion = src.select('PRAGMA user_version;').first.columnAt(0) as int;
    final escaped = encPath.replaceAll("'", "''");
    src.execute("ATTACH DATABASE '$escaped' AS encrypted KEY '$hexKey';");
    src.execute("SELECT sqlcipher_export('encrypted');");
    src.execute('PRAGMA encrypted.user_version = $userVersion;');
    src.execute('DETACH DATABASE encrypted;');
    src.close();
    src = null;

    file.deleteSync();
    encFile.renameSync(file.path);
  } catch (e) {
    debugPrint('Pillar 3: legacy DB encryption failed — $e');
    src?.close();
    if (encFile.existsSync()) {
      try {
        encFile.deleteSync();
      } catch (_) {}
    }
    rethrow; // fail-closed: never open a half-migrated / still-plaintext DB
  }
}

/// Reverse of [_encryptLegacyDbIfNeeded]: if [file] is an existing SQLCipher
/// database, rewrite it as a PLAINTEXT SQLite database (preserving all data) so
/// it opens in standard tools (DBeaver / LINQPad) during offline verification.
/// Only invoked while Pillar 3 encryption is disabled. A plaintext or missing
/// file is left untouched.
Future<void> _decryptDbIfNeeded(File file, String hexKey) async {
  if (!file.existsSync()) return; // fresh install → created plaintext by setup

  // Already plaintext? A keyless read succeeds on plaintext, throws on encrypted.
  Database? probe;
  bool isEncrypted;
  try {
    probe = sqlite3.open(file.path);
    probe.select('SELECT count(*) FROM sqlite_master;');
    isEncrypted = false; // readable unkeyed → already plaintext, nothing to do
  } on SqliteException {
    isEncrypted = true;
  } finally {
    probe?.close();
  }
  if (!isEncrypted) return;

  // Encrypted → export into a new plaintext file (ATTACH … KEY '' = no cipher),
  // then swap it in. Mirrors the encrypt path, including the user_version carry.
  final plainPath = '${file.path}.plain';
  final plainFile = File(plainPath);
  Database? src;
  try {
    if (plainFile.existsSync()) plainFile.deleteSync();
    src = sqlite3.open(file.path);
    src.execute("PRAGMA key = '$hexKey';");
    final userVersion = src.select('PRAGMA user_version;').first.columnAt(0) as int;
    final escaped = plainPath.replaceAll("'", "''");
    src.execute("ATTACH DATABASE '$escaped' AS plaintext KEY '';");
    src.execute("SELECT sqlcipher_export('plaintext');");
    src.execute('PRAGMA plaintext.user_version = $userVersion;');
    src.execute('DETACH DATABASE plaintext;');
    src.close();
    src = null;

    file.deleteSync();
    plainFile.renameSync(file.path);
  } catch (e) {
    debugPrint('Pillar 3 disabled: DB decryption failed — $e');
    src?.close();
    if (plainFile.existsSync()) {
      try {
        plainFile.deleteSync();
      } catch (_) {}
    }
    rethrow; // fail-closed: never open a half-migrated DB
  }
}
