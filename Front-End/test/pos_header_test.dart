// Pins the POS header's button slider and its per-till button order.
//
// The header used to be an AppBar across the whole screen with a plain
// horizontal scroll view: a mouse could not drag it (Flutter's desktop default
// — and Windows touch tills often report a finger as a mouse), it stopped on
// half a button, and nothing said more buttons existed. It is now a strip over
// the product side only, the buttons in fixed slots that snap to whole
// buttons, with no scrollbar, and in an order each till sets in Settings.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/menu/pos_header_bar.dart';
import 'package:pos_app/menu/pos_header_order.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

const _slot = kPosHeaderSlotWidth;
const _buttonWidth = 60.0;

Widget _button(int n) => SizedBox(
      key: ValueKey('b$n'),
      width: _buttonWidth,
      height: 40,
      child: Center(child: Text('B$n')),
    );

/// A header of [count] buttons in a [width]-wide strip — 450 is four and a
/// half slots, so the fifth button is cut by the edge.
Future<void> _pumpBar(
  WidgetTester tester,
  int count, {
  double width = 450,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 62,
            child: PosHeaderBar(
              children: [for (var i = 1; i <= count; i++) _button(i)],
            ),
          ),
        ),
      ),
    ),
  );
  // The post-frame read of which edges hide buttons.
  await tester.pump();
}

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position;

/// Where button [n]'s slot begins — the button is centred in it.
double _slotStart(WidgetTester tester, int n) =>
    tester.getTopLeft(find.byKey(ValueKey('b$n'))).dx -
    (_slot - _buttonWidth) / 2;

void main() {
  group('the slider', () {
    testWidgets('a single button sits at the far left', (tester) async {
      await _pumpBar(tester, 1);

      expect(_slotStart(tester, 1), 0);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('swiping two buttons over: 1 2 3 4 → 3 4 5 6', (tester) async {
      await _pumpBar(tester, 12);

      await tester.timedDrag(
        find.byType(PosHeaderBar),
        const Offset(-2 * _slot, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();

      expect(_position(tester).pixels, 2 * _slot);
      // Button 3 now starts the row, whole; 1 and 2 hid off the left edge.
      expect(_slotStart(tester, 3), 0);
    });

    testWidgets('a drag that stops between buttons settles on a whole one',
        (tester) async {
      await _pumpBar(tester, 12);

      await tester.timedDrag(
        find.byType(PosHeaderBar),
        const Offset(-1.3 * _slot, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();

      expect(_position(tester).pixels, 1 * _slot);
    });

    testWidgets('a flick travels further, and still lands on a whole button',
        (tester) async {
      await _pumpBar(tester, 12);

      await tester.fling(
        find.byType(PosHeaderBar),
        const Offset(-120, 0),
        2000,
      );
      await tester.pumpAndSettle();

      final pixels = _position(tester).pixels;
      expect(pixels % _slot, 0);
      expect(pixels, greaterThan(_slot));
    });

    testWidgets('even at the far end the row starts on a whole button',
        (tester) async {
      await _pumpBar(tester, 12);

      await tester.fling(
        find.byType(PosHeaderBar),
        const Offset(-400, 0),
        5000,
      );
      await tester.pumpAndSettle();

      final position = _position(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(position.pixels % _slot, 0);
      // And the last button is fully in view.
      final last = tester.getTopRight(find.byKey(const ValueKey('b12'))).dx;
      expect(last, lessThanOrEqualTo(450));
    });

    testWidgets('the chevrons show where buttons hide, and page a screenful',
        (tester) async {
      await _pumpBar(tester, 12);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Four whole slots fit in 450px.
      expect(_position(tester).pixels, 4 * _slot);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });

    testWidgets('a vertical mouse wheel steps it one button', (tester) async {
      await _pumpBar(tester, 12);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final centre = tester.getCenter(find.byType(PosHeaderBar));
      await tester.sendEventToBinding(pointer.hover(centre));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 50)));
      await tester.pumpAndSettle();

      expect(_position(tester).pixels, _slot);
    });

    testWidgets(
      'on a Windows till: no scrollbar, and a mouse drags it',
      (tester) async {
        await _pumpBar(tester, 12);

        // The desktop default draws a scrollbar on every scroll view.
        expect(find.byType(Scrollbar), findsNothing);
        expect(find.byType(RawScrollbar), findsNothing);

        // …and refuses to drag with a mouse — which is how many Windows touch
        // screens report a finger.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PosHeaderBar)),
          kind: PointerDeviceKind.mouse,
        );
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(-10, 0));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_position(tester).pixels, 2 * _slot);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  });

  group('the button order', () {
    test('a saved order leads; a button it never mentions keeps its place', () {
      final buttons = [_button(1), _button(2), _button(3)];

      final ordered = applyPosHeaderOrder(buttons, const ['b3', 'b1']);

      // b2 was declared second and the saved order predates it — it stays
      // second instead of being exiled to the end.
      expect([for (final b in ordered) (b.key as ValueKey<String>).value],
          ['b3', 'b2', 'b1']);
    });

    test('no saved order leaves the declared order alone', () {
      final buttons = [_button(1), _button(2)];
      expect(applyPosHeaderOrder(buttons, const []), buttons);
    });

    test('the order is saved on this till and read back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer container() => ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );

      final first = container();
      addTearDown(first.dispose);
      first
          .read(posHeaderOrderProvider.notifier)
          .setOrder(const [kPosBtnTax, kPosBtnCustomer]);
      expect(prefs.getStringList(kPosHeaderOrderPrefKey),
          [kPosBtnTax, kPosBtnCustomer]);

      // A fresh start of the app on the same till.
      final second = container();
      addTearDown(second.dispose);
      expect(second.read(posHeaderOrderProvider),
          [kPosBtnTax, kPosBtnCustomer]);

      second.read(posHeaderOrderProvider.notifier).reset();
      expect(prefs.getStringList(kPosHeaderOrderPrefKey), isNull);
      expect(second.read(posHeaderOrderProvider), isEmpty);
    });

    test('the catalogue names every header button once', () {
      final l = lookupAppLocalizations(const Locale('en'));
      final catalogue = posHeaderButtonCatalog(l);

      final ids = [for (final s in catalogue) s.id];
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id');
      expect(ids, hasLength(16));
      // The three that appear by themselves have no switch.
      expect(
        [for (final s in catalogue) if (s.settingKey == null) s.id],
        [kPosBtnOrderType, kPosBtnServiceStatus, kPosBtnPromos],
      );
    });
  });

  group('Settings → POS Buttons', () {
    late ProviderContainer container;

    Future<AppLocalizations> pumpList(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appSettingsProvider.overrideWith(_FakeSettings.new),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: [Locale('en')],
            home: Scaffold(
              body: SingleChildScrollView(
                child: Card(child: PosHeaderButtonOrderList()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return AppLocalizations.of(tester.element(find.byType(Card)));
    }

    testWidgets('one draggable row per header button', (tester) async {
      final l = await pumpList(tester);

      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(16));
      // A switch for each, except the three that appear by themselves.
      expect(find.byType(Switch), findsNWidgets(13));
      expect(find.text(l.posButtonAutomatic), findsNWidgets(3));
      // Nothing to reset while the till shows the default order.
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text(l.resetButtonOrder),
                matching: find.byWidgetPredicate((w) => w is TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('dragging a row to the top saves the new order',
        (tester) async {
      final l = await pumpList(tester);

      // Discount is fourth by default.
      final handle = find.byIcon(Icons.drag_indicator).at(3);
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final order = container.read(posHeaderOrderProvider);
      expect(order.first, kPosBtnDiscount);
      // The full catalogue is stored, hidden buttons included.
      expect(order, hasLength(16));
      expect(find.text(l.resetButtonOrder), findsOneWidget);
    });
  });
}
