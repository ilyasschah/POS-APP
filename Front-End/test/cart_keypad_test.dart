// The cart keypad's rules.
//
// Every key here writes to a line the customer is about to pay for, so the
// edges matter more than the happy path: a stray 0 must not delete a line
// mid-keystroke, a product nobody may reprice must not be repriced, and the
// backspace has to be a backspace before it is a delete.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/cart_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/menu/cart_keypad.dart';
import 'package:pos_app/menu/menu_screen.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

/// The cart notifier, wired the way every other cart test wires it.
CartNotifier _cart() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appSettingsProvider.overrideWith(_FakeSettings.new),
      allTaxesProvider.overrideWith((ref) => Stream.value(const <Tax>[])),
      selectableCustomersProvider.overrideWith(
        (ref) => const AsyncValue.data(<Customer>[]),
      ),
      allCustomersProvider.overrideWith(
        (ref) => Stream.value(const <Customer>[]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(cartProvider.notifier);
}

void main() {
  CartItem item({
    String id = 'line-1',
    double quantity = 1,
    double price = 240,
  }) =>
      CartItem(
        cartItemId: id,
        posOrderId: 0,
        productId: 7,
        quantity: quantity,
        price: price,
        productName: 'Cashew ketchup',
        appliedTaxes: const [],
      );

  group('updateItemPrice', () {
    late CartNotifier cart;

    setUp(() {
      cart = _cart();
      cart.state = cart.state.copyWith(items: [item()]);
    });

    test('sets the unit price of the line', () {
      cart.updateItemPrice('line-1', 199.5);
      expect(cart.state.items.single.price, 199.5);
    });

    test('a free line is allowed — zero is a real price', () {
      cart.updateItemPrice('line-1', 0);
      expect(cart.state.items.single.price, 0);
    });

    test('a negative price is refused, not clamped', () {
      cart.updateItemPrice('line-1', -5);
      expect(cart.state.items.single.price, 240,
          reason: 'the line keeps the price it had');
    });

    test('an unknown line changes nothing', () {
      cart.updateItemPrice('does-not-exist', 10);
      expect(cart.state.items.single.price, 240);
    });

    test('the line keeps its identity and quantity', () {
      cart.updateItemPrice('line-1', 12);
      final line = cart.state.items.single;
      expect(line.cartItemId, 'line-1');
      expect(line.quantity, 1);
    });
  });

  group('updateItemQuantity — the rule the keypad works around', () {
    late CartNotifier cart;

    setUp(() {
      cart = _cart();
      cart.state = cart.state.copyWith(items: [item()]);
    });

    test('zero REMOVES the line', () {
      // Which is why the keypad refuses to apply a 0: it is a state the
      // cashier types through on the way to "0.5", and applying it would
      // delete the line under their fingers.
      cart.updateItemQuantity('line-1', 0);
      expect(cart.state.items, isEmpty);
    });

    test('a positive quantity is set as typed', () {
      cart.updateItemQuantity('line-1', 2.5);
      expect(cart.state.items.single.quantity, 2.5);
    });
  });

  group('CartKeypad widget', () {
    Future<void> pumpKeypad(
      WidgetTester tester, {
      required bool hasSelection,
      required bool priceChangeAllowed,
      bool priceEntersAmount = false,
      CartKeypadMode mode = CartKeypadMode.quantity,
      List<String>? digits,
      VoidCallback? onBackspace,
      ValueChanged<CartKeypadMode>? onModeChanged,
    }) =>
        tester.pumpWidget(MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: CartKeypad(
              mode: mode,
              onModeChanged: onModeChanged ?? (_) {},
              onDigit: (d) => digits?.add(d),
              onSignToggle: () {},
              onBackspace: onBackspace ?? () {},
              hasSelection: hasSelection,
              priceChangeAllowed: priceChangeAllowed,
              priceEntersAmount: priceEntersAmount,
            ),
          ),
        ));

    testWidgets('digits report what was pressed', (tester) async {
      final pressed = <String>[];
      await pumpKeypad(tester,
          hasSelection: true, priceChangeAllowed: true, digits: pressed);

      await tester.tap(find.text('7'));
      await tester.tap(find.text('5'));
      await tester.pump();

      expect(pressed, ['7', '5']);
    });

    testWidgets('with nothing selected every key is dead', (tester) async {
      final pressed = <String>[];
      var backspaces = 0;
      await pumpKeypad(
        tester,
        hasSelection: false,
        priceChangeAllowed: true,
        digits: pressed,
        onBackspace: () => backspaces++,
      );

      await tester.tap(find.text('7'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(pressed, isEmpty);
      expect(backspaces, 0,
          reason: 'a keypad with no line to act on must do nothing');
    });

    testWidgets('Prix is dead for a product that may not be repriced',
        (tester) async {
      final modes = <CartKeypadMode>[];
      await pumpKeypad(
        tester,
        hasSelection: true,
        priceChangeAllowed: false,
        onModeChanged: modes.add,
      );

      await tester.tap(find.text('Price'));
      await tester.pump();

      expect(modes, isEmpty,
          reason: 'the key is visible so the rule is legible, but inert');
    });

    testWidgets('Prix switches mode when the product allows it',
        (tester) async {
      final modes = <CartKeypadMode>[];
      await pumpKeypad(
        tester,
        hasSelection: true,
        priceChangeAllowed: true,
        onModeChanged: modes.add,
      );

      await tester.tap(find.text('Price'));
      await tester.pump();

      expect(modes, [CartKeypadMode.price]);
    });

    testWidgets('the backspace key reports a press', (tester) async {
      var backspaces = 0;
      await pumpKeypad(
        tester,
        hasSelection: true,
        priceChangeAllowed: true,
        onBackspace: () => backspaces++,
      );

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(backspaces, 1);
    });

    testWidgets('there is no X or +/- stepper hiding in the pad',
        (tester) async {
      await pumpKeypad(tester, hasSelection: true, priceChangeAllowed: true);

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
    });

    testWidgets('a weighed line relabels the price key to Amount',
        (tester) async {
      // The key does something else on a weighed line — it takes money and the
      // parent back-solves the weight — so it must not still say "Price". A key
      // that silently changes meaning is a wrong sale waiting to happen.
      await pumpKeypad(
        tester,
        hasSelection: true,
        priceChangeAllowed: true,
        priceEntersAmount: true,
      );

      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Price'), findsNothing);
    });

    testWidgets('a weighed line keeps the key live even when repricing is off',
        (tester) async {
      // "Allow price change" governs REPRICING. Entering an amount is not a
      // reprice — the shelf price is the divisor and survives untouched — so
      // the permission does not gate it.
      final modes = <CartKeypadMode>[];
      await pumpKeypad(
        tester,
        hasSelection: true,
        priceChangeAllowed: false,
        priceEntersAmount: true,
        onModeChanged: modes.add,
      );

      await tester.tap(find.text('Amount'));
      await tester.pump();

      expect(modes, [CartKeypadMode.price]);
    });

    testWidgets('with nothing selected the Amount key is dead too',
        (tester) async {
      final modes = <CartKeypadMode>[];
      await pumpKeypad(
        tester,
        hasSelection: false,
        priceChangeAllowed: false,
        priceEntersAmount: true,
        onModeChanged: modes.add,
      );

      await tester.tap(find.text('Amount'));
      await tester.pump();

      expect(modes, isEmpty);
    });
  });

  group('the amount key back-solves a weight', () {
    // The counter conversation this exists for: a customer asks for 50 dirhams
    // of saffron, not for 1.67 grams of it. The digits are a line TOTAL and the
    // keypad writes the QUANTITY, leaving the shelf price alone as the divisor.
    late CartNotifier cart;

    CartItem saffron({double quantity = 1}) => CartItem(
          cartItemId: 'weighed-1',
          posOrderId: 0,
          productId: 9,
          quantity: quantity,
          price: 30, // 30 MAD per gram
          productName: 'Saffron',
          appliedTaxes: const [],
          uomId: kUomGram,
          isToWeigh: true,
        );

    setUp(() {
      cart = _cart();
      cart.state = cart.state.copyWith(items: [saffron()]);
    });

    /// What `_applyKeypadEntry` does in price mode on a weighed line.
    void enterAmount(double amount) {
      final line = cart.state.items.single;
      final weight = quantityForAmount(amount, line.price, line.uomId);
      if (weight != null && weight > 0) {
        cart.updateItemQuantity(line.cartItemId, weight);
      }
    }

    test('50 MAD of a 30 MAD/g product is 1.6667 g', () {
      enterAmount(50);
      expect(cart.state.items.single.quantity, closeTo(1.6667, 1e-9));
    });

    test('the unit price is NOT touched', () {
      // The whole difference from a reprice. Writing 50 into `price` would set
      // 50 MAD per GRAM and ring up 5 000 for a 100 g bag.
      enterAmount(50);
      expect(cart.state.items.single.price, 30);
    });

    test('the line then costs what the customer asked for', () {
      enterAmount(50);
      final line = cart.state.items.single;
      expect(line.quantity * line.price, closeTo(50, 0.01));
    });

    test('typing digit by digit re-solves from the shelf price each time', () {
      // "5" then "0" is two applications, not a compounding one — which is only
      // true because the divisor never moves.
      enterAmount(5);
      expect(cart.state.items.single.quantity, closeTo(0.1667, 1e-9));
      enterAmount(50);
      expect(cart.state.items.single.quantity, closeTo(1.6667, 1e-9));
      expect(cart.state.items.single.price, 30);
    });

    test('an amount too small to buy anything leaves the line alone', () {
      // 0.0001 g rounds to nothing at storage precision; applying it would
      // delete the line, and the cashier only mistyped a digit.
      final before = cart.state.items.single.quantity;
      enterAmount(0.001);
      expect(cart.state.items.single.quantity, before);
    });
  });

  group('cart row fit', () {
    // TAX + a discount badge + the promo star.
    const badges = 52.0 + 56.0 + 20.0;

    test('a wide cart shows everything', () {
      final fit = cartRowFit(
        width: 520,
        hasDiscount: true,
        badgeWidth: badges,
      );
      expect(fit.showOriginal, isTrue);
      expect(fit.showBadges, isTrue);
    });

    test('a narrow cart keeps the name and the amount, drops the rest', () {
      // 380px is the cart column on the till this was reported from.
      final fit = cartRowFit(
        width: 380,
        hasDiscount: true,
        badgeWidth: badges,
      );
      expect(fit.showOriginal, isTrue,
          reason: 'the old price is worth more than the badges');
      expect(fit.showBadges, isFalse,
          reason: 'badges must never squeeze the product name');
    });

    test('the struck-through price goes before the name is starved', () {
      final fit = cartRowFit(
        width: 300,
        hasDiscount: true,
        badgeWidth: badges,
      );
      expect(fit.showOriginal, isFalse);
      expect(fit.showBadges, isFalse);
    });

    test('badges survive on a narrow row when there is no discount', () {
      // Nothing struck through, so the space goes to the badges instead.
      final fit = cartRowFit(
        width: 380,
        hasDiscount: false,
        badgeWidth: 52,
      );
      expect(fit.showBadges, isTrue);
    });

    test('a line with nothing to show asks for nothing', () {
      final fit = cartRowFit(width: 520, hasDiscount: false, badgeWidth: 0);
      expect(fit.showOriginal, isFalse);
      expect(fit.showBadges, isFalse);
    });

    test('an absurdly narrow cart still returns, showing only the essentials',
        () {
      final fit = cartRowFit(width: 120, hasDiscount: true, badgeWidth: badges);
      expect(fit.showOriginal, isFalse);
      expect(fit.showBadges, isFalse);
    });
  });
}
