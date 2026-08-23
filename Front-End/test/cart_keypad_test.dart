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
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';

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
  });
}
