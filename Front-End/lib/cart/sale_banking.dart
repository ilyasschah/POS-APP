// Banking a sale: the one place a cart becomes an order, a document, its
// payments and its discount lines in local SQLite.
//
// Shared by the ordinary checkout (one tender) and the split bill (one tender
// per guest, all on ONE document). It used to live inline in
// `PaymentCheckoutDialog._complete`; a second copy for the split would have
// been one more money path re-typed in two places — the exact way this
// codebase has watched copies drift before (see `taxAmountsForItem`).
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/discount_display.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/loyalty/loyalty_card_provider.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/settings/device_identity.dart';

/// One tender on a sale: a payment type and the money taken on it.
class SaleTender {
  const SaleTender({required this.paymentTypeId, required this.amount});

  final int paymentTypeId;
  final double amount;
}

/// What banking a sale produced — everything its caller prints and shows.
class BankedSale {
  const BankedSale({
    required this.documentLocalId,
    required this.documentNumber,
    required this.cartState,
    required this.receiptDiscountLines,
  });

  final String documentLocalId;
  final String documentNumber;

  /// The cart AS SOLD. Banking clears the live cart, so every reader after it
  /// — the receipt's customer, the kitchen tickets, the loyalty card — must
  /// read this snapshot, or a credit sale prints "Walk-in".
  final CartState cartState;

  final List<ReceiptDiscountLine> receiptDiscountLines;
}

/// Writes the live cart to local SQLite as a completed sale and clears it.
///
/// [items] is the cart snapshot the operator was shown; [total] what the
/// document comes to after every discount, loyalty points included. [tenders]
/// holds one entry for an ordinary sale and one per guest for a split bill —
/// every one of them becomes a payment on the SAME document.
///
/// No Dio. No network. Nothing here can fail for being offline.
Future<BankedSale> bankCartSale(
  WidgetRef ref, {
  required Company company,
  required User user,
  required List<CartItem> items,
  required double total,
  required List<SaleTender> tenders,
  required int paidStatus,
  required String currencySymbol,
  double pointsUsed = 0,
  double pointsDiscount = 0,
}) async {
  assert(tenders.isNotEmpty, 'A sale is settled by at least one tender.');

  // INVARIANT: the order / document / payment / discount rows below are all
  // written as `'pending'` — NOT `'pending_create'`. They are created
  // server-side by the BatchSync push, so pushPendingDocuments /
  // pushPendingPayments deliberately skip them; writing `'pending_create'`
  // here would double-create them. See `lib/sync/sync_status.dart`.
  final cartState = ref.read(cartProvider);
  final cartNotifier = ref.read(cartProvider.notifier);
  final db = ref.read(appDatabaseProvider);
  final now = DateTime.now().toUtc();
  final orderNum = cartState.orderNumber;

  // 🚨 The session this sale belongs to, stamped on EVERY row it creates —
  // order, document, payment. Without it the drawer owns nothing: the
  // session screen reports "0 documents / 0.00 taken" for a till that sold
  // all day, and the closing count is measured against the opening float
  // alone. Null is legitimate (the gate fails open, and a pre-session sale
  // predates all of this) and banks the sale unattached rather than
  // refusing it.
  final sessionLocalId = ref.read(activeSessionProvider).value?.localId;

  // Offline document number — issued LOCALLY (device-local counter) so the
  // sale is numbered + scannable the instant it completes: refunds work
  // offline and two terminals never collide (the DeviceName prefix). Stamped
  // on BOTH the PosOrder (so BatchSync carries it to the server, which keeps
  // it instead of generating its own) and the local Document.
  final deviceName = await getDeviceName();
  final docNumber = await db.nextDocumentNumber(
    companyId: company.id,
    deviceName: deviceName,
    docTypeCode: DocumentTypes.salesCode,
  );

  // If the cart was loaded from an existing local row (e.g. 'svr_3280'),
  // UPDATE that row instead of inserting a new one. This prevents duplicate
  // orders in both SQLite and SQL Server when the same order is re-opened
  // and paid multiple times.
  final existingLocalId = cartState.existingLocalOrderId;
  final orderLocalId = existingLocalId ?? const Uuid().v4();

  // The order row holds ONE payment type. A split bill's other tenders ride
  // on the document, and sync_manager sends them to the server as a list.
  final orderPaymentTypeId = tenders.first.paymentTypeId;
  final amountPaid = tenders.fold<double>(0, (s, t) => s + t.amount);

  // One stable line id per cart line, SHARED by the pos_order_item, the
  // document_item, and the discount_lines.itemLocalId. BatchSync echoes each
  // created DocumentItem's server id back keyed by this id, so the local
  // document_items row gets its serverId stamped (without which its later
  // edits/deletes could never sync). It also keeps duplicate-product lines
  // distinct end-to-end.
  final lineLocalIds = {
    for (final item in items) item.cartItemId: const Uuid().v4(),
  };

  // Build items first — orderId is the same whether we insert or update.
  final itemCompanions = items.map((item) {
    final summedRate = item.appliedTaxes
        .where((t) => !t.isFixed)
        .fold<double>(0, (sum, t) => sum + t.rate);
    // Per-tax amounts so SyncManager can pass CheckoutItemDto.Taxes to the
    // server, creating DocumentItemTax rows during BatchSync. Sourced from
    // the cart so the banked tax is the tax the cashier was shown — this
    // used to re-derive it and silently ignored `discountApplyRule`.
    final taxEntries = cartNotifier
        .taxAmountsForItem(item)
        .map((t) => {'id': t.id, 'amount': t.amount})
        .toList();
    final taxesJsonStr = taxEntries.isEmpty ? null : jsonEncode(taxEntries);
    // A %-entered item discount is stored as (type 0, the % value) rather
    // than its resolved money, so the saved document line reads "50%" not
    // "Fixed 5". Totals are identical — the backend BatchSync applies the
    // discount type-aware. Skipped when a promotion is mixed in, since one
    // discount field can't hold both a % and the promo's money.
    final pctItemDiscount =
        item.discountInputType == 0 &&
        item.discountInputValue != null &&
        item.promotionalDiscount == 0;
    return PosOrderItemsTableCompanion(
      localId: Value(lineLocalIds[item.cartItemId]!),
      orderId: Value(orderLocalId),
      productId: Value(item.productId),
      quantity: Value(item.quantity),
      unitPrice: Value(item.price),
      discount: Value(
        pctItemDiscount
            ? item.discountInputValue!
            : item.discount + item.promotionalDiscount,
      ),
      discountType: Value(pctItemDiscount ? 0 : item.discountType),
      taxRate: Value(summedRate),
      taxesJson: Value(taxesJsonStr),
      comment: Value(item.comment),
      warehouseId: Value(
        item.warehouseId ?? cartNotifier.effectiveWarehouseId,
      ),
      syncStatus: const Value('pending'),
    );
  }).toList();

  // The cart may have been opened on a table created offline, whose temp id
  // was swapped for a real one by a sync while this cart sat open. Checkout
  // is the last writer, so resolve before persisting or the dead id wins.
  final resolvedTableId = await db.resolveFloorPlanTableId(
    cartState.floorPlanTableId,
  );

  if (existingLocalId != null) {
    // Existing open order (server-originated or previously synced) —
    // update the header row and replace its items in a single transaction.
    await db.completeExistingOrder(
      existingLocalId,
      PosOrdersTableCompanion(
        number: Value(docNumber),
        closedAt: Value(now),
        status: const Value(1),
        sessionLocalId: Value(sessionLocalId),
        total: Value(total),
        discount: Value(cartState.manualCartDiscount),
        warehouseId: Value(cartNotifier.effectiveWarehouseId),
        customerId: Value(cartState.selectedCustomer?.id),
        serviceStatus: Value(cartState.serviceStatus),
        paymentTypeId: Value(orderPaymentTypeId),
        amountPaid: Value(amountPaid),
        syncStatus: const Value('pending'),
        lastModified: Value(now),
      ),
      itemCompanions,
    );
  } else {
    // Brand-new order — insert header + items.
    await db.insertOfflineOrder(
      PosOrdersTableCompanion(
        localId: Value(orderLocalId),
        number: Value(docNumber),
        serverId: const Value(null),
        companyId: Value(company.id),
        userId: Value(user.id),
        tableId: Value(resolvedTableId),
        customerId: Value(cartState.selectedCustomer?.id),
        serviceType: Value(cartState.serviceType),
        serviceStatus: Value(cartState.serviceStatus),
        orderName: Value(orderNum),
        openedAt: Value(now),
        closedAt: Value(now),
        status: const Value(1),
        sessionLocalId: Value(sessionLocalId),
        total: Value(total),
        discount: Value(cartState.manualCartDiscount),
        warehouseId: Value(cartNotifier.effectiveWarehouseId),
        paymentTypeId: Value(orderPaymentTypeId),
        amountPaid: Value(amountPaid),
        syncStatus: const Value('pending'),
        lastModified: Value(now),
      ),
      itemCompanions,
    );
  }

  // ── Local inventory deduction ─────────────────────────────────────────────
  // Mirror the server-side delta logic so local stock stays accurate.
  // Stock is verified up-front in the menu / cart when items are added, so
  // checkout NEVER blocks here — it just deducts (allowing negative if the
  // item somehow went out of stock) and proceeds. This matches the server's
  // offline-replay behaviour (BatchSync replays sales with AllowNegativeStock).
  await db.deductStockForCheckout(
    items: items
        .map(
          (item) => (
            productId: item.productId,
            quantity: item.quantity,
            // The line's own unit — a 100 g line takes 0.100 kg off the
            // shelf, and deductStockForCheckout does that conversion.
            uomId: item.uomId,
            warehouseId: item.warehouseId ?? cartNotifier.effectiveWarehouseId,
            isService: item.isService,
            productName: item.productName,
          ),
        )
        .toList(),
    allowNegative: true,
  );

  // ── Create Document + Payments locally ────────────────────────────────────
  // The Document localId = orderLocalId so sync_manager can link it to
  // the server Document returned by CheckoutPosOrderCommand after BatchSync.
  // cartItemId → document_item localId, so discount_lines link to the
  // permanent document record (the source of truth for receipts/reports).
  final docItemLocalIds = <String, String>{};
  // The choices, snapshotted onto the banked line. Same rows as the parked
  // order carried, re-keyed to the DOCUMENT line — the open order and its
  // lines are deleted the moment this sale is banked, so nothing survives
  // to a reprint unless it is copied here.
  final docItemModifiers = <DocumentItemModifiersTableCompanion>[];
  final docItems = items.map((item) {
    // Same id as this line's pos_order_item, so BatchSync can stamp the
    // returned DocumentItem serverId onto this exact row.
    final docItemLocalId = lineLocalIds[item.cartItemId]!;
    docItemLocalIds[item.cartItemId] = docItemLocalId;
    for (var mi = 0; mi < item.selectedModifiers.length; mi++) {
      final m = item.selectedModifiers[mi];
      docItemModifiers.add(
        DocumentItemModifiersTableCompanion(
          localId: Value(const Uuid().v4()),
          documentItemLocalId: Value(docItemLocalId),
          // Nullable and unenforced: the snapshot is the record, the id
          // only exists so reports can group by option.
          modifierOptionId: Value(m.modifierOptionId),
          groupName: Value(m.groupName),
          name: Value(m.name),
          additionalPrice: Value(m.additionalPrice),
          rank: Value(mi),
        ),
      );
    }
    final lineTotal =
        (item.price - item.discount - item.promotionalDiscount) * item.quantity;
    // From the cart, so `total + taxAmount` reconciles with the document
    // total the customer actually paid under EITHER discountApplyRule.
    // Re-deriving it here hardcoded the "Before tax" rule, so an "After tax"
    // company banked a line that contradicted its own document by
    // (discount × rate) — 30 + 6 on a 37.00 document.
    final taxAmt = cartNotifier.taxForItem(item);
    // Persist the tax-base price + the applied tax so the document editor's
    // Edit-Item dialog can load real values (it was showing 0 / "No tax"
    // because these were never written). The editor is single-tax, so carry
    // the combined % rate and the first applied tax id. The rate stays
    // %-only — a fixed tax has no rate — while taxAmt above is every tax.
    final combinedRate = item.appliedTaxes
        .where((t) => !t.isFixed)
        .fold<double>(0, (s, t) => s + t.rate);
    final firstTaxId =
        item.appliedTaxes.isNotEmpty ? item.appliedTaxes.first.id : null;
    // Mirror the pos_order_items choice so local + pulled docs agree: keep a
    // %-entered discount as (type 0, the % value) instead of the resolved
    // money, so the Edit-Item dialog shows "50%". `total` (lineTotal) stays
    // authoritative and unchanged.
    final pctItemDiscount =
        item.discountInputType == 0 &&
        item.discountInputValue != null &&
        item.promotionalDiscount == 0;
    return DocumentItemsTableCompanion(
      localId: Value(docItemLocalId),
      documentId: Value(orderLocalId),
      productId: Value(item.productId),
      quantity: Value(item.quantity),
      unitPrice: Value(item.price),
      // The EX-TAX price, which for a tax-inclusive product is NOT
      // `item.price` — that already contains the tax. Writing the gross
      // figure here made the banked document claim a 90 MAD inclusive line
      // had a 90 MAD taxable base, and the backend recomputes
      // DocumentItemTax straight off this column.
      priceBeforeTax: Value(cartNotifier.netUnitPriceFor(item)),
      // Store ONLY the manual item discount here — exactly what the server's
      // CheckoutAsync persists (from pos_order_items.discount), so the column
      // is identical on the originating device and on devices that pull the
      // doc back. The promotion is NOT baked in: it lives in discount_lines
      // and surfaces in the Discount Breakdown. Baking it in here made the
      // promotion show twice (item "Item Disc." column + breakdown) and made
      // local docs disagree with pulled ones. `total`/`taxAmount` already net
      // out the promotion via `lineTotal`, so they're unaffected.
      discount: Value(
        pctItemDiscount ? item.discountInputValue! : item.discount,
      ),
      discountType: Value(pctItemDiscount ? 0 : item.discountType),
      total: Value(lineTotal),
      taxAmount: Value(taxAmt),
      taxRate: Value(combinedRate),
      taxId: Value(firstTaxId),
    );
  }).toList();

  PaymentsTableCompanion paymentRow(SaleTender tender, int index) =>
      PaymentsTableCompanion(
        localId: Value(const Uuid().v4()),
        documentId: Value(orderLocalId),
        paymentTypeId: Value(tender.paymentTypeId),
        amount: Value(tender.amount),
        userId: Value(user.id),
        // A second apart — Drift keeps DateTimes to the second — so the
        // Payments tab lists a split bill's guests in the order they paid.
        // An ordinary sale's single payment is stamped `now`, as it always was.
        date: Value(now.add(Duration(seconds: index))),
        companyId: Value(company.id),
        dateCreated: Value(now),
        sessionLocalId: Value(sessionLocalId),
      );

  await db.insertOfflineDocument(
    document: DocumentsTableCompanion(
      localId: Value(orderLocalId),
      number: Value(docNumber),
      companyId: Value(company.id),
      userId: Value(user.id),
      warehouseId: Value(cartNotifier.effectiveWarehouseId),
      total: Value(total),
      discount: Value(cartState.manualCartDiscount),
      discountType: Value(cartState.manualCartDiscountType),
      customerId: Value(cartState.selectedCustomer?.id),
      orderNumber: Value(orderNum),
      serviceType: Value(cartState.serviceType),
      paidStatus: Value(paidStatus),
      date: Value(now),
      sessionLocalId: Value(sessionLocalId),
      syncStatus: const Value('pending'),
      lastModified: Value(now),
    ),
    items: docItems,
    payment: paymentRow(tenders.first, 0),
    otherPayments: [
      for (var i = 1; i < tenders.length; i++) paymentRow(tenders[i], i),
    ],
    itemModifiers: docItemModifiers,
  );

  // ── Phase 2: persist the normalized discount breakdown ────────────────────
  // Cart-derived lines (manual item/cart, promotion, customer profile) come
  // from buildDiscountLines; the loyalty-points redemption — which lives in
  // the checkout dialog, not cart state — is appended last. Must run BEFORE
  // clearCart() since buildDiscountLines reads the live cart.
  final discountLines = cartNotifier.buildDiscountLines(
    companyId: company.id,
    orderLocalId: orderLocalId,
    documentLocalId: orderLocalId,
    itemLocalIds: docItemLocalIds,
  );
  if (pointsDiscount > 0) {
    discountLines.add(
      DiscountLinesTableCompanion(
        localId: Value(const Uuid().v4()),
        companyId: Value(company.id),
        orderLocalId: Value(orderLocalId),
        documentLocalId: Value(orderLocalId),
        source: const Value(DiscountSource.loyaltyPoints),
        sourceRefId: Value(cartState.selectedCustomer?.id),
        value: Value(pointsUsed), // points redeemed
        valueType: const Value(1), // resolved to money in `amount`
        amount: Value(double.parse(pointsDiscount.toStringAsFixed(4))),
        sequence: Value(discountLines.length),
        label: const Value('Loyalty points'),
        syncStatus: const Value('pending'),
        lastModified: Value(now),
      ),
    );
  }
  await db.replaceDiscountLines(
    orderLocalId: orderLocalId,
    documentLocalId: orderLocalId,
    lines: discountLines,
  );

  // Read the persisted lines back as rows to itemize on the receipt. Loyalty
  // is excluded here because the receipt already prints a "Points Used" row.
  final receiptDiscountLines = toReceiptDiscountLines(
    await db.getDiscountLinesForDocument(orderLocalId),
    currencySymbol,
    includeLoyalty: false,
  );

  // Local-only counter bump — replaces the old syncLatestOrderNumber API
  // call. Phase 5 can reconcile with the server's official sequence after
  // BatchSync push if a global counter is needed across devices.
  final nextOrderNum = ref.read(dailyOrderNumberProvider) + 1;
  ref.read(dailyOrderNumberProvider.notifier).state = nextOrderNum;

  // Clear cart now that the order is durably saved.
  cartNotifier.clearCart();

  // A booking's order was just paid — mark the reservation Completed
  // (status 4) so it leaves the In-Service list instead of lingering there.
  // Offline-first: the flip is written to Drift now (allBookingsProvider is a
  // Drift stream, so the calendar updates at once) and the sync pushes
  // /Bookings/UpdateStatus. Best-effort — a booking-status hiccup must never
  // fail an already-banked sale. bookingId is read from the captured
  // cartState, so clearCart() above doesn't erase it.
  final paidBookingId = cartState.bookingId;
  if (paidBookingId != null) {
    try {
      await db.setBookingStatusLocal(paidBookingId, 4); // 4 = Completed
    } catch (e) {
      debugPrint('mark booking $paidBookingId completed on pay failed — $e');
    }
  }

  return BankedSale(
    documentLocalId: orderLocalId,
    documentNumber: docNumber,
    cartState: cartState,
    receiptDiscountLines: receiptDiscountLines,
  );
}

/// Earns the sale's loyalty points and takes off any it redeemed, for a real
/// (non walk-in) customer when the loyalty programme is on. Returns the points
/// earned and the card's new balance for the receipt, or null when the sale
/// earns nothing.
///
/// Earned on [grandTotal] — the bill BEFORE any points were redeemed — as the
/// ordinary checkout always has.
Future<({double earned, double balance})?> settleLoyaltyPoints(
  WidgetRef ref, {
  required Map<String, String> settings,
  required Customer? customer,
  required double grandTotal,
  required double pointsUsed,
}) async {
  if (settings[SettingKeys.loyaltyEnabled]?.toLowerCase() != 'true' ||
      customer == null ||
      customer.code == 'C000') {
    return null;
  }
  final minAmt =
      double.tryParse(settings[SettingKeys.loyaltyMinAmount] ?? '100') ?? 100;
  final ptsPerThreshold =
      double.tryParse(settings[SettingKeys.loyaltyPointsPerThreshold] ?? '10') ??
      10;
  final earned = minAmt > 0
      ? ((grandTotal / minAmt).floor() * ptsPerThreshold).toDouble()
      : 0.0;
  final loyaltyNotifier = ref.read(loyaltyCardNotifierProvider.notifier);
  await loyaltyNotifier.adjustPoints(customer.id, earned - pointsUsed);
  final updatedCard = await loyaltyNotifier.findByCustomerId(customer.id);
  return (earned: earned, balance: updatedCard?.points ?? 0);
}
