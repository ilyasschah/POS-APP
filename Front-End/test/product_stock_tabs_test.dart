// The product editor's Stock and Stock History tabs: every warehouse listed
// (Unassigned where it holds none), the rules read against the stock on hand,
// and a history narrowed to this product over a period the app's own range
// picker chooses.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/product_model.dart';
import 'package:pos_app/product/product_stock_tabs.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/stock/stock_control_model.dart';
import 'package:pos_app/stock/stock_control_provider.dart';
import 'package:pos_app/stock/stock_move_labels.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_moves_provider.dart';
import 'package:pos_app/stock/stock_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product tea() => Product(
      id: 12,
      companyId: 1,
      productGroupId: null,
      name: 'Mint tea',
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
      description: '',
      rank: 0,
    );

StockControl rule({
  double reorderPoint = 10,
  double preferred = 30,
  bool warn = true,
  double warnAt = 3,
}) =>
    StockControl(
      id: 1,
      productId: 12,
      productName: 'Mint tea',
      reorderPoint: reorderPoint,
      preferredQuantity: preferred,
      isLowStockWarningEnabled: warn,
      lowStockWarningQuantity: warnAt,
    );

StockMoveLine move(String id, {int type = DocumentTypes.sales}) =>
    StockMoveLine(
      itemLocalId: id,
      documentLocalId: 'doc-$id',
      documentNumber: 'WH/POS/00$id',
      documentTypeId: type,
      date: DateTime.utc(2026, 9, 9, 21, 20),
      productId: 12,
      productName: 'Mint tea',
      barcode: null,
      uomId: kUomPieces,
      warehouseId: 10,
      warehouseName: 'Main',
      from: StockLocationKind.warehouse,
      to: StockLocationKind.customers,
      quantity: 1,
      status: StockMoveStatus.done,
      userId: 7,
      userName: 'Gérant',
    );

void main() {
  final dates = AppDateFormat('dd/MM/yyyy', timezone: 'Etc/UTC');

  Future<AppLocalizations> pump(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
    Size size = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDateFormatProvider.overrideWithValue(dates),
        allWarehousesProvider.overrideWith((ref) => Stream.value([
              Warehouse(id: 10, name: 'Main'),
              Warehouse(id: 11, name: 'Annex'),
            ])),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byWidget(child)));
  }

  group('Stock', () {
    List<Override> stock(Map<int, double> held, StockControl? r) => [
          stockByWarehouseProvider
              .overrideWith((ref) => Stream.value({12: held})),
          stockControlByProductIdProvider(12).overrideWith((ref) async => r),
        ];

    testWidgets('lists every warehouse — Unassigned where it holds none',
        (tester) async {
      final l = await pump(tester, ProductStockTab(product: tea()),
          overrides: stock({10: 5}, null));

      final five = formatQuantity(5, kUomPieces);
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('Annex'), findsOneWidget);
      // Main's row and the total both read five.
      expect(find.text(five), findsNWidgets(2));
      expect(find.text(l.unassigned), findsOneWidget);
      expect(find.text(l.totalLabel), findsOneWidget);
      expect(find.text(l.noStockRuleSet), findsOneWidget);
    });

    testWidgets('reads the rule against the stock on hand', (tester) async {
      final l = await pump(tester, ProductStockTab(product: tea()),
          overrides: stock({10: 5}, rule()));

      // 5 is at/below the reorder point of 10, above the warning at 3.
      expect(find.text(l.stockStatusReorder), findsOneWidget);
      expect(find.text(formatQuantity(10, kUomPieces)), findsOneWidget);
      expect(find.text(formatQuantity(30, kUomPieces)), findsOneWidget);
      expect(find.text(formatQuantity(3, kUomPieces)), findsOneWidget);
    });

    testWidgets('says low stock in the danger colour', (tester) async {
      final l = await pump(tester, ProductStockTab(product: tea()),
          overrides: stock({10: 2}, rule()));

      final status = find.text(l.stockStatusLow);
      expect(status, findsOneWidget);
      expect(tester.widget<Text>(status).style?.color,
          tester.element(status).dangerColor);
    });

    testWidgets('a warning that is switched off reads as a dash',
        (tester) async {
      final l = await pump(tester, ProductStockTab(product: tea()),
          overrides: stock({10: 50}, rule(warn: false)));

      expect(find.text(l.stockStatusHealthy), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('fits a 7-inch portrait tablet', (tester) async {
      await pump(tester, ProductStockTab(product: tea()),
          overrides: stock({10: 5, 11: 120.5}, rule()),
          size: const Size(600, 960));

      expect(tester.takeException(), isNull);
    });
  });

  group('Stock History', () {
    late List<ProductStockMovesQuery> queries;

    List<Override> history(List<StockMoveLine> lines) => [
          productStockMovesProvider.overrideWith((ref, query) {
            queries.add(query);
            return Stream.value(StockMovePage(lines: lines, hasMore: false));
          }),
        ];

    setUp(() => queries = []);

    testWidgets('asks for this product only, in the Moves History columns',
        (tester) async {
      final l = await pump(tester, ProductStockHistoryTab(product: tea()),
          overrides: history([move('888')]));

      expect(queries.last.productId, 12);
      expect(queries.last.period, isNull);
      for (final header in [
        l.colDate,
        l.colReference,
        l.colProduct,
        l.colFrom,
        l.colTo,
        l.colQuantity,
        l.colStatus,
      ]) {
        expect(find.text(header), findsOneWidget, reason: header);
      }
      expect(find.text(l.colDoneBy), findsNothing);
      expect(find.text('WH/POS/00888'), findsOneWidget);
      expect(find.text('Mint tea'), findsOneWidget);
      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets(
        'an inventory adjustment reads as Product Quantity Updated, in amber',
        (tester) async {
      final l = await pump(tester, ProductStockHistoryTab(product: tea()),
          overrides:
              history([move('1', type: DocumentTypes.inventoryCount)]));

      final ref = find.text(l.productQuantityUpdated('Gérant'));
      expect(ref, findsOneWidget);
      expect(tester.widget<Text>(ref).style?.color,
          tester.element(ref).warningColor);
    });

    testWidgets("the period comes from the app's range picker",
        (tester) async {
      final l = await pump(tester, ProductStockHistoryTab(product: tea()),
          overrides: history([move('888')]));

      await tester.tap(find.text(l.periodAllTime));
      await tester.pumpAndSettle();
      // The app's picker, with its predefined periods — not Material's.
      expect(find.text(l.predefinedPeriod), findsOneWidget);
      await tester.tap(find.text(l.thisMonth));
      await tester.pump();
      await tester.tap(find.text(l.actionOk));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final month = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0),
      );
      expect(queries.last.period, month);
      expect(queries.last.productId, 12);
      expect(find.text(stockPeriodLabel(dates, month)), findsOneWidget);
    });

    testWidgets('ticked rows relabel its exports', (tester) async {
      final l = await pump(tester, ProductStockHistoryTab(product: tea()),
          overrides: history([move('1'), move('2'), move('3')]));

      await tester.tap(find.text('WH/POS/001'));
      await tester.tap(find.text('WH/POS/003'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l.printSelectedPdf(2)), findsOneWidget);
      expect(find.text(l.exportSelectedToExcel(2)), findsOneWidget);
    });
  });
}
