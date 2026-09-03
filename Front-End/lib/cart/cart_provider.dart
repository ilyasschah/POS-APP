import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/session/session_provider.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/api/customer_discount_models.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/floor_plan/floor_plan_table_provider.dart';
import 'package:pos_app/bookings/bookings_provider.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/promotions/promotion_provider.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/kitchen/kitchen_push_service.dart';
import 'package:pos_app/product/product_model.dart'; // Added to use Product.fromDrift
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

final dailyOrderNumberProvider = StateProvider<int>((ref) => 1);

class CartState {
  final int? activePosOrderId;
  final List<CartItem> items;
  final String? orderNumber;
  final bool isLoading;
  final Customer? selectedCustomer;
  final CustomerDiscountDto? selectedCustomerDiscount;
  final double manualCartDiscount;
  final int manualCartDiscountType;
  final double? customerDiscountValue;
  final int? customerDiscountType;
  final String? selectedCartItemId;
  final int serviceType;
  final int serviceStatus;
  final int? floorPlanTableId;
  final int? activeWarehouseId;
  final int? bookingId;
  final int? bookingStaffId;
  final String? existingLocalOrderId;

  CartState({
    this.activePosOrderId,
    this.items = const [],
    this.orderNumber,
    this.isLoading = false,
    this.selectedCustomer,
    this.selectedCustomerDiscount,
    this.manualCartDiscount = 0,
    this.manualCartDiscountType = 0,
    this.customerDiscountValue,
    this.customerDiscountType,
    this.selectedCartItemId,
    this.serviceType = 0,
    this.serviceStatus = 1,
    this.floorPlanTableId,
    this.activeWarehouseId,
    this.bookingId,
    this.bookingStaffId,
    this.existingLocalOrderId,
  });

  CartState copyWith({
    int? activePosOrderId,
    List<CartItem>? items,
    bool? isLoading,
    Customer? selectedCustomer,
    CustomerDiscountDto? selectedCustomerDiscount,
    double? manualCartDiscount,
    int? manualCartDiscountType,
    String? selectedCartItemId,
    String? orderNumber,
    double? customerDiscountValue,
    int? customerDiscountType,
    int? serviceType,
    int? serviceStatus,
    int? floorPlanTableId,
    int? activeWarehouseId,
    int? bookingId,
    int? bookingStaffId,
    String? existingLocalOrderId,
    // copyWith can't otherwise set the customer-discount fields back to null
    // (the `?? this.x` pattern keeps the old value). Set this when switching to
    // a customer with no discount / Walk-in so the previous discount is wiped.
    bool clearCustomerDiscount = false,
    // Same escape hatch for the booking link: reopening a NON-booking order
    // must drop any booking left on the cart from a previous one, or the menu
    // header keeps captioning it with the old guest's booking banner.
    bool clearBooking = false,
    // And the same escape hatch for the local-row link. `existingLocalOrderId:
    // null` reads like "forget which row this cart came from", but the
    // `?? this.x` pattern below made it a NO-OP, so the id of the PREVIOUSLY
    // open order survived into the next one. saveOrderLocally then wrote this
    // order's contents over that older row — the older order silently moved
    // onto this table, and the order actually being edited had no local row, so
    // the next open-orders pull re-materialised it as a second `svr_` row on
    // the same table. That is the "saving an old order creates a duplicate"
    // report. Callers that mean "no local row yet" must set this.
    bool clearExistingLocalOrderId = false,
  }) {
    return CartState(
      activePosOrderId: activePosOrderId ?? this.activePosOrderId,
      items: items ?? this.items,
      orderNumber: orderNumber ?? this.orderNumber,
      isLoading: isLoading ?? this.isLoading,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      selectedCustomerDiscount: clearCustomerDiscount
          ? null
          : (selectedCustomerDiscount ?? this.selectedCustomerDiscount),
      manualCartDiscount: manualCartDiscount ?? this.manualCartDiscount,
      manualCartDiscountType:
          manualCartDiscountType ?? this.manualCartDiscountType,
      customerDiscountValue: clearCustomerDiscount
          ? null
          : (customerDiscountValue ?? this.customerDiscountValue),
      customerDiscountType: clearCustomerDiscount
          ? null
          : (customerDiscountType ?? this.customerDiscountType),
      selectedCartItemId: selectedCartItemId ?? this.selectedCartItemId,
      serviceType: serviceType ?? this.serviceType,
      serviceStatus: serviceStatus ?? this.serviceStatus,
      floorPlanTableId: floorPlanTableId ?? this.floorPlanTableId,
      activeWarehouseId: activeWarehouseId ?? this.activeWarehouseId,
      bookingId: clearBooking ? null : (bookingId ?? this.bookingId),
      bookingStaffId:
          clearBooking ? null : (bookingStaffId ?? this.bookingStaffId),
      existingLocalOrderId: clearExistingLocalOrderId
          ? null
          : (existingLocalOrderId ?? this.existingLocalOrderId),
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  /// Warm, in-memory snapshot of the company's taxes. Kept current by the
  /// `ref.listen` in [build] so [_resolveDefaultTaxes] can map default tax-rate
  /// IDs → [MenuTax] synchronously when an item is added to the cart.
  List<Tax> _taxesCache = const [];

  /// Warm snapshot of the live promotions, kept current the same way — and for
  /// the same reason — as [_taxesCache].
  ///
  /// [_applyPromotions] used to `ref.read(activePromotionsProvider)`, but that
  /// chain bottoms out in an autoDispose *stream*: with no listener holding it
  /// open, a read spins it up, gets `AsyncLoading` (the stream hasn't emitted
  /// yet), and yields null. Promotions therefore only applied when some other
  /// widget happened to be watching them — the POS menu does, the bookings and
  /// floor-plan screens don't — so reopening an order from a table silently
  /// dropped every promotional discount. Listening here pins the stream for the
  /// cart's whole lifetime, making it deterministic wherever it's called from.
  List<PromotionDto> _promotionsCache = const [];

  @override
  CartState build() {
    // Listening (rather than reading) keeps the autoDispose taxes stream warm
    // for the whole lifetime of the (non-autoDispose) cart provider.
    ref.listen<AsyncValue<List<Tax>>>(allTaxesProvider, (_, next) {
      final list = next.value;
      if (list != null) _taxesCache = list;
    }, fireImmediately: true);
    ref.listen<AsyncValue<List<PromotionDto>>>(activePromotionsProvider, (
      _,
      next,
    ) {
      final list = next.value;
      if (list != null) _promotionsCache = list;
    }, fireImmediately: true);
    return CartState();
  }

  /// Resolves the "default tax rate" Products setting into concrete [MenuTax]
  /// objects. Applied to a freshly-added item that carries no taxes of its own,
  /// mirroring what selecting taxes manually in the menu would produce.
  List<MenuTax> _resolveDefaultTaxes() {
    final settings = ref.read(appSettingsProvider);

    // The switch gates the fallback. With it off, the picker is greyed out in
    // Settings but its selection is deliberately KEPT (so turning the feature
    // back on restores it) — auto-applying that retained selection anyway
    // would silently tax orders on a till whose operator sees the feature as
    // disabled.
    final on =
        settings[SettingKeys.taxIncludedByDefault]?.toLowerCase() == 'true';
    if (!on) return const [];

    final ids = parseDefaultTaxRateIds(settings[SettingKeys.defaultTaxRateIds]);
    if (ids.isEmpty) return const [];

    return _taxesCache
        .where((t) => ids.contains(t.id) && t.isEnabled)
        .map(
          (t) => MenuTax(
            id: t.id,
            name: t.name,
            rate: t.rate,
            isFixed: t.isFixed,
            isTaxOnTotal: t.isTaxOnTotal,
          ),
        )
        .toList();
  }

  /// Resolves the taxes assigned to a product in the product editor (the
  /// `product_taxes` table) into concrete [MenuTax] objects, so adding the
  /// product to the cart applies its own tax. Fully offline (reads Drift + the
  /// warm tax cache). Falls back to the configured default tax rates when the
  /// product has no assignment of its own.
  Future<List<MenuTax>> resolveProductTaxes(int productId) async {
    final db = ref.read(appDatabaseProvider);
    final assigned = await db.getProductTaxes(
      productId,
    ); // excludes pending_delete
    if (assigned.isEmpty) return _resolveDefaultTaxes();

    final taxIds = assigned.map((a) => a.taxId).toSet();
    final taxes = _taxesCache
        .where((t) => taxIds.contains(t.id) && t.isEnabled)
        .map(
          (t) => MenuTax(
            id: t.id,
            name: t.name,
            rate: t.rate,
            isFixed: t.isFixed,
            isTaxOnTotal: t.isTaxOnTotal,
          ),
        )
        .toList();
    // A product whose only assignment is a disabled/missing tax falls back to
    // the configured defaults rather than silently applying nothing.
    return taxes.isNotEmpty ? taxes : _resolveDefaultTaxes();
  }

  void _notifyKitchen() {
    ref.read(kitchenSyncProvider).push();
  }

  int get effectiveWarehouseId {
    final fromState = state.activeWarehouseId;
    if (fromState != null && fromState > 0) return fromState;
    return _newOrderWarehouseId;
  }

  /// The warehouse a BRAND-NEW order should source from: the active selection,
  /// else the configured default (`Order.DefaultWarehouseId`).
  ///
  /// Deliberately ignores `state.activeWarehouseId` — that belongs to the order
  /// being replaced, not the one being started. Callers must NOT pre-resolve
  /// this with a hardcoded `?? 1`: [selectedWarehouseProvider] starts null and
  /// is seeded asynchronously, so a caller that substitutes 1 while the seed is
  /// in flight pins the order to warehouse 1 — which may not even exist for the
  /// company — and, because 1 > 0, wins over the default below. That race is
  /// why orders intermittently ignored the configured default warehouse.
  int get _newOrderWarehouseId {
    final fromProvider = ref.read(selectedWarehouseProvider)?.id ?? 0;
    if (fromProvider > 0) return fromProvider;
    final defaultId =
        int.tryParse(
          ref.read(appSettingsProvider)[SettingKeys.defaultWarehouseId] ?? '',
        ) ??
        0;
    return defaultId > 0 ? defaultId : 1;
  }

  String _getPrefix(int serviceType) {
    final types = ref.read(appSettingsProvider.notifier).customServiceTypes;
    return types
            .where((t) => t.id == serviceType)
            .map((t) => t.prefix)
            .firstOrNull ??
        'ORDER';
  }

  static final Map<int, int> _highestSeenSequence = {};
  /// Reseeds [dailyOrderNumberProvider] from the LOCAL Drift DB — offline-first,
  /// no network — so the per-day order-name counter keeps working with no
  /// connection and re-derives correctly after an app restart (the local DB
  /// persists). "Today" is bucketed on the DEVICE's LOCAL day, not UTC, so orders
  /// placed near local midnight aren't mis-grouped in non-UTC venues.
  Future<void> syncOrderNumber(int companyId) async {
    try {
      final db = ref.read(appDatabaseProvider);

      // Local business-day window. Drift stores DateTime as an absolute epoch, so
      // comparing the stored (UTC) instant against LOCAL-midnight boundaries
      // selects exactly the local calendar day.
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // POS names are '{prefix} #{NNN}'. Match ONLY the '#' delimiter so foreign
      // schemes ('PUR-1052', timestamp fallbacks 'DOC-1750…') can't poison the
      // counter and wreck the next order number.
      int seqOf(String? raw) {
        if (raw == null || raw.isEmpty) return 0;
        final m = RegExp(r'#\s*(\d+)$').firstMatch(raw);
        return m == null ? 0 : (int.tryParse(m.group(1)!) ?? 0);
      }

      int absoluteMax = 0;

      // Open orders (active table sessions) currently holding a '#NNN' name.
      final openOrders = await (db.select(db.posOrdersTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.status.equals(0)))
          .get();
      for (final o in openOrders) {
        final s = seqOf(o.orderName);
        if (s > absoluteMax) absoluteMax = s;
      }

      // Today's completed documents (local day).
      final todaysDocs = await (db.select(db.documentsTable)
            ..where((t) => t.companyId.equals(companyId))
            ..where((t) => t.date.isBiggerOrEqualValue(dayStart))
            ..where((t) => t.date.isSmallerThanValue(dayEnd)))
          .get();
      for (final d in todaysDocs) {
        final s = seqOf(d.orderNumber);
        if (s > absoluteMax) absoluteMax = s;
      }

      // High-water guard (per company, per session): never hand back a number
      // lower than one already issued this session, even if a row is mid-write.
      final currentHighWater = _highestSeenSequence[companyId] ?? 0;
      if (absoluteMax > currentHighWater) {
        _highestSeenSequence[companyId] = absoluteMax;
      }
      final nextNumber = (_highestSeenSequence[companyId] ?? 0) + 1;

      ref.read(dailyOrderNumberProvider.notifier).state = nextNumber;
    } catch (_) {}
  }

  /// Sets the service type. By default the order number is re-prefixed to match
  /// the new type; pass [regenerateOrderName] `false` when a bespoke name was
  /// already set (e.g. a table assignment that named the order after the space)
  /// and must be preserved.
  void setServiceType(int newType, {bool regenerateOrderName = true}) {
    final settings = ref.read(appSettingsProvider);
    final typeEnabled =
        settings[SettingKeys.featureServiceTypeEnabled]?.toLowerCase() ==
        'true';
    if (newType != 0 && !typeEnabled) return;

    if (!regenerateOrderName) {
      state = state.copyWith(serviceType: newType);
      return;
    }

    final numMatch = RegExp(r'[#-](\d+)$').firstMatch(state.orderNumber ?? '');
    final num = numMatch?.group(1) ?? '001';

    state = state.copyWith(
      serviceType: newType,
      orderNumber: '${_getPrefix(newType)} #$num',
    );
  }

  void setServiceStatus(int newStatus) {
    state = state.copyWith(serviceStatus: newStatus);
  }

  bool get _discountBeforeTax =>
      ref.read(appSettingsProvider)[SettingKeys.discountApplyRule] ==
      'Before tax';

  /// The ex-tax ("net") view of one cart line — the basis every total below is
  /// built from. See [lineTaxBasis] for the actual split; it is a pure
  /// function in `checkout_models.dart` so the receipt renderer computes the
  /// identical figures without going through Riverpod.
  ///
  /// The whole totals pipeline keeps the identity
  ///   `grandTotal = subtotal − discounts + taxTotal`
  /// by expressing subtotal and item discounts on this net basis, so an
  /// inclusive line reconciles back to exactly its listed price.
  ({double unitPrice, double unitDiscount, double unitPromo}) _lineBasis(
    CartItem item,
  ) => lineTaxBasis(item, discountBeforeTax: _discountBeforeTax);

  /// Ex-tax subtotal. For inclusive lines this is LESS than the shelf price —
  /// the difference reappears in [taxTotal], so [grandTotal] still lands on
  /// the price the customer was quoted.
  double get subtotal => state.items.fold(
    0,
    (sum, item) => sum + (_lineBasis(item).unitPrice * item.quantity),
  );

  double get discountTotal => state.items.fold(0, (sum, item) {
    final b = _lineBasis(item);
    return sum + ((b.unitDiscount + b.unitPromo) * item.quantity);
  });

  double get promotionalDiscountTotal => state.items.fold(
    0,
    (sum, item) => sum + (_lineBasis(item).unitPromo * item.quantity),
  );

  /// The share of the cart-level discounts (customer profile + manual cart)
  /// that each line carries, so a whole-cart discount reduces every line's tax
  /// base proportionally. Only meaningful under the "Before tax" rule.
  double get _cartDiscountFactor {
    final baseBeforeCartDiscounts = subtotal - discountTotal;
    if (baseBeforeCartDiscounts <= 0) return 1.0;
    final totalCartDiscounts =
        customerDiscountAmount + manualCartDiscountAmount;
    return (baseBeforeCartDiscounts - totalCartDiscounts) /
        baseBeforeCartDiscounts;
  }

  /// The resolved tax amounts for one cart line, honouring `discountApplyRule`.
  ///
  /// **This is the single source of truth for line tax — never re-derive it.**
  /// [taxTotal] (what the cart and the payment dialog show), the saved
  /// `document_items.taxAmount`, and the `Taxes` payload the server turns into
  /// `DocumentItemTax` rows all read this, so what the cashier is shown is
  /// exactly what gets banked. They used to compute it in three places and only
  /// this one read the setting, so an "After tax" company banked a document
  /// whose own lines contradicted its total by (discount × rate).
  List<({int id, double amount})> taxAmountsForItem(CartItem item) {
    // Everything here works on the EX-TAX basis. For an exclusive line that is
    // `item.price` unchanged; for an inclusive line the tax is divided out
    // first, so the tax becomes a share OF the shelf price instead of an
    // addition TO it.
    final b = _lineBasis(item);
    final base = _discountBeforeTax
        // Tax base = price minus all discounts (item + proportional cart share).
        ? (b.unitPrice - b.unitDiscount - b.unitPromo) *
              item.quantity *
              _cartDiscountFactor
        // "After tax": tax is computed on the full item price; discounts only
        // reduce the final payable amount, not the taxable base.
        : b.unitPrice * item.quantity;

    return [
      for (final tax in item.appliedTaxes)
        (
          id: tax.id,
          amount:
              tax.isFixed ? tax.rate * item.quantity : base * (tax.rate / 100),
        ),
    ];
  }

  /// The ex-tax unit price of a line — what `document_items.priceBeforeTax`
  /// must store. Public because the checkout dialog banks that column and used
  /// to write the raw, tax-inclusive `item.price` into it.
  double netUnitPriceFor(CartItem item) => _lineBasis(item).unitPrice;

  /// What this line actually adds to the bill: ex-tax base after its own
  /// discounts, plus its tax. For an inclusive line with no discount this
  /// comes back to exactly `price × quantity` — the shelf price.
  ///
  /// Centralised here because the POS line rows used to re-derive it as
  /// `net + net × rate`, which double-taxed every inclusive product on screen
  /// even once the totals below it were right.
  double grossLineTotal(CartItem item) {
    final b = _lineBasis(item);
    final net = (b.unitPrice - b.unitDiscount - b.unitPromo) * item.quantity;
    return net + taxForItem(item);
  }

  /// The same figure BEFORE any discount — the struck-through "was" price.
  double grossLineFullPrice(CartItem item) {
    final b = _lineBasis(item);
    final net = b.unitPrice * item.quantity;
    return item.appliedTaxes.fold<double>(net, (sum, t) {
      if (t.isFixed) return sum + t.rate * item.quantity;
      return sum + net * (t.rate / 100);
    });
  }

  /// Total tax for one line — all taxes, fixed and percentage.
  double taxForItem(CartItem item) =>
      taxAmountsForItem(item).fold<double>(0, (sum, t) => sum + t.amount);

  double get taxTotal =>
      state.items.fold<double>(0, (sum, item) => sum + taxForItem(item));

  double get customerDiscountAmount {
    if (state.customerDiscountValue == null) return 0;
    double base = subtotal - discountTotal;
    if (state.customerDiscountType == 0) {
      return base * (state.customerDiscountValue! / 100);
    } else {
      return state.customerDiscountValue!;
    }
  }

  double get manualCartDiscountAmount {
    double base = subtotal - discountTotal - customerDiscountAmount;
    if (state.manualCartDiscountType == 0) {
      return base * (state.manualCartDiscount / 100);
    } else {
      return state.manualCartDiscount;
    }
  }

  double get grandTotal =>
      subtotal -
      discountTotal -
      customerDiscountAmount -
      manualCartDiscountAmount +
      taxTotal;

  /// Builds the normalized `discount_lines` rows for the current cart state —
  /// one per discount that actually deducted money. Each line keeps its own
  /// value + valueType (so a 10% line and a −20 MAD line never get mixed); the
  /// resolved `amount` is the additive currency figure.
  ///
  /// [itemLocalIds] maps each `CartItem.cartItemId` to the localId of the
  /// persisted item row it should link to (pos_order_items for a parked order,
  /// document_items for a checkout). Provide [orderLocalId] and/or
  /// [documentLocalId] — a checkout shares one header id across both. The
  /// loyalty-points line is appended by the checkout dialog (points live there).
  List<DiscountLinesTableCompanion> buildDiscountLines({
    required int companyId,
    String? orderLocalId,
    String? documentLocalId,
    required Map<String, String> itemLocalIds,
  }) {
    final now = DateTime.now().toUtc();
    final lines = <DiscountLinesTableCompanion>[];
    var seq = 0;

    final promoNames = {
      for (final p in (ref.read(activePromotionsProvider).value ?? const []))
        p.id: p.name,
    };

    DiscountLinesTableCompanion mk({
      required String source,
      required double value,
      required int valueType,
      required double amount,
      String? itemLocalId,
      int? sourceRefId,
      String? label,
    }) => DiscountLinesTableCompanion(
      localId: Value(const Uuid().v4()),
      companyId: Value(companyId),
      orderLocalId: Value(orderLocalId),
      documentLocalId: Value(documentLocalId),
      itemLocalId: Value(itemLocalId),
      source: Value(source),
      sourceRefId: Value(sourceRefId),
      value: Value(value),
      valueType: Value(valueType),
      amount: Value(double.parse(amount.toStringAsFixed(4))),
      sequence: Value(seq++),
      label: Value(label),
      syncStatus: const Value('pending'),
      lastModified: Value(now),
    );

    // ── Item-level lines (manual + promotional), in cart order ──────────────
    for (final item in state.items) {
      final itemLocalId = itemLocalIds[item.cartItemId];
      if (item.discount > 0) {
        lines.add(
          mk(
            source: DiscountSource.manualItem,
            // Record the figure as entered ("10%") when known, falling back to the
            // resolved money value. `amount` is always the resolved currency.
            value: item.discountInputValue ?? item.discount,
            valueType: item.discountInputType ?? item.discountType,
            amount: item.discount * item.quantity,
            itemLocalId: itemLocalId,
            sourceRefId: item.productId,
          ),
        );
      }
      if (item.promotionalDiscount > 0) {
        lines.add(
          mk(
            source: DiscountSource.promotion,
            value: item.promotionalDiscount,
            valueType: 1, // already resolved to per-unit currency
            amount: item.promotionalDiscount * item.quantity,
            itemLocalId: itemLocalId,
            sourceRefId: item.promotionId,
            label: item.promotionId == null
                ? null
                : promoNames[item.promotionId],
          ),
        );
      }
    }

    // ── Order-level lines, in application order (customer → manual cart) ─────
    if (customerDiscountAmount > 0) {
      lines.add(
        mk(
          source: DiscountSource.customerProfile,
          value: state.customerDiscountValue ?? 0,
          valueType: state.customerDiscountType ?? 0,
          amount: customerDiscountAmount,
          sourceRefId: state.selectedCustomer?.id,
        ),
      );
    }
    if (manualCartDiscountAmount > 0) {
      lines.add(
        mk(
          source: DiscountSource.manualCart,
          value: state.manualCartDiscount,
          valueType: state.manualCartDiscountType,
          amount: manualCartDiscountAmount,
        ),
      );
    }

    return lines;
  }

  void _applyPromotions(List<CartItem> items) {
    // A conditional promotion asks "does the CART hold N of this product?", not
    // "does this ROW hold N?". With `Order.SeparateRowForEachItem` on, three
    // Pepsis are three rows of quantity 1, so a per-row check can never satisfy
    // "Buy 2" no matter how many the customer actually buys. Totalling by
    // product first makes the condition independent of how the cart is split;
    // for an unsplit cart the total IS the row quantity, so nothing changes.
    final cartQtyByProduct = <int, double>{};
    for (final i in items) {
      cartQtyByProduct[i.productId] = (cartQtyByProduct[i.productId] ?? 0) +
          i.quantity;
    }

    for (var item in items) {
      double bestDiscount = 0;
      int? bestPromoId;
      for (var promo in _promotionsCache) {
        for (var pItem in promo.items) {
          if (pItem.productId == item.productId) {
            // A conditional line ("Buy 2, get 10% off") only earns its discount
            // once the cart actually holds the required quantity. This was never
            // checked: every conditional promo fired on the first unit, so the
            // condition the operator configured did nothing at all.
            // conditionType 0 (Same Product) is the only kind the editor offers;
            // an unknown type is left unapplied rather than guessed at.
            if (pItem.isConditional) {
              if (pItem.conditionType != 0) continue;
              final cartQty = cartQtyByProduct[item.productId] ?? 0;
              if (cartQty < pItem.quantity) continue;
            }
            double currentDiscount = 0;
            // discountType: 0 for %, 1 for $
            if (pItem.discountType == 0) {
              currentDiscount = item.price * (pItem.value / 100);
            } else {
              currentDiscount = pItem.value;
            }
            if (currentDiscount > bestDiscount) {
              bestDiscount = currentDiscount;
              bestPromoId = promo.id;
            }
          }
        }
      }
      item.promotionalDiscount = bestDiscount;
      // Track which promotion won so the discount_lines record can reference it
      // (null when no promo applied).
      item.promotionId = bestDiscount > 0 ? bestPromoId : null;
    }
  }

  /// Re-points the cart at a table whose temp id a sync swapped for a real one.
  ///
  /// The cart lives in memory, so [AppDatabase.remapFloorPlanTableRefs] can't
  /// rewrite it the way it rewrites rows. It heals from the same forwarding map,
  /// which also repairs the header, whose table lookup would otherwise miss and
  /// fall back to printing the raw negative id.
  Future<void> healTableId() async {
    final id = state.floorPlanTableId;
    if (id == null || id >= 0) return;
    final real =
        await ref.read(appDatabaseProvider).resolveFloorPlanTableId(id);
    if (real != null && real != id) {
      state = state.copyWith(floorPlanTableId: real);
    }
  }

  /// Starts a NEW order on an empty floor-plan table.
  ///
  /// Builds a fresh [CartState] instead of reusing [setOrderContext], which is
  /// the "move the order I'm holding onto a table" path and therefore preserves
  /// the cart by design. Driving a new table through it inherited the previous
  /// order's items, discounts — and its `existingLocalOrderId`, so the next save
  /// rewrote the previously parked order's row onto this table, silently moving
  /// the order and emptying the table it came from.
  void startTableOrder({
    required int tableId,
    required String tableName,
    int serviceType = 0,
  }) {
    state = CartState(
      activePosOrderId: 0, // local-only sentinel; materialised at checkout
      serviceType: serviceType,
      serviceStatus: 1,
      floorPlanTableId: tableId,
      orderNumber: 'ORD- $tableName',
      activeWarehouseId: _newOrderWarehouseId,
    );
    _seedDefaultCustomer();
  }

  /// Selects the starting customer for a freshly-started order, so a new order
  /// never silently inherits the previous customer's profile discount.
  ///
  /// [customerId] names the customer the order already belongs to (a booking's
  /// customer); it falls back to Walk-in when absent or unknown locally. Without
  /// it, an order opened from a booking for "Ilyass" was banked against Walk-in
  /// and lost their profile discount.
  Future<void> _seedDefaultCustomer({int? customerId}) async {
    // AWAIT the loaded list rather than reading a cold sync snapshot. This runs
    // from a booking's Start Service, where the customers provider is usually
    // autoDispose-cold (nothing on the booking detail dialog watches it) and its
    // `.value` is null — the old code then bailed WITHOUT seeding, leaving the
    // booking order with no customer, which the menu defaulted to Walk-in.
    // allCustomersProvider includes disabled records, so a booking's customer is
    // still honoured even if it was later disabled.
    final List<Customer> customers;
    try {
      customers = await ref.read(allCustomersProvider.future);
    } catch (_) {
      return; // no company / stream closed early — leave seeding to the menu.
    }
    if (customers.isEmpty) return;
    final booked = customerId == null
        ? null
        : customers.where((c) => c.id == customerId).firstOrNull;
    final customer =
        booked ??
        customers.firstWhere(
          (c) => c.code == 'C000',
          orElse: () => customers.first,
        );
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId != null) await setCustomer(companyId, customer);
  }

  void setOrderContext(
    int orderId,
    int warehouseId, {
    int? tableId,
    String? orderNumber,
  }) {
    state = state.copyWith(
      activePosOrderId: orderId,
      floorPlanTableId: tableId,
      orderNumber: orderNumber,
      activeWarehouseId: warehouseId,
    );
    final warehouses = ref.read(allWarehousesProvider).value ?? [];
    final wh = warehouses.where((w) => w.id == warehouseId).firstOrNull;
    if (wh != null) {
      ref.read(selectedWarehouseProvider.notifier).state = wh;
    }
  }

  Future<void> setCustomer(int companyId, Customer customer) async {
    final discount = await ApiClient().getCustomerDiscount(
      companyId,
      customer.id,
    );
    // A customer with no discount (or a Walk-in) must wipe any discount left
    // over from the previously-selected customer — otherwise the old -X line
    // stays stuck on the order. copyWith can't null these fields normally, so
    // signal an explicit clear when there's no usable discount value.
    final hasDiscount = discount?.value != null;
    state = state.copyWith(
      selectedCustomer: customer,
      selectedCustomerDiscount: hasDiscount ? discount : null,
      customerDiscountValue: hasDiscount ? discount!.value : null,
      customerDiscountType: hasDiscount ? discount!.type : null,
      clearCustomerDiscount: !hasDiscount,
    );
    // Derived totals (customerDiscountAmount, cartTotalProvider, …) are getters
    // off this state, so assigning state above recalculates them immediately;
    // watchers rebuild and the stale discount line disappears at once.
    ref.read(currentCustomerProvider.notifier).setCustomer(customer);
  }

  /// Restores the customer + their profile discount for a reopened order from
  /// the saved `discount_lines` (fully offline — no API call). Reopening used to
  /// drop the customer discount entirely, silently changing the total; we now
  /// read the `customer_profile` line's value/type back. Returns nulls when the
  /// order carried no customer discount.
  Future<({Customer? customer, double? value, int? type})>
  _restoreCustomerDiscount(String orderLocalId, int? customerId) async {
    final db = ref.read(appDatabaseProvider);
    Customer? customer;
    if (customerId != null) {
      final row =
          await (db.select(db.customersTable)
                ..where((t) => t.id.equals(customerId))
                ..limit(1))
              .getSingleOrNull();
      if (row != null) customer = Customer.fromDrift(row);
    }
    final lines = await db.getDiscountLinesForOrder(orderLocalId);
    final cust = lines
        .where((l) => l.source == DiscountSource.customerProfile)
        .firstOrNull;
    if (cust != null) {
      return (customer: customer, value: cust.value, type: cust.valueType);
    }

    // 🚨 No `customer_profile` line means one of two things, and only one of
    // them is "no discount":
    //   • the order really carries none — the fallback below finds nothing
    //     either, so the result is identical; or
    //   • the order was PULLED from another terminal. `discount_lines` never
    //     cross the wire for an OPEN order (only checkout's BatchSync sends
    //     them), so a cross-device order arrives with no lines at all.
    //
    // The second case was a real money discrepancy: this terminal applied no
    // customer discount, so its grand total came out HIGHER than the till that
    // rang the order up — and checking out here would have charged the customer
    // the undiscounted price. The discount itself is master data, so read it
    // from the local mirror exactly as picking that customer on a fresh order
    // would. Drift, not the API: reopening an order must work offline.
    if (customerId == null) {
      return (customer: customer, value: null, type: null);
    }
    final profile = await (db.select(db.customerDiscountsTable)
          ..where((t) => t.customerId.equals(customerId))
          ..where((t) => t.syncStatus.isNotIn(['pending_delete']))
          ..limit(1))
        .get()
        .then((r) => r.firstOrNull);
    if (profile == null || profile.value <= 0) {
      return (customer: customer, value: null, type: null);
    }
    return (customer: customer, value: profile.value, type: profile.type);
  }

  Future<void> clearFloorPlanTable(
    int newServiceType, {
    required int companyId,
  }) async {
    if (state.floorPlanTableId != null) {
      try {
        await ApiClient().freeFloorPlanTable(
          companyId,
          state.floorPlanTableId!,
        );
      } catch (_) {}
    }
    final existingNum = RegExp(
      r'[#-](\d+)$',
    ).firstMatch(state.orderNumber ?? '')?.group(1);
    final newOrderNumber = existingNum != null
        ? '${_getPrefix(newServiceType)} #$existingNum'
        : '${_getPrefix(newServiceType)} #${ref.read(dailyOrderNumberProvider).toString().padLeft(3, '0')}';
    state = CartState(
      activePosOrderId: state.activePosOrderId,
      items: state.items,
      orderNumber: newOrderNumber,
      isLoading: state.isLoading,
      selectedCustomer: state.selectedCustomer,
      selectedCustomerDiscount: state.selectedCustomerDiscount,
      manualCartDiscount: state.manualCartDiscount,
      manualCartDiscountType: state.manualCartDiscountType,
      customerDiscountValue: state.customerDiscountValue,
      customerDiscountType: state.customerDiscountType,
      selectedCartItemId: state.selectedCartItemId,
      serviceType: newServiceType,
      serviceStatus: state.serviceStatus,
      floorPlanTableId: null,
      activeWarehouseId: state.activeWarehouseId,
      bookingId: state.bookingId,
      bookingStaffId: state.bookingStaffId,
    );
  }

  Future<void> startTablelessOrder(
    ApiClient apiClient,
    int companyId,
    int userId,
    int serviceType,
  ) async {
    final orderNum = ref.read(dailyOrderNumberProvider);
    final label = orderNum.toString().padLeft(3, '0');
    final orderNumber = '${_getPrefix(serviceType)} #$label';
    state = CartState(
      activePosOrderId: 0,
      serviceType: serviceType,
      serviceStatus: 1,
      floorPlanTableId: null,
      orderNumber: orderNumber,
      activeWarehouseId: effectiveWarehouseId,
      selectedCustomer: state.selectedCustomer,
      selectedCustomerDiscount: state.selectedCustomerDiscount,
      customerDiscountValue: state.customerDiscountValue,
      customerDiscountType: state.customerDiscountType,
    );
    try {
      _notifyKitchen();
    } catch (_) {}
  }

  Future<int> startBookingOrder(
    ApiClient apiClient,
    int companyId,
    int userId,
    int bookingId,
    String guestName, {
    int? staffUserId,
    int? floorPlanTableId,
    int? customerId,
  }) async {
    state = CartState(
      activePosOrderId: 0,
      serviceType: 0,
      serviceStatus: 1,
      floorPlanTableId: floorPlanTableId,
      orderNumber: 'APT- $guestName',
      activeWarehouseId: effectiveWarehouseId,
      bookingId: bookingId,
      bookingStaffId: staffUserId,
    );
    // The order belongs to whoever the booking was made for — not Walk-in.
    await _seedDefaultCustomer(customerId: customerId);
    return 0;
  }

  void setWarehouseId(int warehouseId) {
    state = state.copyWith(activeWarehouseId: warehouseId);
    final warehouses = ref.read(allWarehousesProvider).value ?? [];
    final wh = warehouses.where((w) => w.id == warehouseId).firstOrNull;
    if (wh != null) {
      ref.read(selectedWarehouseProvider.notifier).state = wh;
    }
  }

  void setCartDiscount(double discount, int type) {
    state = state.copyWith(
      manualCartDiscount: discount,
      manualCartDiscountType: type,
    );
  }

  /// Sets a per-item manual discount. [discount] is the resolved per-unit money
  /// the dialog already computed; [inputValue]/[inputType] are the figure as the
  /// user entered it ("10" + 0 for 10%), preserved so records/receipts can show
  /// "10%" instead of its flattened money value.
  void setItemDiscount(
    String cartItemId,
    double discount,
    int discountType, {
    double? inputValue,
    int? inputType,
  }) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index >= 0) {
      items[index].discount = discount;
      items[index].discountType = discountType;
      items[index].discountInputValue = inputValue;
      items[index].discountInputType = inputType;
      state = state.copyWith(items: items);
    }
  }

  void setSelectedProduct(String? cartItemId) {
    state = state.copyWith(selectedCartItemId: cartItemId);
  }

  void clearCart({bool keepCustomer = false, String? overrideServiceType}) {
    final serviceTypeName =
        overrideServiceType ??
        ref.read(appSettingsProvider)[SettingKeys.defaultServiceType];
    int initialServiceType = 0;
    if (serviceTypeName != null) {
      final types = ref.read(appSettingsProvider.notifier).customServiceTypes;
      final match = types
          .where((t) => t.name.toLowerCase() == serviceTypeName.toLowerCase())
          .firstOrNull;
      if (match != null) initialServiceType = match.id;
    }

    state = CartState(
      items: const [],
      isLoading: false,
      serviceType: initialServiceType,
      selectedCustomer: keepCustomer ? state.selectedCustomer : null,
      customerDiscountValue: keepCustomer ? state.customerDiscountValue : null,
      customerDiscountType: keepCustomer ? state.customerDiscountType : null,
      manualCartDiscount: keepCustomer ? state.manualCartDiscount : 0,
      manualCartDiscountType: keepCustomer ? state.manualCartDiscountType : 0,
    );

    if (keepCustomer) return;
    _seedDefaultCustomer();
  }

  void addItem(
    MenuProduct product, {
    double quantity = 1,
    String? comment,
    String? measurementUnit,
    List<SelectedModifier> modifiers = const [],
  }) {
    if (state.activePosOrderId == null) return;

    final settings = ref.read(appSettingsProvider);
    final separateRow =
        settings[SettingKeys.separateRowForEachItem]?.toLowerCase() == 'true';
    final newCartItemId =
        '${product.id}_${DateTime.now().microsecondsSinceEpoch}';

    // The modifiers add to the unit price BEFORE anything else looks at it, so
    // tax, discounts, promotions and every report keep working untouched.
    final surcharge = modifierSurcharge(modifiers);
    final unitPrice = product.price + surcharge;

    final items = List<CartItem>.from(state.items);
    // 🚨 The merge key includes the CHOSEN MODIFIERS, not just the product.
    // Merging on product id alone collapsed a plain burger and a burger with
    // extra cheese into one line at whichever price arrived first — and the
    // kitchen got a single ticket for two different sandwiches.
    final incomingKey = modifierSelectionKey(modifiers);
    final existingIndex = separateRow
        ? -1
        : items.indexWhere((i) =>
            i.productId == product.id &&
            modifierSelectionKey(i.selectedModifiers) == incomingKey);

    // `stockQuantity` is a STOCK figure — held in the category's reference unit
    // — while `quantity` is in the product's sale unit, so the two only compare
    // after a conversion. Both POS call sites pass a sentinel 9999 because the
    // real guard is `_passesStockGuards` against live local stock; this stays
    // correct for anything that ever passes a genuine figure.
    final stockCap = uomFromReference(product.stockQuantity, product.uomId);

    if (existingIndex >= 0) {
      if (items[existingIndex].quantity + quantity > stockCap) {
        throw Exception("Not enough stock!");
      }
      items[existingIndex].quantity += quantity;
      // Merge any newly-chosen comment into the existing line. Without this, a
      // comment picked when re-adding a product that's already in the cart
      // (separate-row OFF) is silently dropped and never reaches the kitchen
      // ticket. Comma-joined + de-duped to match how the comment picker stores it.
      final incoming = comment?.trim() ?? '';
      if (incoming.isNotEmpty) {
        items[existingIndex].comment =
            _mergeComments(items[existingIndex].comment, incoming);
      }
    } else {
      if (quantity > stockCap) {
        throw Exception("Not enough stock!");
      }
      // Fall back to the configured default tax rates when the product brings
      // none of its own, so taxes are applied automatically on add.
      final appliedTaxes = product.taxes.isNotEmpty
          ? product.taxes
          : _resolveDefaultTaxes();
      items.add(
        CartItem(
          cartItemId: newCartItemId,
          posOrderId: state.activePosOrderId!,
          productId: product.id,
          price: unitPrice,
          basePrice: product.price,
          selectedModifiers: List<SelectedModifier>.from(modifiers),
          cost: product.cost,
          quantity: quantity,
          productName: product.name,
          appliedTaxes: appliedTaxes,
          comment: comment,
          measurementUnit: measurementUnit ?? product.measurementUnit,
          uomId: product.uomId,
          isToWeigh: product.isToWeigh,
          isService: product.isService,
          // Decides whether the taxes above are already baked into `price` or
          // get added on top of it.
          isTaxInclusive: product.isTaxInclusivePrice,
        ),
      );
    }
    _applyPromotions(items);
    state = state.copyWith(items: items);
  }

  /// Combines two comma-separated comment strings, dropping blanks and
  /// case-insensitive duplicates while preserving order (existing parts first,
  /// then any new ones). Kept comma-joined so it renders as one line and matches
  /// how the menu's item-note dialog stores a selection.
  String _mergeComments(String? existing, String incoming) {
    final seen = <String>{};
    final parts = <String>[];
    for (final chunk in [existing ?? '', incoming]) {
      for (final p in chunk.split(',')) {
        final t = p.trim();
        if (t.isNotEmpty && seen.add(t.toLowerCase())) parts.add(t);
      }
    }
    return parts.join(', ');
  }

  void incrementItem(String cartItemId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index >= 0) {
      items[index].quantity += 1;
      _applyPromotions(items);
    }
    state = state.copyWith(items: items);
  }

  void decrementItem(String cartItemId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index >= 0 && items[index].quantity > 1) {
      items[index].quantity -= 1;
      _applyPromotions(items);
    }
    state = state.copyWith(items: items);
  }

  /// Sets (or clears, with null) the comment on an existing cart line, so a
  /// modifier can be changed after the item is in the cart instead of only at
  /// add time. Comments carry no price, so promotions don't need re-applying.
  void setItemComment(String cartItemId, String? comment) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index < 0) return;
    items[index].comment = comment;
    state = state.copyWith(items: items);
  }

  void removeItem(String cartItemId) {
    final items = List<CartItem>.from(state.items);
    items.removeWhere((i) => i.cartItemId == cartItemId);
    _applyPromotions(items);
    state = state.copyWith(items: items);
  }

  void updateItemQuantity(String cartItemId, double newQuantity) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index >= 0) {
      if (newQuantity <= 0) {
        items.removeAt(index);
      } else {
        items[index].quantity = newQuantity;
      }
      _applyPromotions(items);
    }
    state = state.copyWith(items: items);
  }

  /// Sets one line's unit price — the cart keypad's **Prix** mode.
  ///
  /// 🚨 The CALLER decides whether this is allowed: only a product with
  /// `isPriceChangeAllowed` may be repriced, and that flag rides on the cart
  /// item itself. Enforcing it here as well would be the wrong place — a
  /// promotion or a price-list change also writes this field and is not the
  /// cashier overriding a price.
  ///
  /// Promotions are re-applied because a repriced line can cross a threshold
  /// ("10% off over 100") that the old price did not.
  void updateItemPrice(String cartItemId, double newPrice) {
    if (newPrice < 0) return;

    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index < 0) return;

    // The cashier is repricing what they can SEE, which is the modified unit
    // price — so [newPrice] becomes `price` and the base is back-derived, not
    // the other way round. Setting `basePrice = newPrice` would silently add
    // the surcharge on top and ring up more than was typed.
    items[index].price = newPrice;
    items[index].basePrice =
        newPrice - modifierSurcharge(items[index].selectedModifiers);
    _applyPromotions(items);
    state = state.copyWith(items: items);
  }

  /// Re-chooses the modifiers on a line already in the cart.
  ///
  /// Recomputes from [CartItem.basePrice] rather than from the current `price`,
  /// so changing the choices twice cannot compound: the surcharge is applied to
  /// the product's own price every time, never to a price that already carries
  /// one.
  ///
  /// A manual reprice is deliberately NOT preserved — the operator repriced a
  /// line that no longer exists in the same form, and silently carrying an
  /// override onto a different set of choices is how a line ends up at a price
  /// nobody chose.
  void setItemModifiers(
    String cartItemId,
    List<SelectedModifier> modifiers, {
    String? comment,
  }) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index < 0) return;

    final item = items[index];
    item.selectedModifiers = List<SelectedModifier>.from(modifiers);
    item.price = item.basePrice + modifierSurcharge(modifiers);
    if (comment != null) item.comment = comment.trim().isEmpty ? null : comment;

    _applyPromotions(items);
    state = state.copyWith(items: items);
  }

  void updateItemTaxes(String cartItemId, List<MenuTax> newTaxes) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.cartItemId == cartItemId);
    if (index >= 0) {
      items[index].appliedTaxes = newTaxes;
    }
    state = state.copyWith(items: items);
  }

  /// The catalogue rows behind a set of order lines, keyed by product id.
  ///
  /// 🚨 Reopening an order has to restore each line's UNIT, and the server's
  /// `PosOrderItem` payload carries none — it sends a bare number. Rebuilding a
  /// line without it defaulted every one to `pcs`, so a parked 100 g line came
  /// back reading `x100`, and every downstream unit decision (the stock
  /// deduction, the guards, the receipt) then worked in the wrong unit on an
  /// order that had been perfectly correct when it was parked. Drift already
  /// holds the products offline, so the unit is looked up rather than guessed.
  Future<Map<int, Product>> _productsForLines(
    AppDatabase db,
    Iterable<int> productIds,
  ) async {
    final ids = productIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows =
        await (db.select(db.productsTable)..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: Product.fromDrift(r)};
  }

  Future<bool> loadExistingOrder(
    ApiClient apiClient,
    int companyId,
    int tableId,
    int? warehouseId,
  ) async {
    state = state.copyWith(isLoading: true);
    // Only used by the API fallback below; the local path takes the warehouse
    // off the saved order row itself.
    final resolvedWarehouseId = (warehouseId != null && warehouseId > 0)
        ? warehouseId
        : _newOrderWarehouseId;
    try {
      final db = ref.read(appDatabaseProvider);
      final localRow =
          await (db.select(db.posOrdersTable)
                ..where((t) => t.companyId.equals(companyId))
                ..where((t) => t.tableId.equals(tableId))
                ..where((t) => t.status.equals(0))
                ..limit(1))
              .getSingleOrNull();

      if (localRow != null) {
        // await, not a bare return: without it this Future escapes the try
        // and the catch below never clears isLoading, so a failed local
        // load leaves the cart spinning forever.
        return await loadOrderFromLocal(localRow.localId);
      }
      final order = await apiClient.getActiveOrderForTable(companyId, tableId);
      if (order == null) return false;

      final posOrderId = order['id'] ?? order['Id'];
      final orderNumber = order['number'] ?? order['Number'] ?? "ORD-TEMP";
      final discount = (order['discount'] ?? order['Discount'] ?? 0).toDouble();
      final discountType = (order['discountType'] ?? order['DiscountType'] ?? 0)
          .toInt();

      final itemsData = await apiClient.getOrderItems(companyId, posOrderId);

      final customerId = order['customerId'] ?? order['CustomerId'];
      if (customerId != null) {
        // AWAIT the list rather than reading a cold `.value`. Nothing keeps
        // allCustomersProvider warm on a reopen path, so the snapshot read was
        // usually null and the order silently came back as Walk-in — the same
        // cold-read trap already fixed in _seedDefaultCustomer.
        List<Customer> customers;
        try {
          customers = await ref.read(allCustomersProvider.future);
        } catch (_) {
          customers = const [];
        }
        final customer = customers.where((c) => c.id == customerId).firstOrNull;
        if (customer != null) {
          await setCustomer(companyId, customer);
        }
      }

      final serviceType = (order['serviceType'] ?? order['ServiceType'] ?? 0)
          .toInt();
      final serviceStatus =
          (order['serviceStatus'] ?? order['ServiceStatus'] ?? 1).toInt();
      final floorPlanTableId =
          order['floorPlanTableId'] ?? order['FloorPlanTableId'];

      final lineProducts = await _productsForLines(
        db,
        itemsData
            .map((i) => (i['productId'] ?? i['ProductId']) as int?)
            .whereType<int>(),
      );

      final List<CartItem> loadedItems = [];
      for (int li = 0; li < itemsData.length; li++) {
        final item = itemsData[li];
        final serverId = (item['id'] ?? item['Id']) as int?;
        final productId = (item['productId'] ?? item['ProductId']) as int;
        final catalogue = lineProducts[productId];
        final cartItemId = (serverId != null && serverId > 0)
            ? serverId.toString()
            : '${productId}_$li';
        loadedItems.add(
          CartItem(
            cartItemId: cartItemId,
            posOrderId: posOrderId,
            productId: productId,
            price: (item['price'] ?? item['Price'] ?? 0).toDouble(),
            quantity: (item['quantity'] ?? item['Quantity'] ?? 1).toDouble(),
            discount: (item['discount'] ?? item['Discount'] ?? 0).toDouble(),
            productName: item['productName'] ?? item['ProductName'] ?? 'Item',
            // Restored from the catalogue — see [_productsForLines]. A product
            // that is not in the local cache keeps CartItem's `pcs` default,
            // which is the same identity conversion it had before.
            uomId: catalogue?.uomId ?? kUomPieces,
            isToWeigh: catalogue?.isToWeigh ?? false,
            isService: catalogue?.isService ?? false,
            measurementUnit: catalogue?.measurementUnit,
            appliedTaxes:
                (item['taxes'] as List?)
                    ?.map((t) => MenuTax.fromJson(t))
                    .toList() ??
                (item['Taxes'] as List?)
                    ?.map((t) => MenuTax.fromJson(t))
                    .toList() ??
                [],
            comment: (item['comment'] ?? item['Comment']) as String?,
            isSaved: true,
            // The server's PosOrderItem payload carries no tax-mode flag, so
            // this inherits CartItem's `true` default. That matches the
            // catalogue (Product.IsTaxInclusivePrice defaults true on both
            // DBs), and keeps a PULLED open order priced identically to the
            // till that parked it — which persists the flag locally.
          ),
        );
      }

      _applyPromotions(loadedItems);

      // Carry the server order's booking link into the cart — and when it has
      // none, CLEAR any bookingId left from a previous cart, or paying this
      // order would complete an unrelated reservation.
      final loadedBookingId =
          ((order['bookingId'] ?? order['BookingId']) as num?)?.toInt();
      state = state.copyWith(
        activePosOrderId: posOrderId,
        items: loadedItems,
        orderNumber: orderNumber,
        manualCartDiscount: discount,
        manualCartDiscountType: discountType,
        serviceType: serviceType,
        serviceStatus: serviceStatus,
        floorPlanTableId: floorPlanTableId,
        activeWarehouseId: resolvedWarehouseId,
        bookingId: loadedBookingId,
        clearBooking: loadedBookingId == null,
        isLoading: false,
        // This is the API fallback — the local lookup above found nothing, so
        // this cart has no local row. Without clearing, the previous order's
        // localId stayed on the cart and the next save overwrote THAT order.
        clearExistingLocalOrderId: true,
      );

      final warehouses = ref.read(allWarehousesProvider).value ?? const [];
      final wh = warehouses
          .where((w) => w.id == resolvedWarehouseId)
          .firstOrNull;
      if (wh != null) {
        ref.read(selectedWarehouseProvider.notifier).state = wh;
      }

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> saveOrderLocally({
    required int companyId,
    required int userId,
  }) async {
    if (state.items.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final db = ref.read(appDatabaseProvider);
      final now = DateTime.now().toUtc();

      final serverId =
          (state.activePosOrderId != null && state.activePosOrderId! > 0)
          ? state.activePosOrderId
          : null;

      // Reuse the existing local row for this order so an edit never leaves a
      // DUPLICATE behind. Prefer the tracked existingLocalOrderId; otherwise —
      // a reopen path that didn't set it (e.g. a server-only order loaded via
      // loadOrderById's API fallback, or a row the sync materialised as
      // svr_<id>) — find the row by its serverId. Only mint a fresh UUID when
      // there genuinely is no local row for this order yet.
      String? resolvedLocalId = state.existingLocalOrderId;
      if (resolvedLocalId == null && serverId != null) {
        final int sid = serverId;
        final existing = await (db.select(db.posOrdersTable)
              ..where((t) => t.serverId.equals(sid))
              ..where((t) => t.companyId.equals(companyId))
              ..limit(1))
            .getSingleOrNull();
        resolvedLocalId = existing?.localId;
      }
      final String localId = resolvedLocalId ?? const Uuid().v4();

      final orderNum =
          state.orderNumber ??
          () {
            final n = ref.read(dailyOrderNumberProvider);
            return '${_getPrefix(state.serviceType)} #${n.toString().padLeft(3, '0')}';
          }();

      final settings = ref.read(appSettingsProvider);
      final discountBeforeTax =
          settings[SettingKeys.discountApplyRule] == 'Before tax';

      final taxRows = <PosOrderItemTaxesTableCompanion>[];
      // Snapshots of what each line was customised with. They hang off the
      // line's own localId, minted just below.
      final modifierRows = <PosOrderItemModifiersTableCompanion>[];

      // cartItemId → the localId its pos_order_item row gets, so discount_lines
      // can link item-level discounts to the right row.
      final itemLocalIds = <String, String>{};

      final items = state.items.map((item) {
        final itemLocalId = const Uuid().v4();
        itemLocalIds[item.cartItemId] = itemLocalId;

        for (var mi = 0; mi < item.selectedModifiers.length; mi++) {
          final m = item.selectedModifiers[mi];
          modifierRows.add(
            PosOrderItemModifiersTableCompanion(
              localId: Value(const Uuid().v4()),
              orderItemLocalId: Value(itemLocalId),
              // Nullable and unenforced: the snapshot below is the record, the
              // id only exists so reports can group by option.
              modifierOptionId: Value(m.modifierOptionId),
              groupName: Value(m.groupName),
              name: Value(m.name),
              additionalPrice: Value(m.additionalPrice),
              rank: Value(mi),
            ),
          );
        }

        final summedRate = item.appliedTaxes
            .where((t) => !t.isFixed)
            .fold<double>(0, (sum, t) => sum + t.rate);

        final taxableBase = discountBeforeTax
            ? (item.price - item.discount - item.promotionalDiscount) *
                  item.quantity
            : item.price * item.quantity;

        final taxBreakdown = <Map<String, dynamic>>[];
        for (final tax in item.appliedTaxes) {
          final double amount;
          if (tax.isFixed) {
            amount = tax.rate * item.quantity;
          } else {
            amount = taxableBase * (tax.rate / 100);
          }
          taxBreakdown.add({
            'id': tax.id,
            'amount': double.parse(amount.toStringAsFixed(4)),
          });
          taxRows.add(
            PosOrderItemTaxesTableCompanion(
              localId: Value(const Uuid().v4()),
              orderId: Value(localId),
              productId: Value(item.productId),
              taxRateId: Value(tax.id),
              taxAmount: Value(amount),
              syncStatus: const Value('pending'),
            ),
          );
        }

        return PosOrderItemsTableCompanion(
          localId: Value(itemLocalId),
          orderId: Value(localId),
          productId: Value(item.productId),
          quantity: Value(item.quantity),
          unitPrice: Value(item.price),
          discount: Value(item.discount),
          discountType: Value(item.discountType),
          // Preserve the operator's input form (10% vs a fixed amount) so it
          // survives a save→push→pull to another till (discount_lines don't cross
          // for an open order). Null when no manual item discount was entered.
          discountInputValue: Value(item.discountInputValue),
          discountInputType: Value(item.discountInputType),
          // Pinned so reopening this order prices it the same way even if the
          // product's tax mode is edited in the meantime.
          isTaxInclusive: Value(item.isTaxInclusive),
          taxRate: Value(summedRate),
          comment: Value(item.comment),
          warehouseId: Value(item.warehouseId ?? effectiveWarehouseId),
          taxesJson: Value(
            taxBreakdown.isEmpty ? null : jsonEncode(taxBreakdown),
          ),
          syncStatus: const Value('pending'),
        );
      }).toList();

      // Resolve in case a sync swapped this table's temp id while the cart was
      // open — see AppDatabase.resolveFloorPlanTableId.
      final resolvedTableId =
          await db.resolveFloorPlanTableId(state.floorPlanTableId);

      await db.saveOpenOrder(
        PosOrdersTableCompanion(
          localId: Value(localId),
          serverId: Value(serverId),
          companyId: Value(companyId),
          userId: Value(userId),
          tableId: Value(resolvedTableId),
          customerId: Value(state.selectedCustomer?.id),
          serviceType: Value(state.serviceType),
          serviceStatus: Value(state.serviceStatus),
          orderName: Value(orderNum),
          bookingId: Value(state.bookingId),
          bookingStaffId: Value(state.bookingStaffId),
          openedAt: Value(now),
          status: const Value(0),
          // A parked order belongs to the session that took it — this is what
          // makes "3 orders still parked" block that session's close instead of
          // silently letting the drawer shut on unfinished tables.
          sessionLocalId:
              Value(ref.read(activeSessionProvider).value?.localId),
          total: Value(grandTotal),
          discount: Value(state.manualCartDiscount),
          discountType: Value(state.manualCartDiscountType),
          warehouseId: Value(effectiveWarehouseId),
          syncStatus: const Value('pending'),
          lastModified: Value(now),
        ),
        items,
        itemTaxes: taxRows,
        itemModifiers: modifierRows,
      );

      // Phase 2: record the normalized discount breakdown for this order. The
      // legacy header/item `discount` columns above stay populated for back-compat.
      await db.replaceDiscountLines(
        orderLocalId: localId,
        lines: buildDiscountLines(
          companyId: companyId,
          orderLocalId: localId,
          itemLocalIds: itemLocalIds,
        ),
      );

      final isFirstSave = state.existingLocalOrderId == null;
      state = state.copyWith(
        existingLocalOrderId: localId,
        orderNumber: orderNum,
      );
      if (isFirstSave) {
        ref.read(dailyOrderNumberProvider.notifier).state =
            ref.read(dailyOrderNumberProvider) + 1;
      }
      // Push the fresh snapshot to the paired Kitchen Displays now that the
      // order (or its edit) is in Drift — this is what makes a saved/updated
      // order appear on the KDS without any manual refresh.
      _notifyKitchen();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Loads an open order directly from local Drift — used when the order has
  /// no serverId yet (created offline, not yet synced). Bypasses the API so
  /// the 404 that `loadOrderById` would get for id=0 never fires.
  Future<bool> loadOrderFromLocal(String localId) async {
    state = state.copyWith(
      isLoading: true,
      clearExistingLocalOrderId: true,
    );
    try {
      final db = ref.read(appDatabaseProvider);

      final row =
          await (db.select(db.posOrdersTable)
                ..where((t) => t.localId.equals(localId))
                ..limit(1))
              .getSingleOrNull();
      if (row == null) return false;

      final itemRows = await (db.select(
        db.posOrderItemsTable,
      )..where((t) => t.orderId.equals(localId))).get();

      // NB: the customer is restored below via _restoreCustomerDiscount (a direct
      // Drift read by id) + the copyWith + the currentCustomerProvider sync. The
      // old cold-read setCustomer here was removed: it read
      // allCustomersProvider.value, which is usually empty when reopening a
      // booking's order (nothing keeps that provider warm), so it silently set no
      // customer — and even when it did, its state was overwritten by the restore
      // below. It also fired a needless network call on an offline-first path.

      // Offline-First fix: Build a map of products directly from database cache
      // instead of reading the potentially uninitialized stream provider
      final productIds = itemRows
          .map((item) => item.productId)
          .whereType<int>()
          .toSet()
          .toList();

      final Map<int, Product> productMap = {};
      if (productIds.isNotEmpty) {
        final productRows = await (db.select(
          db.productsTable,
        )..where((t) => t.id.isIn(productIds))).get();
        for (final r in productRows) {
          final product = Product.fromDrift(r);
          productMap[product.id] = product;
        }
      }

      // Build a tax lookup map so we can reconstruct full MenuTax objects
      // (rate, isFixed, etc.) from the IDs stored in taxesJson.
      final allTaxRows = await db.select(db.taxesTable).get();
      final taxMap = {
        for (final t in allTaxRows)
          t.id: MenuTax(
            id: t.id,
            name: t.name,
            rate: t.rate,
            isFixed: t.isFixed,
            isTaxOnTotal: t.isTaxOnTotal,
          ),
      };

      // The chosen modifiers, keyed by the line's own localId. Loaded up front
      // rather than per line so reopening an order is one query, not N.
      final modifiersByLine = await db.orderItemModifiersByLine(localId);

      // Build CartItems using the safe query-backed product map for metadata.
      final List<CartItem> loadedItems = itemRows.map((item) {
        final product = productMap[item.productId];

        // Reconstruct full MenuTax objects by looking up each tax ID in the
        // local taxes cache. taxesJson stores [{id, amount}] — the amount is
        // for SyncManager only; the cart needs the live rate/isFixed/etc.
        List<MenuTax> appliedTaxes = const [];
        if (item.taxesJson != null) {
          final decoded = jsonDecode(item.taxesJson!) as List;
          appliedTaxes = decoded
              .map((e) => taxMap[e['id'] as int])
              .whereType<MenuTax>()
              .toList();
        }

        return CartItem(
          cartItemId: '${item.productId}_${item.localId}',
          posOrderId: row.serverId ?? 0,
          productId: item.productId,
          price: item.unitPrice,
          quantity: item.quantity,
          discount: item.discount,
          discountType: item.discountType,
          productName: (product?.name ?? 'Product ${item.productId}'),
          appliedTaxes: appliedTaxes,
          warehouseId: item.warehouseId,
          comment: item.comment,
          // 🚨 Restored from the line's own SNAPSHOTS, not recomputed from the
          // catalogue. Without this a parked order reopened with the right
          // TOTAL and no choices on it — the surcharge is already inside
          // `unitPrice`, so the money looked correct while the kitchen ticket
          // had lost the instruction. `basePrice` is derived back out so
          // re-editing the choices recomputes from the product's own price
          // instead of compounding on one that already carries a surcharge.
          selectedModifiers:
              selectedModifiersFromRows(modifiersByLine[item.localId] ?? const []),
          basePrice: item.unitPrice -
              modifierSurcharge(selectedModifiersFromRows(
                  modifiersByLine[item.localId] ?? const [])),
          // The unit is NOT stored on the order line — it belongs to the
          // product, and a reopened line has to read it back or it silently
          // becomes `pcs`. Same restore as the two API paths above.
          uomId: product?.uomId ?? kUomPieces,
          isToWeigh: product?.isToWeigh ?? false,
          measurementUnit: product?.measurementUnit,
          // Cross-till fallback for the discount input form: the discount_lines
          // restore below overrides this for the originating till, but a PULLED
          // order carries no lines, so this is what makes it show "10%".
          discountInputValue: item.discountInputValue,
          discountInputType: item.discountInputType,
          isService: product?.isService ?? false,
          // Prefer the value pinned when the order was parked. A row written
          // before v57 has none — fall back to the product's current flag, and
          // only then to the `true` catalogue default.
          isTaxInclusive:
              item.isTaxInclusive ?? product?.isTaxInclusivePrice ?? true,
        );
      }).toList();

      _applyPromotions(loadedItems);

      // Restore each item's manual-discount entry (%/fixed) from the saved lines
      // (matched by product) so a reopened order shows "10%" rather than its
      // flattened money value, and re-saving preserves the original figure.
      final savedLines = await db.getDiscountLinesForOrder(localId);
      final manualByProduct = <int, DiscountLinesTableData>{};
      for (final l in savedLines) {
        if (l.source == DiscountSource.manualItem && l.sourceRefId != null) {
          manualByProduct[l.sourceRefId!] = l;
        }
      }
      for (final it in loadedItems) {
        final l = manualByProduct[it.productId];
        if (l != null) {
          it.discountInputValue = l.value;
          it.discountInputType = l.valueType;
        }
      }

      // Restore the customer + their profile discount from the saved lines, so
      // the reopened total matches what was parked (offline, no API call).
      final restored = await _restoreCustomerDiscount(localId, row.customerId);

      state = state.copyWith(
        // `?? 0` is load-bearing, not defensive. serverId is null for any order
        // created offline and not yet synced — i.e. every booking order. The POS
        // treats `activePosOrderId == null` as "no order is open" and silently
        // calls startTablelessOrder on the next product tap, which builds a
        // FRESH CartState: existingLocalOrderId and bookingId are wiped, so the
        // following save minted a new UUID and left a DUPLICATE row behind
        // rather than updating this order. 0 is the established "local-only
        // order" sentinel (startTableOrder / startBookingOrder both use it) and
        // saveOrderLocally already maps it back to a null serverId.
        activePosOrderId: row.serverId ?? 0,
        items: loadedItems,
        orderNumber: row.orderName,
        serviceType: row.serviceType,
        serviceStatus: row.serviceStatus,
        floorPlanTableId: row.tableId,
        activeWarehouseId: row.warehouseId,
        manualCartDiscount: row.discount,
        manualCartDiscountType: row.discountType,
        selectedCustomer: restored.customer,
        customerDiscountValue: restored.value,
        customerDiscountType: restored.type,
        // Reinstate the booking this order was opened from, so reopening it by
        // tapping its table shows the same "<table> · Staff: <name>" header and
        // booking banner as opening it from the bookings screen. A non-booking
        // order must actively clear the field, not inherit the last cart's.
        bookingId: row.bookingId,
        bookingStaffId: row.bookingStaffId,
        clearBooking: row.bookingId == null,
        isLoading: false,
        existingLocalOrderId: localId,
      );

      final warehouses = ref.read(allWarehousesProvider).value ?? const [];
      final wh = warehouses.where((w) => w.id == row.warehouseId).firstOrNull;
      if (wh != null) ref.read(selectedWarehouseProvider.notifier).state = wh;

      // The POS header watches currentCustomerProvider, but the copyWith above
      // only set the cart's selectedCustomer. Sync the two, or a reopened order
      // (e.g. a booking's "Open Service") shows a stale Walk-in / empty value the
      // Notifier still holds from the previous order instead of this order's real
      // customer. This is the single source that keeps the header truthful.
      final loadedCustomer = state.selectedCustomer;
      if (loadedCustomer != null) {
        ref.read(currentCustomerProvider.notifier).setCustomer(loadedCustomer);
      } else {
        ref.invalidate(currentCustomerProvider);
      }

      return true;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<bool> loadOrderById(
    ApiClient apiClient,
    int companyId,
    int posOrderId,
    int warehouseId,
  ) async {
    state = state.copyWith(
      isLoading: true,
      clearExistingLocalOrderId: true,
    );
    try {
      final db = ref.read(appDatabaseProvider);
      final localRow =
          await (db.select(db.posOrdersTable)
                ..where((t) => t.serverId.equals(posOrderId))
                ..limit(1))
              .getSingleOrNull();
      if (localRow != null) {
        // await, not a bare return: without it this Future escapes the try
        // and the catch below never clears isLoading, so a failed local
        // load leaves the cart spinning forever.
        return await loadOrderFromLocal(localRow.localId);
      }
      final order = await apiClient.getPosOrderById(companyId, posOrderId);
      final orderNumber = order['number'] ?? order['Number'] ?? "ORD-TEMP";
      final discount = (order['discount'] ?? order['Discount'] ?? 0).toDouble();
      final discountType = (order['discountType'] ?? order['DiscountType'] ?? 0)
          .toInt();

      final itemsData = await apiClient.getOrderItems(companyId, posOrderId);
      final customerId = order['customerId'] ?? order['CustomerId'];
      if (customerId != null) {
        // AWAIT the list rather than reading a cold `.value`. Nothing keeps
        // allCustomersProvider warm on a reopen path, so the snapshot read was
        // usually null and the order silently came back as Walk-in — the same
        // cold-read trap already fixed in _seedDefaultCustomer.
        List<Customer> customers;
        try {
          customers = await ref.read(allCustomersProvider.future);
        } catch (_) {
          customers = const [];
        }
        final customer = customers.where((c) => c.id == customerId).firstOrNull;
        if (customer != null) {
          await setCustomer(companyId, customer);
        }
      }

      final serviceType = (order['serviceType'] ?? order['ServiceType'] ?? 0)
          .toInt();
      final serviceStatus =
          (order['serviceStatus'] ?? order['ServiceStatus'] ?? 1).toInt();
      final floorPlanTableId =
          order['floorPlanTableId'] ?? order['FloorPlanTableId'];

      final lineProducts = await _productsForLines(
        db,
        itemsData
            .map((i) => (i['productId'] ?? i['ProductId']) as int?)
            .whereType<int>(),
      );

      final List<CartItem> loadedItems = [];
      for (int li = 0; li < itemsData.length; li++) {
        final item = itemsData[li];
        final serverId = (item['id'] ?? item['Id']) as int?;
        final productId = (item['productId'] ?? item['ProductId']) as int;
        final catalogue = lineProducts[productId];
        final cartItemId = (serverId != null && serverId > 0)
            ? serverId.toString()
            : '${productId}_$li';
        loadedItems.add(
          CartItem(
            cartItemId: cartItemId,
            posOrderId: posOrderId,
            productId: productId,
            price: (item['price'] ?? item['Price'] ?? 0).toDouble(),
            quantity: (item['quantity'] ?? item['Quantity'] ?? 1).toDouble(),
            discount: (item['discount'] ?? item['Discount'] ?? 0).toDouble(),
            productName: item['productName'] ?? item['ProductName'] ?? 'Item',
            // Restored from the catalogue — see [_productsForLines]. A product
            // that is not in the local cache keeps CartItem's `pcs` default,
            // which is the same identity conversion it had before.
            uomId: catalogue?.uomId ?? kUomPieces,
            isToWeigh: catalogue?.isToWeigh ?? false,
            isService: catalogue?.isService ?? false,
            measurementUnit: catalogue?.measurementUnit,
            appliedTaxes:
                (item['taxes'] as List?)
                    ?.map((t) => MenuTax.fromJson(t))
                    .toList() ??
                (item['Taxes'] as List?)
                    ?.map((t) => MenuTax.fromJson(t))
                    .toList() ??
                [],
            comment: (item['comment'] ?? item['Comment']) as String?,
            isSaved: true,
            // The server's PosOrderItem payload carries no tax-mode flag, so
            // this inherits CartItem's `true` default. That matches the
            // catalogue (Product.IsTaxInclusivePrice defaults true on both
            // DBs), and keeps a PULLED open order priced identically to the
            // till that parked it — which persists the flag locally.
          ),
        );
      }

      _applyPromotions(loadedItems);
      // Same booking-link hygiene as loadExistingOrder: adopt the server
      // order's bookingId, and clear a stale one when it carries none.
      final loadedBookingId =
          ((order['bookingId'] ?? order['BookingId']) as num?)?.toInt();
      state = state.copyWith(
        activePosOrderId: posOrderId,
        items: loadedItems,
        orderNumber: orderNumber,
        manualCartDiscount: discount,
        manualCartDiscountType: discountType,
        serviceType: serviceType,
        serviceStatus: serviceStatus,
        floorPlanTableId: floorPlanTableId,
        activeWarehouseId: warehouseId,
        bookingId: loadedBookingId,
        clearBooking: loadedBookingId == null,
        isLoading: false,
        existingLocalOrderId: localRow?.localId,
        // localRow is null on this branch (it is the API fallback), so the line
        // above is a no-op by design — be explicit that this cart has no local
        // row rather than letting the previous order's id ride along.
        clearExistingLocalOrderId: localRow == null,
      );

      final warehouses = ref.read(allWarehousesProvider).value ?? const [];
      final wh = warehouses.where((w) => w.id == warehouseId).firstOrNull;
      if (wh != null) {
        ref.read(selectedWarehouseProvider.notifier).state = wh;
      }

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  @Deprecated(
    'Use AppDatabase.insertOfflineOrder via PaymentCheckoutDialog instead.',
  )
  Future<bool> checkoutOrder({
    required ApiClient apiClient,
    required int companyId,
    required int userId,
    required int paymentTypeId,
    required double amountPaid,
    required int documentTypeId,
  }) async {
    if (state.activePosOrderId == null || state.items.isEmpty) return false;
    state = state.copyWith(isLoading: true);

    try {
      final response = await apiClient.bulkAddPosOrderItems(
        companyId,
        effectiveWarehouseId,
        state.items,
        grandTotal,
      );

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? "Failed to save cart before checkout.",
        );
      }

      final activeTableId =
          state.floorPlanTableId ?? ref.read(floorPlanTableProvider);
      final checkoutOrderNum = ref
          .read(dailyOrderNumberProvider)
          .toString()
          .padLeft(3, '0');
      String orderNumber =
          state.orderNumber ??
          '${_getPrefix(state.serviceType)} #$checkoutOrderNum';
      if (state.orderNumber == null && activeTableId != null) {
        final tables = ref.read(tablesByFloorPlanProvider).value ?? const [];
        final table = tables.where((t) => t.id == activeTableId).firstOrNull;
        if (table != null) orderNumber = "ORD- ${table.name}";
      }
      await apiClient.updatePosOrder(companyId, {
        "id": state.activePosOrderId,
        "userId": userId,
        "number": orderNumber,
        "discount": state.manualCartDiscount,
        "discountType": state.manualCartDiscountType,
        "total": grandTotal,
        "customerId": state.selectedCustomer?.id,
        "serviceType": state.serviceType,
        "serviceStatus": state.serviceStatus,
        "floorPlanTableId": activeTableId,
        "warehouseId": effectiveWarehouseId,
      });

      List<CheckoutItemDto> checkoutItems = [];
      for (var item in state.items) {
        double priceAfterDiscount =
            item.price - item.discount - item.promotionalDiscount;
        double totalAfterDiscount = priceAfterDiscount * item.quantity;
        double itemTaxTotal = 0;
        List<CheckoutItemTaxDto> itemTaxes = [];

        for (var tax in item.appliedTaxes) {
          double amount = tax.isFixed
              ? (tax.rate * item.quantity)
              : (totalAfterDiscount * (tax.rate / 100));
          itemTaxTotal += amount;
          itemTaxes.add(CheckoutItemTaxDto(taxId: tax.id, amount: amount));
        }

        double finalItemTotal = totalAfterDiscount + itemTaxTotal;

        checkoutItems.add(
          CheckoutItemDto(
            productId: item.productId,
            quantity: item.quantity,
            priceBeforeTaxAfterDiscount: priceAfterDiscount,
            priceAfterDiscount: priceAfterDiscount,
            total: finalItemTotal,
            totalAfterDocumentDiscount: totalAfterDiscount,
            taxes: itemTaxes,
          ),
        );
      }

      final request = CheckoutRequest(
        posOrderId: state.activePosOrderId!,
        paymentTypeId: paymentTypeId,
        amountPaid: amountPaid,
        documentTypeId: documentTypeId,
        warehouseId: effectiveWarehouseId,
        items: checkoutItems,
        grandTotal: grandTotal,
        orderNumber: orderNumber,
      );

      final success = await apiClient.checkoutPosOrder(
        companyId,
        userId,
        request,
      );

      if (success) {
        _notifyKitchen();
        clearCart();
        ref.invalidate(allBookingsProvider);
        ref.invalidate(tablesByFloorPlanProvider);
        await Future.delayed(const Duration(milliseconds: 300));
        await syncOrderNumber(companyId);
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> voidOrder({
    required ApiClient apiClient,
    required int companyId,
  }) async {
    if (state.activePosOrderId == null) return false;
    state = state.copyWith(isLoading: true);
    try {
      final success = await apiClient.voidPosOrder(
        companyId,
        state.activePosOrderId!,
        // `?? 1` here targeted a warehouse the company may not even own (see
        // effectiveWarehouseId). Voiding restores stock, so a bogus id restocks
        // the wrong place. effectiveWarehouseId resolves selection → configured
        // default and only then falls back.
        effectiveWarehouseId,
      );
      if (success) {
        _notifyKitchen();
        clearCart();
        ref.invalidate(allBookingsProvider);
        ref.invalidate(tablesByFloorPlanProvider);
        await Future.delayed(const Duration(milliseconds: 300));
        await syncOrderNumber(companyId);
      }
      return success;
    } catch (e) {
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Persists the open order and empties the till — used when the operator
  /// leaves the POS for the floor plan via the header Tables button.
  ///
  /// Delegates to [saveOrderLocally] rather than writing its own copy of the
  /// save. It used to have one, and it had drifted badly: it minted a FRESH
  /// `localId` with `serverId: null` on every call, so suspending an order
  /// that was already backed by a local row INSERTED A SECOND ONE — two open
  /// orders on the same table, which is exactly what the operator hit by
  /// reopening a table and then pressing Tables in the header. [saveOrderLocally]
  /// resolves the existing row (by `existingLocalOrderId`, else by `serverId`)
  /// and upserts it, which is the behaviour the normal Save button always had.
  ///
  /// Delegating also recovers four things the private copy silently dropped:
  /// the order's `serverId`, its **booking link**, the per-item `taxesJson`
  /// and the `pos_order_item_taxes` rows — the last two now being money data.
  /// And the daily order number is no longer burned on every suspend; it
  /// advances only on a genuinely new order.
  Future<bool> saveAndSuspend({
    required int companyId,
    required int userId,
  }) async {
    if (state.activePosOrderId == null) return false;
    if (state.items.isEmpty) return false;

    await saveOrderLocally(companyId: companyId, userId: userId);
    clearCart();
    return true;
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  () => CartNotifier(),
);

Future<void> syncLatestOrderNumber(WidgetRef ref, int companyId) =>
    ref.read(cartProvider.notifier).syncOrderNumber(companyId);

final cartTotalProvider = Provider<double>((ref) {
  final cartState = ref.watch(cartProvider);
  final cartNotifier = ref.watch(cartProvider.notifier);

  if (cartState.items.isEmpty) return 0.0;

  // Delegate entirely to the notifier's getters so there is a single source
  // of truth for tax calculation (including discountApplyRule).
  return cartNotifier.grandTotal;
});
