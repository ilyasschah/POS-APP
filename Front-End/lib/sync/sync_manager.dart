import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/sync/image_sync_helper.dart';
import 'package:pos_app/sync/sync_status.dart';

/// Pulls master data from the C# API into local Drift tables.
///
/// Each `_pull*` method follows the same delta pattern:
///   1. Read the per-entity watermark from `sync_meta`.
///   2. Call `GET /<Entity>/GetAll?companyId=X&modifiedAfter=<watermark>`.
///   3. Upsert rows by server `id`.
///   4. Stamp `sync_meta` with the time the request *started* (so any rows
///      written server-side mid-request are picked up by the next pull).
///
/// AppProperties is special — see [_pullAppProperties].

/// Thrown when the server rejects a sync because this terminal exceeds the
/// tenant's paid seat allowance, or has been blocked (Pillar 4). Surfaced to the
/// operator as a hard error instead of being swallowed as a normal step failure.
class SeatLimitException implements Exception {
  final String message;
  SeatLimitException(this.message);
  @override
  String toString() => message;
}

class SyncManager {
  SyncManager({
    required this.db,
    required this.dio,
    required this.authStorage,
    ImageSyncHelper? imageHelper,
  }) : imageHelper = imageHelper ?? ImageSyncHelper(dio);

  final AppDatabase db;
  final Dio dio;
  final AuthStorage authStorage;
  final ImageSyncHelper imageHelper;

  static const _kProducts = 'products';
  static const _kTaxes = 'taxes';
  static const _kFloorPlans = 'floor_plans';
  static const _kFloorPlanTables = 'floor_plan_tables';
  static const _kUsers = 'users';
  static const _kAppProperties = 'app_properties';
  static const _kProductGroups = 'product_groups';
  static const _kPaymentTypes = 'payment_types';
  static const _kCustomers = 'customers';
  static const _kPromotions = 'promotions';
  static const _kProductComments = 'product_comments';
  static const _kDocuments = 'documents';
  static const _kLoyaltyCards = 'loyalty_cards';

  /// Labels of steps that failed during the most recent [sync] run. Reset at the
  /// start of each run; safe as instance state because syncs never overlap (the
  /// notifier/watchers gate on `isLoading`).
  final List<String> _failedSteps = [];

  /// Human-readable notices for ops the server actively *rejected* this run
  /// (e.g. deleting a product still linked to a document). Unlike [_failedSteps]
  /// these won't be retried — they were resolved locally (the row was reverted),
  /// but the user should be told why their action didn't stick. Reset each run.
  final List<String> _rejectionNotices = [];

  /// Snapshot of the rejection notices from the most recent [sync] run, for the
  /// UI to surface after the run finishes. Empty = nothing was rejected.
  List<String> get rejectionNotices => List.of(_rejectionNotices);

  /// Runs [op], recording + logging (but swallowing) any error so one failing
  /// step never aborts the rest of the sync. The collected labels are returned
  /// by [sync] so the UI can surface exactly which entities didn't sync.
  Future<void> _step(String label, Future<void> Function() op) async {
    try {
      await op();
    } on SeatLimitException {
      rethrow; // licensing block must surface to the UI, not be swallowed
    } catch (e) {
      _failedSteps.add(label);
      debugPrint('sync step "$label" failed — $e');
    }
  }

  /// Runs a full bidirectional sync and returns the labels of any steps that
  /// failed (empty list = everything synced cleanly).
  Future<List<String>> sync(int companyId) async {
    _failedSteps.clear();
    _rejectionNotices.clear();

    // Pillar 4: tag every request this sync makes with the terminal's device
    // signature, so the server can enforce the seat cap at each BatchSync ingress
    // (orders, shifts, loyalty cards, time-clock).
    dio.options.headers['X-Device-Id'] = await authStorage.getOrCreateDeviceId();

    // Sliding-window token refresh: exchange the still-valid device JWT for a
    // fresh one so live terminals never hit expiry on the gated admin-write
    // endpoints. Non-fatal — an expired token (offline > lifetime) just 401s here
    // and the operator re-logins; offline sales never depend on this.
    await _step('refreshToken', () async {
      final res = await dio.post('/Auth/Refresh'); // interceptor attaches current token
      final data = res.data;
      final token = data is Map ? data['token'] as String? : null;
      if (token != null && token.isNotEmpty) {
        // Persist only — the interceptor reads the latest token from storage on
        // every request, so the rest of this sync (and later ones) picks it up.
        // Do NOT pin it onto this singleton Dio's base headers: that would make
        // it sticky and a later user's sync would keep sending the prior token.
        await authStorage.saveJwt(token);
      }
    });

    // ── PUSH phase (local → cloud) ─────────────────────────────────────────
    // Wrapped so a push failure (e.g. one stuck order whose BatchSync rethrows)
    // can never prevent the PULL phase below from running.
    await _step('push', () => _pushAll(companyId));

    // ── PULL phase (cloud → local) ─────────────────────────────────────────
    // pullMasterData isolates each entity internally; pullDocuments is wrapped
    // here so a document-pull failure is reported but never throws.
    await pullMasterData(companyId);
    await _step('documents', () => pullDocuments(companyId));
    // After documents (so each line's local document exists to attach to).
    await _step('discountLines', () => pullDiscountLines(companyId));

    return List.of(_failedSteps);
  }

  Future<void> _pushAll(int companyId) async {
    // Drop unsyncable orphans (temp-product refs whose product row is gone)
    // before pushing, so they don't 400-loop forever and a sale that sold a
    // now-deleted product doesn't sit stuck at "(Pending sync)".
    final purged = await db.purgeOrphanedTempRefs();
    if (purged > 0) {
      debugPrint('purgeOrphanedTempRefs: removed $purged orphaned row(s).');
    }

    // ── Master data first ────────────────────────────────────────────────────
    // Everything an order/document/payment can reference by id must be created
    // (and its temp→real id remapped onto referencing rows) BEFORE those orders
    // push — otherwise BatchSync 400s on a productId/taxId/paymentTypeId the
    // server has never seen, and the sale gets stuck at "(Pending sync)".
    await pushPendingProductGroupOps(companyId); // remaps products.groupId
    await pushPendingProductOps(companyId);      // remaps order/doc items.productId
    await pushPendingProductCommentOps(companyId); // comments on offline products
    await pushPendingBarcodeOps(companyId);
    await pushPendingTaxOps(companyId);          // remaps product-tax + item taxes
    await pushPendingPaymentTypeOps(companyId);  // remaps payments/orders.paymentTypeId
    await pushPendingVoidReasonOps(companyId);
    await pushPendingPromotionOps(companyId);
    // Tables must own real ids before ANY transactional row that points at one:
    // orders carry floorPlanTableId, bookings carry a tableIds list.
    await pushPendingFloorPlanTableOps(companyId); // remaps orders + bookings
    // ── Transactional data (now all their referenced ids are real) ───────────
    await pushPendingOpenOrders(companyId);
    await pushPendingOrders(companyId);
    // Manual document editor: create/update/delete headers + their line items.
    // Runs before paid-status/payments so a locally-created document already
    // carries its server id when those are pushed.
    await pushPendingDocuments(companyId);
    await pushPendingDocumentItems(companyId);
    // Offline refunds (device-local /Document/Refund). Runs after orders +
    // documents so a verified refund's original sale already exists server-side.
    await pushPendingRefundOps(companyId);
    // Paid-status + standalone payment edits made in the document editor. Run
    // after pushPendingOrders so locally-created documents already carry their
    // server id before their payments are pushed.
    await pushPendingPaidStatus(companyId);
    await pushPendingPayments(companyId);
    // Heal checkout payments that are still 'pending' under an already-synced
    // document (they were posted server-side by checkout, so they're not lost).
    await db.reconcileSyncedCheckoutPayments();
    await pushPendingVoids(companyId);
    await pushPendingCashMovements(companyId);
    await pushPendingZReports(companyId);
    await pushPendingUserOps(companyId);
    await pushPendingCustomerOps(companyId);
    await pushPendingCustomerDiscountOps(companyId);
    // Bookings reference customers/users (now pushed) by id.
    await pushPendingBookings(companyId);
    await pushPendingLoyaltyCardOps(companyId);
    await pushPendingShifts(companyId);
    await pushPendingTimeClockEntries(companyId);
    await pushPendingAppProperties(companyId);
    await pushPendingCompanyOps(companyId);
    // Warehouse + stock ordering matters:
    //  1. create/update warehouses first (a stock "move" may target a brand-new
    //     warehouse that must exist on the server),
    //  2. then push the stock revoke/move ops (empties a warehouse),
    //  3. then delete warehouses (the backend FK rejects deleting one that
    //     still holds stock).
    await pushPendingWarehouseOps(companyId, deletePhase: false);
    await pushPendingStockOps(companyId);
    // Offline stock + stock-control edits made on the Stock screen.
    await pushPendingStocks(companyId);
    await pushPendingStockControls(companyId);
    // Product↔tax assignments — after products (productId) and taxes (taxId)
    // have both been pushed + remapped above.
    await pushPendingProductTaxes(companyId);
    await pushPendingWarehouseOps(companyId, deletePhase: true);
  }

  // ==========================================================================
  // PUSH — app-property edits made offline. Two cases:
  //  • temp negative-id rows  → brand-new settings (e.g. App.DefaultScreen)
  //    that never reached the server → POST /ApplicationProperties/Add.
  //  • positive-id 'pending' rows → existing settings edited offline →
  //    PATCH /ApplicationProperties/Update.
  // Without this, offline setting changes would live only in local Drift.
  // ==========================================================================
  Future<void> pushPendingAppProperties(int companyId) async {
    // ── New settings created offline (temp negative ids) → /Add ────────────
    final newRows = await (db.select(db.appPropertiesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.id.isSmallerThanValue(0)))
        .get();

    for (final p in newRows) {
      try {
        final res = await dio.post<dynamic>(
          '/ApplicationProperties/Add',
          queryParameters: {'companyId': companyId},
          data: {'name': p.name, 'value': p.value ?? ''},
        );

        // If /Add echoes back the created row with its server id, swap the
        // temp row for the real one immediately (robust even if the following
        // pull fails). Otherwise leave the temp row for pullAppProperties to
        // reconcile (its dedup drops temp rows once the server row arrives).
        final data = res.data;
        final newId = data is Map<String, dynamic> ? data['id'] as int? : null;
        if (newId != null) {
          await db.into(db.appPropertiesTable).insertOnConflictUpdate(
                AppPropertiesTableCompanion(
                  id: Value(newId),
                  companyId: Value(companyId),
                  name: Value(p.name),
                  value: Value(p.value),
                  lastModified: Value(DateTime.now().toUtc()),
                  syncStatus: const Value('synced'),
                ),
              );
          await (db.delete(db.appPropertiesTable)
                ..where((t) => t.id.equals(p.id)))
              .go();
        }
      } catch (e) {
        debugPrint('pushPendingAppProperties (add): ${p.name} failed — $e');
        // Leave the temp row; next sync retries.
      }
    }

    // ── Existing settings edited offline (positive id, 'pending') → /Update ─
    final editedRows = await (db.select(db.appPropertiesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.id.isBiggerThanValue(0))
          ..where((t) => t.syncStatus.equals('pending')))
        .get();

    for (final p in editedRows) {
      try {
        await dio.patch<dynamic>(
          '/ApplicationProperties/Update',
          queryParameters: {'companyId': companyId},
          data: {'id': p.id, 'newValue': p.value ?? ''},
        );
        await (db.update(db.appPropertiesTable)
              ..where((t) => t.id.equals(p.id)))
            .write(const AppPropertiesTableCompanion(
          syncStatus: Value('synced'),
        ));
      } catch (e) {
        debugPrint('pushPendingAppProperties (update): ${p.name} failed — $e');
        // Leave it 'pending'; next sync retries.
      }
    }
  }

  Future<void> pullMasterData(int companyId) async {
    // Each pull is isolated via [_step] — a single entity failing (network blip,
    // unexpected payload) must not abort the remaining pulls.
    await _step('products', () => pullProducts(companyId));
    await _step('taxes', () => pullTaxes(companyId));
    await _step('floorPlans', () => pullFloorPlans(companyId));
    await _step('floorPlanTables', () => pullFloorPlanTables(companyId));
    await _step('users', () => pullUsers(companyId));
    await _step('appProperties', () => pullAppProperties(companyId));
    await _step('productGroups', () => pullProductGroups(companyId));
    await _step('paymentTypes', () => pullPaymentTypes(companyId));
    await _step('customers', () => pullCustomers(companyId));
    await _step('promotions', () => pullPromotions(companyId));
    await _step('productComments', () => pullProductComments(companyId));
    await _step('securityKeys', () => pullSecurityKeys(companyId));
    await _step('company', () => pullCompany(companyId));
    await _step('stocks', () => pullStocks(companyId));
    await _step('warehouses', () => pullWarehouses(companyId));
    await _step('loyaltyCards', () => pullLoyaltyCards(companyId));
    await _step('startingCash', () => pullStartingCash(companyId));
    await _step('bookings', () => pullBookings(companyId));
    await _step('documentTypes', () => pullDocumentTypes(companyId));
    await _step('documentCategories', () => pullDocumentCategories(companyId));
    await _step('voidReasons', () => pullVoidReasons(companyId));
    await _step('stockControls', () => pullStockControls(companyId));
    await _step('productTaxes', () => pullProductTaxes(companyId));
    await _step('barcodes', () => pullBarcodes(companyId));
    // ── v39 schema-clone tables (cloud → local mirror) ──
    await _step('countries', () => pullCountries(companyId));
    await _step('currencies', () => pullCurrencies(companyId));
    await _step('counters', () => pullCounters(companyId));
    await _step('fiscalItems', () => pullFiscalItems(companyId));
    await _step('templates', () => pullTemplates(companyId));
    await _step('posVoids', () => pullPosVoids(companyId));
    await _step('printerSettings', () => pullPosPrinterSettings(companyId));
    await _step('userDevicePins', () => pullUserDevicePins(companyId));
    await _step('documentItemTaxes', () => pullDocumentItemTaxes(companyId));
    await _step('documentItemExpirationDates',
        () => pullDocumentItemExpirationDates(companyId));
    await _step('zReportPaymentSummaries',
        () => pullZReportPaymentSummaries(companyId));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // v39 schema-clone pulls. Each mirrors a cloud table into its local Drift
  // twin by a full replace (delete-all + insert) — these are reference/config
  // tables, so last-write-from-cloud wins. Best-effort: a failure preserves the
  // existing local cache. Push is N/A here (not edited offline on the POS;
  // voids keep their own pending queue).
  // ══════════════════════════════════════════════════════════════════════════

  /// Full-replace a mirror table inside one transaction.
  Future<void> _replaceTable<T extends Table, D>(
      TableInfo<T, D> table, List<Insertable<D>> rows) async {
    await db.transaction(() async {
      await db.delete(table).go();
      if (rows.isNotEmpty) await db.batch((b) => b.insertAll(table, rows));
    });
  }

  int? _i(dynamic v) => (v as num?)?.toInt();
  double? _d(dynamic v) => (v as num?)?.toDouble();
  DateTime? _dt(dynamic v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;

  Future<void> pullCountries(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/Country/GetAllCountries');
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => CountriesTableCompanion(
                serverId: Value(_i(j['id'])),
                name: Value((j['name'] as String?) ?? ''),
                code: Value(j['code'] as String?),
              ))
          .toList();
      await _replaceTable(db.countriesTable, rows);
    } catch (e) {
      debugPrint('pullCountries failed: $e — local cache preserved.');
    }
  }

  Future<void> pullCurrencies(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/Currencies/GetAll');
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => CurrenciesTableCompanion(
                serverId: Value(_i(j['id'])),
                name: Value((j['name'] as String?) ?? ''),
                code: Value(j['code'] as String?),
              ))
          .toList();
      await _replaceTable(db.currenciesTable, rows);
    } catch (e) {
      debugPrint('pullCurrencies failed: $e — local cache preserved.');
    }
  }

  Future<void> pullCounters(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/DocumentsCounters/GetAll');
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => CountersTableCompanion(
                name: Value((j['name'] as String?) ?? ''),
                value: Value(_i(j['value']) ?? 0),
                companyId: Value(_i(j['companyId']) ?? companyId),
              ))
          .toList();
      await _replaceTable(db.countersTable, rows);
    } catch (e) {
      debugPrint('pullCounters failed: $e — local cache preserved.');
    }
  }

  Future<void> pullFiscalItems(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/FiscalItems/GetAll');
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => FiscalItemsTableCompanion(
                plu: Value(_i(j['plu']) ?? 0),
                name: Value((j['name'] as String?) ?? ''),
                vat: Value((j['vat'] as String?) ?? ''),
                companyId: Value(_i(j['companyId']) ?? companyId),
              ))
          .toList();
      await _replaceTable(db.fiscalItemsTable, rows);
    } catch (e) {
      debugPrint('pullFiscalItems failed: $e — local cache preserved.');
    }
  }

  Future<void> pullTemplates(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/Templates/GetAll');
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => TemplatesTableCompanion(
                serverId: Value(_i(j['id'])),
                name: Value((j['name'] as String?) ?? ''),
                value: Value((j['value'] as String?) ?? ''),
                companyId: Value(_i(j['companyId']) ?? companyId),
              ))
          .toList();
      await _replaceTable(db.templatesTable, rows);
    } catch (e) {
      debugPrint('pullTemplates failed: $e — local cache preserved.');
    }
  }

  Future<void> pullPosVoids(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/PosVoids/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => PosVoidsTableCompanion(
                serverId: Value(_i(j['id'])),
                orderNumber: Value((j['orderNumber'] as String?) ?? ''),
                userName: Value((j['userName'] as String?) ?? ''),
                productName: Value((j['productName'] as String?) ?? ''),
                roundNumber: Value(_i(j['roundNumber']) ?? 0),
                quantity: Value(_d(j['quantity']) ?? 0),
                price: Value(_d(j['price']) ?? 0),
                discount: Value(_d(j['discount']) ?? 0),
                discountType: Value(_i(j['discountType']) ?? 0),
                total: Value(_d(j['total']) ?? 0),
                isConfirmed: Value((j['isConfirmed'] as bool?) ?? false),
                reason: Value(j['reason'] as String?),
                voidedByName: Value(j['voidedByName'] as String?),
                dateCreated: Value(_dt(j['dateCreated']) ?? DateTime.now().toUtc()),
                dateVoided: Value(_dt(j['dateVoided']) ?? DateTime.now().toUtc()),
                companyId: Value(_i(j['companyId']) ?? companyId),
              ))
          .toList();
      await _replaceTable(db.posVoidsTable, rows);
    } catch (e) {
      debugPrint('pullPosVoids failed: $e — local cache preserved.');
    }
  }

  Future<void> pullPosPrinterSettings(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/PosPrinterSettings/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => PosPrinterSettingsTableCompanion(
                serverId: Value(_i(j['id'])),
                printerName: Value((j['printerName'] as String?) ?? ''),
                paperWidth: Value(_i(j['paperWidth']) ?? 0),
                header: Value(j['header'] as String?),
                footer: Value(j['footer'] as String?),
                feedLines: Value(_i(j['feedLines']) ?? 0),
                cutPaper: Value((j['cutPaper'] as bool?) ?? false),
                printBitmap: Value((j['printBitmap'] as bool?) ?? false),
                openCashDrawer: Value((j['openCashDrawer'] as bool?) ?? false),
                cashDrawerCommand: Value(j['cashDrawerCommand'] as String?),
                headerAlignment: Value(_i(j['headerAlignment']) ?? 0),
                footerAlignment: Value(_i(j['footerAlignment']) ?? 0),
                isFormattingEnabled: Value((j['isFormattingEnabled'] as bool?) ?? false),
                printerType: Value(_i(j['printerType']) ?? 0),
                numberOfCopies: Value(_i(j['numberOfCopies']) ?? 0),
                codePage: Value(_i(j['codePage']) ?? 0),
                characterSet: Value(_i(j['characterSet']) ?? 0),
                companyId: Value(_i(j['companyId']) ?? companyId),
              ))
          .toList();
      await _replaceTable(db.posPrinterSettingsTable, rows);
    } catch (e) {
      debugPrint('pullPosPrinterSettings failed: $e — local cache preserved.');
    }
  }

  Future<void> pullUserDevicePins(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/UserDevicePins/GetActiveDevices',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => UserDevicePinsTableCompanion(
                serverId: Value(_i(j['id'])),
                userId: Value(_i(j['userId']) ?? 0),
                companyId: Value(_i(j['companyId']) ?? companyId),
                deviceId: Value((j['deviceId'] as String?) ?? ''),
                hashedPin: Value((j['hashedPin'] as String?) ?? ''),
                createdAt: Value(_dt(j['createdAt']) ?? DateTime.now().toUtc()),
              ))
          .toList();
      await _replaceTable(db.userDevicePinsTable, rows);
    } catch (e) {
      debugPrint('pullUserDevicePins failed: $e — local cache preserved.');
    }
  }

  Future<void> pullDocumentItemTaxes(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/DocumentItemTaxes/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => DocumentItemTaxesTableCompanion(
                documentItemId: Value(_i(j['documentItemId']) ?? 0),
                taxId: Value(_i(j['taxId']) ?? 0),
                amount: Value(_d(j['amount']) ?? 0),
                companyId: Value(companyId),
              ))
          .toList();
      await _replaceTable(db.documentItemTaxesTable, rows);
    } catch (e) {
      debugPrint('pullDocumentItemTaxes failed: $e — local cache preserved.');
    }
  }

  Future<void> pullDocumentItemExpirationDates(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/DocumentItemExpirationDates/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => DocumentItemExpirationDatesTableCompanion(
                documentItemId: Value(_i(j['documentItemId']) ?? 0),
                expirationDate:
                    Value(_dt(j['expirationDate']) ?? DateTime.now().toUtc()),
                companyId: Value(companyId),
              ))
          .toList();
      await _replaceTable(db.documentItemExpirationDatesTable, rows);
    } catch (e) {
      debugPrint(
          'pullDocumentItemExpirationDates failed: $e — local cache preserved.');
    }
  }

  Future<void> pullZReportPaymentSummaries(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/ZReportPaymentSummaries/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => ZReportPaymentSummariesTableCompanion(
                serverId: Value(_i(j['id'])),
                zReportId: Value(_i(j['zReportId']) ?? 0),
                paymentTypeId: Value(_i(j['paymentTypeId']) ?? 0),
                totalAmount: Value(_d(j['totalAmount']) ?? 0),
              ))
          .toList();
      await _replaceTable(db.zReportPaymentSummariesTable, rows);
    } catch (e) {
      debugPrint(
          'pullZReportPaymentSummaries failed: $e — local cache preserved.');
    }
  }

  // ==========================================================================
  // PRODUCT TAXES — offline-first bulk pull + per-assignment push.
  // ==========================================================================
  Future<void> pullProductTaxes(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/ProductTaxes/GetAll',
      queryParameters: {'companyId': companyId},
    );
    final rows = res.data;
    if (rows == null) return;

    final serverPairs = <String>{};
    for (final j in rows.cast<Map<String, dynamic>>()) {
      final productId = (j['productId'] as num?)?.toInt() ?? 0;
      final taxId = (j['taxId'] as num?)?.toInt() ?? 0;
      serverPairs.add('$productId:$taxId');
      await db.upsertSyncedProductTax(ProductTaxesTableCompanion(
        productId: Value(productId),
        taxId: Value(taxId),
        companyId: Value(companyId),
        syncStatus: const Value('synced'),
      ));
    }

    // Drop synced assignments removed on the server; keep local pending edits.
    for (final r in await db.getProductTaxesBySyncStatus(companyId, 'synced')) {
      if (!serverPairs.contains('${r.productId}:${r.taxId}')) {
        await db.hardDeleteProductTax(r.productId, r.taxId);
      }
    }
  }

  Future<void> pushPendingProductTaxes(int companyId) async {
    for (final r
        in await db.getProductTaxesBySyncStatus(companyId, 'pending_create')) {
      try {
        await dio.post<dynamic>(
          '/ProductTaxes/Add',
          queryParameters: {'companyId': companyId},
          data: {'productId': r.productId, 'taxId': r.taxId},
        );
        await db.markProductTaxSynced(r.productId, r.taxId);
      } catch (e) {
        debugPrint('pushPendingProductTaxes (add) ${r.productId} failed — $e');
      }
    }
    for (final r
        in await db.getProductTaxesBySyncStatus(companyId, 'pending_delete')) {
      try {
        await dio.delete<dynamic>(
          '/ProductTaxes/Delete',
          queryParameters: {
            'productId': r.productId,
            'taxId': r.taxId,
            'companyId': companyId,
          },
        );
        await db.hardDeleteProductTax(r.productId, r.taxId);
      } catch (e) {
        debugPrint('pushPendingProductTaxes (delete) ${r.productId} failed — $e');
      }
    }
  }

  // ==========================================================================
  // BARCODES — bulk pull so the product editor reads them offline without a
  // per-open /Barcodes/GetByProductId fetch. Local pending edits are preserved;
  // pushes are handled by pushPendingBarcodeOps.
  // ==========================================================================
  Future<void> pullBarcodes(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/Barcodes/GetAllBarCodeProductName',
      queryParameters: {'companyId': companyId},
    );
    final rows = res.data;
    if (rows == null) return;

    await db.transaction(() async {
      // Replace the synced cache; keep pending_create / pending_delete.
      await (db.delete(db.barcodesTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals('synced')))
          .go();
      for (final b in rows.cast<Map<String, dynamic>>()) {
        await db.into(db.barcodesTable).insert(BarcodesTableCompanion(
              localId: Value(const Uuid().v4()),
              serverId: Value((b['id'] as num?)?.toInt() ?? 0),
              productId: Value((b['productId'] as num?)?.toInt() ?? 0),
              companyId: Value(companyId),
              value: Value(b['value'] as String? ?? ''),
              syncStatus: const Value('synced'),
            ));
      }
    });
  }

  /// Drains offline void-reason writes to the server (mirrors pushPendingTaxOps).
  /// Note: Add/Update take their fields as query params; Update/Delete return 204.
  Future<void> pushPendingVoidReasonOps(int companyId) async {
    final pending =
        await (db.select(db.voidReasonsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (pending.isEmpty) return;

    for (final v in pending) {
      try {
        final isTemp = v.id < 0;

        if (v.syncStatus == 'pending_delete') {
          if (!isTemp) {
            await dio.delete<dynamic>('/VoidReasons/Delete/${v.id}');
          }
          await (db.delete(
            db.voidReasonsTable,
          )..where((x) => x.id.equals(v.id))).go();
          continue;
        }

        if (isTemp) {
          final res = await dio.post<dynamic>(
            '/VoidReasons/Add',
            queryParameters: {
              'companyId': companyId,
              'name': v.name,
              'rank': v.rank,
            },
          );
          final body =
              res.data is Map ? ((res.data as Map)['data'] ?? res.data) : null;
          final realId = (body is Map ? (body['id'] as num?) : null)?.toInt();
          if (realId == null) {
            throw Exception('Server returned no id for void reason create');
          }

          await db.transaction(() async {
            await (db.delete(
              db.voidReasonsTable,
            )..where((x) => x.id.equals(v.id))).go();
            await db.into(db.voidReasonsTable).insert(
              VoidReasonsTableCompanion(
                id: Value(realId),
                companyId: Value(v.companyId),
                name: Value(v.name),
                rank: Value(v.rank),
                lastModified: Value(DateTime.now().toUtc()),
                syncStatus: const Value('synced'),
              ),
            );
          });
        } else {
          await dio.put<dynamic>(
            '/VoidReasons/Update/${v.id}',
            queryParameters: {'name': v.name, 'rank': v.rank},
          );
          await (db.update(
            db.voidReasonsTable,
          )..where((x) => x.id.equals(v.id))).write(
            const VoidReasonsTableCompanion(syncStatus: Value('synced')),
          );
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: v.syncStatus,
          logLabel: 'pushPendingVoidReasonOps: ${v.id} (${v.syncStatus})',
          entityLabel: 'Void reason "${v.name}"',
          apply: (s, _) => (db.update(db.voidReasonsTable)
                ..where((x) => x.id.equals(v.id)))
              .write(VoidReasonsTableCompanion(syncStatus: Value(s))),
        );
      }
    }
  }

  Future<void> pullVoidReasons(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/VoidReasons/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => VoidReasonsTableCompanion(
                id: Value((j['id'] as num?)?.toInt() ?? 0),
                companyId: Value(companyId),
                name: Value((j['name'] as String?) ?? ''),
                rank: Value((j['rank'] as num?)?.toInt() ?? 0),
                lastModified: Value(DateTime.now().toUtc()),
                syncStatus: const Value('synced'),
              ))
          .toList();
      await db.replaceVoidReasons(companyId, rows);
    } catch (e) {
      debugPrint('pullVoidReasons failed: $e — local cache preserved.');
    }
  }

  // ==========================================================================
  // PULL — Document types + categories (full replace). Small, rarely-changing
  // master data that the document editor's type picker needs offline.
  // ==========================================================================
  Future<void> pullDocumentTypes(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/DocumentType/GetAll');
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => DocumentTypesTableCompanion(
                id: Value((j['id'] as num?)?.toInt() ?? 0),
                name: Value((j['name'] as String?) ?? ''),
                code: Value(j['code'] as String?),
                documentCategoryId:
                    Value((j['documentCategoryId'] as num?)?.toInt()),
                stockDirection:
                    Value((j['stockDirection'] as num?)?.toInt() ?? 0),
                lastModified: Value(DateTime.now().toUtc()),
              ))
          .toList();
      if (rows.isNotEmpty) await db.upsertDocumentTypes(rows);
    } catch (e) {
      debugPrint('pullDocumentTypes failed: $e — local cache preserved.');
    }
  }

  Future<void> pullDocumentCategories(int companyId) async {
    try {
      final res = await dio.get<dynamic>('/DocumentCategory/GetAll',
          queryParameters: {'companyId': companyId});
      final list = ((res.data as List?) ?? const []).cast<Map<String, dynamic>>();
      final rows = list
          .map((j) => DocumentCategoriesTableCompanion(
                id: Value((j['id'] as num?)?.toInt() ?? 0),
                companyId: Value(companyId),
                name: Value((j['name'] as String?) ?? ''),
                lastModified: Value(DateTime.now().toUtc()),
              ))
          .toList();
      if (rows.isNotEmpty) await db.upsertDocumentCategories(rows);
    } catch (e) {
      debugPrint('pullDocumentCategories failed: $e — local cache preserved.');
    }
  }

  // ==========================================================================
  // BOOKINGS — full-set MERGE pull (offline-first safe).
  //
  // /Bookings/GetAll returns the full set (no watermark), so we can still
  // reflect server-side deletes — but unlike the old wipe-and-replace, local
  // changes win until pushed: rows with a pending status are never overwritten
  // or removed. We only (a) delete already-synced local rows the server no
  // longer has, and (b) upsert server rows that aren't locally pending. All in
  // one transaction so the Drift watch stream emits exactly once.
  // ==========================================================================
  Future<void> pullBookings(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/Bookings/GetAll',
      queryParameters: {'companyId': companyId},
    );
    final serverRows = (res.data ?? const []).cast<Map<String, dynamic>>();
    final serverIds = serverRows.map((j) => j['id'] as int).toList();

    // Rows with unpushed local changes — preserve them verbatim.
    final pendingIds =
        (await (db.select(db.bookingsTable)
                  ..where((t) => t.companyId.equals(companyId))
                  ..where((t) => t.syncStatus.isNotIn(const ['synced'])))
                .get())
            .map((r) => r.id)
            .toSet();

    await db.transaction(() async {
      // (a) Reflect server-side deletes — but only for clean (synced) rows.
      await (db.delete(db.bookingsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.syncStatus.equals('synced'))
            ..where((t) => t.id.isNotIn(serverIds)))
          .go();

      // (b) Upsert server rows, skipping anything locally pending.
      await db.batch((batch) {
        for (final json in serverRows) {
          final id = json['id'] as int;
          if (pendingIds.contains(id)) continue;
          final tableIds = (json['tableIds'] as List<dynamic>?)
                  ?.map((e) => (e as num).toInt())
                  .toList() ??
              const <int>[];
          batch.insert(
            db.bookingsTable,
            BookingsTableCompanion(
              id: Value(id),
              companyId: Value(json['companyId'] as int? ?? companyId),
              customerId: Value(json['customerId'] as int?),
              userId: Value(json['userId'] as int?),
              reservationName: Value(json['reservationName'] as String? ?? ''),
              tableIdsJson: Value(jsonEncode(tableIds)),
              documentId: Value(json['documentId'] as int?),
              posOrderId: Value(json['posOrderId'] as int?),
              startTime: Value(DateTime.parse(json['startTime'] as String)),
              endTime: Value(DateTime.parse(json['endTime'] as String)),
              guestCount: Value(json['guestCount'] as int? ?? 1),
              status: Value(json['status'] as int? ?? 1),
              note: Value(json['note'] as String?),
              lastModified: Value(_parseLastModified(json['lastModified'])),
              syncStatus: const Value('synced'),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  // ==========================================================================
  // FLOOR PLAN TABLES — push offline create / update / delete.
  //  • pending_create (temp id) → POST /Add; swap the temp row for the server id.
  //    The payload is rebuilt from the local row, so moves/renames made before
  //    the first sync ride along with the create.
  //  • pending_update (real id) → PATCH /Update (name + shape) and
  //    /UpdateGeometry (position + size).
  //  • pending_delete → DELETE on the server (real ids only); temp rows that
  //    never synced are just dropped.
  //
  // Names are unique per plan server-side (UQ_FloorPlanTable_Name_PerPlan), so a
  // create whose name was taken while offline is a rejection, not a retry — it
  // resolves to sync_failed and keeps the local row.
  // ==========================================================================
  Future<void> pushPendingFloorPlanTableOps(int companyId) async {
    final pending =
        await (db.select(db.floorPlanTablesTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();
    if (pending.isEmpty) return;

    for (final t in pending) {
      try {
        final isTemp = t.id < 0;

        if (t.syncStatus == 'pending_delete') {
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/FloorPlanTables/Delete',
              queryParameters: {'id': t.id, 'companyId': companyId},
            );
          }
          await (db.delete(
            db.floorPlanTablesTable,
          )..where((x) => x.id.equals(t.id))).go();
          continue;
        }

        if (isTemp) {
          final res = await dio.post<dynamic>(
            '/FloorPlanTables/Add',
            queryParameters: {'companyId': companyId},
            data: {
              'floorPlanId': t.floorPlanId,
              'name': t.name,
              'positionX': t.positionX,
              'positionY': t.positionY,
              'width': t.width,
              'height': t.height,
              'isRound': t.isRound,
              'status': t.status,
            },
          );
          final data = res.data;
          final realId =
              data is Map ? ((data['id'] ?? data['Id']) as num?)?.toInt() : null;
          if (realId == null || realId <= 0) {
            throw Exception('Server returned no id for floor plan table create');
          }
          await db.transaction(() async {
            await (db.delete(
              db.floorPlanTablesTable,
            )..where((x) => x.id.equals(t.id))).go();
            await db.into(db.floorPlanTablesTable).insert(
                  FloorPlanTablesTableCompanion(
                    id: Value(realId),
                    companyId: Value(t.companyId),
                    floorPlanId: Value(t.floorPlanId),
                    name: Value(t.name),
                    positionX: Value(t.positionX),
                    positionY: Value(t.positionY),
                    width: Value(t.width),
                    height: Value(t.height),
                    isRound: Value(t.isRound),
                    status: Value(t.status),
                    lastModified: Value(DateTime.now().toUtc()),
                    syncStatus: const Value('synced'),
                    syncError: const Value(null),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
            await db.remapFloorPlanTableRefs(t.id, realId, companyId);
          });
        } else {
          await dio.patch<dynamic>(
            '/FloorPlanTables/Update',
            queryParameters: {'companyId': companyId},
            data: {'id': t.id, 'name': t.name, 'isRound': t.isRound},
          );
          await dio.patch<dynamic>(
            '/FloorPlanTables/UpdateGeometry',
            queryParameters: {'companyId': companyId},
            data: {
              'id': t.id,
              'positionX': t.positionX,
              'positionY': t.positionY,
              'width': t.width,
              'height': t.height,
            },
          );
          await (db.update(
            db.floorPlanTablesTable,
          )..where((x) => x.id.equals(t.id))).write(
            const FloorPlanTablesTableCompanion(
              syncStatus: Value('synced'),
              syncError: Value(null),
            ),
          );
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: t.syncStatus,
          logLabel: 'pushPendingFloorPlanTableOps: table ${t.id} (${t.syncStatus})',
          entityLabel: 'Table "${t.name}"',
          apply: (s, msg) => (db.update(db.floorPlanTablesTable)
                ..where((x) => x.id.equals(t.id)))
              .write(FloorPlanTablesTableCompanion(
                  syncStatus: Value(s), syncError: Value(msg))),
        );
      }
    }
  }

  // ==========================================================================
  // BOOKINGS — push offline create / update / status / delete.
  //  • pending_create (temp id) → POST /Add, then a status patch if it isn't
  //    the default Scheduled; swap the temp row for the server id.
  //  • pending_update (real id) → PATCH /Update (full edit) + /UpdateStatus
  //    (covers both full edits and status-only changes made offline).
  //  • pending_delete → DELETE on the server (real ids only); temp rows that
  //    never synced are just dropped.
  // ==========================================================================
  Future<void> pushPendingBookings(int companyId) async {
    final pending =
        await (db.select(db.bookingsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();
    if (pending.isEmpty) return;

    // The booking delete endpoint requires a warehouse id; use the company's
    // first known warehouse (falls back to 1).
    final whRow = await (db.select(db.warehousesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..limit(1))
        .getSingleOrNull();
    final warehouseId = whRow?.id ?? 1;

    for (final b in pending) {
      try {
        final isTemp = b.id < 0;

        // ── DELETE ──────────────────────────────────────────────────────────
        if (b.syncStatus == 'pending_delete') {
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/Bookings/Delete',
              queryParameters: {
                'companyId': companyId,
                'id': b.id,
                'warehouseid': warehouseId,
              },
            );
          }
          await (db.delete(
            db.bookingsTable,
          )..where((x) => x.id.equals(b.id))).go();
          continue;
        }

        final tableIds = (jsonDecode(b.tableIdsJson) as List<dynamic>)
            .map((e) => (e as num).toInt())
            .toList();
        final payload = <String, dynamic>{
          'reservationName': b.reservationName,
          'guestCount': b.guestCount,
          'startTime': b.startTime.toIso8601String(),
          'endTime': b.endTime.toIso8601String(),
          'userId': b.userId,
          'tableIds': tableIds,
          'customerId': b.customerId,
          'note': b.note,
        };

        // ── CREATE (temp id always POSTs) ─────────────────────────────────
        if (isTemp) {
          final res = await dio.post<dynamic>(
            '/Bookings/Add',
            queryParameters: {'companyId': companyId},
            data: payload,
          );
          final body =
              res.data is Map ? ((res.data as Map)['data'] ?? res.data) : null;
          final realId = (body is Map ? (body['id'] as num?) : null)?.toInt();
          if (realId == null) {
            throw Exception('Server returned no id for booking create');
          }
          // A status changed offline before the first sync (default is 1).
          if (b.status != 1) {
            await dio.patch<dynamic>(
              '/Bookings/UpdateStatus',
              queryParameters: {'companyId': companyId},
              data: {
                'bookingId': realId,
                'status': b.status,
                'documentId': b.documentId,
              },
            );
          }
          await db.transaction(() async {
            await (db.delete(
              db.bookingsTable,
            )..where((x) => x.id.equals(b.id))).go();
            await db.into(db.bookingsTable).insert(
              BookingsTableCompanion(
                id: Value(realId),
                companyId: Value(b.companyId),
                customerId: Value(b.customerId),
                userId: Value(b.userId),
                reservationName: Value(b.reservationName),
                tableIdsJson: Value(b.tableIdsJson),
                documentId: Value(b.documentId),
                posOrderId: Value(b.posOrderId),
                startTime: Value(b.startTime),
                endTime: Value(b.endTime),
                guestCount: Value(b.guestCount),
                status: Value(b.status),
                note: Value(b.note),
                lastModified: Value(DateTime.now().toUtc()),
                syncStatus: const Value('synced'),
              ),
              mode: InsertMode.insertOrReplace,
            );
          });
        } else {
          // ── UPDATE (real id): full edit + status ──────────────────────────
          await dio.patch<dynamic>(
            '/Bookings/Update',
            queryParameters: {'companyId': companyId},
            data: {'bookingId': b.id, ...payload},
          );
          await dio.patch<dynamic>(
            '/Bookings/UpdateStatus',
            queryParameters: {'companyId': companyId},
            data: {
              'bookingId': b.id,
              'status': b.status,
              'documentId': b.documentId,
            },
          );
          await (db.update(
            db.bookingsTable,
          )..where((x) => x.id.equals(b.id))).write(
            const BookingsTableCompanion(syncStatus: Value('synced')),
          );
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: b.syncStatus,
          logLabel: 'pushPendingBookings: booking ${b.id} (${b.syncStatus})',
          entityLabel: 'Booking "${b.reservationName}"',
          apply: (s, _) =>
              (db.update(db.bookingsTable)..where((x) => x.id.equals(b.id)))
                  .write(BookingsTableCompanion(syncStatus: Value(s))),
        );
      }
    }
  }

  Future<void> pushPendingOrders(int companyId) async {
    final pending = await db.getPendingOrders();
    if (pending.isEmpty) return;

    // Attach each order's normalized discount breakdown so DiscountLine rows are
    // persisted server-side for cloud analytics. Fetched per order (async) and
    // folded into the batch payload below.
    final orders = <Map<String, dynamic>>[];
    for (final o in pending) {
      final discounts = await db.getDiscountLinesForOrder(o.order.localId);
      orders.add(_orderToBatchJson(o, discounts));
    }
    final payload = {'orders': orders};

    final List<dynamic> results;
    try {
      // X-Device-Id is set on dio.options in sync() (Pillar 4 seat enforcement).
      final res = await dio.post<Map<String, dynamic>>(
        '/PosOrder/BatchSync',
        queryParameters: {'companyId': companyId},
        data: payload,
      );
      results = (res.data?['results'] as List<dynamic>?) ?? const [];
    } on DioException catch (e) {
      // Licensing rejection — surface it as a hard, visible error rather than a
      // swallowed step failure, so the operator understands why sync stopped.
      if (e.response?.statusCode == 403) {
        final data = e.response?.data;
        final err = data is Map ? data['error'] : null;
        if (err == 'seat_limit_exceeded' || err == 'device_blocked') {
          throw SeatLimitException(
            (data is Map ? data['message'] as String? : null) ??
                'This device is not authorized to sync (license / seat limit).',
          );
        }
      }
      rethrow;
    }

    for (final raw in results) {
      final r = raw as Map<String, dynamic>;
      final localId = r['localId'] as String?;
      if (localId == null) continue;

      final success = r['success'] as bool? ?? false;
      try {
        if (success) {
          final serverId = r['serverId'] as int?;
          if (serverId != null) {
            await db.linkDocumentToServer(localId, serverId);
            // Stamp each local document_items row with the server-assigned id the
            // checkout created (keyed by the shared line localId). Without this the
            // origin device's checkout items keep serverId=null and their later
            // edits/deletes can never sync. Survives deleteCompletedOrder below
            // (that removes pos_orders/items only; document_items are separate).
            final itemServerIds = r['itemServerIds'];
            if (itemServerIds is Map) {
              for (final entry in itemServerIds.entries) {
                final lineLocalId = entry.key as String?;
                final itemServerId = (entry.value as num?)?.toInt();
                if (lineLocalId != null && itemServerId != null) {
                  await db.markDocumentItemSynced(lineLocalId, itemServerId);
                }
              }
            }
            // The server persisted this sale's DiscountLine rows — stamp the
            // local lines synced so they aren't re-pushed. (They survive the
            // order delete: they also link to the document by localId.)
            await db.markDiscountLinesSynced(localId);
            await db.deleteCompletedOrder(localId);
          } else {
            await db.markOrderFailed(
              localId,
              'Server returned success without a serverId.',
            );
          }
        } else {
          final error = r['error'] as String? ?? 'Unknown server error.';
          await db.markOrderFailed(localId, error);
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic> _orderToBatchJson(
    PosOrderWithItems o,
    List<DiscountLinesTableData> discounts,
  ) {
    // Resolve item-level discount lines to their productId via the order items
    // (the local line stores productId only as sourceRefId for manual_item, not
    // for promotion — this map is reliable for both).
    final productByItemLocalId = {for (final it in o.items) it.localId: it.productId};
    return {
      'localId': o.order.localId,
      'existingServerId': o.order.serverId,
      'paymentTypeId': o.order.paymentTypeId,
      'amountPaid': o.order.amountPaid,
      'orderTotal': o.order.total ?? 0,
      // Device-local document number issued offline at checkout. The server
      // keeps it verbatim instead of generating its own (offline-first).
      'clientDocumentNumber': o.order.number,
      'order': {
        'userId': o.order.userId,
        'number': o.order.orderName,
        'discount': o.order.discount,
        'discountType': o.order.discountType,
        'total': o.order.total,
        'customerId': o.order.customerId,
        'serviceType': o.order.serviceType,
        'serviceStatus': o.order.serviceStatus,
        'floorPlanTableId': o.order.tableId,
        'warehouseId': o.order.warehouseId,
      },
      'items': o.items.map((item) {
        final List<Map<String, dynamic>> taxEntries = item.taxesJson != null
            ? (jsonDecode(item.taxesJson!) as List).cast<Map<String, dynamic>>()
            : const [];
        final appliedTaxIds = taxEntries.map((t) => t['id'] as int).toList();
        final taxes = taxEntries
            .map((t) => {'taxId': t['id'] as int, 'amount': t['amount']})
            .toList();
        return {
          'posOrderId': 0,
          'productId': item.productId,
          // Stable line id shared with the local document_item. The server echoes
          // the created DocumentItem id back keyed by this, so we can stamp the
          // local document_items.serverId for later edit/delete sync.
          'lineLocalId': item.localId,
          'roundNumber': 1,
          'quantity': item.quantity,
          'price': item.unitPrice,
          'discount': item.discount,
          'discountType': item.discountType,
          'discountAppliedType': 0,
          'comment': item.comment,
          'bundle': null,
          'appliedTaxIds': appliedTaxIds,
          'taxes': taxes,
        };
      }).toList(),
      'discounts': discounts.map((d) => {
            // Item-level lines carry their productId (resolved from the order
            // item); whole-order lines send null.
            'productId':
                d.itemLocalId != null ? productByItemLocalId[d.itemLocalId] : null,
            'source': d.source,
            'sourceRefId': d.sourceRefId,
            'value': d.value,
            'valueType': d.valueType,
            'amount': d.amount,
            'sequence': d.sequence,
            'label': d.label,
          }).toList(),
    };
  }

  // ==========================================================================
  // PULL — discount lines (multi-device mirror). Brings the discount breakdown
  // of sales made on OTHER devices into local Drift, so the document editor /
  // reports show them everywhere. Read-only: lines are only created at checkout.
  //
  // Each server line is attached to the local document whose serverId matches
  // its DocumentId. Lines whose document isn't local yet are skipped (the next
  // sync, after pullDocuments lands it, picks them up). Per document we replace
  // only the SYNCED rows, so a not-yet-pushed local edit is never clobbered.
  // ==========================================================================
  Future<void> pullDiscountLines(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/DiscountLines/GetAll',
      queryParameters: {'companyId': companyId},
    );
    final rows = res.data;
    if (rows == null) return;

    // serverId → local document localId, for the documents we hold locally.
    final localDocs = await (db.select(db.documentsTable)
          ..where((t) => t.serverId.isNotNull()))
        .get();
    final localIdByServerId = {
      for (final d in localDocs)
        if (d.serverId != null) d.serverId!: d.localId,
    };

    // Group incoming lines by their (local) document.
    final byDocLocalId = <String, List<DiscountLinesTableCompanion>>{};
    for (final j in rows.cast<Map<String, dynamic>>()) {
      final documentId = (j['documentId'] as num?)?.toInt();
      final docLocalId = documentId == null ? null : localIdByServerId[documentId];
      if (docLocalId == null) continue; // document not present locally yet
      byDocLocalId.putIfAbsent(docLocalId, () => []).add(
            DiscountLinesTableCompanion(
              localId: Value(const Uuid().v4()),
              companyId: Value(companyId),
              orderLocalId: Value(docLocalId),
              documentLocalId: Value(docLocalId),
              itemLocalId: const Value(null),
              source: Value((j['source'] as String?) ?? ''),
              sourceRefId: Value((j['sourceRefId'] as num?)?.toInt()),
              value: Value((j['value'] as num?)?.toDouble() ?? 0),
              valueType: Value((j['valueType'] as num?)?.toInt() ?? 0),
              amount: Value((j['amount'] as num?)?.toDouble() ?? 0),
              sequence: Value((j['sequence'] as num?)?.toInt() ?? 0),
              label: Value(j['label'] as String?),
              serverId: Value((j['id'] as num?)?.toInt()),
              syncStatus: const Value('synced'),
              lastModified: Value(DateTime.now().toUtc()),
            ),
          );
    }

    for (final entry in byDocLocalId.entries) {
      await db.replacePulledDiscountLines(entry.key, entry.value);
    }
  }

  Future<void> pushPendingOpenOrders(int companyId) async {
    final pending = await db.getPendingOpenOrders();
    if (pending.isEmpty) return;

    for (final o in pending) {
      // An item still pointing at a temp (negative) product id means that
      // product's own create hasn't reached the server yet (e.g. its push is
      // stuck). Posting now would 400 with "product not found", so wait for the
      // next cycle once the product syncs — and record why in the meantime.
      if (o.items.any((i) => i.productId < 0)) {
        await db.setOrderSyncError(
          o.order.localId,
          'Waiting for an offline product in this order to sync first.',
        );
        debugPrint(
          'pushPendingOpenOrders: ${o.order.localId} skipped — '
          'item references an unsynced (temp) product id.',
        );
        continue;
      }
      try {
        int serverId;
        if (o.order.serverId == null) {
          final res = await dio.post<dynamic>(
            '/PosOrder/Create',
            queryParameters: {'companyId': companyId},
            data: {
              'userId': o.order.userId,
              'number': o.order.orderName ?? 'ORD',
              'discount': o.order.discount,
              'discountType': o.order.discountType,
              'total': o.order.total ?? 0,
              'customerId': o.order.customerId,
              'serviceType': o.order.serviceType,
              'serviceStatus': o.order.serviceStatus,
              'floorPlanTableId': o.order.tableId,
              'warehouseId': o.order.warehouseId,
            },
          );
          final data = res.data;
          serverId = data is int
              ? data
              : (data['id'] ??
                        data['Id'] ??
                        data['posOrderId'] ??
                        data['PosOrderId'])
                    as int;

          await db.setServerId(o.order.localId, serverId);
        } else {
          serverId = o.order.serverId!;
          await dio.patch<dynamic>(
            '/PosOrder/Update',
            queryParameters: {'companyId': companyId},
            data: {
              "id": serverId,
              "userId": o.order.userId,
              "number": o.order.orderName,
              "discount": o.order.discount,
              "discountType": o.order.discountType,
              "total": o.order.total,
              "customerId": o.order.customerId,
              "serviceType": o.order.serviceType,
              "serviceStatus": o.order.serviceStatus,
              "floorPlanTableId": o.order.tableId,
              "warehouseId": o.order.warehouseId,
            },
          );
        }

        if (o.items.isNotEmpty) {
          final itemsJson = o.items.map((item) {
            final List<Map<String, dynamic>> taxEntries = item.taxesJson != null
                ? (jsonDecode(item.taxesJson!) as List)
                      .cast<Map<String, dynamic>>()
                : const [];
            final appliedTaxIds = taxEntries
                .map((t) => t['id'] as int)
                .toList();
            return {
              'posOrderId': serverId,
              'PosOrderId': serverId,
              'productId': item.productId,
              'ProductId': item.productId,
              'quantity': item.quantity,
              'Quantity': item.quantity,
              'price': item.unitPrice,
              'Price': item.unitPrice,
              'discount': item.discount,
              'Discount': item.discount,
              'discountType': item.discountType,
              'DiscountType': item.discountType,
              'discountAppliedType': 0,
              'DiscountAppliedType': 0,
              'comment': item.comment,
              'Comment': item.comment,
              'roundNumber': 1,
              'RoundNumber': 1,
              'bundle': null,
              'Bundle': null,
              'appliedTaxIds': appliedTaxIds,
              'AppliedTaxIds': appliedTaxIds,
            };
          }).toList();

          await dio.post<dynamic>(
            '/PosOrderItem/BulkAdd',
            queryParameters: {
              'companyId': companyId,
              'warehouseId': o.order.warehouseId,
              'orderTotal': o.order.total ?? 0,
              // This is an offline replay of an already-parked order — the stock
              // decision was made at cart-add time (menu's _passesStockGuards),
              // so don't let the server re-block it for current stock levels.
              // Mirrors BatchSync's behaviour for completed sales.
              'allowNegativeStock': true,
            },
            data: itemsJson,
          );
        }

        // Phase 3: mark fully synced.
        await db.markOrderSynced(o.order.localId, serverId);
      } catch (e) {
        // Pull the server's structured reason out of the response body (the raw
        // DioException only says "status code 400"). Per the API contract a
        // business rejection looks like {success:false, message:"...", ...}.
        final msg = _serverErrMsg(e);
        // Keep the order 'pending' so it auto-recovers once the cause is fixed
        // (e.g. restock, or the referenced product finishes syncing) — but
        // persist the reason so the Sync Status panel explains the hold-up.
        await db.setOrderSyncError(o.order.localId, msg);
        debugPrint('pushPendingOpenOrders: ${o.order.localId} failed — $msg');
        // Leave as pending; next sync will retry.
      }
    }
  }

  Future<void> pushPendingVoids(int companyId) async {
    final pending = await db.getPendingVoids();
    if (pending.isEmpty) return;

    for (final v in pending) {
      try {
        final items = (jsonDecode(v.itemsJson) as List)
            .cast<Map<String, dynamic>>();

        // An item still pointing at a temp (negative) product id means its
        // product create hasn't synced yet (remapProductId rewrites this blob
        // once it does). Leave the void for the next cycle rather than 400.
        if (items.any((i) => (i['productId'] as int? ?? 0) < 0)) {
          continue;
        }

        // Step 1: post a PosVoid row for every voided item.
        for (final item in items) {
          await dio.post<dynamic>(
            '/PosVoids/Add',
            queryParameters: {
              'companyId': companyId,
              'orderNumber': v.orderNumber,
              'userId': v.userId,
              'userName': (item['userName'] ?? '') as String,
              'productId': item['productId'] as int,
              'productName': (item['productName'] ?? '') as String,
              'roundNumber': (item['roundNumber'] ?? 1) as int,
              'quantity': item['quantity'],
              'price': item['price'],
              'discount': (item['discount'] ?? 0),
              'discountType': (item['discountType'] ?? 0) as int,
              'total': item['total'],
              'voidedById': v.userId,
              'voidedByName': (item['userName'] ?? '') as String,
              if (v.reason != null) 'reason': v.reason,
            },
          );
        }

        // Step 2: delete the server PosOrder (void = remove the open order).
        await dio.delete<dynamic>(
          '/PosOrder/Delete',
          queryParameters: {
            'id': v.serverOrderId,
            'companyId': companyId,
            'warehouseId': v.warehouseId,
          },
        );

        await db.markVoidSynced(v.localId);
      } catch (e) {
        debugPrint('pushPendingVoids: ${v.localId} failed — $e');
        // Leave as pending; next sync retries.
      }
    }
  }

  // ==========================================================================
  // PUSH — pending cash movements to /StartingCash/Add (individual POSTs)
  // ==========================================================================

  /// Pushes every `syncStatus='pending'` cash_movement to /StartingCash/Add.
  /// No batch endpoint exists server-side, so we loop individually — fine
  /// for the typical end-of-shift queue size (single digits).
  ///
  /// Per-item failure marks just that row failed; the loop continues. Whole-
  /// transport failures (e.g. server unreachable mid-loop) leave remaining
  /// rows pending for the next retry.
  Future<void> pushPendingCashMovements(int companyId) async {
    final pending = await db.getPendingCashMovements();
    if (pending.isEmpty) return;

    for (final m in pending) {
      try {
        final res = await dio.post<dynamic>(
          '/StartingCash/Add',
          queryParameters: {
            'companyId': companyId,
            'userId': m.userId,
            'amount': m.amount,
            // Drift stores 'in'/'out' as text for readability; the C# API
            // expects 0 (cash in) / 1 (cash out). Convert at the boundary.
            'startingCashType': m.type == 'in' ? 0 : 1,
            if (m.note != null && m.note!.isNotEmpty) 'description': m.note,
          },
        );

        // /StartingCash/Add returns the created StartingCashDto with an `id`.
        final data = res.data;
        final serverId = data is Map<String, dynamic>
            ? (data['id'] as int?)
            : null;

        if (serverId != null) {
          await db.markCashMovementSynced(m.localId, serverId);
        } else {
          // Server accepted the POST but we couldn't parse an id — mark
          // synced without server linkage rather than retry forever.
          await db.markCashMovementSynced(m.localId, 0);
        }
      } catch (e) {
        await db.markCashMovementFailed(m.localId, e.toString());
        // Continue the loop — one bad movement shouldn't block the rest.
      }
    }
  }

  // ==========================================================================
  // PUSH — pending Z-reports via /ZReports/Generate (individual POSTs)
  // ==========================================================================

  /// Pushes every `syncStatus='pending'` z_report. /ZReports/Generate is a
  /// server-side aggregation, so we don't send our local totals — we just
  /// ask the server to generate its own Z-report for the user/company and
  /// use the returned id to mark the local snapshot as synced.
  ///
  /// CRITICAL ORDERING: This must run AFTER pushPendingOrders and
  /// pushPendingCashMovements so that all source data the server aggregates
  /// over is already present. `sync()` enforces this order.
  Future<void> pushPendingZReports(int companyId) async {
    final pending = await db.getPendingZReports();
    if (pending.isEmpty) return;

    for (final report in pending) {
      try {
        final res = await dio.post<dynamic>(
          '/ZReports/Generate',
          queryParameters: {'companyId': companyId, 'userId': report.userId},
        );

        final data = res.data;
        final map = data is Map<String, dynamic> ? data : null;
        final serverId = map?['id'] as int?;
        // The server owns Z numbering across devices, so its number supersedes
        // the device-local one issued at close time. The local totals stand:
        // they were computed from this device's documents at the moment of
        // closing, which is what the cashier's slip states.
        final serverNumber = map?['number'] as int?;

        await db.markZReportSynced(report.localId, serverId ?? 0,
            serverNumber: serverNumber);
      } catch (e) {
        await db.markZReportFailed(report.localId, e.toString());
      }
    }
  }

  // ==========================================================================
  // PUSH — pending product creates / updates / deletes
  // ==========================================================================

  /// Pushes all locally-queued product mutations to the server:
  ///   • pending_create → POST /Products/Add  (temp negative id → real id)
  ///   • pending_update → PATCH /Products/Update
  ///   • pending_delete → DELETE /Products/Delete  (then hard-delete locally)
  ///
  /// Must run BEFORE pushPendingOrders so newly created products exist on the
  /// server before any order that references them is synced.
  /// True when [e] is a server REJECTION (the request reached the server and it
  /// returned an HTTP error) rather than an offline / transient connection error.
  /// A rejection won't succeed by retrying, so the caller resolves it locally
  /// instead of leaving it pending to loop on every sync.
  bool _isServerRejection(Object e) => e is DioException && e.response != null;

  /// Best-effort human message from a server error response.
  String _serverErrMsg(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) return d['message'].toString();
      if (d != null) return d.toString();
      return e.message ?? 'Server rejected the request.';
    }
    return e.toString();
  }

  /// Shared push-failure resolver. A server REJECTION (HTTP response) can't be
  /// fixed by retrying, so it's resolved to a terminal status via [apply]:
  ///   • pending_delete → 'synced'  (un-delete; the server still has the row),
  ///   • create / update → 'sync_failed' (keep the local data, stop retrying).
  /// An offline / transient error (no response) is left pending to retry.
  /// [apply] writes the row with the chosen status (+ the server message for
  /// tables that carry a syncError column).
  ///
  /// When a delete is rejected the row is un-deleted (reappears in the UI), so
  /// pass [entityLabel] (e.g. a product/barcode name) to record a user-facing
  /// notice explaining why the delete didn't stick — surfaced after the sync.
  Future<void> _resolveRejection({
    required Object error,
    required String syncStatus,
    required String logLabel,
    required Future<void> Function(String newStatus, String message) apply,
    String? entityLabel,
  }) async {
    if (_isServerRejection(error)) {
      final msg = _serverErrMsg(error);
      final isDeleteRevert = syncStatus == 'pending_delete';
      final newStatus = isDeleteRevert ? 'synced' : 'sync_failed';
      await apply(newStatus, msg);
      if (isDeleteRevert && entityLabel != null) {
        _rejectionNotices.add('$entityLabel couldn\'t be deleted — $msg');
      }
      debugPrint('$logLabel rejected — $msg (resolved, won\'t retry)');
    } else {
      // Offline / transient (no HTTP response) — keep the row at its current
      // status so the next sync retries, but PERSIST the reason so the Sync
      // Status panel can explain why it's still pending (instead of the cause
      // living only in a debugPrint the operator never sees).
      await apply(syncStatus, _serverErrMsg(error));
      debugPrint('$logLabel failed — $error (will retry)');
    }
  }

  Future<void> pushPendingProductOps(int companyId) async {
    final pending =
        await (db.select(db.productsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (pending.isEmpty) return;

    for (final p in pending) {
      try {
        // A temp (negative) id means the product was created offline and has
        // never existed on the server yet.
        final isTemp = p.id < 0;

        // ── DELETE ────────────────────────────────────────────────────────
        if (p.syncStatus == 'pending_delete') {
          // Deleting a row that never reached the server is pure local cleanup
          // — there is nothing on the server to delete, so don't 400 on it.
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/Products/Delete',
              queryParameters: {'id': p.id, 'companyId': companyId},
            );
          }
          await (db.delete(
            db.productsTable,
          )..where((t) => t.id.equals(p.id))).go();
          continue;
        }

        // Re-encode image from disk so we can include it in the request body.
        String imageBase64 = '';
        if (p.localImagePath != null) {
          try {
            final bytes = await File(p.localImagePath!).readAsBytes();
            imageBase64 = base64Encode(bytes);
          } catch (_) {}
        }

        // ── CREATE ──────────────────────────────────────────────────────────
        // A temp id must ALWAYS be POSTed, even if a later offline edit flipped
        // its status to pending_update: the product never reached the server, so
        // PATCH /Products/Update would 400 forever on an unknown id (and drag
        // every product-keyed dependent — barcodes, stock rules — into the same
        // loop). Creating it first lets remapProductId cascade the real id.
        if (isTemp) {
          final res = await dio.post<Map<String, dynamic>>(
            '/Products/Add',
            queryParameters: {'companyId': companyId},
            data: {
              'name': p.name,
              'productGroupId': p.productGroupId,
              'code': p.code,
              'plu': p.plu,
              'measurementUnit': p.measurementUnit,
              'price': p.price,
              'cost': p.cost,
              'markup': p.markup,
              'rank': p.rank,
              'ageRestriction': p.ageRestriction,
              'description': p.description,
              'isTaxInclusivePrice': p.isTaxInclusivePrice,
              'isService': p.isService,
              'isPriceChangeAllowed': p.isPriceChangeAllowed,
              'isUsingDefaultQuantity': p.isUsingDefaultQuantity,
              'isEnabled': p.isEnabled,
              'color': p.colorHex ?? '#000000',
              'imageBase64': imageBase64,
            },
          );
          final body = res.data?['data'] ?? res.data;
          final realId = (body['id'] as num?)?.toInt();
          if (realId == null) {
            throw Exception('Server returned no id for product create');
          }

          // Replace the temp row: delete by temp id, insert with real id, and
          // cascade the id swap to product-keyed tables (taxes, stock rules,
          // barcodes, stocks) so their pending pushes use the real id.
          await db.transaction(() async {
            await (db.delete(
              db.productsTable,
            )..where((t) => t.id.equals(p.id))).go();
            await db
                .into(db.productsTable)
                .insert(
                  ProductsTableCompanion(
                    id: Value(realId),
                    companyId: Value(p.companyId),
                    name: Value(p.name),
                    price: Value(p.price),
                    cost: Value(p.cost),
                    productGroupId: Value(p.productGroupId),
                    isService: Value(p.isService),
                    colorHex: Value(p.colorHex),
                    localImagePath: Value(p.localImagePath),
                    code: Value(p.code),
                    plu: Value(p.plu),
                    measurementUnit: Value(p.measurementUnit),
                    description: Value(p.description),
                    markup: Value(p.markup),
                    rank: Value(p.rank),
                    ageRestriction: Value(p.ageRestriction),
                    isPriceChangeAllowed: Value(p.isPriceChangeAllowed),
                    isUsingDefaultQuantity: Value(p.isUsingDefaultQuantity),
                    isTaxInclusivePrice: Value(p.isTaxInclusivePrice),
                    isEnabled: Value(p.isEnabled),
                    syncStatus: const Value('synced'),
                    lastModified: Value(DateTime.now().toUtc()),
                  ),
                );
            await db.remapProductId(p.id, realId);
          });
        } else {
          // ── UPDATE (real, server-known id) ────────────────────────────────
          await dio.patch<dynamic>(
            '/Products/Update',
            queryParameters: {'id': p.id, 'companyId': companyId},
            data: {
              'id': p.id,
              'name': p.name,
              'productGroupId': p.productGroupId,
              'code': p.code,
              'plu': p.plu,
              'measurementUnit': p.measurementUnit,
              'price': p.price,
              'cost': p.cost,
              'markup': p.markup,
              'rank': p.rank,
              'ageRestriction': p.ageRestriction,
              'description': p.description,
              'isTaxInclusivePrice': p.isTaxInclusivePrice,
              'isService': p.isService,
              'isPriceChangeAllowed': p.isPriceChangeAllowed,
              'isUsingDefaultQuantity': p.isUsingDefaultQuantity,
              'isEnabled': p.isEnabled,
              'color': p.colorHex ?? '#000000',
              'imageBase64': imageBase64,
            },
          );
          await (db.update(
            db.productsTable,
          )..where((t) => t.id.equals(p.id))).write(
            const ProductsTableCompanion(
              syncStatus: Value('synced'),
              syncError: Value(null),
            ),
          );
        }
      } catch (e) {
        // Server rejection → un-delete (the row still exists on the server) or
        // flag sync_failed for create/update; either way stop retrying. Offline
        // / transient errors are left pending to retry on the next sync.
        await _resolveRejection(
          error: e,
          syncStatus: p.syncStatus,
          logLabel: 'pushPendingProductOps: product ${p.id} (${p.syncStatus})',
          entityLabel: '"${p.name}"',
          apply: (newStatus, msg) =>
              (db.update(db.productsTable)..where((t) => t.id.equals(p.id)))
                  .write(ProductsTableCompanion(
            syncStatus: Value(newStatus),
            syncError: Value(msg),
          )),
        );
      }
    }
  }

  /// Pushes every pending barcode write (pending_create / pending_delete) to
  /// the server. Runs after [pushPendingProductOps] so new product IDs are
  /// already resolved before we try to associate barcodes with them.
  Future<void> pushPendingBarcodeOps(int companyId) async {
    final pending =
        await (db.select(db.barcodesTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where((t) => t.syncStatus.isNotIn(['synced'])))
            .get();

    for (final b in pending) {
      try {
        switch (b.syncStatus) {
          case 'pending_create':
            final res = await dio.post<dynamic>(
              '/Barcodes/Add',
              queryParameters: {'companyId': companyId},
              data: {'productId': b.productId, 'value': b.value},
            );
            final serverId = (res.data is Map ? res.data['id'] : null) as int?;
            await (db.update(
              db.barcodesTable,
            )..where((t) => t.localId.equals(b.localId))).write(
              BarcodesTableCompanion(
                serverId: Value(serverId),
                syncStatus: const Value('synced'),
              ),
            );

          case 'pending_delete':
            if (b.serverId != null) {
              await dio.delete<dynamic>(
                '/Barcodes/Delete',
                queryParameters: {'id': b.serverId, 'companyId': companyId},
              );
            }
            await (db.delete(
              db.barcodesTable,
            )..where((t) => t.localId.equals(b.localId))).go();
        }
      } catch (e) {
        // A delete the server rejects gets un-deleted (barcode reappears) with a
        // user-facing notice; a rejected create is flagged sync_failed so it
        // stops retrying. Offline/transient errors stay pending for next sync.
        // (barcodes carry no syncError column, so the message is logged only.)
        await _resolveRejection(
          error: e,
          syncStatus: b.syncStatus,
          logLabel: 'pushPendingBarcodeOps: barcode ${b.localId} (${b.syncStatus})',
          entityLabel: 'Barcode "${b.value}"',
          apply: (newStatus, _) =>
              (db.update(db.barcodesTable)..where((t) => t.localId.equals(b.localId)))
                  .write(BarcodesTableCompanion(syncStatus: Value(newStatus))),
        );
      }
    }
  }

  // ==========================================================================
  // SYNC META HELPERS
  // ==========================================================================

  Future<DateTime?> _getLastSync(String entity) async {
    final row = await (db.select(
      db.syncMetaTable,
    )..where((t) => t.entity.equals(entity))).getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> _setLastSync(String entity, DateTime time) async {
    await db
        .into(db.syncMetaTable)
        .insertOnConflictUpdate(
          SyncMetaTableCompanion(
            entity: Value(entity),
            lastSyncedAt: Value(time.toUtc()),
          ),
        );
  }

  /// Encodes the watermark in the form the C# `modifiedAfter` query param
  /// expects: ISO-8601 with the trailing `Z` so it parses as `DateTimeKind.Utc`.
  Map<String, dynamic> _query(int companyId, DateTime? watermark) => {
    'companyId': companyId,
    if (watermark != null) 'modifiedAfter': watermark.toUtc().toIso8601String(),
  };

  /// Parses a server timestamp into UTC. Falls back to `now` so a missing
  /// `lastModified` (server not yet backfilled) doesn't write `default(DateTime)`
  /// into the DB.
  DateTime _parseLastModified(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.parse(raw).toUtc();
    }
    return DateTime.now().toUtc();
  }

  /// Like [_parseLastModified] but returns null when the field is missing —
  /// used for optional timestamps (dateCreated / dateUpdated) where "missing"
  /// is meaningful and shouldn't be silently replaced with `now`.
  DateTime? _parseNullableDate(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw).toUtc();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ==========================================================================
  // DELTA PULLS
  // ==========================================================================

  Future<void> pullProducts(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kProducts);

    final res = await dio.get<List<dynamic>>(
      '/Products/GetAll',
      queryParameters: _query(companyId, watermark),
    );

    final rows = res.data ?? const [];

    // Sequential image processing — one file handle at a time. ImageSyncHelper
    // never throws (it logs + returns null on failure), so a single bad image
    // can never abort the loop or leave a half-written product row.
    for (final json in rows.cast<Map<String, dynamic>>()) {
      final id = json['id'] as int;

      // Existing API serves base64 in `image`. ImageSyncHelper handles both
      // base64 and URL transparently — when the backend moves to a CDN, no
      // Flutter change required. Failures return null; the product still
      // inserts with localImagePath: null and the UI falls back to its
      // placeholder icon.
      final localImagePath = await imageHelper.downloadAndSaveImage(
        json['image'] as String?,
        id,
      );
      await db
          .into(db.productsTable)
          .insertOnConflictUpdate(
            ProductsTableCompanion(
              id: Value(id),
              companyId: Value(json['companyId'] as int? ?? companyId),
              name: Value(json['name'] as String? ?? ''),
              price: Value((json['price'] as num?)?.toDouble() ?? 0),
              cost: Value((json['cost'] as num?)?.toDouble() ?? 0),
              barcode: Value(_firstBarcode(json)),
              productGroupId: Value(json['productGroupId'] as int?),
              isService: Value(json['isService'] as bool? ?? false),
              colorHex: Value(json['color'] as String?),
              localImagePath: Value(localImagePath),
              // Schema v2 columns — needed for the admin product editor to
              // render without round-tripping to the API.
              code: Value(json['code'] as String?),
              plu: Value(json['plu'] as int?),
              measurementUnit: Value(json['measurementUnit'] as String?),
              description: Value(json['description'] as String?),
              markup: Value((json['markup'] as num?)?.toDouble()),
              rank: Value(json['rank'] as int? ?? 0),
              currencyId: Value(json['currencyId'] as int?),
              ageRestriction: Value(json['ageRestriction'] as int?),
              lastPurchasePrice: Value(
                (json['lastPurchasePrice'] as num?)?.toDouble(),
              ),
              dateCreated: Value(_parseNullableDate(json['dateCreated'])),
              dateUpdated: Value(_parseNullableDate(json['dateUpdated'])),
              isPriceChangeAllowed: Value(
                json['isPriceChangeAllowed'] as bool? ?? false,
              ),
              isUsingDefaultQuantity: Value(
                json['isUsingDefaultQuantity'] as bool? ?? true,
              ),
              isTaxInclusivePrice: Value(
                json['isTaxInclusivePrice'] as bool? ?? true,
              ),
              isEnabled: Value(json['isEnabled'] as bool? ?? true),
              lastModified: Value(_parseLastModified(json['lastModified'])),
            ),
          );
    }

    await _setLastSync(_kProducts, startedAt);
  }

  String? _firstBarcode(Map<String, dynamic> json) {
    final list = json['barcodes'];
    if (list is List && list.isNotEmpty) {
      final first = list.first;
      return first?.toString();
    }
    return null;
  }

  /// Drains offline tax-rate writes to the server. Mirrors pushPendingProductOps:
  /// a temp (negative) id is always POSTed — even if a later edit flipped it to
  /// pending_update — so /Taxes/UpdateTax never 400s on an id the server never
  /// saw. On create the temp id is swapped for the real one and cascaded to
  /// product-tax assignments via remapTaxId.
  Future<void> pushPendingTaxOps(int companyId) async {
    final pending =
        await (db.select(db.taxesTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (pending.isEmpty) return;

    for (final t in pending) {
      try {
        final isTemp = t.id < 0;

        // ── DELETE ────────────────────────────────────────────────────────
        if (t.syncStatus == 'pending_delete') {
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/Taxes/DeleteTax',
              queryParameters: {'id': t.id, 'companyId': companyId},
            );
          }
          await (db.delete(
            db.taxesTable,
          )..where((x) => x.id.equals(t.id))).go();
          continue;
        }

        final payload = <String, dynamic>{
          'name': t.name,
          'rate': t.rate,
          'code': t.code,
          'isFixed': t.isFixed,
          'isTaxOnTotal': t.isTaxOnTotal,
          'isEnabled': t.isEnabled,
        };

        // ── CREATE (temp id always POSTs) ─────────────────────────────────
        if (isTemp) {
          final res = await dio.post<dynamic>(
            '/Taxes/AddTax',
            queryParameters: {'companyId': companyId},
            data: payload,
          );
          final body =
              res.data is Map ? ((res.data as Map)['data'] ?? res.data) : null;
          final realId = (body is Map ? (body['id'] as num?) : null)?.toInt();
          if (realId == null) {
            throw Exception('Server returned no id for tax create');
          }

          await db.transaction(() async {
            await (db.delete(
              db.taxesTable,
            )..where((x) => x.id.equals(t.id))).go();
            await db.into(db.taxesTable).insert(
              TaxesTableCompanion(
                id: Value(realId),
                companyId: Value(t.companyId),
                name: Value(t.name),
                rate: Value(t.rate),
                code: Value(t.code),
                isFixed: Value(t.isFixed),
                isTaxOnTotal: Value(t.isTaxOnTotal),
                isEnabled: Value(t.isEnabled),
                lastModified: Value(DateTime.now().toUtc()),
                syncStatus: const Value('synced'),
              ),
            );
            await db.remapTaxId(t.id, realId);
          });
        } else {
          // ── UPDATE (real, server-known id) ──────────────────────────────
          await dio.patch<dynamic>(
            '/Taxes/UpdateTax',
            queryParameters: {'companyId': companyId},
            data: {'id': t.id, ...payload},
          );
          await (db.update(
            db.taxesTable,
          )..where((x) => x.id.equals(t.id))).write(
            const TaxesTableCompanion(syncStatus: Value('synced')),
          );
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: t.syncStatus,
          logLabel: 'pushPendingTaxOps: tax ${t.id} (${t.syncStatus})',
          entityLabel: 'Tax "${t.name}"',
          apply: (s, _) =>
              (db.update(db.taxesTable)..where((x) => x.id.equals(t.id)))
                  .write(TaxesTableCompanion(syncStatus: Value(s))),
        );
      }
    }
  }

  Future<void> pullTaxes(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kTaxes);

    final res = await dio.get<List<dynamic>>(
      '/Taxes/GetAllTaxes',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Local changes win until pushed: never overwrite a row that's still
    // pending_update/pending_delete (or resurrect a tombstoned one).
    final pendingIds =
        (await (db.select(db.taxesTable)
                  ..where((t) => t.companyId.equals(companyId))
                  ..where((t) => t.syncStatus.isNotIn(['synced'])))
                .get())
            .map((r) => r.id)
            .toSet();

    await db.batch((batch) {
      for (final json in rows.cast<Map<String, dynamic>>()) {
        final id = json['id'] as int;
        if (pendingIds.contains(id)) continue;
        batch.insert(
          db.taxesTable,
          TaxesTableCompanion(
            id: Value(id),
            companyId: Value(json['companyId'] as int? ?? companyId),
            name: Value(json['name'] as String? ?? ''),
            rate: Value((json['rate'] as num?)?.toDouble() ?? 0),
            // Schema v2 columns.
            code: Value(json['code'] as String?),
            isFixed: Value(json['isFixed'] as bool? ?? false),
            isTaxOnTotal: Value(json['isTaxOnTotal'] as bool? ?? true),
            isEnabled: Value(json['isEnabled'] as bool? ?? true),
            lastModified: Value(_parseLastModified(json['lastModified'])),
            syncStatus: const Value('synced'),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _setLastSync(_kTaxes, startedAt);
  }

  Future<void> pullFloorPlans(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kFloorPlans);

    final res = await dio.get<List<dynamic>>(
      '/FloorPlans/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    await db.batch((batch) {
      for (final json in rows.cast<Map<String, dynamic>>()) {
        batch.insert(
          db.floorPlansTable,
          FloorPlansTableCompanion(
            id: Value(json['id'] as int),
            companyId: Value(json['companyId'] as int? ?? companyId),
            name: Value(json['name'] as String? ?? ''),
            color: Value(json['color'] as String? ?? 'Transparent'),
            lastModified: Value(_parseLastModified(json['lastModified'])),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _setLastSync(_kFloorPlans, startedAt);
  }

  Future<void> pullFloorPlanTables(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kFloorPlanTables);

    final res = await dio.get<List<dynamic>>(
      '/FloorPlanTables/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Loop individually to protect rows with pending local edits from being
    // overwritten by stale server data. Same pattern as pullCustomers — and it
    // matters doubly here: insertOrReplace rewrites the WHOLE row, so an unset
    // syncStatus would silently fall back to its 'synced' default and strand the
    // pending change.
    for (final json in rows.cast<Map<String, dynamic>>()) {
      final id = json['id'] as int;
      final existing = await (db.select(
        db.floorPlanTablesTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null && existing.syncStatus != 'synced') continue;

      await db.into(db.floorPlanTablesTable).insertOnConflictUpdate(
            FloorPlanTablesTableCompanion(
              id: Value(id),
              companyId: Value(json['companyId'] as int? ?? companyId),
              floorPlanId: Value(json['floorPlanId'] as int),
              name: Value(json['name'] as String? ?? ''),
              positionX: Value((json['positionX'] as num?)?.toDouble() ?? 0),
              positionY: Value((json['positionY'] as num?)?.toDouble() ?? 0),
              width: Value((json['width'] as num?)?.toDouble() ?? 0),
              height: Value((json['height'] as num?)?.toDouble() ?? 0),
              isRound: Value(json['isRound'] as bool? ?? false),
              status: Value(json['status'] as int? ?? 0),
              lastModified: Value(_parseLastModified(json['lastModified'])),
              syncStatus: const Value('synced'),
            ),
          );
    }

    await _setLastSync(_kFloorPlanTables, startedAt);
  }

  Future<void> pullUsers(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kUsers);

    // deviceId is required server-side for HashedPin to resolve correctly —
    // each device has its own PIN per user. Without it, every user comes
    // back with `hashedPin: null` and offline login silently breaks.
    final deviceId = await authStorage.getOrCreateDeviceId();

    final res = await dio.get<List<dynamic>>(
      '/Users/GetAllUsers',
      queryParameters: {..._query(companyId, watermark), 'deviceId': deviceId},
    );
    final rows = res.data ?? const [];

    await db.batch((batch) {
      for (final json in rows.cast<Map<String, dynamic>>()) {
        // Hash-only — never persist a raw `password` field even if the
        // server slips up and sends one. (Plan rule.)
        final hashedPin = json['hashedPin'] as String?;
        final firstName = _nullIfBlank(json['firstName'] as String?);
        final lastName = _nullIfBlank(json['lastName'] as String?);
        final username = _nullIfBlank(json['username'] as String?);
        final displayName = [
          firstName,
          lastName,
        ].whereType<String>().join(' ').trim();

        batch.insert(
          db.usersTable,
          UsersTableCompanion(
            id: Value(json['id'] as int),
            companyId: Value(json['companyId'] as int? ?? companyId),
            name: Value(displayName.isEmpty ? (username ?? '') : displayName),
            firstName: Value(firstName),
            lastName: Value(lastName),
            username: Value(username),
            email: Value(json['email'] as String?),
            pinHash: Value(hashedPin),
            role: Value(json['accessLevel'] as int? ?? 0),
            isEnabled: Value(json['isEnabled'] as bool? ?? true),
            lastModified: Value(_parseLastModified(json['lastModified'])),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _setLastSync(_kUsers, startedAt);
  }

  // ==========================================================================
  // PHASE 3.6 PULLS — ProductGroups, PaymentTypes, Customers, Promotions
  //
  // The 4 endpoints below DON'T currently accept `modifiedAfter` server-side
  // (their entities have LastModified, but the DTOs + controllers haven't
  // been extended like the 6 entities in Phase 0/3.5). Sending the param
  // anyway — ASP.NET silently ignores unknown query params, and the moment
  // the backend adds the filter no Flutter change is required.
  //
  // Until then these are effectively full-table pulls each cycle. Fine for
  // typical sizes (single-digit groups, ~10 payment types, hundreds of
  // customers/promotions); revisit if customer counts blow up.
  // ==========================================================================

  /// Pushes every pending product-group write (create / update / delete) to
  /// the server, then lets the subsequent [pullProductGroups] bring back the
  /// canonical server data (including server-assigned IDs and image URLs).
  Future<void> pushPendingProductGroupOps(int companyId) async {
    final pending =
        await (db.select(db.productGroupsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where((t) => t.syncStatus.isNotIn(['synced'])))
            .get();

    for (final g in pending) {
      try {
        // Re-encode the locally-saved icon so the server can store it.
        String imageBase64 = '';
        if (g.localImagePath != null) {
          try {
            final file = File(g.localImagePath!);
            if (file.existsSync()) {
              imageBase64 = base64Encode(await file.readAsBytes());
            }
          } catch (_) {}
        }

        // A temp (negative) id means the group was created offline and has
        // never existed on the server yet.
        final isTemp = g.id < 0;

        if (g.syncStatus == 'pending_delete') {
          // Nothing on the server to delete for a never-synced row.
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/ProductGroups/Delete',
              queryParameters: {'id': g.id, 'companyId': companyId},
            );
          }
          await (db.delete(
            db.productGroupsTable,
          )..where((t) => t.id.equals(g.id))).go();
          continue;
        }

        // A temp id must ALWAYS be POSTed, even if a later offline edit flipped
        // its status to pending_update — otherwise /ProductGroups/Update 400s
        // forever on an id the server never saw.
        if (isTemp) {
          final res = await dio.post<dynamic>(
            '/ProductGroups/Add',
            queryParameters: {'companyId': companyId},
            data: {
              'name': g.name,
              'parentGroupId': g.parentGroupId,
              'color': g.colorHex,
              'image': imageBase64,
              'rank': g.rank,
            },
          );
          final serverId =
              (res.data is Map ? (res.data as Map)['id'] : null) as int?;
          if (serverId != null) {
            // Rename temp image file to the real server ID.
            String? newPath = g.localImagePath;
            if (newPath != null) {
              try {
                final renamed = newPath.replaceAll(
                  '${g.id}_image',
                  '${serverId}_image',
                );
                await File(newPath).rename(renamed);
                newPath = renamed;
              } catch (_) {}
            }
            await db.transaction(() async {
              await (db.delete(
                db.productGroupsTable,
              )..where((t) => t.id.equals(g.id))).go();
              await db
                  .into(db.productGroupsTable)
                  .insertOnConflictUpdate(
                    ProductGroupsTableCompanion(
                      id: Value(serverId),
                      companyId: Value(g.companyId),
                      name: Value(g.name),
                      parentGroupId: Value(g.parentGroupId),
                      colorHex: Value(g.colorHex),
                      rank: Value(g.rank),
                      localImagePath: Value(newPath),
                      lastModified: Value(DateTime.now().toUtc()),
                      syncStatus: const Value('synced'),
                    ),
                  );
              await db.remapProductGroupId(g.id, serverId);
            });
          }
        } else {
          await dio.patch<dynamic>(
            '/ProductGroups/Update',
            queryParameters: {'companyId': companyId},
            data: {
              'id': g.id,
              'name': g.name,
              'parentGroupId': g.parentGroupId,
              'color': g.colorHex,
              'image': imageBase64,
              'rank': g.rank,
            },
          );
          await (db.update(
            db.productGroupsTable,
          )..where((t) => t.id.equals(g.id))).write(
            const ProductGroupsTableCompanion(syncStatus: Value('synced')),
          );
        }
      } catch (e) {
        if (_isServerRejection(e)) {
          final msg = _serverErrMsg(e);
          // Server rejected it (e.g. duplicate name, group in use). Stop looping:
          //  • delete → un-delete locally (the server still has it).
          //  • create/update → flag sync_failed (keep local data, stop retrying).
          final revert = g.syncStatus == 'pending_delete';
          await (db.update(db.productGroupsTable)
                ..where((t) => t.id.equals(g.id)))
              .write(ProductGroupsTableCompanion(
                syncStatus: Value(revert ? 'synced' : 'sync_failed'),
                syncError: Value(msg),
              ));
          debugPrint(
            'pushPendingProductGroupOps: group ${g.id} (${g.syncStatus}) '
            'rejected — $msg (resolved, won\'t retry)',
          );
        } else {
          debugPrint(
            'pushPendingProductGroupOps: group ${g.id} (${g.syncStatus}) '
            'failed — $e (will retry)',
          );
        }
      }
    }
  }

  Future<void> pullProductGroups(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kProductGroups);

    final res = await dio.get<List<dynamic>>(
      '/ProductGroups/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Sequential image saves + upserts. Can't use db.batch here because the
    // ImageSyncHelper awaits don't compose with batch's sync callback.
    for (final json in rows.cast<Map<String, dynamic>>()) {
      final id = json['id'] as int;

      // Don't overwrite rows that have unsync-ed local edits.
      final existing = await (db.select(
        db.productGroupsTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null && existing.syncStatus != 'synced') continue;

      // Download/decode the group icon. Returns null on null/empty source
      // or any decode/write failure (logged via debugPrint inside the helper).
      final localImagePath = await imageHelper.downloadAndSaveImage(
        json['image'] as String?,
        id,
        folder: 'group_images',
      );
      await db
          .into(db.productGroupsTable)
          .insertOnConflictUpdate(
            ProductGroupsTableCompanion(
              id: Value(id),
              companyId: Value(json['companyId'] as int? ?? companyId),
              name: Value(json['name'] as String? ?? ''),
              parentGroupId: Value(json['parentGroupId'] as int?),
              colorHex: Value(json['color'] as String? ?? 'Transparent'),
              rank: Value(json['rank'] as int? ?? 0),
              localImagePath: Value(localImagePath),
              lastModified: Value(_parseLastModified(json['lastModified'])),
              syncStatus: const Value('synced'),
            ),
          );
    }

    await _setLastSync(_kProductGroups, startedAt);
  }

  /// Drains offline payment-type writes to the server (mirrors pushPendingTaxOps).
  Future<void> pushPendingPaymentTypeOps(int companyId) async {
    final pending =
        await (db.select(db.paymentTypesTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (pending.isEmpty) return;

    for (final p in pending) {
      try {
        final isTemp = p.id < 0;

        if (p.syncStatus == 'pending_delete') {
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/PaymentTypes/Delete',
              queryParameters: {'id': p.id, 'companyId': companyId},
            );
          }
          await (db.delete(
            db.paymentTypesTable,
          )..where((x) => x.id.equals(p.id))).go();
          continue;
        }

        final payload = <String, dynamic>{
          'name': p.name,
          'code': p.code,
          'ordinal': p.ordinal,
          'shortcutKey': p.shortcutKey,
          'isEnabled': p.isEnabled,
          'isQuickPayment': p.isQuickPayment,
          'isCustomerRequired': p.isCustomerRequired,
          'isChangeAllowed': p.isChangeAllowed,
          'markAsPaid': p.markAsPaid,
          'openCashDrawer': p.openCashDrawer,
          'isFiscal': p.isFiscal,
          'isSlipRequired': p.isSlipRequired,
        };

        if (isTemp) {
          final res = await dio.post<dynamic>(
            '/PaymentTypes/Add',
            queryParameters: {'companyId': companyId},
            data: payload,
          );
          final body =
              res.data is Map ? ((res.data as Map)['data'] ?? res.data) : null;
          final realId = (body is Map ? (body['id'] as num?) : null)?.toInt();
          if (realId == null) {
            throw Exception('Server returned no id for payment type create');
          }

          await db.transaction(() async {
            await (db.delete(
              db.paymentTypesTable,
            )..where((x) => x.id.equals(p.id))).go();
            await db.into(db.paymentTypesTable).insert(
              PaymentTypesTableCompanion(
                id: Value(realId),
                companyId: Value(p.companyId),
                name: Value(p.name),
                code: Value(p.code),
                ordinal: Value(p.ordinal),
                shortcutKey: Value(p.shortcutKey),
                isEnabled: Value(p.isEnabled),
                isQuickPayment: Value(p.isQuickPayment),
                isCustomerRequired: Value(p.isCustomerRequired),
                isChangeAllowed: Value(p.isChangeAllowed),
                markAsPaid: Value(p.markAsPaid),
                openCashDrawer: Value(p.openCashDrawer),
                isFiscal: Value(p.isFiscal),
                isSlipRequired: Value(p.isSlipRequired),
                lastModified: Value(DateTime.now().toUtc()),
                syncStatus: const Value('synced'),
              ),
            );
            await db.remapPaymentTypeId(p.id, realId);
          });
        } else {
          await dio.patch<dynamic>(
            '/PaymentTypes/Update',
            queryParameters: {'companyId': companyId},
            data: {'id': p.id, ...payload},
          );
          await (db.update(
            db.paymentTypesTable,
          )..where((x) => x.id.equals(p.id))).write(
            const PaymentTypesTableCompanion(syncStatus: Value('synced')),
          );
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: p.syncStatus,
          logLabel: 'pushPendingPaymentTypeOps: ${p.id} (${p.syncStatus})',
          entityLabel: 'Payment type "${p.name}"',
          apply: (s, _) => (db.update(db.paymentTypesTable)
                ..where((x) => x.id.equals(p.id)))
              .write(PaymentTypesTableCompanion(syncStatus: Value(s))),
        );
      }
    }
  }

  Future<void> pullPaymentTypes(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kPaymentTypes);

    final res = await dio.get<List<dynamic>>(
      '/PaymentTypes/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Local changes win until pushed.
    final pendingIds =
        (await (db.select(db.paymentTypesTable)
                  ..where((t) => t.companyId.equals(companyId))
                  ..where((t) => t.syncStatus.isNotIn(['synced'])))
                .get())
            .map((r) => r.id)
            .toSet();

    await db.batch((batch) {
      for (final json in rows.cast<Map<String, dynamic>>()) {
        final id = json['id'] as int;
        if (pendingIds.contains(id)) continue;
        batch.insert(
          db.paymentTypesTable,
          PaymentTypesTableCompanion(
            id: Value(id),
            companyId: Value(json['companyId'] as int? ?? companyId),
            name: Value(json['name'] as String? ?? ''),
            code: Value(json['code'] as String?),
            isCustomerRequired: Value(
              json['isCustomerRequired'] as bool? ?? false,
            ),
            isFiscal: Value(json['isFiscal'] as bool? ?? false),
            isSlipRequired: Value(json['isSlipRequired'] as bool? ?? false),
            isChangeAllowed: Value(json['isChangeAllowed'] as bool? ?? false),
            ordinal: Value(json['ordinal'] as int? ?? 0),
            isEnabled: Value(json['isEnabled'] as bool? ?? true),
            isQuickPayment: Value(json['isQuickPayment'] as bool? ?? false),
            openCashDrawer: Value(json['openCashDrawer'] as bool? ?? false),
            shortcutKey: Value(json['shortcutKey'] as String?),
            markAsPaid: Value(json['markAsPaid'] as bool? ?? false),
            lastModified: Value(_parseLastModified(json['lastModified'])),
            syncStatus: const Value('synced'),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _setLastSync(_kPaymentTypes, startedAt);
  }

  // ==========================================================================
  // PUSH — pending customer creates / updates / deletes
  // ==========================================================================

  /// Pushes all locally-queued customer mutations to the server:
  ///   • pending_create → POST /Customer/AddCustomercommand (temp negative id → real id)
  ///   • pending_update → PATCH /Customer/UpdateCustomercommand
  ///   • pending_delete → DELETE /Customer/DeleteCustomercommand (then hard-delete locally)
  Future<void> pushPendingCustomerOps(int companyId) async {
    final pending =
        await (db.select(db.customersTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (pending.isEmpty) return;

    for (final c in pending) {
      try {
        switch (c.syncStatus) {
          case 'pending_create':
            final res = await dio.post<dynamic>(
              '/Customer/AddCustomercommand',
              queryParameters: {'companyId': companyId},
              data: {
                'name': c.name,
                'code': c.code,
                'taxNumber': c.taxNumber,
                'address': c.address,
                'postalCode': c.postalCode,
                'city': c.city,
                'countryId': c.countryId ?? 0,
                'email': c.email,
                'phoneNumber': c.phoneNumber,
                'isEnabled': c.isEnabled,
                'isCustomer': c.isCustomer,
                'isSupplier': c.isSupplier,
                'isTaxExempt': c.isTaxExempt,
                'dueDatePeriod': c.dueDatePeriod ?? 0,
                'streetName': c.streetName,
                'additionalStreetName': c.additionalStreetName,
                'buildingNumber': c.buildingNumber,
                'plotIdentification': c.plotIdentification,
                'citySubdivisionName': c.citySubdivisionName,
                // Required by CreateCustomerRequest — omitting them fails
                // deserialization outright (400) before the handler runs. Send the
                // real offline creation time, not the sync time, so a customer
                // created during an outage keeps its true DateCreated.
                'dateCreated': (c.dateCreated ?? c.lastModified)
                    .toUtc()
                    .toIso8601String(),
                'dateUpdated': (c.dateUpdated ?? c.lastModified)
                    .toUtc()
                    .toIso8601String(),
              },
            );
            final data = res.data;
            int realId = 0;
            if (data is int) {
              realId = data;
            } else if (data is Map) {
              realId = ((data['id'] ?? data['Id']) as num?)?.toInt() ?? 0;
            }
            if (realId <= 0) {
              throw Exception('Server returned no id for customer create');
            }

            // Replace temp row with real id; also update any pending discounts
            // that reference the old temp customer id.
            await db.transaction(() async {
              await (db.delete(
                db.customersTable,
              )..where((t) => t.id.equals(c.id))).go();
              await db
                  .into(db.customersTable)
                  .insert(
                    CustomersTableCompanion(
                      id: Value(realId),
                      companyId: Value(c.companyId),
                      name: Value(c.name),
                      code: Value(c.code),
                      taxNumber: Value(c.taxNumber),
                      address: Value(c.address),
                      postalCode: Value(c.postalCode),
                      city: Value(c.city),
                      countryId: Value(c.countryId),
                      email: Value(c.email),
                      phoneNumber: Value(c.phoneNumber),
                      isEnabled: Value(c.isEnabled),
                      isCustomer: Value(c.isCustomer),
                      isSupplier: Value(c.isSupplier),
                      dueDatePeriod: Value(c.dueDatePeriod),
                      streetName: Value(c.streetName),
                      additionalStreetName: Value(c.additionalStreetName),
                      buildingNumber: Value(c.buildingNumber),
                      plotIdentification: Value(c.plotIdentification),
                      citySubdivisionName: Value(c.citySubdivisionName),
                      isTaxExempt: Value(c.isTaxExempt),
                      lastModified: Value(DateTime.now().toUtc()),
                      syncStatus: const Value('synced'),
                    ),
                  );
              // Update any pending discounts that referenced the temp customer id.
              await (db.update(
                db.customerDiscountsTable,
              )..where((t) => t.customerId.equals(c.id))).write(
                CustomerDiscountsTableCompanion(customerId: Value(realId)),
              );
            });

          case 'pending_update':
            await dio.patch<dynamic>(
              '/Customer/UpdateCustomercommand',
              queryParameters: {'companyId': companyId},
              data: {
                'id': c.id,
                'name': c.name,
                'code': c.code,
                'taxNumber': c.taxNumber,
                'address': c.address,
                'postalCode': c.postalCode,
                'city': c.city,
                'countryId': c.countryId ?? 0,
                'email': c.email,
                'phoneNumber': c.phoneNumber,
                'isEnabled': c.isEnabled,
                'isCustomer': c.isCustomer,
                'isSupplier': c.isSupplier,
                'isTaxExempt': c.isTaxExempt,
                'dueDatePeriod': c.dueDatePeriod ?? 0,
                'streetName': c.streetName,
                'additionalStreetName': c.additionalStreetName,
                'buildingNumber': c.buildingNumber,
                'plotIdentification': c.plotIdentification,
                'citySubdivisionName': c.citySubdivisionName,
              },
            );
            await (db.update(
              db.customersTable,
            )..where((t) => t.id.equals(c.id))).write(
              const CustomersTableCompanion(
                syncStatus: Value('synced'),
                syncError: Value(null),
              ),
            );

          case 'pending_delete':
            await dio.delete<dynamic>(
              '/Customer/DeleteCustomercommand',
              queryParameters: {'id': c.id, 'companyId': companyId},
            );
            await (db.delete(
              db.customerDiscountsTable,
            )..where((t) => t.customerId.equals(c.id))).go();
            await (db.delete(
              db.customersTable,
            )..where((t) => t.id.equals(c.id))).go();
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: c.syncStatus,
          logLabel: 'pushPendingCustomerOps: customer ${c.id} (${c.syncStatus})',
          entityLabel: 'Customer "${c.name}"',
          apply: (s, msg) =>
              (db.update(db.customersTable)..where((t) => t.id.equals(c.id)))
                  .write(CustomersTableCompanion(
                      syncStatus: Value(s), syncError: Value(msg))),
        );
      }
    }
  }

  /// Pushes all locally-queued customer-discount mutations to the server.
  /// Skips discounts with a negative (temp) customerId — those belong to
  /// customers that haven't been synced yet; [pushPendingCustomerOps] resolves
  /// the real customerId first, so the next sync cycle picks these up.
  Future<void> pushPendingCustomerDiscountOps(int companyId) async {
    final pending =
        await (db.select(db.customerDiscountsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (pending.isEmpty) return;

    for (final d in pending) {
      // Skip if the parent customer hasn't been synced yet (temp negative id).
      if (d.customerId < 0) continue;

      try {
        switch (d.syncStatus) {
          case 'pending_create':
            final res = await dio.post<dynamic>(
              // Backend route is [HttpPost("Add")] — NOT "Create" (that 404s).
              '/CustomerDiscounts/Add',
              queryParameters: {'companyId': companyId},
              data: {
                'customerId': d.customerId,
                'type': d.type,
                'uid': d.uid,
                'value': d.value,
              },
            );
            final data = res.data;
            int realId = 0;
            if (data is Map) {
              realId = ((data['id'] ?? data['Id']) as num?)?.toInt() ?? 0;
            }
            await db.transaction(() async {
              await (db.delete(
                db.customerDiscountsTable,
              )..where((t) => t.id.equals(d.id))).go();
              if (realId > 0) {
                await db
                    .into(db.customerDiscountsTable)
                    .insert(
                      CustomerDiscountsTableCompanion(
                        id: Value(realId),
                        companyId: Value(d.companyId),
                        customerId: Value(d.customerId),
                        type: Value(d.type),
                        uid: Value(d.uid),
                        value: Value(d.value),
                        lastModified: Value(DateTime.now().toUtc()),
                        syncStatus: const Value('synced'),
                      ),
                    );
              }
            });

          case 'pending_update':
            await dio.patch<dynamic>(
              '/CustomerDiscounts/Update',
              queryParameters: {'companyId': companyId},
              data: {'id': d.id, 'type': d.type, 'value': d.value},
            );
            await (db.update(
              db.customerDiscountsTable,
            )..where((t) => t.id.equals(d.id))).write(
              const CustomerDiscountsTableCompanion(
                syncStatus: Value('synced'),
                syncError: Value(null),
              ),
            );

          case 'pending_delete':
            if (d.id > 0) {
              await dio.delete<dynamic>(
                '/CustomerDiscounts/Delete',
                queryParameters: {'id': d.id, 'companyId': companyId},
              );
            }
            await (db.delete(
              db.customerDiscountsTable,
            )..where((t) => t.id.equals(d.id))).go();
        }
      } catch (e) {
        debugPrint(
          'pushPendingCustomerDiscountOps: discount ${d.id} (${d.syncStatus}) failed — $e',
        );
        try {
          await (db.update(
            db.customerDiscountsTable,
          )..where((t) => t.id.equals(d.id))).write(
            CustomerDiscountsTableCompanion(syncError: Value(e.toString())),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> pullCustomers(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kCustomers);

    // Existing route is /Customer/GetAllCustomers (singular controller).
    final res = await dio.get<List<dynamic>>(
      '/Customer/GetAllCustomers',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Loop individually to protect rows with pending local edits from being
    // overwritten by stale server data. Same pattern as pullProductGroups.
    for (final json in rows.cast<Map<String, dynamic>>()) {
      final id = json['id'] as int;
      final existing = await (db.select(
        db.customersTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null && existing.syncStatus != 'synced') continue;

      await db
          .into(db.customersTable)
          .insertOnConflictUpdate(
            CustomersTableCompanion(
              id: Value(id),
              companyId: Value(json['companyId'] as int? ?? companyId),
              code: Value(json['code'] as String?),
              name: Value(json['name'] as String? ?? 'Unknown'),
              taxNumber: Value(json['taxNumber'] as String?),
              address: Value(json['address'] as String?),
              postalCode: Value(json['postalCode'] as String?),
              city: Value(json['city'] as String?),
              countryId: Value(json['countryId'] as int?),
              email: Value(json['email'] as String?),
              phoneNumber: Value(json['phoneNumber'] as String?),
              isEnabled: Value(json['isEnabled'] as bool? ?? true),
              isCustomer: Value(json['isCustomer'] as bool? ?? true),
              isSupplier: Value(json['isSupplier'] as bool? ?? false),
              dueDatePeriod: Value(json['dueDatePeriod'] as int?),
              streetName: Value(json['streetName'] as String?),
              additionalStreetName: Value(
                json['additionalStreetName'] as String?,
              ),
              buildingNumber: Value(json['buildingNumber'] as String?),
              plotIdentification: Value(json['plotIdentification'] as String?),
              citySubdivisionName: Value(
                json['citySubdivisionName'] as String?,
              ),
              isTaxExempt: Value(json['isTaxExempt'] as bool? ?? false),
              lastModified: Value(_parseLastModified(json['lastModified'])),
              syncStatus: const Value('synced'),
            ),
          );
    }

    await _setLastSync(_kCustomers, startedAt);
  }

  /// Single-row pull: fetches the active company via `/Company/GetById`,
  /// writes the logo to disk via ImageSyncHelper, and upserts the lean
  /// row into `companies`. No `modifiedAfter` watermark — single tiny
  /// record, cheaper to re-fetch each sync than to track timestamps.
  /// Pushes an offline company field edit (update-only). The logo is handled by
  /// the online upload path, so it's not touched here.
  Future<void> pushPendingCompanyOps(int companyId) async {
    final pending =
        await (db.select(db.companiesTable)
              ..where((t) => t.id.equals(companyId))
              ..where((t) => t.syncStatus.equals('pending_update')))
            .getSingleOrNull();
    if (pending == null) return;

    try {
      await dio.patch<dynamic>(
        '/Company/Update',
        data: {
          'id': pending.id,
          'name': pending.name,
          'countryId': pending.countryId,
          'taxNumber': pending.taxNumber,
          'streetName': pending.streetName,
          'buildingNumber': pending.buildingNumber,
          'additionalStreetName': pending.additionalStreetName,
          'plotIdentification': pending.plotIdentification,
          'citySubdivisionName': pending.citySubdivisionName,
          'countrySubentity': pending.countrySubentity,
          'postalCode': pending.postalCode,
          'city': pending.city,
          'email': pending.email,
          'phoneNumber': pending.phone,
          'bankAccountNumber': pending.bankAccountNumber,
          'bankDetails': pending.bankDetails,
        },
      );
      await (db.update(db.companiesTable)..where((t) => t.id.equals(companyId)))
          .write(const CompaniesTableCompanion(syncStatus: Value('synced')));
    } catch (e) {
      await _resolveRejection(
        error: e,
        syncStatus: pending.syncStatus,
        logLabel: 'pushPendingCompanyOps: $companyId',
        apply: (s, _) =>
            (db.update(db.companiesTable)..where((t) => t.id.equals(companyId)))
                .write(CompaniesTableCompanion(syncStatus: Value(s))),
      );
    }
  }

  Future<void> pullCompany(int companyId) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/Company/GetById',
      queryParameters: {'id': companyId},
    );
    final json = res.data;
    if (json == null) return;

    // Don't clobber a locally-edited (pending_update) company row — local wins
    // until pushPendingCompanyOps has pushed it.
    final existing = await (db.select(db.companiesTable)
          ..where((t) => t.id.equals(companyId)))
        .getSingleOrNull();
    if (existing != null && existing.syncStatus != 'synced') return;

    // The C# API serves the logo as a base64 string under `logo`. Write
    // it to disk under company_logos/ and store only the path in Drift.
    // Disk write is best-effort — a missing logo never blocks the upsert.
    final localLogoPath = await imageHelper.downloadAndSaveImage(
      json['logo'] as String?,
      json['id'] as int? ?? companyId,
      folder: 'company_logos',
    );

    await db
        .into(db.companiesTable)
        .insertOnConflictUpdate(
          CompaniesTableCompanion(
            id: Value(json['id'] as int? ?? companyId),
            name: Value(json['name'] as String? ?? ''),
            taxNumber: Value(json['taxNumber'] as String?),
            address: Value(json['address'] as String?),
            phone: Value(json['phoneNumber'] as String?),
            // Full field set so the My Company editor works offline.
            countryId: Value(json['countryId'] as int?),
            postalCode: Value(json['postalCode'] as String?),
            city: Value(json['city'] as String?),
            email: Value(json['email'] as String?),
            bankAccountNumber: Value(json['bankAccountNumber'] as String?),
            bankDetails: Value(json['bankDetails'] as String?),
            streetName: Value(json['streetName'] as String?),
            additionalStreetName:
                Value(json['additionalStreetName'] as String?),
            buildingNumber: Value(json['buildingNumber'] as String?),
            plotIdentification: Value(json['plotIdentification'] as String?),
            citySubdivisionName: Value(json['citySubdivisionName'] as String?),
            countrySubentity: Value(json['countrySubentity'] as String?),
            localLogoPath: Value(localLogoPath),
            lastModified: Value(_parseLastModified(json['lastModified'])),
            syncStatus: const Value('synced'),
          ),
        );
  }

  /// Pulls all stock records for [companyId] and upserts them into the local
  /// `stocks` table. No delta watermark — the full list is small enough
  /// (~products × warehouses rows) that a full replace is cheapest.
  /// Must run AFTER pushes so local quantities reflect server-side deductions.
  Future<void> pullStocks(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/Stocks/GetAllStocks',
      queryParameters: {'companyId': companyId},
    );
    final rows = res.data;
    if (rows == null) return;

    final now = DateTime.now().toUtc();
    final serverIds = <int>{};

    for (final m in rows.cast<Map<String, dynamic>>()) {
      final id = m['id'] as int;
      serverIds.add(id);
      // Don't clobber a row that has unsynced local edits.
      final existing = await (db.select(db.stocksTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (existing != null && existing.syncStatus != 'synced') continue;
      await db.into(db.stocksTable).insertOnConflictUpdate(StocksTableCompanion(
        id: Value(id),
        productId: Value(m['productId'] as int),
        warehouseId: Value(m['warehouseId'] as int),
        companyId: Value(m['companyId'] as int? ?? companyId),
        quantity: Value(((m['quantity'] ?? 0) as num).toDouble()),
        lastModified: Value(now),
        syncStatus: const Value('synced'),
      ));
    }

    // Drop synced server rows deleted elsewhere; keep local pending/temp rows.
    final localSynced = await (db.select(db.stocksTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.syncStatus.equals('synced'))
          ..where((t) => t.id.isBiggerThanValue(0)))
        .get();
    for (final s in localSynced) {
      if (!serverIds.contains(s.id)) {
        await (db.delete(db.stocksTable)..where((t) => t.id.equals(s.id))).go();
      }
    }
  }

  // ==========================================================================
  // PUSH — offline stock CRUD (add / update / delete quantities).
  // ==========================================================================
  Future<void> pushPendingStocks(int companyId) async {
    for (final s in await db.getStocksBySyncStatus(companyId, 'pending_create')) {
      try {
        final res = await dio.post<dynamic>(
          '/Stocks/Add',
          queryParameters: {'companyId': companyId},
          data: {
            'productId': s.productId,
            'warehouseId': s.warehouseId,
            'quantity': s.quantity,
          },
        );
        final newId = _parseDocServerId(res.data);
        if (newId != null) {
          await db.replaceStockTempId(s.id, newId);
        } else {
          // Server didn't echo an id — drop the temp row; pullStocks re-adds
          // the authoritative one.
          await db.hardDeleteStock(s.id);
        }
      } catch (e) {
        debugPrint('pushPendingStocks (add) ${s.id} failed — $e');
      }
    }

    for (final s in await db.getStocksBySyncStatus(companyId, 'pending_update')) {
      if (s.id < 0) continue;
      try {
        await dio.patch<dynamic>(
          '/Stocks/Update',
          queryParameters: {'companyId': companyId},
          data: {
            'id': s.id,
            'newProductId': s.productId,
            'newWarehouseId': s.warehouseId,
            'newQuantity': s.quantity,
          },
        );
        await db.markStockSynced(s.id);
      } catch (e) {
        debugPrint('pushPendingStocks (update) ${s.id} failed — $e');
      }
    }

    for (final s in await db.getStocksBySyncStatus(companyId, 'pending_delete')) {
      try {
        if (s.id > 0) {
          await dio.delete<dynamic>(
            '/Stocks/Delete',
            queryParameters: {'id': s.id, 'companyId': companyId},
          );
        }
        await db.hardDeleteStock(s.id);
      } catch (e) {
        debugPrint('pushPendingStocks (delete) ${s.id} failed — $e');
      }
    }
  }

  // ==========================================================================
  // STOCK CONTROLS — offline-first pull + CRUD push.
  // ==========================================================================
  Future<void> pullStockControls(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/StockControls/GetAll',
      queryParameters: {'companyId': companyId},
    );
    final rows = res.data;
    if (rows == null) return;

    final now = DateTime.now().toUtc();
    final serverProductIds = <int>{};
    for (final j in rows.cast<Map<String, dynamic>>()) {
      final productId = (j['productId'] as num?)?.toInt() ?? 0;
      serverProductIds.add(productId);
      await db.upsertSyncedStockControl(StockControlsTableCompanion(
        productId: Value(productId),
        companyId: Value(companyId),
        serverId: Value((j['id'] as num?)?.toInt()),
        reorderPoint: Value((j['reorderPoint'] as num?)?.toDouble() ?? 0),
        preferredQuantity: Value((j['preferredQuantity'] as num?)?.toDouble() ?? 0),
        isLowStockWarningEnabled:
            Value(j['isLowStockWarningEnabled'] as bool? ?? true),
        lowStockWarningQuantity:
            Value((j['lowStockWarningQuantity'] as num?)?.toDouble() ?? 0),
        lastModified: Value(now),
        syncStatus: const Value('synced'),
      ));
    }

    // Drop synced rules deleted elsewhere; keep local pending edits.
    for (final sc in await db.getStockControlsBySyncStatus(companyId, 'synced')) {
      if (!serverProductIds.contains(sc.productId)) {
        await db.hardDeleteStockControl(sc.productId);
      }
    }
  }

  Future<void> pushPendingStockControls(int companyId) async {
    for (final sc
        in await db.getStockControlsBySyncStatus(companyId, 'pending_create')) {
      try {
        await dio.post<dynamic>(
          '/StockControls/Add',
          queryParameters: {'companyId': companyId},
          data: {
            'productId': sc.productId,
            'reorderPoint': sc.reorderPoint,
            'preferredQuantity': sc.preferredQuantity,
            'isLowStockWarningEnabled': sc.isLowStockWarningEnabled,
            'lowStockWarningQuantity': sc.lowStockWarningQuantity,
            if (sc.customerId != null) 'customerId': sc.customerId,
          },
        );
        // Add doesn't echo the id — fetch it so future edits/deletes can target
        // the server row.
        int? newId;
        try {
          final g = await dio.get<dynamic>(
            '/StockControls/GetByProductId',
            queryParameters: {'productId': sc.productId, 'companyId': companyId},
          );
          if (g.data is Map) newId = (g.data['id'] as num?)?.toInt();
        } catch (_) {}
        await db.markStockControlSynced(sc.productId, newId);
      } catch (e) {
        debugPrint('pushPendingStockControls (add) ${sc.productId} failed — $e');
      }
    }

    for (final sc
        in await db.getStockControlsBySyncStatus(companyId, 'pending_update')) {
      if (sc.serverId == null) continue;
      try {
        await dio.patch<dynamic>(
          '/StockControls/Update',
          queryParameters: {'companyId': companyId},
          data: {
            'id': sc.serverId,
            'reorderPoint': sc.reorderPoint,
            'preferredQuantity': sc.preferredQuantity,
            'isLowStockWarningEnabled': sc.isLowStockWarningEnabled,
            'lowStockWarningQuantity': sc.lowStockWarningQuantity,
            if (sc.customerId != null) 'customerId': sc.customerId,
          },
        );
        await db.markStockControlSynced(sc.productId, sc.serverId);
      } catch (e) {
        debugPrint(
            'pushPendingStockControls (update) ${sc.productId} failed — $e');
      }
    }

    for (final sc
        in await db.getStockControlsBySyncStatus(companyId, 'pending_delete')) {
      try {
        if (sc.serverId != null) {
          await dio.delete<dynamic>(
            '/StockControls/Delete',
            queryParameters: {'id': sc.serverId, 'companyId': companyId},
          );
        }
        await db.hardDeleteStockControl(sc.productId);
      } catch (e) {
        debugPrint(
            'pushPendingStockControls (delete) ${sc.productId} failed — $e');
      }
    }
  }

  // ==========================================================================
  // WAREHOUSES — offline-first pull + CRUD push.
  // ==========================================================================

  Future<void> pullWarehouses(int companyId) async {
    final res = await dio.get<List<dynamic>>(
      '/Warehouses/GetAll',
      queryParameters: {'companyId': companyId},
    );
    final rows = res.data ?? const [];
    final now = DateTime.now().toUtc();
    final serverIds = <int>{};

    for (final j in rows.cast<Map<String, dynamic>>()) {
      final id = j['id'] as int;
      serverIds.add(id);
      // Don't clobber a row that has unsynced local edits.
      final existing = await (db.select(db.warehousesTable)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (existing != null && existing.syncStatus != 'synced') continue;
      await db.into(db.warehousesTable).insertOnConflictUpdate(
            WarehousesTableCompanion(
              id: Value(id),
              companyId: Value(j['companyId'] as int? ?? companyId),
              name: Value(j['name'] as String? ?? ''),
              lastModified: Value(now),
              syncStatus: const Value('synced'),
            ),
          );
    }

    // Drop synced server rows that no longer exist on the server (deleted on
    // another device). Local pending rows (negative ids / non-'synced') are
    // preserved so an offline edit is never lost.
    final localSynced = await (db.select(db.warehousesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.syncStatus.equals('synced'))
          ..where((t) => t.id.isBiggerThanValue(0)))
        .get();
    for (final w in localSynced) {
      if (!serverIds.contains(w.id)) {
        await (db.delete(db.warehousesTable)..where((t) => t.id.equals(w.id)))
            .go();
      }
    }
  }

  /// Pushes locally-queued warehouse CRUD. Split into two phases by
  /// [deletePhase] so the caller can sequence creates/updates BEFORE the stock
  /// ops and deletes AFTER them (see `sync`).
  Future<void> pushPendingWarehouseOps(int companyId,
      {required bool deletePhase}) async {
    final statuses = deletePhase
        ? ['pending_delete']
        : ['pending_create', 'pending_update'];
    final pending = await (db.select(db.warehousesTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.syncStatus.isIn(statuses)))
        .get();

    for (final w in pending) {
      try {
        switch (w.syncStatus) {
          case 'pending_create':
            final res = await dio.post<dynamic>(
              '/Warehouses/Add',
              queryParameters: {'companyId': companyId},
              data: {'name': w.name},
            );
            final data = res.data;
            final realId = data is Map
                ? ((data['id'] ?? data['Id']) as num?)?.toInt()
                : null;
            if (realId == null) {
              throw Exception('Server returned no id for warehouse create');
            }
            await db.transaction(() async {
              await (db.delete(db.warehousesTable)
                    ..where((t) => t.id.equals(w.id)))
                  .go();
              await db.into(db.warehousesTable).insertOnConflictUpdate(
                    WarehousesTableCompanion(
                      id: Value(realId),
                      companyId: Value(w.companyId),
                      name: Value(w.name),
                      lastModified: Value(DateTime.now().toUtc()),
                      syncStatus: const Value('synced'),
                    ),
                  );
              // Repoint any queued stock "move" that targeted the temp id.
              await (db.update(db.pendingStockOpsTable)
                    ..where((t) => t.targetWarehouseId.equals(w.id)))
                  .write(PendingStockOpsTableCompanion(
                      targetWarehouseId: Value(realId)));
            });

          case 'pending_update':
            await dio.patch<dynamic>(
              '/Warehouses/Update',
              queryParameters: {'companyId': companyId},
              data: {'id': w.id, 'name': w.name},
            );
            await (db.update(db.warehousesTable)
                  ..where((t) => t.id.equals(w.id)))
                .write(const WarehousesTableCompanion(
              syncStatus: Value('synced'),
              syncError: Value(null),
            ));

          case 'pending_delete':
            if (w.id > 0) {
              await dio.delete<dynamic>(
                '/Warehouses/Delete',
                queryParameters: {'id': w.id, 'companyId': companyId},
              );
            }
            await (db.delete(db.warehousesTable)
                  ..where((t) => t.id.equals(w.id)))
                .go();
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: w.syncStatus,
          logLabel: 'pushPendingWarehouseOps: ${w.id} (${w.syncStatus})',
          entityLabel: 'Warehouse "${w.name}"',
          apply: (s, msg) =>
              (db.update(db.warehousesTable)..where((t) => t.id.equals(w.id)))
                  .write(WarehousesTableCompanion(
                      syncStatus: Value(s), syncError: Value(msg))),
        );
      }
    }
  }

  /// Drains the stock revoke/move queue created when a warehouse with stock is
  /// deleted offline. Runs AFTER warehouse creates (so a move target exists)
  /// and BEFORE warehouse deletes (so the warehouse is empty first).
  Future<void> pushPendingStockOps(int companyId) async {
    final ops = await (db.select(db.pendingStockOpsTable)
          ..where((t) => t.companyId.equals(companyId)))
        .get();

    for (final op in ops) {
      // A move whose target is still a temp (negative) id can't be pushed yet —
      // its warehouse/product create hasn't synced (remapProductId repoints the
      // productId once the product lands). Leave it for the next cycle.
      if (op.operation == 'move' &&
          ((op.targetWarehouseId == null || op.targetWarehouseId! < 0) ||
              (op.productId != null && op.productId! < 0))) {
        continue;
      }
      try {
        if (op.operation == 'delete') {
          await dio.delete<dynamic>(
            '/Stocks/Delete',
            queryParameters: {'id': op.stockId, 'companyId': companyId},
          );
        } else {
          await dio.patch<dynamic>(
            '/Stocks/Update',
            queryParameters: {'companyId': companyId},
            data: {
              'id': op.stockId,
              'newQuantity': op.quantity ?? 0,
              'newWarehouseId': op.targetWarehouseId,
              'newProductId': op.productId,
            },
          );
        }
        await (db.delete(db.pendingStockOpsTable)
              ..where((t) => t.id.equals(op.id)))
            .go();
      } on DioException catch (e) {
        // Already gone on the server — drop the op so it doesn't block deletes.
        if (e.response?.statusCode == 404) {
          await (db.delete(db.pendingStockOpsTable)
                ..where((t) => t.id.equals(op.id)))
              .go();
        } else {
          debugPrint('pushPendingStockOps: ${op.id} failed — $e');
        }
      } catch (e) {
        debugPrint('pushPendingStockOps: ${op.id} failed — $e');
      }
    }
  }

  // ==========================================================================
  // PULL — today's cash movements from /StartingCash/GetByDateRange
  // ==========================================================================

  /// Pulls today's StartingCash rows for [companyId] and inserts any that the
  /// local DB doesn't already know about (by server `id`), so the Cash In/Out
  /// list shows movements from every till even offline. Runs AFTER
  /// pushPendingCashMovements so locally-created rows already carry their
  /// serverId and are skipped here (no duplicates).
  Future<void> pullStartingCash(int companyId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    final List<dynamic>? rows;
    try {
      final res = await dio.get<List<dynamic>>(
        '/StartingCash/GetByDateRange',
        queryParameters: {
          'companyId': companyId,
          'startDate': start.toIso8601String(),
          'endDate': start.toIso8601String(),
        },
      );
      rows = res.data;
    } catch (e) {
      debugPrint('pullStartingCash failed: $e — local cash preserved.');
      return;
    }
    if (rows == null || rows.isEmpty) return;

    final known = await db.getStartingCashFinalizationByServerId();
    final toInsert = <StartingCashTableCompanion>[];
    final toFinalize = <int, int>{}; // serverId → zReportNumber
    for (final raw in rows) {
      final m = raw as Map<String, dynamic>;
      final serverId = m['id'] as int?;
      if (serverId == null) continue;
      final zReportNumber = m['zReportNumber'] as int?;

      if (known.containsKey(serverId)) {
        // Already local — the only meaningful change is finalization: the
        // server just stamped a Z-report number on a previously-open row.
        final alreadyFinalized = known[serverId]!;
        if (!alreadyFinalized && zReportNumber != null) {
          toFinalize[serverId] = zReportNumber;
        }
        continue;
      }

      // Map server fields → local schema: StartingCashType 0/1 → 'in'/'out',
      // Description → note, DateCreated → createdAt, ZReportNumber → zReportNumber.
      final type = (m['startingCashType'] as int? ?? 0) == 1 ? 'out' : 'in';
      toInsert.add(StartingCashTableCompanion.insert(
        localId: const Uuid().v4(),
        companyId: (m['companyId'] as int?) ?? companyId,
        userId: m['userId'] as int,
        amount: (m['amount'] as num).toDouble(),
        type: type,
        note: Value(m['description'] as String?),
        createdAt: DateTime.parse(m['dateCreated'] as String),
        zReportNumber: Value(zReportNumber),
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ));
    }

    await db.insertSyncedStartingCash(toInsert);
    await db.applyStartingCashZReportNumbers(toFinalize);
  }

  // ==========================================================================
  // PUSH — Manual document editor headers (create / update / delete).
  // pending_create → POST /Document/Add (stamps the server id + links),
  // pending_update → PATCH /Document/Update, pending_delete → DELETE then
  // remove the local row. Line items are pushed separately so the document
  // always has a server id first.
  // ==========================================================================
  // Drains offline refunds straight from Drift — the refund outbox now lives in
  // the DB (no shared_preferences queue), so a refund survives a device
  // backup/restore and syncs like every other entity. A refund is a local
  // Document (document_type_id 4, syncStatus `pending`) whose items + payment we
  // rebuild the /Document/Refund payload from. The server keeps
  // clientDocumentNumber verbatim and dedups on it (ProcessRefundCommand), so a
  // re-push after an ambiguous failure is idempotent — never a second refund.
  Future<void> pushPendingRefundOps(int companyId) async {
    const refundTypeId = 4; // DocumentTypeConstants.Refund
    final pending = await (db.select(db.documentsTable)
          ..where((t) => t.companyId.equals(companyId))
          ..where((t) => t.documentTypeId.equals(refundTypeId))
          ..where((t) => t.syncStatus.equals(SyncStatuses.pending)))
        .get();

    for (final doc in pending) {
      try {
        final items = await (db.select(db.documentItemsTable)
              ..where((t) => t.documentId.equals(doc.localId)))
            .get();
        final payment = await (db.select(db.paymentsTable)
              ..where((t) => t.documentId.equals(doc.localId))
              ..limit(1))
            .getSingleOrNull();
        // Can't rebuild a refund with no payment row — skip (defensive).
        if (payment == null) continue;

        final payload = <String, dynamic>{
          'originalDocumentNumber': doc.referenceDocumentNumber ?? '',
          'refundPaymentTypeId': payment.paymentTypeId,
          'warehouseId': doc.warehouseId,
          // Quantities/totals are stored negative locally; the API wants positives.
          'items': items
              .map((it) => {
                    'productId': it.productId,
                    'quantity': it.quantity.abs(),
                    'price': it.unitPrice,
                  })
              .toList(),
          'isBlind': doc.isBlind,
          if (doc.approvedByUserId != null)
            'approvedByUserId': doc.approvedByUserId,
          // Kept verbatim by the server so the offline number never changes.
          'clientDocumentNumber': doc.number,
        };

        await dio.post<dynamic>(
          '/Document/Refund',
          queryParameters: {'companyId': companyId, 'userId': doc.userId},
          data: payload,
        );

        // Flip the document + its items + its payment to synced. pullDocuments
        // reconciles server ids by (device-local) number afterward.
        await db.transaction(() async {
          await (db.update(db.documentsTable)
                ..where((t) => t.localId.equals(doc.localId)))
              .write(DocumentsTableCompanion(
            syncStatus: const Value(SyncStatuses.synced),
            lastModified: Value(DateTime.now().toUtc()),
          ));
          await (db.update(db.documentItemsTable)
                ..where((t) => t.documentId.equals(doc.localId)))
              .write(const DocumentItemsTableCompanion(
                  syncStatus: Value(SyncStatuses.synced)));
          await (db.update(db.paymentsTable)
                ..where((t) => t.documentId.equals(doc.localId)))
              .write(const PaymentsTableCompanion(
                  syncStatus: Value(SyncStatuses.synced)));
        });
      } catch (e) {
        // 4xx (definitive rejection) or transient (offline/5xx): leave it pending;
        // it shows on the Documents screen and retries next sync (idempotent).
        debugPrint('pushPendingRefundOps: ${doc.localId} failed — $e');
      }
    }
  }

  // Drains MANUALLY created/edited/deleted documents (the document editor).
  // By design this only handles pending_create/update/delete and NEVER
  // [SyncStatuses.pending]: checkout & refund documents use `pending` and are
  // created server-side via the BatchSync / Refund command path, so pushing them
  // here too would double-create them. See [SyncStatuses] for the full invariant.
  Future<void> pushPendingDocuments(int companyId) async {
    // ── Deletes ────────────────────────────────────────────────────────────
    for (final doc in await db.getDocumentsBySyncStatus(
        companyId, SyncStatuses.pendingDelete)) {
      try {
        if (doc.serverId != null) {
          await dio.delete<dynamic>(
            '/Document/Delete',
            queryParameters: {'id': doc.serverId, 'companyId': companyId},
          );
        }
        await (db.delete(db.documentsTable)
              ..where((t) => t.localId.equals(doc.localId)))
            .go();
      } catch (e) {
        debugPrint('pushPendingDocuments (delete) ${doc.localId} failed — $e');
      }
    }

    // ── Creates ────────────────────────────────────────────────────────────
    for (final doc in await db.getDocumentsBySyncStatus(
        companyId, SyncStatuses.pendingCreate)) {
      try {
        final res = await dio.post<dynamic>(
          '/Document/Add',
          queryParameters: {'companyId': companyId},
          data: _documentAddJson(doc),
        );
        final serverId = _parseDocServerId(res.data);
        if (serverId == null) continue; // retry next sync
        await db.linkDocumentToServer(doc.localId, serverId);
      } catch (e) {
        debugPrint('pushPendingDocuments (create) ${doc.localId} failed — $e');
      }
    }

    // ── Header updates ─────────────────────────────────────────────────────
    for (final doc in await db.getDocumentsBySyncStatus(
        companyId, SyncStatuses.pendingUpdate)) {
      if (doc.serverId == null) continue;
      try {
        await dio.patch<dynamic>(
          '/Document/Update',
          queryParameters: {'companyId': companyId},
          data: _documentUpdateJson(doc),
        );
        await (db.update(db.documentsTable)
              ..where((t) => t.localId.equals(doc.localId)))
            .write(const DocumentsTableCompanion(syncStatus: Value('synced')));
      } catch (e) {
        debugPrint('pushPendingDocuments (update) ${doc.localId} failed — $e');
      }
    }
  }

  Map<String, dynamic> _documentAddJson(DocumentsTableData d) => {
        'number': d.number,
        'userId': d.userId,
        'customerId': d.customerId,
        'orderNumber': d.orderNumber,
        'date': d.date.toIso8601String(),
        'stockDate': (d.stockDate ?? d.date).toIso8601String(),
        'dueDate': (d.dueDate ?? d.date).toIso8601String(),
        'total': d.total,
        'isClockedOut': true,
        'documentTypeId': d.documentTypeId,
        'warehouseId': d.warehouseId,
        'internalNote': d.internalNote ?? '',
        'note': d.note ?? '',
        'referenceDocumentNumber': d.referenceDocumentNumber ?? '',
        'discount': d.discount,
        'discountType': d.discountType,
        'paidStatus': d.paidStatus,
        'discountApplyRule': d.discountApplyRule,
        'serviceType': d.serviceType,
      };

  Map<String, dynamic> _documentUpdateJson(DocumentsTableData d) => {
        'id': d.serverId,
        'number': d.number,
        'customerId': d.customerId,
        'userId': d.userId,
        'date': d.date.toIso8601String(),
        'stockDate': (d.stockDate ?? d.date).toIso8601String(),
        'dueDate': (d.dueDate ?? d.date).toIso8601String(),
        'documentTypeId': d.documentTypeId,
        'warehouseId': d.warehouseId,
        'internalNote': d.internalNote ?? '',
        'note': d.note ?? '',
        'referenceDocumentNumber': d.referenceDocumentNumber ?? '',
        'discount': d.discount,
        'discountType': d.discountType,
        'discountApplyRule': d.discountApplyRule,
        'total': d.total,
        'paidStatus': d.paidStatus,
      };

  int? _parseDocServerId(dynamic body) {
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    if (data is Map) {
      return int.tryParse(
          data['id']?.toString() ?? data['Id']?.toString() ?? '');
    }
    if (data is num) return data.toInt();
    return null;
  }

  // ==========================================================================
  // PUSH — Manual document line items (create / update / delete). Items are
  // keyed to their parent by document localId; a create is skipped until its
  // document has a server id. Tax + expiration attachments ride along on create.
  // ==========================================================================
  Future<void> pushPendingDocumentItems(int companyId) async {
    // ── Creates ────────────────────────────────────────────────────────────
    for (final it in await db.getDocumentItemsBySyncStatus('pending_create')) {
      final doc = await db.getDocumentByLocalId(it.documentId);
      final docServerId = doc?.serverId;
      if (docServerId == null) continue;

      // Step 1: create the line item. This is the ONLY stock-affecting call —
      // the server adjusts inventory in DocumentItemService.CreateAsync (keyed on
      // the document type), NOT via a DB trigger (there is no stock trigger). If
      // it throws, the item was not created — leave it pending and retry next sync.
      final int? itemServerId;
      try {
        final res = await dio.post<dynamic>(
          '/DocumentItems/Add',
          queryParameters: {'companyId': companyId},
          data: {
            'documentId': docServerId,
            'productId': it.productId,
            'quantity': it.quantity,
            'expectedQuantity': it.quantity,
            'priceBeforeTax': it.priceBeforeTax,
            'price': it.unitPrice,
            'discount': it.discount,
            'discountType': it.discountType,
            'discountApplyRule': true,
          },
        );
        itemServerId = _parseDocServerId(res.data);
      } catch (e) {
        debugPrint('pushPendingDocumentItems (create) ${it.localId} failed — $e');
        continue;
      }

      // Step 2: the item now exists server-side (stock already adjusted), so
      // mark it synced IMMEDIATELY. Critical: a failure in the best-effort tax /
      // expiration attachments below must never leave it 'pending_create',
      // otherwise the next sync re-creates the item and re-runs the server-side
      // stock adjustment — the cause of the "+N every sync" inventory drift.
      await db.markDocumentItemSynced(it.localId, itemServerId);

      // Step 3: best-effort attachments — isolated so neither can re-create the
      // item. Past expiration dates are skipped (the server rejects them with
      // "Expiration date cannot be in the past").
      if (itemServerId != null && it.taxId != null) {
        try {
          await dio.post<dynamic>(
            '/DocumentItemTaxes/Add',
            queryParameters: {'companyId': companyId},
            data: {'documentItemId': itemServerId, 'taxId': it.taxId},
          );
        } catch (e) {
          debugPrint('pushPendingDocumentItems (tax) ${it.localId} failed — $e');
        }
      }
      if (itemServerId != null &&
          it.expirationDate != null &&
          it.expirationDate!.isAfter(DateTime.now())) {
        try {
          await dio.post<dynamic>(
            '/DocumentItemExpirationDates/Add',
            queryParameters: {'companyId': companyId},
            data: {
              'documentItemId': itemServerId,
              'expirationDate': it.expirationDate!.toIso8601String(),
            },
          );
        } catch (e) {
          debugPrint(
              'pushPendingDocumentItems (expiration) ${it.localId} failed — $e');
        }
      }
    }

    // ── Updates ────────────────────────────────────────────────────────────
    for (final it in await db.getDocumentItemsBySyncStatus('pending_update')) {
      if (it.serverId == null) continue;
      final doc = await db.getDocumentByLocalId(it.documentId);
      final docServerId = doc?.serverId;
      if (docServerId == null) continue;
      try {
        await dio.patch<dynamic>(
          '/DocumentItems/Update',
          queryParameters: {'companyId': companyId},
          data: {
            'id': it.serverId,
            'documentId': docServerId,
            'productId': it.productId,
            'quantity': it.quantity,
            'expectedQuantity': it.quantity,
            'priceBeforeTax': it.priceBeforeTax,
            'price': it.unitPrice,
            'discount': it.discount,
            'discountType': it.discountType,
            'productCost': 0,
            'discountApplyRule': true,
          },
        );
        if (it.expirationDate != null &&
            it.expirationDate!.isAfter(DateTime.now())) {
          // Best-effort upsert; skip past dates the server rejects.
          try {
            await dio.post<dynamic>(
              '/DocumentItemExpirationDates/Add',
              queryParameters: {'companyId': companyId},
              data: {
                'documentItemId': it.serverId,
                'expirationDate': it.expirationDate!.toIso8601String(),
              },
            );
          } catch (_) {}
        }
        await db.markDocumentItemSynced(it.localId, it.serverId);
      } catch (e) {
        debugPrint('pushPendingDocumentItems (update) ${it.localId} failed — $e');
      }
    }

    // ── Deletes ────────────────────────────────────────────────────────────
    for (final it in await db.getDocumentItemsBySyncStatus('pending_delete')) {
      try {
        if (it.serverId != null) {
          await dio.delete<dynamic>(
            '/DocumentItems/Delete',
            queryParameters: {'id': it.serverId, 'companyId': companyId},
          );
        }
        await db.hardDeleteDocumentItem(it.localId);
      } catch (e) {
        debugPrint('pushPendingDocumentItems (delete) ${it.localId} failed — $e');
      }
    }
  }

  // ==========================================================================
  // PUSH — Paid-status toggles made offline in the document editor.
  // documents.paid_status_dirty rows (with a server id) are PATCHed to
  // /Document/Update; the flag is cleared on success and retried otherwise.
  // ==========================================================================
  Future<void> pushPendingPaidStatus(int companyId) async {
    final dirty = await db.getPaidStatusDirtyDocuments(companyId);
    for (final doc in dirty) {
      try {
        await dio.patch<dynamic>(
          '/Document/Update',
          queryParameters: {'companyId': companyId},
          data: {'id': doc.serverId, 'paidStatus': doc.paidStatus},
        );
        await db.clearPaidStatusDirty(doc.localId);
      } catch (e) {
        debugPrint('pushPendingPaidStatus ${doc.localId} failed — $e');
      }
    }
  }

  // ==========================================================================
  // PUSH — Standalone payment CRUD made offline in the document editor.
  //   pending_create → POST /Payments/Add  (stamps the returned server id)
  //   pending_update → PATCH /Payments/Update
  //   pending_delete → DELETE /Payments/Delete then hard-delete the local row
  // A create whose parent document isn't on the server yet is skipped until it
  // is (its document syncs first via pushPendingOrders / linkDocumentToServer).
  // ==========================================================================
  // Drains MANUALLY added/edited/deleted payments. Like pushPendingDocuments,
  // this only handles pending_create/update/delete and NEVER
  // [SyncStatuses.pending]: a checkout/refund payment uses `pending` and is
  // created server-side by the BatchSync / Refund command, so pushing it here too
  // would write a duplicate payment. See [SyncStatuses] for the full invariant.
  Future<void> pushPendingPayments(int companyId) async {
    // ── Creates ────────────────────────────────────────────────────────────
    for (final p in await db.getPaymentsBySyncStatus(SyncStatuses.pendingCreate)) {
      final doc = await db.getDocumentByLocalId(p.documentId);
      final docServerId = doc?.serverId;
      if (docServerId == null) continue; // wait for the document to sync first
      try {
        final res = await dio.post<dynamic>(
          '/Payments/Add',
          queryParameters: {'companyId': companyId},
          data: {
            'documentId': docServerId,
            'paymentTypeId': p.paymentTypeId,
            'amount': p.amount,
            'userId': p.userId,
          },
        );
        await db.markPaymentSynced(p.localId, _parsePaymentServerId(res.data));
      } catch (e) {
        debugPrint('pushPendingPayments (create) ${p.localId} failed — $e');
      }
    }

    // ── Updates ────────────────────────────────────────────────────────────
    for (final p in await db.getPaymentsBySyncStatus(SyncStatuses.pendingUpdate)) {
      if (p.serverId == null) continue;
      try {
        await dio.patch<dynamic>(
          '/Payments/Update',
          queryParameters: {'companyId': companyId},
          data: {
            'id': p.serverId,
            'amount': p.amount,
            'date': p.date.toIso8601String(),
          },
        );
        await db.markPaymentSynced(p.localId, p.serverId);
      } catch (e) {
        debugPrint('pushPendingPayments (update) ${p.localId} failed — $e');
      }
    }

    // ── Deletes ────────────────────────────────────────────────────────────
    for (final p in await db.getPaymentsBySyncStatus(SyncStatuses.pendingDelete)) {
      try {
        if (p.serverId != null) {
          await dio.delete<dynamic>(
            '/Payments/Delete',
            queryParameters: {'id': p.serverId, 'companyId': companyId},
          );
        }
        await db.hardDeletePayment(p.localId);
      } catch (e) {
        debugPrint('pushPendingPayments (delete) ${p.localId} failed — $e');
      }
    }
  }

  int? _parsePaymentServerId(dynamic body) {
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    if (data is Map) {
      return int.tryParse(
          data['id']?.toString() ?? data['Id']?.toString() ?? '');
    }
    if (data is num) return data.toInt();
    return null;
  }

  // ==========================================================================
  // PULL — Documents from /Document/GetSalesHistory
  // ==========================================================================

  /// Pulls the last 90 days of sales documents from the server and upserts
  /// them into the local Drift DocumentsTable.
  ///
  /// Two cases per server document:
  ///   1. A local row with the same serverId already exists (created at checkout
  ///      on this device) → update the server-assigned document number.
  ///   2. No local row (created on another device) → insert a new 'srv_X'
  ///      sentinel row so the local history is complete across all devices.
  Future<void> pullDocuments(int companyId) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(const Duration(days: 90));

    // Delta watermark: after the first full pull, only fetch documents changed
    // (DateUpdated) since the last successful pull, so a steady device transfers
    // almost nothing instead of the whole 90-day window every sync. The local DB
    // is never pruned, so unreturned (unchanged) docs simply stay as they are.
    final watermark = await _getLastSync(_kDocuments);

    try {
      final res = await dio.get<dynamic>(
        '/Document/GetSalesHistory',
        queryParameters: {
          'companyId': companyId,
          'startDate': from.toIso8601String().substring(0, 10),
          'endDate': now.toIso8601String().substring(0, 10),
          // Pull line items + customerId so the local DB can compute the
          // dashboard / item-level reports fully offline.
          'includeItems': true,
          if (watermark != null)
            'modifiedAfter': watermark.toUtc().toIso8601String(),
        },
      );

      final list = ((res.data as List?) ?? []).cast<Map<String, dynamic>>();

      // Set of document localIds that already have line items locally — lets us
      // backfill items exactly once for documents pulled before includeItems
      // existed (or created on other devices), without rewriting items every
      // sync or touching local-origin docs that already carry their items.
      final withItemsRows = await (db.selectOnly(db.documentItemsTable,
              distinct: true)
            ..addColumns([db.documentItemsTable.documentId]))
          .get();
      final docsWithItems = withItemsRows
          .map((r) => r.read(db.documentItemsTable.documentId))
          .whereType<String>()
          .toSet();

      for (final d in list) {
        final serverId = (d['id'] as num?)?.toInt() ?? 0;
        if (serverId == 0) continue;

        final dateStr = (d['stockDate'] ?? d['date'] ?? '') as String;
        final date = DateTime.tryParse(dateStr) ?? now;
        final total = ((d['total'] as num?)?.toDouble()) ?? 0.0;
        final disc = ((d['discount'] as num?)?.toDouble()) ?? 0.0;
        final number = (d['number'] as String?) ?? '';
        final orderNo = d['orderNumber'] as String?;
        final refOf = d['referenceDocumentNumber'] as String?;
        final paid = (d['paidStatus'] as num?)?.toInt() ?? 1;
        final customerId = (d['customerId'] as num?)?.toInt();
        final rawItems =
            ((d['items'] as List?) ?? const []).cast<Map<String, dynamic>>();

        // Build item rows for a given document localId. The server item id is
        // captured (when present) so the offline editor can later edit/delete
        // these server-originated items and have the change pushed.
        List<DocumentItemsTableCompanion> buildItems(String docLocalId) =>
            rawItems
                .map((m) => DocumentItemsTableCompanion.insert(
                      localId: const Uuid().v4(),
                      documentId: docLocalId,
                      productId: (m['productId'] as num?)?.toInt() ?? 0,
                      quantity: ((m['quantity'] as num?) ?? 0).toDouble(),
                      unitPrice: ((m['unitPrice'] as num?) ?? 0).toDouble(),
                      total: ((m['total'] as num?) ?? 0).toDouble(),
                      serverId: Value((m['id'] as num?)?.toInt()),
                      priceBeforeTax: Value(
                          ((m['priceBeforeTax'] as num?) ?? 0).toDouble()),
                      discount:
                          Value(((m['discount'] as num?) ?? 0).toDouble()),
                      discountType:
                          Value((m['discountType'] as num?)?.toInt() ?? 0),
                    ))
                .toList();

        // Case 1: already in local DB by serverId — stamp the number, and
        // backfill items if this row has none yet (older pull / other device).
        final existing =
            await (db.select(db.documentsTable)
                  ..where((t) => t.serverId.equals(serverId))
                  ..limit(1))
                .getSingleOrNull();

        if (existing != null) {
          // Never clobber a document with unsynced local edits — the pusher
          // owns it until it reaches the server. Reconciling it here would
          // drop a pending header/total/delete change.
          const manualPending = {
            'pending_create',
            'pending_update',
            'pending_delete',
          };
          if (manualPending.contains(existing.syncStatus)) {
            continue;
          }
          if (existing.number != number || existing.syncStatus != 'synced') {
            await (db.update(
              db.documentsTable,
            )..where((t) => t.localId.equals(existing.localId))).write(
              DocumentsTableCompanion(
                number: Value(number),
                syncStatus: const Value('synced'),
                lastModified: Value(date),
              ),
            );
          }
          if (rawItems.isNotEmpty &&
              !docsWithItems.contains(existing.localId)) {
            await db.batch((b) =>
                b.insertAll(db.documentItemsTable, buildItems(existing.localId)));
          }
          continue;
        }

        // Case 1b: a document created locally (e.g. an offline refund pushed via
        // its own queue) carries the server number but no serverId yet — match
        // by number and stamp the serverId so we adopt the existing row instead
        // of inserting a duplicate. Its local total/items are preserved.
        if (number.isNotEmpty) {
          final byNumber =
              await (db.select(db.documentsTable)
                    ..where((t) => t.number.equals(number))
                    ..where((t) => t.serverId.isNull())
                    ..limit(1))
                  .getSingleOrNull();
          if (byNumber != null) {
            await (db.update(db.documentsTable)
                  ..where((t) => t.localId.equals(byNumber.localId)))
                .write(DocumentsTableCompanion(
              serverId:     Value(serverId),
              syncStatus:   const Value('synced'),
              lastModified: Value(date),
            ));
            if (rawItems.isNotEmpty &&
                !docsWithItems.contains(byNumber.localId)) {
              await db.batch((b) => b.insertAll(
                  db.documentItemsTable, buildItems(byNumber.localId)));
            }
            continue;
          }
        }

        // Case 2: new document from another device — insert sentinel row
        // plus its line items + customerId so the local DB can compute the
        // dashboard / item reports offline.
        // userId / warehouseId are not returned by GetSalesHistory; use 0.
        final docLocalId = 'srv_$serverId';
        await db.upsertServerDocument(
          document: DocumentsTableCompanion(
            localId: Value(docLocalId),
            serverId: Value(serverId),
            companyId: Value(companyId),
            userId: const Value(0),
            warehouseId: const Value(0),
            number: Value(number),
            total: Value(total),
            discount: Value(disc),
            customerId: Value(customerId),
            orderNumber: Value(orderNo),
            referenceDocumentNumber: Value(refOf),
            paidStatus: Value(paid),
            date: Value(date),
            syncStatus: const Value('synced'),
            lastModified: Value(date),
          ),
          items: buildItems(docLocalId),
        );
      }

      await _setLastSync(_kDocuments, now);
    } catch (e) {
      debugPrint('pullDocuments failed: $e — local history preserved.');
    }
  }

  Future<void> pullProductComments(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kProductComments);

    final res = await dio.get<List<dynamic>>(
      '/ProductComments/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Don't let an incremental pull overwrite/resurrect a comment the user is
    // locally deleting before its DELETE has been pushed. (Negative temp
    // pending_create rows never collide with positive server ids.)
    final pendingDeletes = await db.pendingDeleteProductCommentIds(companyId);

    await db.batch((batch) {
      for (final json in rows.cast<Map<String, dynamic>>()) {
        final id = json['id'] as int;
        if (pendingDeletes.contains(id)) continue;
        batch.insert(
          db.productCommentsTable,
          ProductCommentsTableCompanion(
            id: Value(id),
            companyId: Value(json['companyId'] as int? ?? companyId),
            productId: Value(json['productId'] as int? ?? 0),
            comment: Value(json['comment'] as String? ?? ''),
            lastModified: Value(_parseLastModified(json['lastModified'])),
            syncStatus: const Value('synced'),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });

    await _setLastSync(_kProductComments, startedAt);
  }

  /// Drains offline product-comment writes. Runs AFTER pushPendingProductOps so
  /// a comment on an offline-created product already carries the real productId
  /// (remapProductId cascaded it). A temp (negative) id always POSTs, then its
  /// row is swapped for the server id. A pending_delete issues the server DELETE
  /// (skipped for a temp id the server never saw) then hard-deletes locally.
  Future<void> pushPendingProductCommentOps(int companyId) async {
    final pending = await db.getPendingProductComments(companyId);
    if (pending.isEmpty) return;

    for (final c in pending) {
      try {
        final isTemp = c.id < 0;

        // ── DELETE ────────────────────────────────────────────────────────
        if (c.syncStatus == 'pending_delete') {
          if (!isTemp) {
            await dio.delete<dynamic>(
              '/ProductComments/Delete',
              queryParameters: {'id': c.id, 'companyId': companyId},
            );
          }
          await db.hardDeleteProductComment(c.id);
          continue;
        }

        // ── CREATE (temp id always POSTs) ─────────────────────────────────
        final res = await dio.post<dynamic>(
          '/ProductComments/Add',
          queryParameters: {'companyId': companyId},
          data: {'productId': c.productId, 'comment': c.comment},
        );
        final body =
            res.data is Map ? ((res.data as Map)['data'] ?? res.data) : null;
        final realId = (body is Map ? (body['id'] as num?) : null)?.toInt();
        if (realId == null) {
          throw Exception('Server returned no id for product comment create');
        }
        await db.transaction(() async {
          await db.hardDeleteProductComment(c.id);
          await db.upsertSyncedProductComment(
            id: realId,
            companyId: c.companyId,
            productId: c.productId,
            comment: c.comment,
            lastModified: DateTime.now().toUtc(),
          );
        });
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: c.syncStatus,
          logLabel:
              'pushPendingProductCommentOps: comment ${c.id} (${c.syncStatus})',
          entityLabel: 'Comment "${c.comment}"',
          apply: (s, _) => (db.update(db.productCommentsTable)
                ..where((x) => x.id.equals(c.id)))
              .write(ProductCommentsTableCompanion(syncStatus: Value(s))),
        );
      }
    }
  }

  /// Drains the [PendingUserOpsTable] by replaying each queued write against
  /// the server. Called during [sync] after all order/cash pushes so user-state
  /// changes (toggle, edit, security-key level) land before master-data pull
  /// overwrites the Drift rows with authoritative server values.
  ///
  /// Each op is attempted independently; a failure leaves the row for the next
  /// sync retry. On success the row is deleted.
  Future<void> pushPendingUserOps(int companyId) async {
    final ops = await (db.select(
      db.pendingUserOpsTable,
    )..where((t) => t.companyId.equals(companyId))).get();
    if (ops.isEmpty) return;

    for (final op in ops) {
      try {
        final payload = jsonDecode(op.payload) as Map<String, dynamic>;
        switch (op.operation) {
          case 'toggle_user':
            await dio.patch(
              '/Users/UpdateUser',
              queryParameters: {'companyId': companyId},
              data: {
                'id': payload['userId'],
                'isEnabled': payload['isEnabled'],
              },
            );
          case 'update_user':
            await dio.patch(
              '/Users/UpdateUser',
              queryParameters: {'companyId': companyId},
              data: payload,
            );
          case 'update_security_key':
            await dio.patch(
              '/SecurityKeys/Update',
              queryParameters: {'companyId': companyId},
              data: {'name': payload['name'], 'level': payload['level']},
            );
          default:
            debugPrint('pushPendingUserOps: unknown op "${op.operation}"');
        }
        // Success — remove from queue.
        await (db.delete(
          db.pendingUserOpsTable,
        )..where((t) => t.id.equals(op.id))).go();
      } on DioException {
        // Still offline or transient error — leave the row for next retry.
        debugPrint(
          'pushPendingUserOps: op ${op.id} (${op.operation}) failed — will retry',
        );
      }
    }
  }

  /// Fetches all security key rules from the server and does a full replace in
  /// Drift (delete-old + bulk-insert-new inside a transaction). No watermark
  /// is used because the table is tiny (< 20 rows) and the endpoint does not
  /// support `modifiedAfter`. Failures are silently swallowed so a network
  /// drop never breaks the sync pipeline — cached rules stay in place.
  Future<void> pullSecurityKeys(int companyId) async {
    try {
      final res = await dio.get<List<dynamic>>(
        '/SecurityKeys/GetAll',
        queryParameters: {'companyId': companyId},
      );
      final rows = (res.data ?? const []).cast<Map<String, dynamic>>();

      await db.transaction(() async {
        await (db.delete(
          db.securityKeysTable,
        )..where((t) => t.companyId.equals(companyId))).go();
        if (rows.isNotEmpty) {
          await db.batch((b) {
            b.insertAll(
              db.securityKeysTable,
              rows.map(
                (j) => SecurityKeysTableCompanion(
                  companyId: Value(companyId),
                  name: Value(j['name'] as String? ?? ''),
                  level: Value((j['level'] as num?)?.toInt() ?? 1),
                ),
              ),
            );
          });
        }
      });
    } on DioException {
      // Offline or server error — leave existing cached rules intact.
    }
  }

  Future<void> pullPromotions(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kPromotions);

    final res = await dio.get<List<dynamic>>(
      '/Promotions/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = (res.data ?? const []).cast<Map<String, dynamic>>();

    for (final json in rows) {
      final promoId = (json['id'] as num?)?.toInt() ?? 0;

      // Don't overwrite rows that have unsync-ed local edits.
      final existing = await (db.select(
        db.promotionsTable,
      )..where((t) => t.id.equals(promoId))).getSingleOrNull();
      if (existing != null && existing.syncStatus != 'synced') continue;

      await db.transaction(() async {
        await db
            .into(db.promotionsTable)
            .insertOnConflictUpdate(
              PromotionsTableCompanion(
                id: Value(promoId),
                companyId: Value(json['companyId'] as int? ?? companyId),
                name: Value(json['name'] as String? ?? 'Unnamed'),
                daysOfWeek: Value(json['daysOfWeek'] as int? ?? 127),
                isEnabled: Value(json['isEnabled'] as bool? ?? true),
                startDate: Value(_parseNullableDate(json['startDate'])),
                startTime: Value(
                  (json['startTime'] as String?)?.isEmpty == true
                      ? null
                      : json['startTime'] as String?,
                ),
                endDate: Value(_parseNullableDate(json['endDate'])),
                endTime: Value(
                  (json['endTime'] as String?)?.isEmpty == true
                      ? null
                      : json['endTime'] as String?,
                ),
                lastModified: Value(_parseLastModified(json['lastModified'])),
                syncStatus: const Value('synced'),
              ),
            );
        // Replace items for this promotion with the server version.
        await (db.delete(
          db.promotionItemsTable,
        )..where((t) => t.promotionId.equals(promoId))).go();
        final items = ((json['items'] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>();
        for (final item in items) {
          await db
              .into(db.promotionItemsTable)
              .insertOnConflictUpdate(
                PromotionItemsTableCompanion(
                  id: Value((item['id'] as num?)?.toInt() ?? 0),
                  promotionId: Value(promoId),
                  productId: Value((item['productId'] as num?)?.toInt() ?? 0),
                  discountType: Value(
                    (item['discountType'] as num?)?.toInt() ?? 0,
                  ),
                  priceType: Value((item['priceType'] as num?)?.toInt() ?? 0),
                  value: Value((item['value'] as num?)?.toDouble() ?? 0),
                  isConditional: Value(item['isConditional'] as bool? ?? false),
                  quantity: Value((item['quantity'] as num?)?.toDouble() ?? 1),
                  conditionType: Value(
                    (item['conditionType'] as num?)?.toInt() ?? 0,
                  ),
                  quantityLimit: Value(
                    (item['quantityLimit'] as num?)?.toDouble() ?? 0,
                  ),
                ),
              );
        }
      });
    }

    await _setLastSync(_kPromotions, startedAt);
  }

  /// Pushes every pending promotion write (create / update / delete) to the
  /// server. Runs in [sync] after product ops so any newly-created products
  /// referenced by promotion items already exist server-side.
  Future<void> pushPendingPromotionOps(int companyId) async {
    final pending =
        await (db.select(db.promotionsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where((t) => t.syncStatus.isNotIn(['synced'])))
            .get();

    for (final p in pending) {
      try {
        final localItems = await (db.select(
          db.promotionItemsTable,
        )..where((t) => t.promotionId.equals(p.id))).get();

        switch (p.syncStatus) {
          case 'pending_create':
            final body = {
              'name': p.name,
              'daysOfWeek': p.daysOfWeek,
              'startDate': p.startDate?.toUtc().toIso8601String(),
              'startTime': p.startTime,
              'endDate': p.endDate?.toUtc().toIso8601String(),
              'endTime': p.endTime,
              'items': localItems
                  .map(
                    (i) => {
                      'productId': i.productId,
                      'discountType': i.discountType,
                      'priceType': i.priceType,
                      'value': i.value,
                      'isConditional': i.isConditional,
                      'quantity': i.quantity,
                      'conditionType': i.conditionType,
                      'quantityLimit': i.quantityLimit,
                    },
                  )
                  .toList(),
            };
            final res = await dio.post<dynamic>(
              '/Promotions/Add',
              queryParameters: {'companyId': companyId},
              data: body,
            );
            final serverJson = res.data as Map<String, dynamic>;
            final serverId = (serverJson['id'] as num?)?.toInt() ?? 0;
            final serverItems = ((serverJson['items'] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>();
            await db.transaction(() async {
              await (db.delete(
                db.promotionsTable,
              )..where((t) => t.id.equals(p.id))).go();
              await (db.delete(
                db.promotionItemsTable,
              )..where((t) => t.promotionId.equals(p.id))).go();
              await db
                  .into(db.promotionsTable)
                  .insertOnConflictUpdate(
                    PromotionsTableCompanion(
                      id: Value(serverId),
                      companyId: Value(p.companyId),
                      name: Value(p.name),
                      daysOfWeek: Value(p.daysOfWeek),
                      isEnabled: Value(p.isEnabled),
                      startDate: Value(p.startDate),
                      startTime: Value(p.startTime),
                      endDate: Value(p.endDate),
                      endTime: Value(p.endTime),
                      lastModified: Value(DateTime.now().toUtc()),
                      syncStatus: const Value('synced'),
                    ),
                  );
              for (final item in serverItems) {
                await db
                    .into(db.promotionItemsTable)
                    .insertOnConflictUpdate(
                      PromotionItemsTableCompanion(
                        id: Value((item['id'] as num?)?.toInt() ?? 0),
                        promotionId: Value(serverId),
                        productId: Value(
                          (item['productId'] as num?)?.toInt() ?? 0,
                        ),
                        discountType: Value(
                          (item['discountType'] as num?)?.toInt() ?? 0,
                        ),
                        priceType: Value(
                          (item['priceType'] as num?)?.toInt() ?? 0,
                        ),
                        value: Value((item['value'] as num?)?.toDouble() ?? 0),
                        isConditional: Value(
                          item['isConditional'] as bool? ?? false,
                        ),
                        quantity: Value(
                          (item['quantity'] as num?)?.toDouble() ?? 1,
                        ),
                        conditionType: Value(
                          (item['conditionType'] as num?)?.toInt() ?? 0,
                        ),
                        quantityLimit: Value(
                          (item['quantityLimit'] as num?)?.toDouble() ?? 0,
                        ),
                      ),
                    );
              }
            });

          case 'pending_update':
            final body = {
              'id': p.id,
              'name': p.name,
              'daysOfWeek': p.daysOfWeek,
              'isEnabled': p.isEnabled,
              'startDate': p.startDate?.toUtc().toIso8601String(),
              'startTime': p.startTime,
              'endDate': p.endDate?.toUtc().toIso8601String(),
              'endTime': p.endTime,
              'items': localItems
                  .map(
                    (i) => {
                      'id': i.id > 0 ? i.id : 0,
                      'productId': i.productId,
                      'discountType': i.discountType,
                      'priceType': i.priceType,
                      'value': i.value,
                      'isConditional': i.isConditional,
                      'quantity': i.quantity,
                      'conditionType': i.conditionType,
                      'quantityLimit': i.quantityLimit,
                    },
                  )
                  .toList(),
            };
            await dio.put<dynamic>(
              '/Promotions/Update',
              queryParameters: {'companyId': companyId},
              data: body,
            );
            await (db.update(
              db.promotionsTable,
            )..where((t) => t.id.equals(p.id))).write(
              const PromotionsTableCompanion(syncStatus: Value('synced')),
            );

          case 'pending_delete':
            await dio.delete<dynamic>(
              '/Promotions/Delete',
              queryParameters: {'id': p.id, 'companyId': companyId},
            );
            await (db.delete(
              db.promotionItemsTable,
            )..where((t) => t.promotionId.equals(p.id))).go();
            await (db.delete(
              db.promotionsTable,
            )..where((t) => t.id.equals(p.id))).go();
        }
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: p.syncStatus,
          logLabel: 'pushPendingPromotionOps: promo ${p.id} (${p.syncStatus})',
          entityLabel: 'Promotion "${p.name}"',
          apply: (s, msg) =>
              (db.update(db.promotionsTable)..where((t) => t.id.equals(p.id)))
                  .write(PromotionsTableCompanion(
                      syncStatus: Value(s), syncError: Value(msg))),
        );
      }
    }
  }

  // ==========================================================================
  // APP PROPERTIES — bidirectional, per-key timestamp guard.
  //
  // Plan rule: never blindly overwrite. The user can change a setting locally
  // (offline) and the push hasn't happened yet — a stale server row arriving
  // via pull must NOT clobber it.
  //
  // We compare `serverLastModified` against `localLastModified` per row and
  // upsert only when the server is strictly newer.
  // ==========================================================================
  Future<void> pullAppProperties(int companyId) async {
    final startedAt = DateTime.now().toUtc();
    final watermark = await _getLastSync(_kAppProperties);

    final res = await dio.get<List<dynamic>>(
      '/ApplicationProperties/GetAll',
      queryParameters: _query(companyId, watermark),
    );
    final rows = res.data ?? const [];

    // Apply every upsert/cleanup inside a SINGLE transaction so Drift notifies
    // the watched query (behind rawAppPropertiesProvider) just once on commit,
    // not once per row. Per-row emissions were re-running
    // AppSettingsNotifier.build() in back-to-back ticks, which trips Riverpod
    // 3's "Only one task can be scheduled at a time" scheduler assertion when a
    // setting is saved — most visibly the first time a brand-new key such as
    // App.DefaultScreen is created (that path is the only one that pulls).
    await db.transaction(() async {
      for (final json in rows.cast<Map<String, dynamic>>()) {
        final id = json['id'] as int;
        final serverLastModified = _parseLastModified(json['lastModified']);

        final localRow = await (db.select(
          db.appPropertiesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();

        if (localRow != null &&
            !serverLastModified.isAfter(localRow.lastModified)) {
          // Local copy is equal or newer — preserve it.
          continue;
        }

        final name = json['name'] as String? ?? '';
        await db
            .into(db.appPropertiesTable)
            .insertOnConflictUpdate(
              AppPropertiesTableCompanion(
                id: Value(id),
                companyId: Value(json['companyId'] as int? ?? companyId),
                name: Value(name),
                value: Value(json['value'] as String?),
                lastModified: Value(serverLastModified),
                // Authoritative server value — clears any local pending flag.
                syncStatus: const Value('synced'),
              ),
            );

        // Drop any offline-only temp row (negative id) for this key now that the
        // server has assigned a real id — prevents a duplicate name row.
        await (db.delete(db.appPropertiesTable)
              ..where((t) => t.name.equals(name))
              ..where((t) => t.id.isSmallerThanValue(0)))
            .go();
      }
    });

    await _setLastSync(_kAppProperties, startedAt);

    // Materialise any settings that still have NO row after the pull, so the DB
    // ends up with an explicit row for EVERY setting (with its default value) on
    // first open — instead of only the ones the operator has touched.
    await _seedMissingAppPropertyDefaults(companyId);
  }

  /// Writes a `pending` row (using each setting's built-in default) for every
  /// [kSettingDefaults] key that has no local row yet. Runs only after a
  /// successful AppProperties pull, so keys the server already has are present
  /// locally and never re-seeded (no duplicates). Idempotent and non-destructive:
  /// existing keys — in ANY sync state — are left untouched, so a user's saved
  /// value is never overwritten. The seeded rows push to the server on next sync.
  Future<void> _seedMissingAppPropertyDefaults(int companyId) async {
    final existing = await (db.select(db.appPropertiesTable)
          ..where((t) => t.companyId.equals(companyId)))
        .get();
    final existingKeys = existing.map((r) => r.name).toSet();

    final missing = kSettingDefaults.entries
        .where((e) => !existingKeys.contains(e.key))
        .toList();
    if (missing.isEmpty) return;

    final now = DateTime.now().toUtc();
    await db.batch((b) {
      for (final e in missing) {
        b.insert(
          db.appPropertiesTable,
          AppPropertiesTableCompanion(
            // Same deterministic (companyId, key) temp-id scheme as
            // AppSettingsNotifier._tempIdForKey, so a later manual edit of the
            // same key updates this row, not a 2nd one — and it stays unique per
            // company on the app_properties.id primary key (a key-only id threw a
            // UNIQUE constraint when a 2nd company seeded the same key).
            id: Value(-((Object.hash(companyId, e.key) & 0x7fffffff) + 1)),
            companyId: Value(companyId),
            name: Value(e.key),
            value: Value(e.value),
            lastModified: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      }
    });
    debugPrint('Seeded ${missing.length} default app property row(s).');
  }

  // ==========================================================================
  // LOYALTY CARDS — push pending writes, then pull all cards for company
  // ==========================================================================

  /// Pushes all locally-queued loyalty card mutations to the server using the
  /// batch sync endpoint. Pending deletes are handled individually via DELETE.
  ///
  /// After a successful batch push, temp rows (negative IDs from pending_create)
  /// are hard-deleted locally and pending_update rows are marked 'synced'. The
  /// subsequent [pullLoyaltyCards] then brings back the canonical server rows
  /// with real server-assigned IDs.
  Future<void> pushPendingLoyaltyCardOps(int companyId) async {
    final allPending =
        await (db.select(db.loyaltyCardsTable)
              ..where((t) => t.companyId.equals(companyId))
              ..where(
                (t) => t.syncStatus.isIn([
                  'pending_create',
                  'pending_update',
                  'pending_delete',
                ]),
              ))
            .get();

    if (allPending.isEmpty) return;

    // Split into upserts vs deletes.
    final toUpsert = allPending
        .where((r) => r.syncStatus != 'pending_delete')
        .toList();
    final toDelete = allPending
        .where((r) => r.syncStatus == 'pending_delete')
        .toList();

    // ── Batch upsert ──────────────────────────────────────────────────────────
    if (toUpsert.isNotEmpty) {
      try {
        final cards = toUpsert
            .map(
              (r) => {
                // Negative IDs are temp — omit so the server treats them as creates.
                if (r.id > 0) 'id': r.id,
                'customerId': r.customerId,
                'cardNumber': r.cardNumber,
                'points': r.points,
                'lastModified': r.lastModified.toUtc().toIso8601String(),
              },
            )
            .toList();

        await dio.post<dynamic>(
          '/LoyaltyCards/BatchSync',
          queryParameters: {'companyId': companyId},
          data: {'cards': cards},
        );

        // Remove temp rows and mark updates as synced.
        await db.transaction(() async {
          for (final r in toUpsert) {
            if (r.id < 0) {
              await (db.delete(
                db.loyaltyCardsTable,
              )..where((t) => t.id.equals(r.id))).go();
            } else {
              await (db.update(
                db.loyaltyCardsTable,
              )..where((t) => t.id.equals(r.id))).write(
                const LoyaltyCardsTableCompanion(
                  syncStatus: Value('synced'),
                  syncError: Value(null),
                ),
              );
            }
          }
        });
      } catch (e) {
        if (_isServerRejection(e)) {
          // The whole batch was rejected by the server — flag every row in it
          // sync_failed so it stops retrying (it's all-or-nothing server-side).
          final msg = _serverErrMsg(e);
          for (final r in toUpsert) {
            await (db.update(db.loyaltyCardsTable)
                  ..where((t) => t.id.equals(r.id)))
                .write(LoyaltyCardsTableCompanion(
                    syncStatus: const Value('sync_failed'), syncError: Value(msg)));
          }
          debugPrint(
            'pushPendingLoyaltyCardOps: batch upsert rejected — $msg '
            '(resolved, won\'t retry)',
          );
        } else {
          // Offline / transient — leave rows pending for next retry.
          debugPrint(
            'pushPendingLoyaltyCardOps: batch upsert failed — $e (will retry)',
          );
        }
      }
    }

    // ── Individual deletes ────────────────────────────────────────────────────
    for (final r in toDelete) {
      try {
        await dio.delete<dynamic>(
          '/LoyaltyCards/Delete',
          queryParameters: {'id': r.id, 'companyId': companyId},
        );
        await (db.delete(
          db.loyaltyCardsTable,
        )..where((t) => t.id.equals(r.id))).go();
      } catch (e) {
        await _resolveRejection(
          error: e,
          syncStatus: r.syncStatus,
          logLabel: 'pushPendingLoyaltyCardOps: delete card ${r.id}',
          entityLabel: 'Loyalty card ${r.cardNumber ?? r.id}',
          apply: (s, _) => (db.update(db.loyaltyCardsTable)
                ..where((t) => t.id.equals(r.id)))
              .write(LoyaltyCardsTableCompanion(syncStatus: Value(s))),
        );
      }
    }
  }

  // ==========================================================================
  // PUSH — pending shifts via /api/Shifts/BatchSync
  // ==========================================================================

  /// Pushes every `syncStatus='pending'` shift to /api/Shifts/BatchSync.
  /// The server returns a Results list mapping each localId → serverId so we
  /// can update the local row without a separate pull.
  Future<void> pushPendingShifts(int companyId) async {
    final pending = await db.getPendingShifts();
    if (pending.isEmpty) return;

    try {
      final shifts = pending
          .map((s) => {
                if (s.serverId != null) 'serverId': s.serverId,
                'localId': s.localId,
                'userId': s.userId,
                'openedAt': s.openedAt.toIso8601String(),
                if (s.closedAt != null)
                  'closedAt': s.closedAt!.toIso8601String(),
                'startingCash': s.startingCash,
                if (s.actualEndingCash != null)
                  'actualEndingCash': s.actualEndingCash,
                'status': s.status,
                'lastModified': s.lastModified.toIso8601String(),
              })
          .toList();

      final res = await dio.post<Map<String, dynamic>>(
        '/Shifts/BatchSync',
        queryParameters: {'companyId': companyId},
        data: {'shifts': shifts},
      );

      final data = res.data;
      final results =
          (data?['results'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();

      for (final r in results) {
        final localId = r['localId'] as String?;
        final serverId = (r['serverId'] as num?)?.toInt();
        if (localId != null && serverId != null && serverId > 0) {
          await db.markShiftSynced(localId, serverId);
        }
      }
    } catch (e) {
      debugPrint('pushPendingShifts failed — $e');
      // Leave rows pending for next retry; don't mark failed on transport error.
    }
  }

  // ==========================================================================
  // PUSH — pending time clock entries via /api/TimeClock/BatchSync
  // ==========================================================================

  Future<void> pushPendingTimeClockEntries(int companyId) async {
    final pending = await db.getPendingTimeClockEntries();
    if (pending.isEmpty) return;

    try {
      final entries = pending
          .map((e) => {
                if (e.serverId != null) 'serverId': e.serverId,
                'localId': e.localId,
                'userId': e.userId,
                'clockInTime': e.clockInTime.toIso8601String(),
                if (e.clockOutTime != null)
                  'clockOutTime': e.clockOutTime!.toIso8601String(),
                'lastModified': DateTime.now().toUtc().toIso8601String(),
              })
          .toList();

      final res = await dio.post<Map<String, dynamic>>(
        '/TimeClock/BatchSync',
        queryParameters: {'companyId': companyId},
        data: {'entries': entries},
      );

      final data = res.data;
      final results =
          (data?['results'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();

      for (final r in results) {
        final localId = r['localId'] as String?;
        final serverId = (r['serverId'] as num?)?.toInt();
        if (localId != null && serverId != null && serverId > 0) {
          await db.markTimeClockEntrySynced(localId, serverId);
        }
      }
    } catch (e) {
      debugPrint('pushPendingTimeClockEntries failed — $e');
    }
  }

  /// Pulls all loyalty cards for [companyId] and upserts them into the local
  /// Drift table. Skips rows that have pending local edits so offline writes
  /// are never overwritten by stale server data.
  Future<void> pullLoyaltyCards(int companyId) async {
    try {
      final res = await dio.get<List<dynamic>>(
        '/LoyaltyCards/GetAll',
        queryParameters: {'companyId': companyId},
      );
      final rows = (res.data ?? const []).cast<Map<String, dynamic>>();

      for (final json in rows) {
        final id = (json['id'] as num?)?.toInt() ?? 0;
        if (id <= 0) continue;

        final existing = await (db.select(
          db.loyaltyCardsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing != null && existing.syncStatus != 'synced') continue;

        await db
            .into(db.loyaltyCardsTable)
            .insertOnConflictUpdate(
              LoyaltyCardsTableCompanion(
                id: Value(id),
                companyId: Value(json['companyId'] as int? ?? companyId),
                customerId: Value((json['customerId'] as num?)?.toInt() ?? 0),
                cardNumber: Value(json['cardNumber'] as String?),
                points: Value((json['points'] as num?)?.toDouble() ?? 0),
                lastModified: Value(_parseLastModified(json['lastModified'])),
                syncStatus: const Value('synced'),
                syncError: const Value(null),
              ),
            );
      }

      await _setLastSync(_kLoyaltyCards, DateTime.now().toUtc());
    } catch (e) {
      debugPrint('pullLoyaltyCards failed: $e — local data preserved.');
    }
  }
}

/// Converts an empty-or-whitespace string to null so Drift never stores "".
String? _nullIfBlank(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}
