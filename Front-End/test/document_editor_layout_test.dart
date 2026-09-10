// Pins the layout of the document editor dialog — all six tabs.
//
// The editor was redesigned onto the same house components as the product
// editor (lib/core/ilyass_form.dart): titled section cards, fields that pair
// up only while they fit, the header's Save in a fixed footer. What this
// guards:
//
//   • no overflow on any tab, on any screen the POS ships on. Two real ones
//     were fixed: the payment summary's fixed Row of three cards ran off a 7"
//     tablet, and the payments DataTable could not scroll sideways;
//   • the header's Save sits in the footer on the three header tabs only;
//   • the items table scrolls sideways on a narrow screen instead of squeezing
//     eight columns, and its row actions are finger-sized;
//   • the Discount tab says "no discounts" instead of rendering a blank page;
//   • the tabs that need a saved header explain why and lead back to it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_provider.dart';
import 'package:pos_app/cart/payment_model.dart';
import 'package:pos_app/cart/payment_provider.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/customer/customer_provider.dart';
import 'package:pos_app/document/document_editor_screen.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/stock/warehouse_provider.dart';

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

const _localId = 'doc-local-1';
const _serverId = 55;

Document _doc() => Document(
      id: _serverId,
      localId: _localId,
      number: 'FAC-0012',
      userId: 1,
      customerId: 0,
      companyId: 0,
      documentTypeId: 2,
      documentTypeName: 'FA - Invoice',
      warehouseId: 0,
      date: '2026-09-01',
      total: 120,
    );

DocumentItem _item(int id, String name, double qty, double price) =>
    DocumentItem(
      id: id,
      localId: 'item-$id',
      companyId: 0,
      documentId: _serverId,
      productId: id,
      productName: name,
      quantity: qty,
      expectedQuantity: qty,
      priceBeforeTax: price,
      price: price,
      discount: 0,
      discountType: 0,
      productCost: 0,
      priceBeforeTaxAfterDiscount: price * qty,
      priceAfterDiscount: price * qty,
      total: price * qty,
      totalAfterDocumentDiscount: price * qty,
      discountApplyRule: true,
      taxRate: 20,
      totalWithTax: price * qty * 1.2,
    );

final _items = [
  _item(1, 'Coca-Cola 33cl can, chilled — carton of twenty-four', 2, 30),
  _item(2, 'Espresso', 3, 10),
];

final _payments = [
  PaymentModel(
    id: 9,
    documentId: _serverId,
    paymentTypeId: 1,
    paymentTypeName: 'Cash',
    amount: 50,
    date: DateTime(2026, 9, 2),
    userId: 1,
    localId: 'pay-1',
  ),
];

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

/// Opens the editor through the real `showDocumentEditor`, on [tab].
Future<AppLocalizations> _openEditor(
  WidgetTester tester,
  Size screen, {
  Document? document,
  int tab = 0,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(_FakeSettings.new),
        selectableCustomersProvider.overrideWith(
          (ref) => const AsyncValue.data(<Customer>[]),
        ),
        allUsersProvider.overrideWith((ref) => Stream.value(const [])),
        allWarehousesProvider.overrideWith((ref) => Stream.value(const [])),
        localDocumentItemsProvider(
          const LocalItemsArgs(
            docLocalId: _localId,
            docServerId: _serverId,
            companyId: 0,
          ),
        ).overrideWith((ref) => Stream.value(_items)),
        localDocumentPaymentsProvider(
          const LocalPaymentsArgs(
            documentLocalId: _localId,
            documentServerId: _serverId,
            companyId: 0,
          ),
        ).overrideWith((ref) => Stream.value(_payments)),
        documentDiscountLinesProvider(_localId)
            .overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showDocumentEditor(
                context,
                ref,
                existingDocument: document,
                initialTabIndex: tab,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // The dialog's entrance, the streams' first events, and a frame to show
  // them.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
  return AppLocalizations.of(tester.element(find.byType(AlertDialog)));
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

/// The field a label belongs to — the InputDecorator that draws it.
Finder _decorator(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(InputDecorator))
    .first;

/// The section header each tab opens on.
final _tabHeaders = <int, String Function(AppLocalizations)>{
  0: (l) => l.documentInfo,
  1: (l) => l.partiesLogistics,
  2: (l) => l.financialsNotes,
  3: (l) => l.documentItems,
  4: (l) => l.discountBreakdown,
  5: (l) => l.appliedPayments,
};

void main() {
  for (final tab in _tabHeaders.entries) {
    group('tab ${tab.key} lays out without overflow on', () {
      for (final screen in _screens.entries) {
        testWidgets(screen.key, (tester) async {
          final l = await _openEditor(
            tester,
            screen.value,
            document: _doc(),
            tab: tab.key,
          );

          // A RenderFlex overflow surfaces here as an exception.
          expect(tester.takeException(), isNull);
          expect(
            find.text(tab.value(l).toUpperCase()),
            findsOneWidget,
            reason: 'the tab should open on its section card',
          );

          // The footer is fixed and reachable on every tab.
          expect(
            _hittable(tester, find.widgetWithText(TextButton, l.actionClose)),
            isTrue,
          );
          // The header's Save lives there too — on the header tabs only.
          final save = find.widgetWithText(ElevatedButton, l.saveHeaderChanges);
          if (tab.key < 3) {
            expect(save, findsOneWidget);
            expect(_hittable(tester, save), isTrue);
          } else {
            expect(save, findsNothing);
          }
        });
      }
    });
  }

  testWidgets('Info, wide: type beside number, three dates in one row',
      (tester) async {
    final l = await _openEditor(tester, _wide, document: _doc());

    final type = _decorator(l.documentType);
    expect(
      find.descendant(of: type, matching: find.text('FA - Invoice')),
      findsOneWidget,
      reason: 'the document type reads as a field value, not a button label',
    );
    final number = find.widgetWithText(TextFormField, l.numberLabel);
    expect(tester.getTopLeft(type).dy, tester.getTopLeft(number).dy);
    expect(tester.getSize(type).width, greaterThan(tester.getSize(number).width));

    final date = _decorator(l.dateLabel);
    final due = _decorator(l.dueDate);
    final stock = _decorator(l.stockDate);
    expect(tester.getTopLeft(due).dy, tester.getTopLeft(date).dy);
    expect(tester.getTopLeft(stock).dy, tester.getTopLeft(date).dy);
  });

  testWidgets('Info, narrow: the dates stack', (tester) async {
    final l = await _openEditor(tester, _narrow, document: _doc());

    final date = _decorator(l.dateLabel);
    final due = _decorator(l.dueDate);
    expect(tester.getTopLeft(due).dy, greaterThan(tester.getTopLeft(date).dy));
    expect(tester.getTopLeft(due).dx, tester.getTopLeft(date).dx);
  });

  testWidgets('Financials: "apply after tax" is an option card, value kept',
      (tester) async {
    final l = await _openEditor(tester, _wide, document: _doc(), tab: 2);

    final option = find.widgetWithText(SwitchListTile, l.applyAfterTax);
    expect(option, findsOneWidget);
    // The document's own setting (true), unchanged by the redesign.
    expect(tester.widget<SwitchListTile>(option).value, isTrue);
  });

  testWidgets('Items: rows, count, total, and finger-sized row actions',
      (tester) async {
    final l = await _openEditor(tester, _wide, document: _doc(), tab: 3);

    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text(l.itemsBaseTotal), findsOneWidget);
    // The count beside the section title.
    expect(find.text('${_items.length}'), findsWidgets);
    expect(
      _hittable(tester, find.widgetWithText(FilledButton, l.addProduct)),
      isTrue,
    );

    final edits = find.byTooltip(l.editItemAction);
    final deletes = find.byTooltip(l.deleteItemAction);
    expect(edits, findsNWidgets(_items.length));
    expect(deletes, findsNWidgets(_items.length));
    // Was a 26px InkWell; the house rule is a 36×36 target.
    final button = find.ancestor(of: edits.first, matching: find.byType(IconButton));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(36));
    expect(tester.getSize(button).width, greaterThanOrEqualTo(36));
  });

  testWidgets('Items, narrow: the table scrolls sideways instead of squeezing',
      (tester) async {
    await _openEditor(tester, _narrow, document: _doc(), tab: 3);

    expect(tester.takeException(), isNull);
    expect(
      find.ancestor(
        of: find.text('Espresso'),
        matching: find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Payments, wide: the three figures share one row',
      (tester) async {
    final l = await _openEditor(tester, _wide, document: _doc(), tab: 5);

    final total = find.text(l.documentTotal);
    final paid = find.text(l.totalPaid);
    final remaining = find.text(l.remainingBalance);
    expect(tester.getTopLeft(paid).dy, tester.getTopLeft(total).dy);
    expect(tester.getTopLeft(remaining).dy, tester.getTopLeft(total).dy);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
  });

  testWidgets('Payments, narrow: the figures wrap instead of overflowing',
      (tester) async {
    final l = await _openEditor(tester, _narrow, document: _doc(), tab: 5);

    expect(tester.takeException(), isNull);
    // As many per row as fit (two here), the rest wrapping below — the old
    // fixed Row kept all three on one line and ran off the screen.
    final total = find.text(l.documentTotal);
    final remaining = find.text(l.remainingBalance);
    expect(
      tester.getTopLeft(remaining).dy,
      greaterThan(tester.getTopLeft(total).dy),
    );
    // The table sits in a sideways scroll view rather than overflowing.
    expect(
      find.ancestor(
        of: find.byType(DataTable),
        matching: find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Discounts: an empty document says so instead of a blank page',
      (tester) async {
    final l = await _openEditor(tester, _wide, document: _doc(), tab: 4);

    expect(find.text(l.noDocumentDiscounts), findsOneWidget);
  });

  testWidgets('a new document explains the locked tabs and leads back',
      (tester) async {
    final l = await _openEditor(tester, _screens['compact window 1024x768']!,
        tab: 3);

    expect(tester.takeException(), isNull);
    expect(find.text(l.newDocument), findsOneWidget);
    expect(
      find.text(l.saveHeaderFirstHint(l.createAndAddItems)),
      findsOneWidget,
    );
    // No header tab is open, so no header Save in the footer.
    expect(
      find.widgetWithText(ElevatedButton, l.createAndAddItems),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, l.documentInfo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(l.documentInfo.toUpperCase()), findsOneWidget);
    expect(
      _hittable(
        tester,
        find.widgetWithText(ElevatedButton, l.createAndAddItems),
      ),
      isTrue,
    );
  });
}
