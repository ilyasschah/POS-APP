// Pins the house dropdown — `IlyassDropdown`, the one every screen now uses.
//
// What it replaced, and what this guards against coming back:
//   • the legacy `DropdownButton` laid its menu OVER the field, with the
//     current choice on top, hiding the very field being changed — the menu
//     must open BELOW the field and leave it in plain sight;
//   • square, un-themed menus — the menu is the rounded house surface in every
//     theme mode, and the current choice is marked in the accent;
//   • a parent that changes the value in code (a unit that forces a weight, a
//     list that loads late) must be reflected, not ignored by a form field that
//     seeded itself once;
//   • category headers must never be selectable, and a null-valued "None"
//     placeholder must show like any other option.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/app_theme.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';

const _languages = <IlyassDropdownItem<String?>>[
  IlyassDropdownItem(value: 'en', label: 'English'),
  IlyassDropdownItem(value: 'fr', label: 'Français'),
  IlyassDropdownItem(value: 'ar', label: 'العربية'),
];

/// A screen holding one dropdown and what was picked in it, plus a button
/// that changes the value from code.
class _Host extends StatefulWidget {
  const _Host({this.initial = 'en', this.items = _languages, this.hint});

  final String? initial;
  final List<IlyassDropdownItem<String?>> items;
  final String? hint;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? _value = widget.initial;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IlyassDropdown<String?>(
                      label: 'Language',
                      hint: widget.hint,
                      value: _value,
                      items: widget.items,
                      onChanged: (v) => setState(() => _value = v),
                    ),
                    const SizedBox(height: 240),
                    Text('value: $_value'),
                    TextButton(
                      onPressed: () => setState(() => _value = 'ar'),
                      child: const Text('set from code'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

final Finder _field = find.byWidgetPredicate((w) => w is IlyassDropdown);

/// The menu entries a finger can reach — the open menu's, never the hidden
/// measuring copy.
Finder _entries() => find
    .descendant(of: _field, matching: find.byType(MenuItemButton))
    .hitTestable();

Finder _entry(String label) =>
    find.descendant(of: _entries(), matching: find.text(label));

/// What the closed field shows.
String _shown(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(of: _field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_field);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens its menu BELOW the field, leaving the field in sight',
      (tester) async {
    await tester.pumpWidget(const _Host());
    final fieldRect = tester.getRect(_field);

    await _open(tester);

    final entries = _entries();
    expect(entries, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      expect(
        tester.getRect(entries.at(i)).top,
        greaterThan(fieldRect.bottom),
        reason: 'The menu must drop below the field, not be laid over it.',
      );
    }
    // Nothing covers the field: a tap on it still reaches it.
    expect(
      find
          .descendant(of: _field, matching: find.byType(EditableText))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('picking an entry reports it, shows it, and closes the menu',
      (tester) async {
    await tester.pumpWidget(const _Host());
    expect(_shown(tester), 'English');

    await _open(tester);
    await tester.tap(_entry('Français'));
    await tester.pumpAndSettle();

    expect(find.text('value: fr'), findsOneWidget);
    expect(_shown(tester), 'Français');
    expect(_entries(), findsNothing);
  });

  testWidgets('shows a value changed from code', (tester) async {
    await tester.pumpWidget(const _Host());

    await tester.tap(find.text('set from code'));
    await tester.pumpAndSettle();

    expect(_shown(tester), 'العربية');
  });

  testWidgets('marks the current choice with a check in the accent colour',
      (tester) async {
    await tester.pumpWidget(const _Host(initial: 'fr'));
    await _open(tester);

    final check = find.descendant(
      of: _entries(),
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(check, findsOneWidget);
    final marked = find.ancestor(of: check, matching: find.byType(MenuItemButton));
    expect(
      find.descendant(of: marked, matching: find.text('Français')),
      findsOneWidget,
    );
    expect(
      tester.widget<Icon>(check).color,
      Theme.of(tester.element(_field)).colorScheme.primary,
    );
  });

  testWidgets('a category header is shown but can never be picked',
      (tester) async {
    await tester.pumpWidget(const _Host(
      initial: 'kg',
      items: [
        IlyassDropdownItem(value: '#weight', label: 'Weight', header: true),
        IlyassDropdownItem(value: 'kg', label: 'kg'),
        IlyassDropdownItem(value: 'g', label: 'g'),
      ],
    ));
    await _open(tester);

    // Set apart as a section title.
    final header = find.descendant(of: _entries(), matching: find.text('WEIGHT'));
    expect(header, findsOneWidget);
    final button = tester.widget<MenuItemButton>(
      find.ancestor(of: header, matching: find.byType(MenuItemButton)),
    );
    expect(button.onPressed, isNull);

    await tester.tap(header, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('value: kg'), findsOneWidget);
  });

  testWidgets('a null-valued placeholder shows like any other option',
      (tester) async {
    await tester.pumpWidget(const _Host(
      initial: null,
      items: [
        IlyassDropdownItem(value: null, label: 'No Tax'),
        IlyassDropdownItem(value: 'vat', label: 'VAT (20.0%)'),
      ],
    ));

    expect(_shown(tester), 'No Tax');
  });

  testWidgets('shows the hint when no option matches the value',
      (tester) async {
    await tester.pumpWidget(const _Host(initial: null, hint: 'Choose…'));

    expect(_shown(tester), isEmpty);
    expect(find.text('Choose…'), findsOneWidget);
  });

  testWidgets('shows its prefix icon in the field', (tester) async {
    // DropdownMenu drops `leadingIcon` when a decorationBuilder is supplied —
    // the customer, warehouse and staff pickers all lost their icon that way.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IlyassDropdown<String?>(
          label: 'Language',
          prefixIcon: Icons.translate,
          value: 'en',
          items: _languages,
          onChanged: (_) {},
        ),
      ),
    ));

    expect(
      find.descendant(of: _field, matching: find.byIcon(Icons.translate)),
      findsOneWidget,
    );
  });

  testWidgets('sits in an AlertDialog, full-width or sized to its options',
      (tester) async {
    // AlertDialog sizes its content with IntrinsicWidth, which throws on any
    // widget that cannot report an intrinsic width.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IlyassDropdown<String?>(
                  label: 'Language',
                  value: 'en',
                  items: _languages,
                  onChanged: (_) {},
                ),
                IlyassDropdown<String?>(
                  expand: false,
                  dense: true,
                  value: 'en',
                  items: _languages,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_field, findsNWidgets(2));
  });

  test('every theme mode gives menus the rounded house surface', () {
    for (final mode in const [
      'light',
      'dark',
      'dimmed',
      'night',
      'gray',
      'high_contrast',
    ]) {
      final theme = buildAppTheme(mode, const Color(0xFF3F51B5));
      for (final style in [
        theme.dropdownMenuTheme.menuStyle,
        theme.menuTheme.style,
      ]) {
        final shape = style?.shape?.resolve(const {});
        expect(shape, isA<RoundedRectangleBorder>(), reason: mode);
        expect(
          (shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(12),
          reason: mode,
        );
        expect(
          style!.backgroundColor?.resolve(const {}),
          theme.colorScheme.surfaceContainerHigh,
          reason: mode,
        );
      }
      final popupShape = theme.popupMenuTheme.shape;
      expect(popupShape, isA<RoundedRectangleBorder>(), reason: mode);
    }
  });
}
