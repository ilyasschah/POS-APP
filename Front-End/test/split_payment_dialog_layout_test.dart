// Pins the layout and the hand-over of the split bill dialog.
//
//   • no overflow on any screen the POS ships on — the cards wrap by the width
//     they get, the pool stacks above them on a narrow screen;
//   • tapping an item then a card moves it there, and a line of several asks
//     how many.
//
// Paying is not driven here: it needs the session gate and the database, and
// the money itself is pinned in split_bill_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/cart/payment_type_model.dart';
import 'package:pos_app/cart/payment_type_provider.dart';
import 'package:pos_app/cart/split_bill.dart';
import 'package:pos_app/cart/split_payment_dialog.dart';
import 'package:pos_app/l10n/app_localizations.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

CartItem _line(String id, String name, double qty, double price) => CartItem(
      cartItemId: id,
      posOrderId: 0,
      productId: id.hashCode,
      quantity: qty,
      price: price,
      productName: name,
      appliedTaxes: const [],
      isTaxInclusive: false,
    );

SplitBill _bill() {
  final items = [
    _line('tagine', 'Chicken tagine with preserved lemon and green olives', 1, 95),
    _line('tea', 'Mint tea', 3, 12),
    _line('juice', 'Orange juice', 2, 18),
  ];
  return SplitBill(
    items: items,
    grandTotal: items.fold(0, (s, i) => s + i.price * i.quantity * 1.1),
    money: splitUnitMoney(
      items: items,
      netUnitPrice: (i) => i.price,
      lineNet: (i) => i.price * i.quantity,
      lineTax: (i) => i.price * i.quantity * 0.1,
      orderLevelDiscount: 0,
    ),
  );
}

final _types = [
  PaymentType(id: 1, name: 'Cash', markAsPaid: true),
  PaymentType(id: 2, name: 'Card', markAsPaid: true),
  PaymentType(id: 3, name: 'Account', markAsPaid: false, isCustomerRequired: true),
];

const _screens = <String, Size>{
  'Windows till 1366x768': Size(1366, 768),
  '10-inch landscape 1280x800': Size(1280, 800),
  'compact window 1024x768': Size(1024, 768),
  'portrait tablet 800x1280': Size(800, 1280),
  '7-inch portrait 600x960': Size(600, 960),
};

Future<void> _open(WidgetTester tester, Size screen, SplitBill bill) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(_FakeSettings.new),
        allPaymentTypesProvider.overrideWith((ref) => Stream.value(_types)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => SplitPaymentDialog(
                  bill: bill,
                  loyaltyBaseTotal: bill.grandTotal,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final entry in _screens.entries) {
    testWidgets('lays out without overflow on ${entry.key}', (tester) async {
      await _open(tester, entry.value, _bill());

      expect(find.text('Split bill'), findsOneWidget);
      expect(find.text('Split 1'), findsOneWidget);
      expect(find.text('Split 2'), findsOneWidget);
      expect(find.text('Add split'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an item tapped then a card moves onto that card', (tester) async {
    final bill = _bill();
    await _open(tester, const Size(1366, 768), bill);

    await tester.tap(find.text('Orange juice'));
    await tester.pump();
    // Two of them: the card asks how many. Take both.
    await tester.tap(find.text('Tap or drag items here').first);
    await tester.pumpAndSettle();
    expect(find.text('How many “Orange juice”?'), findsOneWidget);
    await tester.tap(find.text('All (2)'));
    await tester.pumpAndSettle();

    expect(bill.splits.first.allocations['juice'], 2);
    expect(bill.unassigned('juice'), 0);
    expect(find.textContaining('Pay '), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a line of several can go to two guests', (tester) async {
    final bill = _bill();
    await _open(tester, const Size(1366, 768), bill);

    await tester.tap(find.text('Mint tea'));
    await tester.pump();
    await tester.tap(find.text('Tap or drag items here').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign')); // one of the three
    await tester.pumpAndSettle();

    expect(bill.splits.first.allocations['tea'], 1);
    expect(bill.unassigned('tea'), 2,
        reason: 'the rest stays in the pool for the next guest');
  });

  testWidgets('cancelling with nothing paid closes straight away',
      (tester) async {
    await _open(tester, const Size(1366, 768), _bill());

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Split bill'), findsNothing);
  });
}
