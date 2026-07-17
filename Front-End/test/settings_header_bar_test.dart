// Pins the settings header bar's LAYOUT.
//
// Why this file exists: the first attempt at moving this search field out of the
// sidebar shipped a bug that `dart analyze`, `flutter build` and the whole test
// suite all passed — the field was wrapped in an `Align` with a null
// heightFactor, which EXPANDS to fill its slot, so it swallowed the entire
// screen and the settings body rendered blank. Layout correctness is invisible
// to every other check in this repo, so it gets asserted here in pixels.
//
// The header's own failure mode is different from that one: an AppBar toolbar is
// only kToolbarHeight tall and its title has finite width, so the risks are
// (a) the field overflowing the toolbar vertically and (b) a RenderFlex overflow
// on a narrow tablet. Both are covered below.
//
// The title is now a Stack (centring the field independently of the "Settings"
// label) rather than a Row, which swaps one risk for another: a Stack CANNOT
// RenderFlex-overflow, so the overflow test below can no longer catch a field
// that has grown into the title — it would silently paint on top of it instead.
// That overlap is asserted explicitly for exactly that reason.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/settings/settings_screen.dart';

Future<void> _pump(WidgetTester tester, Size screen) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          appBar: SettingsHeaderBar(),
          body: Center(child: Text('tab content')),
        ),
      ),
    ),
  );
}

// A 13" desktop-ish window and the 10" landscape tablet from CLAUDE.md.
const _desktop = Size(1920, 1080);
const _tablet = Size(1280, 800);

void main() {
  testWidgets('the header stays a header — the body keeps its height', (
    tester,
  ) async {
    await _pump(tester, _tablet);

    final header = tester.getSize(find.byType(SettingsHeaderBar));
    expect(header.width, _tablet.width, reason: 'header spans the full width');
    // The footer version of this bug rendered at the full 800 and blanked the
    // screen. A header is a toolbar; it must never grow like that.
    expect(header.height, lessThan(120));
    expect(find.text('tab content'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the field is capped and centred on a wide monitor', (
    tester,
  ) async {
    await _pump(tester, _desktop);

    final field = tester.getSize(find.byType(TextField));
    // Without the cap the field would span the whole 1920px monitor.
    expect(field.width, lessThanOrEqualTo(480));
    // Centred on the header, not left-aligned beside the title: the Stack
    // deliberately centres it regardless of how wide the title happens to be.
    expect(
      tester.getCenter(find.byType(TextField)).dx,
      closeTo(tester.getCenter(find.byType(SettingsHeaderBar)).dx, 1),
    );
    // Touch target: 44px minimum (CLAUDE.md) — the reason its padding is 12.
    expect(field.height, greaterThanOrEqualTo(44));
  });

  testWidgets('the centred field never collides with the title', (
    tester,
  ) async {
    // A Stack silently paints its children on top of one another, so this can
    // only be caught by measuring: at 480 wide the field starts to eat the
    // "Settings" label somewhere below ~860px of window width.
    for (final screen in [_desktop, _tablet]) {
      await _pump(tester, screen);
      final titleRight = tester.getTopRight(find.text('Settings')).dx;
      final fieldLeft = tester.getTopLeft(find.byType(TextField)).dx;
      expect(
        fieldLeft,
        greaterThanOrEqualTo(titleRight),
        reason: 'search field overlaps the "Settings" title at $screen',
      );
    }
  });

  testWidgets('the field fits inside the toolbar and never overflows', (
    tester,
  ) async {
    for (final screen in [_desktop, _tablet]) {
      await _pump(tester, screen);
      // A RenderFlex overflow throws during paint; takeException surfaces it.
      expect(
        tester.takeException(),
        isNull,
        reason: 'header overflowed at $screen',
      );
      // The field must fit the toolbar, or it paints outside the AppBar.
      final field = tester.getSize(find.byType(TextField));
      expect(field.height, lessThanOrEqualTo(kToolbarHeight));
    }
  });
}
