// The cart's action row must survive an unbounded width.
//
// 🚨 The bug this pins. `_CartToolButton` is a Row with a Flexible child, so it
// lays out only inside a BOUNDED width — fine wrapped in `Expanded`, fatal
// dropped bare into a Row, because a Row hands its non-flex children an
// unbounded width. The keypad toggle was added that way and took the whole cart
// panel down with it: "RenderFlex children have non-zero flex but incoming
// width constraints are unbounded", then a few hundred lines of
// "RenderBox was not laid out".
//
// And it was invisible until someone ran a DEBUG build. That message is an
// assertion, compiled out of release — the release macOS build drew a blank
// cart and reported nothing at all. Hence a test rather than a careful look.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/menu/menu_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget body) => tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Scaffold(body: body),
        ),
      );

  final toggle = CartIconToggle(
    icon: Icons.dialpad,
    tooltip: 'Keypad',
    active: false,
    onTap: () {},
  );

  testWidgets('lays out where a Row puts a non-flex child — unbounded width',
      (tester) async {
    // Exactly the position it occupies in the cart, and exactly what broke.
    await pump(tester, Row(children: [toggle]));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CartIconToggle)), const Size(44, 44));
  });

  testWidgets('keeps its size beside a flexible neighbour in a narrow cart',
      (tester) async {
    // kCartWidthMin is 250 — the narrowest the cart panel can be dragged.
    await pump(
      tester,
      SizedBox(
        width: 250,
        child: Row(
          children: [
            const Expanded(child: SizedBox(height: 44)),
            const SizedBox(width: 8),
            toggle,
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Fixed, not squeezed: the customer button beside it absorbs the surplus.
    expect(tester.getSize(find.byType(CartIconToggle)), const Size(44, 44));
  });

  testWidgets('renders the icon it is given, in both states', (tester) async {
    await pump(tester, Row(children: [toggle]));
    expect(find.byIcon(Icons.dialpad), findsOneWidget);

    await pump(
      tester,
      Row(
        children: [
          CartIconToggle(
            icon: Icons.keyboard_hide_outlined,
            tooltip: 'Hide keypad',
            active: true,
            onTap: () {},
          ),
        ],
      ),
    );
    expect(find.byIcon(Icons.keyboard_hide_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
