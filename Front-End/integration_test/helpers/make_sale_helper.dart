/// `makeSale` — rings one product up and pays for it.
///
/// ```dart
/// await ensureRegisterOpen(tester, ctx);
/// final sale = await makeSale(tester, ctx);           // sells the first thing
/// final sale = await makeSale(tester, ctx, productName: espresso);
/// ```
///
/// Returns what was sold and for how much, so the verification pass compares the
/// banked row against **what the cashier was shown** rather than against a total
/// the test re-derived for itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/payment_checkout_dialog.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/menu/menu_screen.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_provider.dart';
import 'package:pos_app/product/product_search_bar.dart';
import 'package:pos_app/product/product_sort.dart';
import 'package:pos_app/session/session_provider.dart';

import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// One completed sale, as the till reported it at the moment of checkout.
class E2ESale {
  const E2ESale({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.userId,
    required this.sessionLocalId,
    required this.documentsBefore,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  /// The grand total the cashier was shown, captured BEFORE checkout cleared
  /// the cart. Every later assertion is made against this.
  final double total;

  final int paymentTypeId;
  final String paymentTypeName;
  final int userId;

  /// The open session's local id, or null when `RequireOpenSession` is off —
  /// in which case a sale banks unattached BY DESIGN, and asserting a link
  /// would fail a correctly-working till.
  ///
  /// A String, not an int: session rows are keyed by a UUID `localId` the
  /// terminal mints offline, the same convention `documents` and `barcodes` use.
  final String? sessionLocalId;

  /// Which documents existed before this sale.
  ///
  /// 🚨 The local database also holds documents pulled from the SERVER and from
  /// OTHER tills, so "the newest row" is a guess. The row that was not here a
  /// moment ago is not.
  final Set<String> documentsBefore;
}

/// Sells one product and completes the payment.
///
/// [productName] follows the smart-default rule: named, it sells that product;
/// omitted, it walks the catalogue for the first thing a cashier could actually
/// ring up. [paymentTypeName] likewise defaults to the first type that can carry
/// an ordinary cash sale.
///
/// Assumes the register is open (`ensureRegisterOpen`) and the till is on the
/// POS tab.
Future<E2ESale> makeSale(
  WidgetTester tester,
  E2EContext ctx, {
  String? productName,
  String? paymentTypeName,
  String? barcode,
}) async {
  final container = ctx.container;

  final user = container.read(currentUserProvider);
  expect(user, isNotNull, reason: 'Signed in with no current user.');

  await waitFor(
    tester,
    find.byType(MenuScreen),
    timeout: const Duration(seconds: 60),
    because: 'The till is not on the POS menu tab.',
  );

  // 🚨 Wait for the PRODUCTS too, not just the groups. They are separate
  // streams, and a run that started picking while the product list was still
  // loading would read "this group has nothing in it", descend into a sub-folder
  // that was never the target, and fail somewhere else entirely.
  await waitUntil(
    tester,
    () async =>
        (container.read(allProductGroupsProvider).value ?? const []).isNotEmpty &&
        (container.read(allProductsListProvider).value ?? const []).isNotEmpty,
    describe: 'the catalogue reaches the till',
    timeout: const Duration(seconds: 120),
  );

  final target = _pick(container, productName);
  expect(
    target,
    isNotNull,
    reason: productName == null
        ? 'This company has no enabled product in any group. Run setup_catalog '
            'first.'
        : 'No enabled product named "$productName" in this catalogue.',
  );

  final product = target!.product;

  // ── Ring it up ─────────────────────────────────────────────────────────────
  //
  // A RETAIL till sells by scanning. Submitting the code into the search field
  // is exactly what a USB scanner does — it types the digits and sends Enter —
  // so this drives the same `_handleBarcodeSubmit` path a real scan does,
  // nomenclature rules and all, rather than a shortcut around it.
  if (barcode != null) {
    step('Scanning $barcode');
    await _scan(tester, barcode);
    await _settleAddToCart(tester, ctx, product);
  } else {
    await _tapThroughToProduct(tester, ctx, target);
  }

  final cart = container.read(cartProvider);
  expect(
    cart.items.length,
    1,
    reason: 'One tap on one product should put exactly one line in the cart.',
  );
  final line = cart.items.single;
  expect(line.productId, product.id);

  final total = container.read(cartTotalProvider);
  step('Cart: ${line.quantity} × ${line.productName} = $total');

  // ── Pay ────────────────────────────────────────────────────────────────────
  final db = container.read(appDatabaseProvider);
  final sessionLocalId = container.read(activeSessionProvider).value?.localId;
  final before = (await db.getDocuments(companyId: ctx.company.companyId))
      .map((d) => d.localId)
      .toSet();

  await tapVisible(tester, find.text(ctx.l.posPay));
  await waitFor(
    tester,
    find.byType(PaymentCheckoutDialog),
    timeout: const Duration(seconds: 30),
    because: 'PAY did not open the checkout.',
  );

  // 🚨 Read the payment types only once the dialog is UP, never before.
  // `allPaymentTypesProvider` is `autoDispose` and nothing on the till watches
  // it — the checkout dialog is its only listener here. Reading it earlier
  // starts the stream, gets `AsyncLoading` back, and reports a company with no
  // payment types at all.
  await waitUntil(
    tester,
    () async =>
        (container.read(allPaymentTypesProvider).value ?? const []).isNotEmpty,
    describe: 'the payment types load',
    timeout: const Duration(seconds: 60),
  );

  final payType = _payType(container, paymentTypeName);
  step('Paying with ${payType.name}');

  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(PaymentCheckoutDialog),
      matching: find.text(payType.name),
    ),
  );

  // 🚨 Tender has to be TYPED. The Complete button is dead until
  // `paid >= grandTotal` for a type that marks the sale paid, and the numpad
  // starts at 0 — there is no "exact amount" key. Rounding up to the next whole
  // unit is what a cashier hands over, and the app banks `min(tendered, total)`
  // either way, so the change is not counted as money the shop took.
  final tender = total.ceil();
  for (final digit in '$tender'.split('')) {
    await tapVisible(tester, _numKey(digit));
  }
  step('Tendered $tender for $total');

  await tapVisible(tester, find.text(ctx.l.completeTransaction));

  // Both print switches ship off, so the receipt prints SILENTLY and no prompt
  // appears. On a terminal where someone turned the prompt on, answer it rather
  // than time out waiting for a dialog that is waiting for us.
  await pumpFor(tester, const Duration(seconds: 2));
  if (find.text(ctx.l.transactionSuccessful).evaluate().isNotEmpty) {
    await tapVisible(tester, find.text(ctx.l.actionNo));
  }

  await waitForGone(
    tester,
    find.byType(PaymentCheckoutDialog),
    timeout: const Duration(seconds: 120),
  );
  step('Checkout closed');

  return E2ESale(
    productId: product.id,
    productName: product.name,
    quantity: line.quantity,
    unitPrice: line.price,
    total: total,
    paymentTypeId: payType.id,
    paymentTypeName: payType.name,
    userId: user!.id,
    sessionLocalId: sessionLocalId,
    documentsBefore: before,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Picking what to sell
// ─────────────────────────────────────────────────────────────────────────────

/// The named product, or the first one a cashier could actually ring up.
({List<ProductGroup> path, Product product})? _pick(
  ProviderContainer container,
  String? productName,
) {
  if (productName == null) return _firstSellable(container);

  final all = container.read(allProductsListProvider).value ?? const [];
  final match = all.where((p) => p.name == productName && p.isEnabled);
  if (match.isEmpty) return null;

  final product = match.first;
  return (path: _pathTo(container, product.productGroupId), product: product);
}

/// The chain of folders to tap to reach [groupId], outermost first.
List<ProductGroup> _pathTo(ProviderContainer container, int? groupId) {
  final groups = container.read(allProductGroupsProvider).value ?? const [];
  final path = <ProductGroup>[];

  var id = groupId;
  // Bounded rather than `while (id != null)`: a malformed parent chain that
  // points at itself would otherwise loop forever instead of failing.
  for (var depth = 0; id != null && depth <= 6; depth++) {
    final match = groups.where((g) => g.id == id);
    if (match.isEmpty) break;
    path.insert(0, match.first);
    id = match.first.parentGroupId;
  }
  return path;
}

/// The folders to tap, in order, to reach the first sellable product — and it.
///
/// Depth-first in the browser's OWN order, which is the order a finger takes.
/// `BrowserSection` renders `[...visibleGroups, ...visibleProducts]`, so inside
/// any folder the sub-folders come BEFORE the products.
///
/// 🚨 It does not stop at the first folder, and that is deliberate rather than a
/// loosening of "sell the first product". A folder can be empty — these suites
/// leave their groups behind, so a company accumulates them, and one company's
/// first-ranked folder held nothing at all. A test that gave up there would go
/// red over one stale row, having proved nothing about the money path. A cashier
/// faced with "This folder is empty" backs out and taps the next one; so does
/// this, and every folder it opens is printed.
({List<ProductGroup> path, Product product})? _firstSellable(
  ProviderContainer container, {
  ProductGroup? parent,
  int depth = 0,
}) {
  if (depth > 6) return null;

  final groups = container.read(allProductGroupsProvider).value ?? const [];
  for (final child in groups.where((g) => g.parentGroupId == parent?.id)) {
    final found = _firstSellable(container, parent: child, depth: depth + 1);
    if (found != null) {
      return (path: [child, ...found.path], product: found.product);
    }
  }

  final own = _firstProduct(container, parent);
  return own == null ? null : (path: const [], product: own);
}

/// The first product the browser shows inside [group] — `null` for the products
/// that sit at the top level, in no folder at all.
///
/// Same two rules the grid applies: enabled only — the till must never offer a
/// disabled product — and sorted by the company's own `Products.Sorting`
/// setting, which is what decides which card is genuinely first. That is the
/// COMPANY's answer to "first", not the test's.
Product? _firstProduct(ProviderContainer container, ProductGroup? group) {
  final products = (container.read(allProductsListProvider).value ?? const [])
      .where((p) => p.productGroupId == group?.id && p.isEnabled)
      .toList();
  if (products.isEmpty) return null;
  final sortBy =
      container.read(appSettingsProvider)[SettingKeys.productSorting] ?? 'Name';
  sortProductsBy(products, sortBy);
  return products.first;
}

/// A browser tile, by the label printed on it.
///
/// 🚨 `Text` only — deliberately NOT `find.text`, which also matches
/// `EditableText` and would therefore match the search box once anything has
/// been typed into it. Tapping that just re-focuses the field, and nothing is
/// ever rung up.
Finder _cardLabel(String name) =>
    find.byWidgetPredicate((w) => w is Text && w.data == name);

/// Walks the folders down to the product and taps it, as a finger would.
Future<void> _tapThroughToProduct(
  WidgetTester tester,
  E2EContext ctx,
  ({List<ProductGroup> path, Product product}) target,
) async {
  for (final folder in target.path) {
    await tapVisible(tester, _cardLabel(folder.name));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(
      ctx.container.read(currentGroupProvider)?.id,
      folder.id,
      reason: 'Tapping "${folder.name}" did not open it.',
    );
    step('Group opened: ${folder.name}');
  }
  if (target.path.isEmpty) {
    step('Products sit at the top level — no folder to open');
  }

  step('Product: ${target.product.name} @ ${target.product.price}');
  await tapVisible(tester, _cardLabel(target.product.name));
}

/// Types a barcode into the till's search field and submits it.
///
/// 🚨 This is what a USB scanner physically does — it types the digits and sends
/// Enter — so submitting the text drives the app's real `_handleBarcodeSubmit`
/// path, nomenclature rules and all. Tapping the product card instead would
/// prove the cart works while proving nothing about scanning, which is the whole
/// point of a retail till.
///
/// The field CLEARS itself on a successful scan, so it is not read back: an
/// empty box is the success signal, and the cart is what gets asserted.
Future<void> _scan(WidgetTester tester, String barcode) async {
  // 🚨 `ProductSearchBar`, NOT `UnifiedSearchBar`. Two different search widgets
  // live in this app: Management's screens use `UnifiedSearchBar` (which is what
  // `searchList` drives), and the till uses `ProductSearchBar` — the one wired
  // to `onSubmitted: _handleBarcodeSubmit`. Reaching for the wrong one finds
  // nothing on a screen that is plainly showing a search box.
  final field = find.descendant(
    of: find.byType(ProductSearchBar),
    matching: find.byType(TextField),
  );

  if (field.evaluate().isEmpty) {
    // 🚨 Say WHICH of the two problems this is. They have different fixes, and
    // an error naming the wrong one sends you looking at sessions when the
    // actual cause is a switched-off button.
    final blocked = find.byType(MenuScreen).evaluate().isEmpty;
    throw TestFailure(
      blocked
          ? 'The till is not showing the product grid at all, so there is no '
              'search field to scan into. A register that is closed renders '
              'SessionBlockedScreen instead — run ensureRegisterOpen first.\n'
              '  On screen now: ${visibleTexts(tester)}'
          : 'The till is on the POS screen but has no search field. '
              '`ButtonBar.ShowSearch` is off for this company, and that is where '
              'a scan lands — `configureRetailMode` turns it back on, because a '
              'shop that sells by scanning cannot run without it.\n'
              '  On screen now: ${visibleTexts(tester)}',
    );
  }

  await tester.ensureVisible(field.first);
  await tester.tap(field.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.enterText(field.first, barcode);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await pumpFor(tester, const Duration(seconds: 2));
}

/// The payment type this sale is taken on.
///
/// 🚨 Picked deliberately rather than "whatever is first on screen", because two
/// of the flags change what the test is even testing:
///   * `markAsPaid == false` is a credit/tab type — the sale completes with
///     nothing tendered and banks as UNPAID, so the payment assertions would be
///     asserting the wrong thing;
///   * `isCustomerRequired == true` is blocked outright for the walk-in
///     customer, so the checkout would simply refuse.
PaymentType _payType(ProviderContainer container, String? named) {
  final types = (container.read(allPaymentTypesProvider).value ?? const [])
      .where((t) => t.isEnabled)
      .toList();
  if (types.isEmpty) {
    throw TestFailure(
      'This company has no enabled payment type, so no sale can be taken.',
    );
  }
  if (named != null) {
    final match = types.where((t) => t.name == named);
    if (match.isEmpty) {
      throw TestFailure(
        'No enabled payment type named "$named". This company offers: '
        '${types.map((t) => t.name).join(', ')}',
      );
    }
    return match.first;
  }
  return types.firstWhere(
    (t) => t.markAsPaid && !t.isCustomerRequired,
    orElse: () => types.first,
  );
}

/// A key on the checkout numpad.
///
/// Scoped to the dialog: bare single-digit `Text`s exist nowhere else in it —
/// the order summary prints quantities as one composite string — but the till
/// behind it is full of them.
Finder _numKey(String digit) => find.descendant(
      of: find.byType(PaymentCheckoutDialog),
      matching: find.widgetWithText(InkWell, digit),
    );

/// Answers whatever the tapped product asks on its way into the cart.
///
/// 🚨 A tap is not always one tap. Depending on the product's own flags the app
/// asks up to four questions before the line exists, and `setup_catalog`'s
/// products trip several — it stamps an age restriction on every one, and one of
/// the three is sold by weight:
///
///   * `ageRestriction` → confirm the customer is old enough;
///   * `isToWeigh`      → the weight. With no scale configured (every Android
///                        tablet, and any Windows till that has not set one up)
///                        `showWeighItemDialog` goes STRAIGHT to the keypad
///                        rather than showing a dialog that can only say "no
///                        scale", so both shapes have to be handled;
///   * `isUsingDefaultQuantity == false` → the quantity, as a typed field;
///   * `isPriceChangeAllowed`            → the price, defaulted to the shelf one.
///
/// Driven by what is ON SCREEN rather than by predicting from the flags: the
/// order the app asks in is its business, and a prediction that drifts out of
/// date fails as a mysterious timeout instead of an obvious one.
Future<void> _settleAddToCart(
  WidgetTester tester,
  E2EContext ctx,
  Product product,
) async {
  final l = ctx.l;
  final deadline = DateTime.now().add(const Duration(seconds: 45));

  while (DateTime.now().isBefore(deadline)) {
    if (ctx.container.read(cartProvider).items.isNotEmpty) return;

    // Age gate. The confirm button is labelled with the age itself.
    if (product.ageRestriction != null &&
        find.text(l.ageRestriction).evaluate().isNotEmpty) {
      await tapVisible(
        tester,
        find.text(l.confirmMinimumAge('${product.ageRestriction}')),
      );
      continue;
    }

    // The scale dialog, when a scale IS configured. Take the keypad rather than
    // waiting for a reading no test can put on the pan.
    if (find.text(l.weighItem).evaluate().isNotEmpty) {
      await tapVisible(tester, find.text(l.enterQuantity));
      continue;
    }

    // The quantity KEYPAD. It opens seeded with the unit's step (0.001 kg) and
    // the first digit replaces the seed, so one tap on "1" means one whole unit.
    //
    // 🚨 Scoped to the dialog, and it has to be. The CART KEYPAD sitting behind
    // this dialog draws its digits the same way — an `InkWell` around a
    // `Text('1')` — and it comes FIRST in tree order, being under the pushed
    // route rather than in it. An unscoped finder therefore taps a button behind
    // the modal barrier, which DISMISSES the quantity dialog instead of typing
    // into it; `showQuantityKeypad` returns null, the product is never added,
    // and the failure lands here as "the tap put nothing in the cart".
    final keypad = find.byType(Dialog);
    if (find.text(l.setChangeQuantity).evaluate().isNotEmpty) {
      await tapVisible(
        tester,
        find.descendant(of: keypad, matching: find.widgetWithText(InkWell, '1')),
      );
      await tapVisible(
        tester,
        find.descendant(
            of: keypad, matching: find.byIcon(Icons.keyboard_return)),
      );
      continue;
    }

    // The quantity FIELD — a different dialog for a product that merely asks
    // rather than one sold by weight.
    if (find.text(l.enterQuantity).evaluate().isNotEmpty) {
      await fillField(tester, l.fieldQuantity, '1');
      await tapVisible(tester, find.text(l.actionConfirm));
      continue;
    }

    // Price-changeable products open with the shelf price already filled in,
    // which is the price this sale wants.
    if (find.text(l.setSalePrice).evaluate().isNotEmpty) {
      await tapVisible(tester, find.text(l.actionConfirm));
      continue;
    }

    // Running low is a SOFT warning the cashier acknowledges, so acknowledge it.
    // (Out of stock is a different dialog and a hard block — it only fires when
    // `Order.PreventNegativeInventory` is on, and when it does the product
    // genuinely cannot be sold, so this loop correctly runs out and says so.)
    if (find.text(l.actionProceedAnyway).evaluate().isNotEmpty) {
      await tapVisible(tester, find.text(l.actionProceedAnyway));
      continue;
    }

    await pumpFor(tester, const Duration(milliseconds: 400));
  }

  throw TestFailure(
    'Tapping "${product.name}" never put a line in the cart.\n'
    '  A modifier sheet the test does not answer, or a stock guard, will look '
    'exactly like this.\n'
    '  On screen now: ${visibleTexts(tester)}',
  );
}
