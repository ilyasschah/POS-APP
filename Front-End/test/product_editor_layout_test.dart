// Pins the layout of the product editor dialog — every tab.
//
// Each tab was redesigned from loose fields on an empty page into titled
// section cards (General: PRODUCT INFORMATION / DESCRIPTION / PRODUCT
// BEHAVIOR; Pricing: PRICE & COST / TAXES / UNIT & STOCK; one card each on
// Barcodes, Modifiers and the Phase-2 Taxes tab; two side by side on
// Appearance). What this guards:
//
//   • no overflow on any tab, on any screen the POS ships on — a Windows till,
//     a 10" landscape tablet, a compact window, and portrait tablets;
//   • fields pair up when there is room and stack when there is not, from the
//     width the tab actually got (Ilyass Style §2);
//   • the footer stays OUTSIDE the scrolling body, so Save never scrolls away;
//   • the handles the E2E helpers rely on — exact switch titles and field
//     labels, the description key, the Add button sharing the barcode field's
//     Row, every InkWell inside a Wrap on Appearance being a colour swatch, and
//     no Icons.tune (Quick Settings' handle) anywhere in the dialog.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/barcode/barcode_model.dart';
import 'package:pos_app/barcode/barcode_provider.dart';
import 'package:pos_app/barcode/nomenclature/barcode_rules_provider.dart';
import 'package:pos_app/core/ilyass_dropdown.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/modifier/modifier_models.dart';
import 'package:pos_app/modifier/modifier_provider.dart';
import 'package:pos_app/product/product_group_model.dart';
import 'package:pos_app/product/product_group_provider.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/products_screen.dart';
import 'package:pos_app/stock/stock_control_provider.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_moves_provider.dart';
import 'package:pos_app/stock/stock_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/tax/tax_model.dart';
import 'package:pos_app/tax/tax_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';

class _FakeSettings extends AppSettingsNotifier {
  _FakeSettings([this.extra = const {}]);

  final Map<String, String> extra;

  @override
  Map<String, String> build() => {...kSettingDefaults, ...extra};
}

final _drinks = ProductGroup(
  id: 3,
  companyId: 1,
  name: 'Drinks',
  color: '#2196F3',
  rank: 1,
);

Product _coca() => Product(
      id: 12,
      companyId: 1,
      productGroupId: 3,
      name: 'Coca-Cola',
      code: '0001',
      plu: 1,
      price: 12,
      isTaxInclusivePrice: true,
      isPriceChangeAllowed: false,
      isService: false,
      isUsingDefaultQuantity: true,
      isEnabled: true,
      cost: 6,
      color: '#F44336',
      description: 'Chilled 33cl can',
      rank: 0,
    );

final _vat = Tax(id: 4, name: 'VAT', rate: 20.0);

final _barcodes = [
  BarcodeModel(id: 1, localId: 'b1', value: '6111000000017', productId: 12),
  // Not yet on the server — its row carries the "pending sync" badge.
  BarcodeModel(
    id: 0,
    localId: 'b2',
    value: '6111000000024',
    productId: 12,
    syncStatus: 'pending_create',
  ),
];

const _toppings = ModifierGroup(
  id: 7,
  name: 'Toppings',
  maxSelections: 3,
  options: [ModifierOption(id: 1, modifierGroupId: 7, name: 'Cheese')],
);
const _sauce = ModifierGroup(id: 8, name: 'Sauce');

/// The screens the POS actually runs on, in logical pixels.
const _screens = <String, Size>{
  'Windows till 1366x768': Size(1366, 768),
  '10-inch landscape 1280x800': Size(1280, 800),
  'compact window 1024x768': Size(1024, 768),
  'portrait tablet 800x1280': Size(800, 1280),
  '7-inch portrait 600x960': Size(600, 960),
};

const _wide = Size(1366, 768);
const _narrow = Size(600, 960);

/// Opens the editor through `showDialog`, exactly as the Products screen does,
/// so it gets the real dialog constraints rather than a bare widget's.
Future<AppLocalizations> _openEditor(
  WidgetTester tester,
  Size screen, {
  Product? product,
  bool isPostCreation = false,
  Map<String, String> settings = const {},
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(() => _FakeSettings(settings)),
        allProductGroupsProvider.overrideWith((ref) => Stream.value([_drinks])),
        allTaxesProvider.overrideWith((ref) => Stream.value([_vat])),
        barcodesByProductIdProvider(12)
            .overrideWith((ref) => Stream.value(_barcodes)),
        barcodeRulesProvider.overrideWith((ref) => Stream.value(const [])),
        productModifierGroupIdsProvider(12)
            .overrideWith((ref) => Stream.value(const [7])),
        allModifierGroupsProvider
            .overrideWith((ref) => Stream.value(const [_toppings, _sauce])),
        // The Stock and Stock History tabs.
        allWarehousesProvider.overrideWith(
            (ref) => Stream.value([Warehouse(id: 10, name: 'Main')])),
        stockByWarehouseProvider.overrideWith((ref) => Stream.value(const {
              12: {10: 24.0},
            })),
        stockControlByProductIdProvider(12).overrideWith((ref) async => null),
        productStockMovesProvider
            .overrideWith((ref, query) => Stream.value(StockMovePage.empty)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => productEditorDialogForTest(
                  existingProduct: product,
                  isPostCreation: isPostCreation,
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
  // The dialog's entrance, then the streams' first events.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return AppLocalizations.of(tester.element(find.byType(AlertDialog)));
}

/// Switches tab and lets the TabBarView's slide finish.
Future<void> _openTab(WidgetTester tester, String label) async {
  // The tab strip scrolls on a narrow screen, so bring the tab into view
  // first — as the E2E `tapVisible` does.
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  // The new page is first built in the slide's last frame; its providers'
  // first stream events land after it, so give them a frame to show.
  await tester.pump(const Duration(milliseconds: 100));
}

/// True when a tap at [f]'s centre would actually reach it — on screen, not
/// clipped by the scroll view, not under the footer.
bool _hittable(WidgetTester tester, Finder f) {
  final target = tester.renderObject(f);
  return tester
      .hitTestOnBinding(tester.getCenter(f))
      .path
      .any((entry) => entry.target == target);
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Finder _switch(String title) => find.widgetWithText(SwitchListTile, title);

final Finder _anyDropdown = find.byWidgetPredicate(
  (w) => w.runtimeType.toString().startsWith('IlyassDropdown<'),
);

Finder _dropdown(String label) =>
    find.ancestor(of: find.text(label), matching: _anyDropdown).first;

Finder get _groupDropdown => find.byType(IlyassDropdown<int?>);

/// The card a section header sits on — the header's nearest Container.
Finder _sectionCard(String title) => find
    .ancestor(of: find.text(title.toUpperCase()), matching: find.byType(Container))
    .first;

/// A header on each tab, to prove the tab rendered its sections.
final _tabs = <String, (String Function(AppLocalizations), String Function(AppLocalizations))>{
  'Pricing': ((l) => l.pricingTab, (l) => l.priceAndCostSection),
  'Barcodes': ((l) => l.barcodesTab, (l) => l.productBarcodes),
  'Stock': ((l) => l.stock, (l) => l.stockOnHand),
  'Stock History': ((l) => l.stockHistoryTab, (l) => l.stockHistoryTab),
  'Modifiers': ((l) => l.posModifiers, (l) => l.productModifierGroups),
  'Appearance': ((l) => l.setAppearance, (l) => l.productColorMarker),
};

void main() {
  // ── General ────────────────────────────────────────────────────────────────

  group('General lays out without overflow on', () {
    for (final entry in _screens.entries) {
      testWidgets(entry.key, (tester) async {
        final l = await _openEditor(tester, entry.value, product: _coca());

        // A RenderFlex overflow surfaces here as an exception.
        expect(tester.takeException(), isNull);

        // The three sections, in reading order.
        final info = find.text(l.productInformationSection.toUpperCase());
        final description = find.text(l.description.toUpperCase());
        final behavior = find.text(l.productBehaviorSection.toUpperCase());
        expect(info, findsOneWidget);
        expect(description, findsOneWidget);
        expect(behavior, findsOneWidget);
        expect(
          tester.getTopLeft(info).dy,
          lessThan(tester.getTopLeft(description).dy),
        );
        expect(
          tester.getTopLeft(description).dy,
          lessThan(tester.getTopLeft(behavior).dy),
        );

        // Sticky footer: the actions sit outside the scrolling tab body and
        // can be tapped however long the form gets.
        final save = find.widgetWithText(ElevatedButton, l.actionSaveChanges);
        final cancel = find.widgetWithText(TextButton, l.actionCancel);
        expect(save, findsOneWidget);
        expect(cancel, findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: save,
          ),
          findsNothing,
        );
        expect(_hittable(tester, save), isTrue);
      });
    }
  });

  testWidgets('General, wide: fields pair up 3:2, options two to a row',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());

    final name = _field(l.productNameRequired);
    // Same row, and the name — the primary field — gets the wider column.
    expect(tester.getTopLeft(name).dy, tester.getTopLeft(_groupDropdown).dy);
    expect(
      tester.getSize(name).width,
      greaterThan(tester.getSize(_groupDropdown).width),
    );
    expect(
      tester.getTopLeft(_field(l.productCodeSku)).dy,
      tester.getTopLeft(_field(l.plu)).dy,
    );
    expect(
      tester.getTopLeft(_field(l.ageRestriction)).dy,
      tester.getTopLeft(_field(l.rankDisplayOrder)).dy,
    );
    // The columns line up down the section.
    expect(
      tester.getTopLeft(_field(l.plu)).dx,
      tester.getTopLeft(_groupDropdown).dx,
    );

    // Two option cards per row, equal height, so no ragged edge.
    final service = _switch(l.isServiceNotPhysical);
    final weight = _switch(l.sellByWeight);
    expect(tester.getTopLeft(service).dy, tester.getTopLeft(weight).dy);
    expect(tester.getSize(service).height, tester.getSize(weight).height);
    expect(
      tester.getTopLeft(_switch(l.changePriceAllowed)).dy,
      greaterThan(tester.getTopLeft(service).dy),
    );
  });

  testWidgets('General, narrow: fields and options stack', (tester) async {
    final l = await _openEditor(tester, _narrow, product: _coca());

    final name = _field(l.productNameRequired);
    expect(
      tester.getTopLeft(_groupDropdown).dy,
      greaterThan(tester.getTopLeft(name).dy),
    );
    expect(tester.getTopLeft(_groupDropdown).dx, tester.getTopLeft(name).dx);
    expect(
      tester.getTopLeft(_switch(l.sellByWeight)).dy,
      greaterThan(tester.getTopLeft(_switch(l.isServiceNotPhysical)).dy),
    );
  });

  testWidgets('General keeps the handles the E2E helpers rely on',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());

    // setSwitch: a SwitchListTile whose title is exactly the label.
    for (final title in [
      l.isServiceNotPhysical,
      l.sellByWeight,
      l.changePriceAllowed,
      l.isEnabledVisible,
    ]) {
      expect(_switch(title), findsOneWidget, reason: title);
    }
    // fillField: a TextFormField carrying its label.
    for (final label in [
      l.productNameRequired,
      l.productCodeSku,
      l.plu,
      l.ageRestriction,
      l.rankDisplayOrder,
    ]) {
      expect(_field(label), findsOneWidget, reason: label);
    }
    // The description has no label; it is found by key.
    expect(find.byKey(kProductDescriptionFieldKey), findsOneWidget);
    // Quick Settings is found by this icon — it must not appear twice.
    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets('General shows the product it was opened with', (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());

    String textOf(Finder f) =>
        tester.widget<TextFormField>(f).controller!.text;
    expect(textOf(_field(l.productNameRequired)), 'Coca-Cola');
    expect(textOf(_field(l.productCodeSku)), '0001');
    expect(textOf(_field(l.plu)), '1');
    expect(
      textOf(find.byKey(kProductDescriptionFieldKey)),
      'Chilled 33cl can',
    );
    expect(
      find.descendant(of: _groupDropdown, matching: find.text('Drinks')),
      findsOneWidget,
    );
    expect(tester.widget<SwitchListTile>(_switch(l.isEnabledVisible)).value,
        isTrue);
  });

  testWidgets('a service still switches sell-by-weight off and disables it',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());

    expect(tester.widget<SwitchListTile>(_switch(l.sellByWeight)).onChanged,
        isNotNull);

    // Below the fold on a 768-high till — scrolled to first, as the E2E
    // `setSwitch` does. The footer stays put while the body scrolls.
    await tester.ensureVisible(_switch(l.isServiceNotPhysical));
    await tester.pump();
    await tester.tap(_switch(l.isServiceNotPhysical));
    await tester.pump();

    final weight = tester.widget<SwitchListTile>(_switch(l.sellByWeight));
    expect(weight.value, isFalse);
    expect(weight.onChanged, isNull);
  });

  testWidgets('a new product keeps its own title and primary action',
      (tester) async {
    final l = await _openEditor(tester, _screens['compact window 1024x768']!);

    expect(tester.takeException(), isNull);
    expect(find.text(l.newProduct), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, l.nextTaxesAndStock),
      findsOneWidget,
    );
  });

  // ── Every other tab ────────────────────────────────────────────────────────

  for (final tab in _tabs.entries) {
    group('${tab.key} lays out without overflow on', () {
      for (final screen in _screens.entries) {
        testWidgets(screen.key, (tester) async {
          final l = await _openEditor(tester, screen.value, product: _coca());
          final (label, header) = tab.value;
          await _openTab(tester, label(l));

          expect(tester.takeException(), isNull);
          expect(find.text(header(l).toUpperCase()), findsOneWidget);
          expect(
            _hittable(
              tester,
              find.widgetWithText(ElevatedButton, l.actionSaveChanges),
            ),
            isTrue,
          );
        });
      }
    });
  }

  // ── Pricing ────────────────────────────────────────────────────────────────

  testWidgets('Pricing, wide, pricing from cost: markup joins the price row',
      (tester) async {
    // The seeded default: Products.CostPriceBasedMarkup is on.
    final l = await _openEditor(
      tester,
      _wide,
      product: _coca(),
      settings: {SettingKeys.costPriceBasedMarkup: 'true'},
    );
    await _openTab(tester, l.pricingTab);

    final selling = _field(l.sellingPriceRequired);
    final cost = _field(l.purchaseCost);
    final markup = _field(l.marginMarkup);
    expect(markup, findsOneWidget);
    // One row, not a half-empty row of its own for the markup.
    expect(tester.getTopLeft(cost).dy, tester.getTopLeft(selling).dy);
    expect(tester.getTopLeft(markup).dy, tester.getTopLeft(selling).dy);
    expect(
      tester.getSize(selling).width,
      greaterThan(tester.getSize(markup).width),
    );
  });

  testWidgets('Pricing, wide: price leads its row, tax sits beside its switch',
      (tester) async {
    final l = await _openEditor(
      tester,
      _wide,
      product: _coca(),
      settings: {SettingKeys.costPriceBasedMarkup: 'false'},
    );
    await _openTab(tester, l.pricingTab);
    expect(_field(l.marginMarkup), findsNothing);

    // The three sections, in order: what it costs, what is added, per what.
    final price = find.text(l.priceAndCostSection.toUpperCase());
    final taxes = find.text(l.taxesLabel.toUpperCase());
    final unit = find.text(l.unitAndStockSection.toUpperCase());
    expect(tester.getTopLeft(price).dy, lessThan(tester.getTopLeft(taxes).dy));
    expect(tester.getTopLeft(taxes).dy, lessThan(tester.getTopLeft(unit).dy));

    final selling = _field(l.sellingPriceRequired);
    final cost = _field(l.purchaseCost);
    expect(tester.getTopLeft(selling).dy, tester.getTopLeft(cost).dy);
    expect(
      tester.getSize(selling).width,
      greaterThan(tester.getSize(cost).width),
    );
    // The price says what one unit of it buys.
    expect(
      find.descendant(
        of: selling,
        matching: find.text('/ ${uomById(kUomPieces).code}'),
      ),
      findsOneWidget,
    );

    final taxPicker = _dropdown(l.primaryTaxRate);
    final inclusive = _switch(l.priceIsTaxInclusive);
    expect(inclusive, findsOneWidget);
    expect(tester.getTopLeft(taxPicker).dy, tester.getTopLeft(inclusive).dy);
    // The columns line up with the price row above.
    expect(tester.getTopLeft(taxPicker).dx, tester.getTopLeft(selling).dx);
    expect(tester.getTopLeft(inclusive).dx, tester.getTopLeft(cost).dx);

    // The unit dropdown the E2E `pickDropdown` finds by its label.
    expect(_dropdown(l.measurementUnit), findsOneWidget);
  });

  testWidgets('Pricing: choosing a tax shows the breakdown panel',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());
    await _openTab(tester, l.pricingTab);
    expect(find.byIcon(Icons.calculate_outlined), findsNothing);

    await tester.tap(_dropdown(l.primaryTaxRate));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('VAT (20.0%)').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
  });

  testWidgets('Pricing, narrow: price and cost stack', (tester) async {
    final l = await _openEditor(tester, _narrow, product: _coca());
    await _openTab(tester, l.pricingTab);

    final selling = _field(l.sellingPriceRequired);
    final cost = _field(l.purchaseCost);
    expect(tester.getTopLeft(cost).dy, greaterThan(tester.getTopLeft(selling).dy));
    expect(tester.getTopLeft(cost).dx, tester.getTopLeft(selling).dx);
  });

  // ── Barcodes ───────────────────────────────────────────────────────────────

  for (final screen in [_wide, _screens['compact window 1024x768']!, _narrow]) {
    testWidgets(
        'Barcodes: Add is reachable without scrolling at '
        '${screen.width.toInt()}x${screen.height.toInt()}', (tester) async {
      final l = await _openEditor(tester, screen, product: _coca());
      await _openTab(tester, l.barcodesTab);

      // The exact lookup `addBarcode` performs: the field's innermost Row
      // must also hold the Add button.
      final field = find.widgetWithText(TextField, l.barcode);
      expect(field, findsOneWidget);
      final addButton = find.descendant(
        of: find.ancestor(of: field, matching: find.byType(Row)).first,
        matching: find.widgetWithText(ElevatedButton, l.actionAdd),
      );
      expect(addButton, findsOneWidget);
      // `addBarcode` taps it WITHOUT ensureVisible.
      expect(_hittable(tester, addButton), isTrue);
      expect(_hittable(tester, find.text('EAN-13')), isTrue);
    });
  }

  testWidgets('Barcodes: every code is listed, with its sync state and count',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());
    await _openTab(tester, l.barcodesTab);

    for (final b in _barcodes) {
      expect(find.widgetWithText(ListTile, b.value), findsOneWidget);
    }
    // `verifyProduct` scopes the pending badge to the barcode's own ListTile.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '6111000000024'),
        matching: find.text(l.pendingSync),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '6111000000017'),
        matching: find.text(l.pendingSync),
      ),
      findsNothing,
    );
    // The count beside the section title.
    expect(
      find.descendant(
        of: _sectionCard(l.productBarcodes),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  // ── Modifiers ──────────────────────────────────────────────────────────────

  testWidgets('Modifiers: one heading, the attached group, a finger-sized add',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());
    await _openTab(tester, l.posModifiers);

    // The picker used to print its own title under the section's — once now.
    expect(find.text(l.productModifierGroupsHint), findsOneWidget);
    expect(find.text(l.productModifierGroups), findsNothing);
    expect(find.widgetWithText(ListTile, 'Toppings'), findsOneWidget);

    final attach = find.ancestor(
      of: find.text(l.attachModifierGroup),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(attach, findsOneWidget);
    expect(tester.getSize(attach).height, greaterThanOrEqualTo(48));
  });

  // ── Appearance ─────────────────────────────────────────────────────────────

  testWidgets('Appearance: every InkWell inside a Wrap is a colour swatch',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());
    await _openTab(tester, l.setAppearance);

    // The E2E `pickSwatch` takes the Nth InkWell inside ANY Wrap. A button
    // laid out in a Wrap here would shift every index it picks.
    final inWraps = find.descendant(
      of: find.byType(Wrap),
      matching: find.byType(InkWell),
    );
    expect(inWraps, findsWidgets);
    for (final e in inWraps.evaluate()) {
      expect(
        find.descendant(
          of: find.byElementPredicate((x) => x == e),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
        reason: 'an InkWell in a Wrap that is not a swatch',
      );
    }
  });

  testWidgets('Appearance, wide: colour and image side by side, one height',
      (tester) async {
    final l = await _openEditor(tester, _wide, product: _coca());
    await _openTab(tester, l.setAppearance);

    final colour = _sectionCard(l.productColorMarker);
    final image = _sectionCard(l.productImage);
    expect(tester.getTopLeft(colour).dy, tester.getTopLeft(image).dy);
    expect(tester.getSize(colour).height, tester.getSize(image).height);
    expect(tester.getTopLeft(image).dx, greaterThan(tester.getTopLeft(colour).dx));
  });

  testWidgets('Appearance, narrow: colour above image', (tester) async {
    final l = await _openEditor(tester, _narrow, product: _coca());
    await _openTab(tester, l.setAppearance);

    final colour = _sectionCard(l.productColorMarker);
    final image = _sectionCard(l.productImage);
    expect(tester.getTopLeft(image).dy, greaterThan(tester.getTopLeft(colour).dy));
    expect(tester.getTopLeft(image).dx, tester.getTopLeft(colour).dx);
  });

  // ── Phase 2: Taxes ─────────────────────────────────────────────────────────

  for (final screen in [_screens['compact window 1024x768']!, _narrow]) {
    testWidgets(
        'Phase 2 opens on its Taxes card at '
        '${screen.width.toInt()}x${screen.height.toInt()}', (tester) async {
      final l = await _openEditor(
        tester,
        screen,
        product: _coca(),
        isPostCreation: true,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l.applyTaxes.toUpperCase()), findsOneWidget);
      expect(_dropdown(l.primaryTaxRate), findsOneWidget);
      expect(
        _hittable(tester, find.widgetWithText(ElevatedButton, l.finishSetup)),
        isTrue,
      );
    });
  }
}
