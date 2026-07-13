import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/auth/login_screen.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/currency/currencies_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/settings/device_identity.dart';
import 'package:pos_app/navigation/main_layout.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/cart/discount_display.dart';
import 'package:pos_app/utils/snackbar_helper.dart';
import 'package:pos_app/utils/customer_display_service.dart';
import 'package:pos_app/customer_display/customer_display_provider.dart';
import 'package:pos_app/customer_display/customer_display_state.dart';
import 'package:pos_app/customer/customer_picker_dialog.dart';
import 'package:pos_app/loyalty/loyalty_card_provider.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';

// ---------------------------------------------------------------------------
// Main Dialog
// ---------------------------------------------------------------------------
class PaymentCheckoutDialog extends ConsumerStatefulWidget {
  const PaymentCheckoutDialog({super.key});

  @override
  ConsumerState<PaymentCheckoutDialog> createState() =>
      _PaymentCheckoutDialogState();
}

class _PaymentCheckoutDialogState extends ConsumerState<PaymentCheckoutDialog> {
  // ── Numpad state: ValueNotifier so ONLY the Paid/Change rows rebuild ──
  final _paidNotifier = ValueNotifier<String>('');

  int? _selectedPaymentTypeId;
  bool _isProcessing = false;

  // Loyalty points state
  bool _loyaltyChecked = false;
  double _pointsUsed = 0;
  double _pointsEarned = 0;
  double _pointsBalance = 0;
  double _pointValue = 1.0;
  LoyaltyCardsTableData? _loyaltyCard; // pre-loaded at dialog open
  double get _pointsDiscount => _pointsUsed * _pointValue;
  double get _effectiveTotal =>
      (_grandTotal - _pointsDiscount).clamp(0.0, double.infinity);

  // Snapshot captured once at open — never re-read during numpad input
  late final double _grandTotal;
  late final double _subtotal;
  late final double _taxTotal;
  late final double _totalDiscount;
  // Order-level discount components, captured so the summary can break them out
  // (item-level discounts are shown per item).
  late final double _itemDiscount;     // manual item + promotion, per line
  late final double _customerDiscount; // customer-profile discount
  late final double _cartDiscount;     // whole-order manual discount
  late final List<CartItem> _cartItems;
  late final String _sym;

  // Captured in initState so dispose() never calls ref.read on an unmounted widget.
  late final Map<String, String> _settingsAtOpen;
  late final CustomerDisplayNotifier _displayNotifier;

  @override
  void initState() {
    super.initState();
    _settingsAtOpen = ref.read(appSettingsProvider);
    _displayNotifier = ref.read(customerDisplayProvider.notifier);
    final notifier = ref.read(cartProvider.notifier);
    _grandTotal = ref.read(cartTotalProvider);
    _subtotal = notifier.subtotal;
    _taxTotal = notifier.taxTotal;
    // discountTotal already includes the per-item promotion, so it must NOT be
    // added again (that double-counted the promo in the displayed total).
    _itemDiscount = notifier.discountTotal;
    _customerDiscount = notifier.customerDiscountAmount;
    _cartDiscount = notifier.manualCartDiscountAmount;
    _totalDiscount = _itemDiscount + _customerDiscount + _cartDiscount;
    _cartItems = List.unmodifiable(ref.read(cartProvider).items);
    _sym = ref.read(currencySymbolProvider);
    _paidNotifier.value = '0';
    _pointValue = double.tryParse(
            _settingsAtOpen[SettingKeys.loyaltyPointValue] ?? '1.0') ??
        1.0;

    // Show the order total on the customer display as soon as the dialog opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider);
      // Serial VFD display
      CustomerDisplayService.showTotal(
        settings: settings,
        total: _grandTotal,
        currencySymbol: _sym,
      );
      // Customer display state machine — transitions to paymentPending
      ref.read(customerDisplayProvider.notifier).showPayment(_grandTotal);
      // Pre-load loyalty card so the info row shows immediately
      _loadLoyaltyCard();
    });
  }

  @override
  void dispose() {
    CustomerDisplayService.showWelcome(settings: _settingsAtOpen);
    if (_displayNotifier.state.status == CustomerDisplayStatus.paymentPending) {
      // Defer the provider write — Riverpod forbids state mutation inside dispose
      // because the widget tree is still being finalized at that point.
      Future.microtask(_displayNotifier.cancelPayment);
    }
    _paidNotifier.dispose();
    super.dispose();
  }

  // ── Loyalty card pre-load ─────────────────────────────────────────────────
  Future<void> _loadLoyaltyCard() async {
    if (_settingsAtOpen[SettingKeys.loyaltyEnabled]?.toLowerCase() != 'true') {
      return;
    }
    final customer = ref.read(cartProvider).selectedCustomer;
    if (customer == null || customer.code == 'C000') return;
    final card = await ref
        .read(loyaltyCardNotifierProvider.notifier)
        .findByCustomerId(customer.id);
    if (mounted && card != null && card.points > 0) {
      setState(() => _loyaltyCard = card);
    }
  }

  // ── Loyalty redemption dialog (user-initiated from the info row) ──────────
  Future<void> _showLoyaltyDialog(BuildContext ctx) async {
    final card = _loyaltyCard;
    if (card == null) return;
    _loyaltyChecked = true; // prevents _handleLoyaltyStep from firing again
    final customer = ref.read(cartProvider).selectedCustomer;
    final result = await showDialog<double>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _LoyaltyPointsDialog(
        customerName: customer?.name ?? '',
        currentPoints: card.points,
        pointValue: _pointValue,
        maxUsable: _grandTotal,
      ),
    );
    if (result != null && mounted) {
      setState(() => _pointsUsed = result);
    }
  }

  // ── Numpad logic ──────────────────────────────────────────────────────────
  void _onKey(String key) {
    final cur = _paidNotifier.value;
    String next;
    switch (key) {
      case '⌫':
        next = cur.length > 1 ? cur.substring(0, cur.length - 1) : '0';
        break;
      case 'C':
        next = '0';
        break;
      case '.':
        next = cur.contains('.') ? cur : '$cur.';
        break;
      case '00':
        next = cur == '0' ? '0' : '${cur}00';
        break;
      default: // digit
        next = cur == '0' ? key : '$cur$key';
    }
    // Cap at 2 decimal places
    final parts = next.split('.');
    if (parts.length > 1 && parts[1].length > 2) return;
    _paidNotifier.value = next;
  }

  double get _paid => double.tryParse(_paidNotifier.value) ?? 0;

  // ── Loyalty points step (runs once, before checkout starts) ──────────────
  Future<void> _handleLoyaltyStep(BuildContext ctx) async {
    if (_loyaltyChecked) return;
    _loyaltyChecked = true;

    if (_settingsAtOpen[SettingKeys.loyaltyEnabled]?.toLowerCase() != 'true') {
      return;
    }
    final customer = ref.read(cartProvider).selectedCustomer;
    if (customer == null || customer.code == 'C000') return;

    final card = await ref
        .read(loyaltyCardNotifierProvider.notifier)
        .findByCustomerId(customer.id);
    if (card == null || card.points <= 0) return;
    if (!ctx.mounted) return;

    final result = await showDialog<double>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _LoyaltyPointsDialog(
        customerName: customer.name,
        currentPoints: card.points,
        pointValue: _pointValue,
        maxUsable: _grandTotal,
      ),
    );
    if (result != null && result > 0 && mounted) {
      setState(() => _pointsUsed = result);
    }
  }

  // ── Checkout ──────────────────────────────────────────────────────────────
  Future<void> _complete(BuildContext ctx) async {
    if (_selectedPaymentTypeId == null) return;

    // Loyalty step runs once before processing, while UI is still interactive.
    await _handleLoyaltyStep(ctx);
    if (!mounted) return;

    setState(() => _isProcessing = true);

    final user = ref.read(currentUserProvider);
    final company = ref.read(selectedCompanyProvider);
    if (company == null || user == null) {
      setState(() => _isProcessing = false);
      return;
    }

    // Capture everything before checkout clears the cart
    final orderNum = ref.read(cartProvider).orderNumber;
    final payTypes = ref.read(allPaymentTypesProvider).asData?.value ?? [];
    final selectedPayType = payTypes
        .where((p) => p.id == _selectedPaymentTypeId)
        .firstOrNull;
    final payName = selectedPayType?.name;

    // Rule 1: block checkout if the payment type requires a real customer.
    // The default walk-in customer has code "C000" — that is not sufficient.
    if (selectedPayType?.isCustomerRequired == true) {
      final customer = ref.read(cartProvider).selectedCustomer;
      if (customer == null || customer.code == 'C000') {
        setState(() => _isProcessing = false);
        if (ctx.mounted) {
          await showDialog<void>(
            context: ctx,
            builder: (c) => AlertDialog(
              icon: Icon(Icons.block, color: context.dangerColor, size: 36),
              title: const Text('Transaction Blocked'),
              content: const Text(
                'Credit payment requires a selected customer.\n\n'
                'Please choose a customer before completing this transaction.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    Uint8List? logoBytes;
    final logoB64 = company.logo;
    if (logoB64 != null && logoB64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoB64);
      } catch (_) {}
    }
    final appSettings = ref.read(appSettingsProvider);

    try {
      // Cap at effectiveTotal (grand total minus any points discount).
      final amountToSave = _paid.clamp(0.0, _effectiveTotal);

      // ── OFFLINE CHECKOUT (Phase 4) ───────────────────────────────────────
      // No Dio. No network. The order + items go straight into local SQLite
      // as `syncStatus: 'pending'`. Phase 5's BatchSync push reconciles with
      // the server when connectivity returns.
      //
      // INVARIANT: the order / document / payment / discount rows below are all
      // written as `'pending'` — NOT `'pending_create'`. They are created
      // server-side by the BatchSync push, so pushPendingDocuments /
      // pushPendingPayments deliberately skip them; writing `'pending_create'`
      // here would double-create them. See `lib/sync/sync_status.dart`.
      final cartState = ref.read(cartProvider);
      final cartNotifier = ref.read(cartProvider.notifier);
      final db = ref.read(appDatabaseProvider);
      final now = DateTime.now().toUtc();

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

      // One stable line id per cart line, SHARED by the pos_order_item, the
      // document_item, and the discount_lines.itemLocalId. BatchSync echoes each
      // created DocumentItem's server id back keyed by this id, so the local
      // document_items row gets its serverId stamped (without which its later
      // edits/deletes could never sync). It also keeps duplicate-product lines
      // distinct end-to-end.
      final lineLocalIds = {
        for (final item in _cartItems) item.cartItemId: const Uuid().v4(),
      };

      // Build items first — orderId is the same whether we insert or update.
      final itemCompanions = _cartItems.map((item) {
        final lineTotal =
            (item.price - item.discount - item.promotionalDiscount) *
            item.quantity;
        final summedRate = item.appliedTaxes
            .where((t) => !t.isFixed)
            .fold<double>(0, (sum, t) => sum + t.rate);
        // Compute per-tax amounts so SyncManager can pass CheckoutItemDto.Taxes
        // to the server, creating DocumentItemTax rows during BatchSync.
        final taxEntries = item.appliedTaxes.map((t) {
          final amount =
              t.isFixed ? t.rate : (t.rate / 100 * lineTotal);
          return {'id': t.id, 'amount': amount};
        }).toList();
        final taxesJsonStr =
            taxEntries.isEmpty ? null : jsonEncode(taxEntries);
        // A %-entered item discount is stored as (type 0, the % value) rather
        // than its resolved money, so the saved document line reads "50%" not
        // "Fixed 5". Totals are identical — the backend BatchSync applies the
        // discount type-aware. Skipped when a promotion is mixed in, since one
        // discount field can't hold both a % and the promo's money.
        final pctItemDiscount = item.discountInputType == 0 &&
            item.discountInputValue != null &&
            item.promotionalDiscount == 0;
        return PosOrderItemsTableCompanion(
          localId: Value(lineLocalIds[item.cartItemId]!),
          orderId: Value(orderLocalId),
          productId: Value(item.productId),
          quantity: Value(item.quantity),
          unitPrice: Value(item.price),
          discount: Value(pctItemDiscount
              ? item.discountInputValue!
              : item.discount + item.promotionalDiscount),
          discountType: Value(pctItemDiscount ? 0 : item.discountType),
          taxRate: Value(summedRate),
          taxesJson: Value(taxesJsonStr),
          comment: Value(item.comment),
          warehouseId:
              Value(item.warehouseId ?? cartNotifier.effectiveWarehouseId),
          syncStatus: const Value('pending'),
        );
      }).toList();

      if (existingLocalId != null) {
        // Existing open order (server-originated or previously synced) —
        // update the header row and replace its items in a single transaction.
        await db.completeExistingOrder(
          existingLocalId,
          PosOrdersTableCompanion(
            number: Value(docNumber),
            closedAt: Value(now),
            status: const Value(1),
            total: Value(_effectiveTotal),
            discount: Value(cartState.manualCartDiscount),
            warehouseId: Value(cartNotifier.effectiveWarehouseId),
            customerId: Value(cartState.selectedCustomer?.id),
            serviceStatus: Value(cartState.serviceStatus),
            paymentTypeId: Value(_selectedPaymentTypeId!),
            amountPaid: Value(amountToSave.toDouble()),
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
            tableId: Value(cartState.floorPlanTableId),
            customerId: Value(cartState.selectedCustomer?.id),
            serviceType: Value(cartState.serviceType),
            serviceStatus: Value(cartState.serviceStatus),
            orderName: Value(orderNum),
            openedAt: Value(now),
            closedAt: Value(now),
            status: const Value(1),
            total: Value(_effectiveTotal),
            discount: Value(cartState.manualCartDiscount),
            warehouseId: Value(cartNotifier.effectiveWarehouseId),
            paymentTypeId: Value(_selectedPaymentTypeId!),
            amountPaid: Value(amountToSave.toDouble()),
            syncStatus: const Value('pending'),
            lastModified: Value(now),
          ),
          itemCompanions,
        );
      }

      // ── Local inventory deduction ─────────────────────────────────────────
      // Mirror the server-side delta logic so local stock stays accurate.
      // Stock is verified up-front in the menu / cart when items are added, so
      // checkout NEVER blocks here — it just deducts (allowing negative if the
      // item somehow went out of stock) and proceeds. This matches the server's
      // offline-replay behaviour (BatchSync replays sales with AllowNegativeStock).
      await db.deductStockForCheckout(
        items: _cartItems
            .map((item) => (
                  productId:   item.productId,
                  quantity:    item.quantity,
                  warehouseId: item.warehouseId ??
                      cartNotifier.effectiveWarehouseId,
                  isService:   item.isService,
                  productName: item.productName,
                ))
            .toList(),
        allowNegative: true,
      );

      // ── Create Document + Payment locally ────────────────────────────────
      // The Document localId = orderLocalId so sync_manager can link it to
      // the server Document returned by CheckoutPosOrderCommand after BatchSync.
      // cartItemId → document_item localId, so discount_lines link to the
      // permanent document record (the source of truth for receipts/reports).
      final docItemLocalIds = <String, String>{};
      final docItems = _cartItems.map((item) {
        // Same id as this line's pos_order_item, so BatchSync can stamp the
        // returned DocumentItem serverId onto this exact row.
        final docItemLocalId = lineLocalIds[item.cartItemId]!;
        docItemLocalIds[item.cartItemId] = docItemLocalId;
        final lineTotal =
            (item.price - item.discount - item.promotionalDiscount) *
            item.quantity;
        final pctTaxes = item.appliedTaxes.where((t) => !t.isFixed);
        final taxAmt =
            pctTaxes.fold<double>(0, (s, t) => s + t.rate / 100 * lineTotal);
        // Persist the tax-base price + the applied tax so the document editor's
        // Edit-Item dialog can load real values (it was showing 0 / "No tax"
        // because these were never written). The editor is single-tax, so carry
        // the combined % rate and the first applied tax id.
        final combinedRate =
            pctTaxes.fold<double>(0, (s, t) => s + t.rate);
        final firstTaxId =
            item.appliedTaxes.isNotEmpty ? item.appliedTaxes.first.id : null;
        // Mirror the pos_order_items choice so local + pulled docs agree: keep a
        // %-entered discount as (type 0, the % value) instead of the resolved
        // money, so the Edit-Item dialog shows "50%". `total` (lineTotal) stays
        // authoritative and unchanged.
        final pctItemDiscount = item.discountInputType == 0 &&
            item.discountInputValue != null &&
            item.promotionalDiscount == 0;
        return DocumentItemsTableCompanion(
          localId:      Value(docItemLocalId),
          documentId:   Value(orderLocalId),
          productId:    Value(item.productId),
          quantity:     Value(item.quantity),
          unitPrice:    Value(item.price),
          priceBeforeTax: Value(item.price),
          // Store ONLY the manual item discount here — exactly what the server's
          // CheckoutAsync persists (from pos_order_items.discount), so the column
          // is identical on the originating device and on devices that pull the
          // doc back. The promotion is NOT baked in: it lives in discount_lines
          // and surfaces in the Discount Breakdown. Baking it in here made the
          // promotion show twice (item "Item Disc." column + breakdown) and made
          // local docs disagree with pulled ones. `total`/`taxAmount` already net
          // out the promotion via `lineTotal`, so they're unaffected.
          discount:     Value(pctItemDiscount
              ? item.discountInputValue!
              : item.discount),
          discountType: Value(pctItemDiscount ? 0 : item.discountType),
          total:        Value(lineTotal),
          taxAmount:    Value(taxAmt),
          taxRate:      Value(combinedRate),
          taxId:        Value(firstTaxId),
        );
      }).toList();

      final markAsPaidFlag = (payTypes
              .where((p) => p.id == _selectedPaymentTypeId)
              .firstOrNull
              ?.markAsPaid ??
          true)
          ? 1
          : 0;

      await db.insertOfflineDocument(
        document: DocumentsTableCompanion(
          localId:        Value(orderLocalId),
          number:         Value(docNumber),
          companyId:      Value(company.id),
          userId:         Value(user.id),
          warehouseId:    Value(cartNotifier.effectiveWarehouseId),
          total:          Value(_effectiveTotal),
          discount:       Value(cartState.manualCartDiscount),
          discountType:   Value(cartState.manualCartDiscountType),
          customerId:     Value(cartState.selectedCustomer?.id),
          orderNumber:    Value(orderNum),
          serviceType:    Value(cartState.serviceType),
          paidStatus:     Value(markAsPaidFlag),
          date:           Value(now),
          syncStatus:     const Value('pending'),
          lastModified:   Value(now),
        ),
        items: docItems,
        payment: PaymentsTableCompanion(
          localId:       Value(const Uuid().v4()),
          documentId:    Value(orderLocalId),
          paymentTypeId: Value(_selectedPaymentTypeId!),
          amount:        Value(amountToSave.toDouble()),
          userId:        Value(user.id),
          date:          Value(now),
          companyId:     Value(company.id),
          dateCreated:   Value(now),
        ),
      );

      // ── Phase 2: persist the normalized discount breakdown ────────────────
      // Cart-derived lines (manual item/cart, promotion, customer profile) come
      // from buildDiscountLines; the loyalty-points redemption — which lives in
      // this dialog, not cart state — is appended last. Must run BEFORE
      // clearCart() since buildDiscountLines reads the live cart.
      final discountLines = cartNotifier.buildDiscountLines(
        companyId: company.id,
        orderLocalId: orderLocalId,
        documentLocalId: orderLocalId,
        itemLocalIds: docItemLocalIds,
      );
      if (_pointsDiscount > 0) {
        discountLines.add(DiscountLinesTableCompanion(
          localId: Value(const Uuid().v4()),
          companyId: Value(company.id),
          orderLocalId: Value(orderLocalId),
          documentLocalId: Value(orderLocalId),
          source: const Value(DiscountSource.loyaltyPoints),
          sourceRefId: Value(cartState.selectedCustomer?.id),
          value: Value(_pointsUsed), // points redeemed
          valueType: const Value(1), // resolved to money in `amount`
          amount: Value(double.parse(_pointsDiscount.toStringAsFixed(4))),
          sequence: Value(discountLines.length),
          label: const Value('Loyalty points'),
          syncStatus: const Value('pending'),
          lastModified: Value(now),
        ));
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
        _sym,
        includeLoyalty: false,
      );

      // Local-only counter bump — replaces the old syncLatestOrderNumber API
      // call. Phase 5 can reconcile with the server's official sequence after
      // BatchSync push if a global counter is needed across devices.
      final nextOrderNum = ref.read(dailyOrderNumberProvider) + 1;
      ref.read(dailyOrderNumberProvider.notifier).state = nextOrderNum;

      // Clear cart now that the order is durably saved.
      cartNotifier.clearCart();

      // ── Loyalty points: earn and deduct ──────────────────────────────────
      final loyaltyCustomer = cartState.selectedCustomer;
      if (_settingsAtOpen[SettingKeys.loyaltyEnabled]?.toLowerCase() == 'true' &&
          loyaltyCustomer != null &&
          loyaltyCustomer.code != 'C000') {
        final minAmt =
            double.tryParse(_settingsAtOpen[SettingKeys.loyaltyMinAmount] ?? '100') ?? 100;
        final ptsPerThreshold =
            double.tryParse(_settingsAtOpen[SettingKeys.loyaltyPointsPerThreshold] ?? '10') ?? 10;
        final earned = minAmt > 0
            ? ((_grandTotal / minAmt).floor() * ptsPerThreshold).toDouble()
            : 0.0;
        final loyaltyNotifier = ref.read(loyaltyCardNotifierProvider.notifier);
        await loyaltyNotifier.adjustPoints(loyaltyCustomer.id, earned - _pointsUsed);
        final updatedCard = await loyaltyNotifier.findByCustomerId(loyaltyCustomer.id);
        if (mounted) {
          setState(() {
            _pointsEarned = earned;
            _pointsBalance = updatedCard?.points ?? 0;
          });
        }
      }

      // Customer display: checkoutSuccess state shows cash+change for 5 s,
      // then the notifier auto-resets to idle.
      ref.read(customerDisplayProvider.notifier).completeCheckout(
        total: _effectiveTotal,
        amountPaid: _paid,
        changeDue: (_paid - _effectiveTotal).clamp(0.0, double.infinity),
      );

      if (!mounted) return;

      // ── Resolve print settings ────────────────────────────────────
      final autoprint =
          (appSettings[SettingKeys.autoprint] ?? '').toLowerCase() == 'true';
      final showPrintDialog =
          (appSettings[SettingKeys.displayReceiptPrintDialog] ?? '')
                  .toLowerCase() ==
              'true';

      void doPrint() => ReceiptPrinterService()
          .printCartReceipt(
            company: company,
            cashier: user,
            customer: ref.read(cartProvider).selectedCustomer,
            orderNumber: orderNum ?? 'WALK-IN',
            printTime: DateTime.now(),
            items: _cartItems,
            subtotal: _subtotal,
            totalDiscount: _totalDiscount,
            discountLines: receiptDiscountLines,
            totalTax: _taxTotal,
            grandTotal: _grandTotal,
            currencySymbol: _sym,
            paymentTypeName: payName,
            amountPaid: _paid,
            logoBytes: logoBytes,
            roleSettings: appSettings,
            pointsUsed: _pointsUsed,
            pointsEarned: _pointsEarned,
            pointsBalance: _pointsBalance,
            pointValue: _pointValue,
          )
          .catchError((_) {});

      if (autoprint) {
        doPrint();
      } else if (showPrintDialog && ctx.mounted) {
        final wantsPrint = await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            icon: Icon(
              Icons.check_circle_outline,
              color: context.successColor,
              size: 36,
            ),
            title: const Text('Transaction Successful'),
            content: const Text('Would you like to print a receipt?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Print Receipt'),
              ),
            ],
          ),
        );
        if (wantsPrint == true) doPrint();
      }

      if (!ctx.mounted) return;

      // ── Close checkout dialog ─────────────────────────────────────
      // Capture the navigator BEFORE popping. Once the dialog closes, `ctx` is
      // being torn down, so reusing it for the post-checkout navigation below
      // (multi-user auto-logout) risks a "deactivated widget's ancestor" throw.
      // The NavigatorState itself outlives the dialog route, so it's safe to hold.
      final navigator = Navigator.of(ctx);
      navigator.pop();

      // ── Background sync — create Document + Payment on server immediately ─
      // Fire-and-forget: the local order row is already saved as 'pending'.
      // If this sync fails the sync button / connectivity watcher will retry.
      ref.read(syncStateProvider.notifier).sync().catchError((_) {});

      // The old syncLatestOrderNumber API call is gone — Phase 4 is offline-only.
      // The local counter bump above (dailyOrderNumberProvider) keeps the next
      // order number unique on this device until Phase 5 reconciles with the
      // server's official sequence.

      // Optional success sound
      if (appSettings[SettingKeys.enableSounds]?.toLowerCase() == 'true') {
        SystemSound.play(SystemSoundType.click);
      }

      // Single-user mode: stay logged in. Multi-user mode: auto-logout so the
      // next cashier can log in.
      final singleUser =
          appSettings[SettingKeys.singleUser]?.toLowerCase() != 'false';
      if (!singleUser && mounted) {
        ref.invalidate(currentUserProvider);
        ref.read(cartProvider.notifier).clearCart();
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
        return;
      }

      // Return to the user's configured default screen, validated against the
      // feature flags so we never land on a disabled (empty) tab — the source
      // of the post-checkout black screen.
      final nextIndex = resolveDefaultScreenIndex(appSettings);

      // The checkout dialog was already closed above (navigator.pop()).
      // Just swap the underlying MainLayout tab reactively — no extra pop (a
      // second pop would remove MainLayout itself → black screen) and no
      // MainLayout rebuild, so the startup cash-in hook never re-fires.
      if (mounted) {
        ref.read(mainNavigationIndexProvider.notifier).state = nextIndex;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showAppSnackbar(context, ref, 'Checkout error: $e', isError: true);
      }
    }
  }

  // ── Customer picker (reused from menu_screen pattern) ─────────────────────
  void _clearCustomer() {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    final customers = ref.read(allCustomersProvider).asData?.value ?? [];
    final defaultCustomer = customers.firstWhere(
      (c) => c.code == 'C000',
      orElse: () => customers.first,
    );
    ref.read(currentCustomerProvider.notifier).setCustomer(defaultCustomer);
    if (companyId != null) {
      ref.read(cartProvider.notifier).setCustomer(companyId, defaultCustomer);
    }
  }

  void _pickCustomer(BuildContext ctx, List<Customer> customers) async {
    final selected = await showCustomerPickerDialog(
      ctx,
      customers,
      selectedId: ref.read(cartProvider).selectedCustomer?.id,
    );
    if (selected == null || !mounted) return;
    final companyId = ref.read(selectedCompanyProvider)?.id;
    ref.read(currentCustomerProvider.notifier).setCustomer(selected);
    if (companyId != null) {
      ref.read(cartProvider.notifier).setCustomer(companyId, selected);
    }
    // Reset loyalty state for the newly selected customer
    _loyaltyChecked = false;
    setState(() {
      _loyaltyCard = null;
      _pointsUsed = 0;
    });
    _loadLoyaltyCard();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payTypesAsync = ref.watch(allPaymentTypesProvider);
    final customer = ref.watch(cartProvider).selectedCustomer;
    final allCustomersAsync = ref.watch(allCustomersProvider);

    // Auto-select first payment type once loaded
    payTypesAsync.whenData((types) {
      if (_selectedPaymentTypeId == null && types.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedPaymentTypeId = types.first.id);
        });
      }
    });

    final selectedPayType = payTypesAsync.asData?.value
        .where((p) => p.id == _selectedPaymentTypeId)
        .firstOrNull;
    final markAsPaid = selectedPayType?.markAsPaid ?? true;

    final showItems =
        ref
            .read(appSettingsProvider)[SettingKeys.showItemsOnPaymentForm]
            ?.toLowerCase() !=
        'false';

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── LEFT: Order Summary (conditionally shown) ─────────────────
            if (showItems) ...[
              _OrderSummaryColumn(
                items: _cartItems,
                subtotal: _subtotal,
                taxTotal: _taxTotal,
                itemDiscount: _itemDiscount,
                customerDiscount: _customerDiscount,
                cartDiscount: _cartDiscount,
                grandTotal: _grandTotal,
                pointsDiscount: _pointsDiscount,
                sym: _sym,
              ),
              VerticalDivider(
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            ],

            // ── CENTER: Payment Methods ────────────────────────────────────
            _PaymentMethodsColumn(
              payTypesAsync: payTypesAsync,
              selectedId: _selectedPaymentTypeId,
              onSelect: (id) => setState(() => _selectedPaymentTypeId = id),
            ),
            VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),

            // ── RIGHT: Numpad & Totals ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer button bar
                  _CustomerBar(
                    customer: customer,
                    allCustomersAsync: allCustomersAsync,
                    onPick: _pickCustomer,
                    onCancel: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                  ),
                  const Divider(height: 1),

                  // Totals display
                  _TotalsDisplay(
                    grandTotal: _effectiveTotal,
                    sym: _sym,
                    paidNotifier: _paidNotifier,
                    markAsPaid: markAsPaid,
                  ),
                  const Divider(height: 1),

                  // Rich customer card — only for real (non-walk-in) customers
                  if (customer != null && customer.code != 'C000')
                    _CustomerDetailCard(
                      customer: customer,
                      onRemove: _clearCustomer,
                    ),

                  // Loyalty info row — visible when the customer has points
                  if (_loyaltyCard != null)
                    _LoyaltyInfoRow(
                      card: _loyaltyCard!,
                      pointValue: _pointValue,
                      pointsUsed: _pointsUsed,
                      sym: _sym,
                      onTap: () => _showLoyaltyDialog(context),
                    ),

                  _Numpad(
                    onKey: _onKey,
                    onComplete: _selectedPaymentTypeId != null && !_isProcessing
                        ? () => _complete(context)
                        : null,
                    isProcessing: _isProcessing,
                    paidNotifier: _paidNotifier,
                    grandTotal: _effectiveTotal,
                    markAsPaid: markAsPaid,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left column: order summary
// ---------------------------------------------------------------------------
class _OrderSummaryColumn extends ConsumerWidget {
  final List<CartItem> items;
  final double subtotal, taxTotal, grandTotal, pointsDiscount;
  final double itemDiscount, customerDiscount, cartDiscount;
  final String sym;

  const _OrderSummaryColumn({
    required this.items,
    required this.subtotal,
    required this.taxTotal,
    required this.itemDiscount,
    required this.customerDiscount,
    required this.cartDiscount,
    required this.grandTotal,
    required this.pointsDiscount,
    required this.sym,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final dualEnabled =
        settings[SettingKeys.dualCurrencyEnabled]?.toLowerCase() == 'true';
    final dualSym = settings[SettingKeys.dualCurrencySymbol] ?? '€';
    final dualRate =
        double.tryParse(settings[SettingKeys.dualCurrencyRate] ?? '1.0') ?? 1.0;
    final discountBeforeTax =
        settings[SettingKeys.discountApplyRule] == 'Before tax';
    // When the shop displays/prints tax-inclusive, item lines and the subtotal
    // fold tax in (mirrors the cart); otherwise tax is shown as its own line.
    final taxIncluded =
        settings[SettingKeys.displayAndPrintTaxIncluded]?.toLowerCase() !=
            'false';
    // Subtotal incl. tax, already net of item-level discounts:
    //   grossSubtotal − customer − cart = grandTotal.
    final grossSubtotal = subtotal - itemDiscount + taxTotal;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final promoNames = {
      for (final p in (ref.watch(activePromotionsProvider).value ?? const []))
        p.id: p.name,
    };

    // One indented detail line under an item (a discount or a tax).
    Widget detail(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(value,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: color ?? muted)),
            ],
          ),
        );

    String fmtQty(double q) =>
        q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
    String fmtRate(double r) =>
        r % 1 == 0 ? r.toInt().toString() : r.toString();

    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: theme.colorScheme.surfaceContainer,
            child: Text(
              'Order Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Items list
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: theme.colorScheme.outlineVariant),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final unitNet =
                      item.price - item.discount - item.promotionalDiscount;
                  final lineNet = unitNet * item.quantity;
                  // Tax base mirrors the cart's rule: "Before tax" taxes the
                  // discounted price; "After tax" taxes the full price.
                  final taxBase = (discountBeforeTax ? unitNet : item.price) *
                      item.quantity;
                  final lineTax = item.appliedTaxes.fold<double>(
                    0,
                    (s, t) => s +
                        (t.isFixed
                            ? t.rate * item.quantity
                            : taxBase * (t.rate / 100)),
                  );
                  // Honor the "display tax-included" setting: the line total and
                  // the per-unit price fold tax in, and the tax rows below become
                  // informational ("incl.") rather than an added amount.
                  final lineShown = taxIncluded ? lineNet + lineTax : lineNet;
                  final unitShown = taxIncluded && item.quantity > 0
                      ? item.price + lineTax / item.quantity
                      : item.price;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + line total
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.productName,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$sym ${lineShown.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${fmtQty(item.quantity)} × $sym ${unitShown.toStringAsFixed(2)}',
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                        // ── Per-item discounts ──
                        if (item.discount > 0)
                          detail(
                            'Item discount',
                            '- $sym ${(item.discount * item.quantity).toStringAsFixed(2)}',
                            color: context.successColor,
                          ),
                        if (item.promotionalDiscount > 0)
                          detail(
                            item.promotionId != null
                                ? (promoNames[item.promotionId] ?? 'Promotion')
                                : 'Promotion',
                            '- $sym ${(item.promotionalDiscount * item.quantity).toStringAsFixed(2)}',
                            color: context.successColor,
                          ),
                        // ── Per-item taxes (informational when tax-included) ──
                        ...item.appliedTaxes.map((t) {
                          final amt = t.isFixed
                              ? t.rate * item.quantity
                              : taxBase * (t.rate / 100);
                          final name = t.isFixed
                              ? t.name
                              : '${t.name} (${fmtRate(t.rate)}%)';
                          final label = taxIncluded ? 'incl. $name' : name;
                          return detail(
                              label, '$sym ${amt.toStringAsFixed(2)}');
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Summary footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              children: [
                // Tax-included (mirrors the cart): subtotal already folds tax in
                // AND is net of item-level discounts, so only order-level
                // discounts are listed and tax is shown as an informational line.
                if (taxIncluded) ...[
                  _SummaryRow('Subtotal (incl. tax)', grossSubtotal, sym, theme),
                  if (customerDiscount > 0)
                    _SummaryRow(
                        'Customer discount', -customerDiscount, sym, theme,
                        color: context.successColor),
                  if (cartDiscount > 0)
                    _SummaryRow('Cart discount', -cartDiscount, sym, theme,
                        color: context.successColor),
                  if (taxTotal > 0)
                    _SummaryRow('Tax (incl.)', taxTotal, sym, theme,
                        color: muted),
                ] else ...[
                  // Tax-exclusive: gross subtotal, then every discount, then tax.
                  _SummaryRow('Subtotal', subtotal, sym, theme),
                  if (itemDiscount > 0)
                    _SummaryRow('Item discounts', -itemDiscount, sym, theme,
                        color: context.successColor),
                  if (customerDiscount > 0)
                    _SummaryRow(
                        'Customer discount', -customerDiscount, sym, theme,
                        color: context.successColor),
                  if (cartDiscount > 0)
                    _SummaryRow('Cart discount', -cartDiscount, sym, theme,
                        color: context.successColor),
                  if (taxTotal > 0) _SummaryRow('Taxes', taxTotal, sym, theme),
                ],
                if (pointsDiscount > 0)
                  _SummaryRow(
                    'Points Redeemed',
                    -pointsDiscount,
                    sym,
                    theme,
                    color: context.successColor,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$sym ${(grandTotal - pointsDiscount).toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (dualEnabled && dualRate > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '≈ ${((grandTotal - pointsDiscount) * dualRate).toStringAsFixed(2)} $dualSym',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget-factory function, intentionally PascalCase so call sites read like a widget.
// ignore: non_constant_identifier_names
Widget _SummaryRow(
  String label,
  double amount,
  String sym,
  ThemeData theme, {
  Color? color,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          '$sym ${amount.abs().toStringAsFixed(2)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Center column: payment methods
// ---------------------------------------------------------------------------
class _PaymentMethodsColumn extends ConsumerWidget {
  final AsyncValue<List<PaymentType>> payTypesAsync;
  final int? selectedId;
  final void Function(int) onSelect;

  const _PaymentMethodsColumn({
    required this.payTypesAsync,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final gridCols =
        int.tryParse(settings[SettingKeys.numberOfPaymentTypeRows] ?? '0') ?? 0;
    final useGrid = gridCols > 1;

    return SizedBox(
      width: useGrid ? gridCols * 130.0 : 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: theme.colorScheme.surfaceContainer,
            child: Text(
              'Payment Method',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: payTypesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              data: (types) {
                final enabled = types.where((t) => t.isEnabled).toList();
                final splitButton = Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        debugPrint('Split payments: to be implemented'),
                    icon: const Icon(Icons.call_split, size: 18),
                    label: const Text('Split Payments'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                );

                if (useGrid) {
                  return Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridCols,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              childAspectRatio: 2.4,
                            ),
                            itemCount: enabled.length,
                            itemBuilder: (ctx, i) {
                              final t = enabled[i];
                              return _PaymentTypeButton(
                                type: t,
                                isSelected: selectedId == t.id,
                                onTap: () => onSelect(t.id),
                              );
                            },
                          ),
                        ),
                        splitButton,
                      ],
                    ),
                  );
                }

                return Material(
                  color: Colors.transparent,
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      ...enabled.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _PaymentTypeButton(
                              type: t,
                              isSelected: selectedId == t.id,
                              onTap: () => onSelect(t.id),
                            ),
                          )),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            debugPrint('Split payments: to be implemented'),
                        icon: const Icon(Icons.call_split, size: 18),
                        label: const Text('Split Payments'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTypeButton extends StatelessWidget {
  final PaymentType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentTypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Icon(
                _iconForPayment(type.name),
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForPayment(String name) {
    final n = name.toLowerCase();
    if (n.contains('cash') || n.contains('espèce') || n.contains('espece')) {
      return Icons.payments_rounded;
    }
    if (n.contains('credit') || n.contains('card') || n.contains('carte')) {
      return Icons.credit_card;
    }
    if (n.contains('debit')) return Icons.credit_card_outlined;
    if (n.contains('check') || n.contains('chèque')) return Icons.receipt_long;
    if (n.contains('voucher')) return Icons.confirmation_number;
    if (n.contains('gift')) return Icons.card_giftcard;
    return Icons.payment;
  }
}

// ---------------------------------------------------------------------------
// Customer bar (top of right column)
// ---------------------------------------------------------------------------
class _CustomerBar extends StatelessWidget {
  final Customer? customer;
  final AsyncValue allCustomersAsync;
  final void Function(BuildContext, List<Customer>) onPick;
  final VoidCallback onCancel;

  const _CustomerBar({
    required this.customer,
    required this.allCustomersAsync,
    required this.onPick,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          allCustomersAsync.when(
            loading: () => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (all) {
              final customers = (all as List<dynamic>)
                  .whereType<Customer>()
                  .where((c) => c.isCustomer)
                  .toList();
              return TextButton.icon(
                onPressed: () => onPick(context, customers),
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(
                  customer?.name ?? 'Walk-in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Totals display (Total / Paid / Change)
// Only Paid and Change rows listen to _paidNotifier — Total never rebuilds
// ---------------------------------------------------------------------------
class _TotalsDisplay extends StatelessWidget {
  final double grandTotal;
  final String sym;
  final ValueNotifier<String> paidNotifier;
  final bool markAsPaid;

  const _TotalsDisplay({
    required this.grandTotal,
    required this.sym,
    required this.paidNotifier,
    required this.markAsPaid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Total — static, never rebuilds
          _TotalRow(
            label: 'Total',
            value: '$sym ${grandTotal.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Paid, Change/Remaining — only these rebuild on numpad input
          ValueListenableBuilder<String>(
            valueListenable: paidNotifier,
            builder: (_, raw, __) {
              final paid = double.tryParse(raw) ?? 0;
              final change = (paid - grandTotal).clamp(0.0, double.infinity);
              final remaining = paid < grandTotal ? grandTotal - paid : 0.0;
              return Column(
                children: [
                  _TotalRow(
                    label: 'Paid',
                    value: '$sym ${paid.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    trailing: Icon(
                      Icons.edit,
                      size: 16,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Show "Remaining" for credit/tab types; show "Change" for cash
                  if (!markAsPaid && remaining > 0) ...[
                    _TotalRow(
                      label: 'Remaining',
                      value: '$sym ${remaining.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: context.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    _TotalRow(
                      label: 'Change',
                      value: '$sym ${change.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: change > 0
                            ? context.successColor
                            : theme.colorScheme.onSurface.withAlpha(100),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;
  final Widget? trailing;

  const _TotalRow({
    required this.label,
    required this.value,
    this.style,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(160),
          ),
        ),
        Row(
          children: [
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            Text(value, style: style ?? theme.textTheme.headlineSmall),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Numpad — fully fluid Expanded layout.
// Returns Expanded so it fills all remaining vertical space in the right
// column. No hardcoded pixel sizes anywhere; Flutter sizes buttons to fit.
//
// Grid layout:
//   Row 1: 7  8  9  ⌫
//   Row 2: 4  5  6  C
//   Row 3+4 left (flex 3):  1 2 3 / 00 0 .
//   Row 3+4 right (flex 1): Complete (spans both rows)
// ---------------------------------------------------------------------------
class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback? onComplete;
  final bool isProcessing;
  final ValueNotifier<String> paidNotifier;
  final double grandTotal;
  final bool markAsPaid;

  const _Numpad({
    required this.onKey,
    required this.onComplete,
    required this.isProcessing,
    required this.paidNotifier,
    required this.grandTotal,
    required this.markAsPaid,
  });

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget numKey(String key) => Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onKey(key),
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            key,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    Widget actionKey(String key) => Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onKey(key),
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: key == '⌫'
              ? Icon(
                  Icons.backspace_outlined,
                  size: 26,
                  color: theme.colorScheme.onErrorContainer,
                )
              : Text(
                  key,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
        ),
      ),
    );

    Widget expandedRow(List<Widget> children) => Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: children[i]),
        ],
      ],
    );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            // Row 1: 7  8  9  ⌫
            Expanded(
              child: expandedRow([
                numKey('7'),
                numKey('8'),
                numKey('9'),
                actionKey('⌫'),
              ]),
            ),
            const SizedBox(height: _gap),
            // Row 2: 4  5  6  C
            Expanded(
              child: expandedRow([
                numKey('4'),
                numKey('5'),
                numKey('6'),
                actionKey('C'),
              ]),
            ),
            const SizedBox(height: _gap),
            // Rows 3+4: number grid left, Complete button right (spans both)
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: 3 cols × 2 rows
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Expanded(
                          child: expandedRow([
                            numKey('1'),
                            numKey('2'),
                            numKey('3'),
                          ]),
                        ),
                        const SizedBox(height: _gap),
                        Expanded(
                          child: expandedRow([
                            numKey('00'),
                            numKey('0'),
                            numKey('.'),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _gap),
                  // Right: Complete spans full height of both rows
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: paidNotifier,
                      builder: (_, raw, __) {
                        final paid = double.tryParse(raw) ?? 0;
                        // Credit/tab types (markAsPaid == false) can complete
                        // even when paid amount is less than the grand total.
                        final canPay =
                            (paid >= grandTotal || !markAsPaid) &&
                            onComplete != null;
                        return _CompleteButton(
                          canPay: canPay,
                          isProcessing: isProcessing,
                          onTap: canPay ? onComplete : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final bool canPay;
  final bool isProcessing;
  final VoidCallback? onTap;

  const _CompleteButton({
    required this.canPay,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: canPay ? context.successColor : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: isProcessing
              ? CircularProgressIndicator(
                  color: context.onStatusColor,
                  strokeWidth: 3,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 36,
                      color: canPay
                          ? context.onStatusColor
                          : theme.colorScheme.onSurface.withAlpha(80),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete\nTransaction',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: canPay
                            ? context.onStatusColor
                            : theme.colorScheme.onSurface.withAlpha(80),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Rich customer detail card ─────────────────────────────────────────────────

class _CustomerDetailCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onRemove;

  const _CustomerDetailCard({required this.customer, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final addressParts = <String>[
      if (customer.streetName != null && customer.streetName!.isNotEmpty)
        customer.streetName!,
      if (customer.city != null && customer.city!.isNotEmpty) customer.city!,
    ];
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(left: BorderSide(color: context.infoColor, width: 4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: context.infoColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (address != null)
                  Text(
                    'Address: $address',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                if (customer.taxNumber != null &&
                    customer.taxNumber!.isNotEmpty)
                  Text(
                    'Tax No.: ${customer.taxNumber}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
            onPressed: onRemove,
            tooltip: 'Remove customer',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loyalty info row (visible in the right column before checkout is confirmed)
// ---------------------------------------------------------------------------
class _LoyaltyInfoRow extends StatelessWidget {
  final LoyaltyCardsTableData card;
  final double pointValue;
  final double pointsUsed;
  final String sym;
  final VoidCallback onTap;

  const _LoyaltyInfoRow({
    required this.card,
    required this.pointValue,
    required this.pointsUsed,
    required this.sym,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final discount = pointsUsed * pointValue;
    final hasRedeemed = pointsUsed > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasRedeemed
              ? cs.tertiaryContainer.withValues(alpha: 0.35)
              : cs.surfaceContainerHigh,
          border: Border(
            left: BorderSide(color: context.warningColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(Icons.loyalty, color: context.warningColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${card.points.toStringAsFixed(0)} pts'
                    ' = ${(card.points * pointValue).toStringAsFixed(2)} $sym',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    hasRedeemed
                        ? 'Redeeming ${pointsUsed.toStringAsFixed(0)} pts'
                            ' (−${discount.toStringAsFixed(2)} $sym)'
                        : 'Tap to redeem points',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasRedeemed
                          ? context.successColor
                          : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loyalty points redemption dialog
// ---------------------------------------------------------------------------
class _LoyaltyPointsDialog extends StatefulWidget {
  final String customerName;
  final double currentPoints;
  final double pointValue;
  final double maxUsable; // grand total cap — can't redeem more DH than the order total

  const _LoyaltyPointsDialog({
    required this.customerName,
    required this.currentPoints,
    required this.pointValue,
    required this.maxUsable,
  });

  @override
  State<_LoyaltyPointsDialog> createState() => _LoyaltyPointsDialogState();
}

class _LoyaltyPointsDialogState extends State<_LoyaltyPointsDialog> {
  final _ctrl = TextEditingController();

  double get _maxPts {
    final maxByTotal = widget.pointValue > 0
        ? (widget.maxUsable / widget.pointValue).floor().toDouble()
        : widget.currentPoints;
    return widget.currentPoints < maxByTotal ? widget.currentPoints : maxByTotal;
  }

  double get _ptsEntered => double.tryParse(_ctrl.text) ?? 0;
  double get _discount => _ptsEntered * widget.pointValue;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final max = _maxPts;
    final entered = _ptsEntered;
    final valid = entered > 0 && entered <= max;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.loyalty, color: cs.primary),
          const SizedBox(width: 8),
          const Text('Redeem Points'),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ${widget.currentPoints.toStringAsFixed(0)} pts'
                    ' = ${(widget.currentPoints * widget.pointValue).toStringAsFixed(2)} DH',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'Max usable this order: ${max.toStringAsFixed(0)} pts',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Points input
            TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Points to use',
                helperText: _discount > 0
                    ? 'Discount: ${_discount.toStringAsFixed(2)} DH'
                    : null,
                suffixText: 'pts',
                border: const OutlineInputBorder(),
                errorText:
                    entered > max && entered > 0 ? 'Exceeds maximum' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            // +/- stepper row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: entered > 0
                      ? () {
                          _ctrl.text = (entered - 1).toStringAsFixed(0);
                          setState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.remove),
                  tooltip: '−1 pt',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${entered.toStringAsFixed(0)} pts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton.outlined(
                  onPressed: entered < max
                      ? () {
                          _ctrl.text = (entered + 1).toStringAsFixed(0);
                          setState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.add),
                  tooltip: '+1 pt',
                ),
              ],
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () {
                _ctrl.text = max.toStringAsFixed(0);
                setState(() {});
              },
              icon: const Icon(Icons.flash_on, size: 16),
              label: Text('Use Max (${max.toStringAsFixed(0)} pts)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 0.0),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, entered) : null,
          child: const Text('Redeem'),
        ),
      ],
    );
  }
}
