// The Stock Moves screen: what each column says and the colour it says it in
// — in both themes — the next page near the end, the ⋮ actions, the period
// chip, and ticked rows being exactly what an export writes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/app_date_format.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/document/document_type_constants.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/settings/settings_provider.dart';
import 'package:pos_app/stock/stock_history_screen.dart';
import 'package:pos_app/stock/stock_move_labels.dart';
import 'package:pos_app/stock/stock_move_line.dart';
import 'package:pos_app/stock/stock_moves_provider.dart';
import 'package:pos_app/stock/warehouse_model.dart';
import 'package:pos_app/stock/warehouse_provider.dart';
import 'package:pos_app/sync/sync_notifier.dart';
import 'package:pos_app/uom/unit_of_measure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

StockMoveLine move(
  String id, {
  StockLocationKind from = StockLocationKind.vendors,
  StockLocationKind to = StockLocationKind.warehouse,
  double quantity = 5,
  StockMoveStatus status = StockMoveStatus.done,
  String? number,
  int type = DocumentTypes.purchase,
}) =>
    StockMoveLine(
      itemLocalId: id,
      documentLocalId: 'doc-$id',
      documentNumber: number ?? 'N-$id',
      documentTypeId: type,
      date: DateTime.utc(2026, 9, 10, 21, 44),
      productId: 100,
      productName: 'Mint tea',
      barcode: '6111245',
      uomId: kUomPieces,
      warehouseId: 10,
      warehouseName: 'Main',
      from: from,
      to: to,
      quantity: quantity,
      status: status,
      userId: 7,
      userName: 'Gérant',
    );

class _FakeSettings extends AppSettingsNotifier {
  @override
  Map<String, String> build() => {...kSettingDefaults};
}

class _Shop extends SelectedCompanyNotifier {
  @override
  Company? build() => Company(id: 1, name: 'Shop');
}

/// Records what the screen asked the sync engine for, and goes nowhere.
class _RecordingSync extends SyncNotifier {
  final calls = <bool>[];

  @override
  Future<void> sync({bool manual = false}) async => calls.add(manual);
}

/// Stands in for the system save dialog: keeps what it was handed and answers
/// "cancelled", so nothing is written to disk and no real dialog opens.
class _CapturingPicker extends FilePicker {
  Uint8List? bytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    this.bytes = bytes;
    return null;
  }
}

/// A loader that counts its calls — the whole-history read an export makes
/// only when no row is ticked.
class _Loader {
  _Loader([this.moves = const []]);

  final List<StockMoveLine> moves;
  final calls = <DateTimeRange?>[];

  Future<List<StockMoveLine>> call({
    required int companyId,
    int? warehouseId,
    int? productId,
    String? search,
    DateTimeRange? period,
  }) async {
    calls.add(period);
    return moves;
  }
}

/// The sheet's rows, as the text or value each cell holds.
List<List<String>> sheetRows(Uint8List xlsx) {
  final sheet = ZipDecoder()
      .decodeBytes(xlsx)
      .files
      .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
  final doc = XmlDocument.parse(utf8.decode(sheet.content));
  return [
    for (final row in doc.findAllElements('row'))
      [
        for (final c in row.findElements('c'))
          c.getAttribute('t') == 'inlineStr'
              ? c.findAllElements('t').single.innerText
              : c.findElements('v').single.innerText,
      ],
  ];
}

void main() {
  final dates = AppDateFormat('dd/MM/yyyy', timezone: 'Etc/UTC');

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester,
    List<StockMoveLine> lines, {
    bool hasMore = false,
    ThemeData? theme,
    Map<String, Object> prefs = const {},
    List<Override> overrides = const [],
  }) async {
    // Wide enough for every column, so no cell sits past the scroll edge.
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(prefs);
    final store = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(store),
        appDateFormatProvider.overrideWithValue(dates),
        stockMovesProvider.overrideWith((ref) =>
            Stream.value(StockMovePage(lines: lines, hasMore: hasMore))),
        allWarehousesProvider
            .overrideWith((ref) => Stream.value(const <Warehouse>[])),
        ...overrides,
      ],
      child: MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StockHistoryScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
        tester.element(find.byType(StockHistoryScreen)));
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(StockHistoryScreen)));

  Future<void> openActions(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  List<Override> exporting(_Loader loader) => [
        appSettingsProvider.overrideWith(_FakeSettings.new),
        selectedCompanyProvider.overrideWith(_Shop.new),
        stockMovesExportLoaderProvider.overrideWithValue(loader.call),
      ];

  testWidgets('each column says what the move did, as Moves History does',
      (tester) async {
    await pumpScreen(tester, [move('a', number: 'WH/POS/00888')]);
    final l = l10n(tester);

    expect(find.text('Sep 10, 9:44 PM'), findsOneWidget);
    expect(find.text('WH/POS/00888'), findsOneWidget);
    expect(find.text('Mint tea'), findsOneWidget);
    expect(find.text('Vendors'), findsOneWidget);
    expect(find.text('Main/Stock'), findsOneWidget);
    expect(find.text(formatQuantity(5, kUomPieces)), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    // Who moved it is part of an adjustment's reference, not a column.
    expect(find.text(l.colDoneBy), findsNothing);
  });

  testWidgets(
      'an inventory adjustment reads as Product Quantity Updated, in amber',
      (tester) async {
    await pumpScreen(tester, [
      move('a',
          type: DocumentTypes.inventoryCount,
          from: StockLocationKind.warehouse,
          to: StockLocationKind.inventoryAdjustment),
    ]);

    final ref = find.text(l10n(tester).productQuantityUpdated('Gérant'));
    expect(ref, findsOneWidget);
    expect(tester.widget<Text>(ref).style?.color,
        tester.element(ref).warningColor);
  });

  testWidgets('a move this till has not synced says so', (tester) async {
    await pumpScreen(tester, [
      move('a', status: StockMoveStatus.pendingSync, number: ''),
    ]);

    expect(find.text('Pending sync'), findsOneWidget);
  });

  for (final (name, theme) in [
    ('light', ThemeData.light()),
    ('dark', ThemeData.dark()),
  ]) {
    testWidgets('in the $name theme: primary reference, green in, red out, '
        'muted virtual locations, a solid Done pill', (tester) async {
      await pumpScreen(
        tester,
        [
          move('in', number: 'IN-1'),
          move('out',
              from: StockLocationKind.warehouse,
              to: StockLocationKind.customers,
              quantity: 2,
              number: 'OUT-1'),
        ],
        theme: theme,
      );

      final context = tester.element(find.byType(StockHistoryScreen));
      final cs = Theme.of(context).colorScheme;
      Color? colorOf(Finder f) => tester.widget<Text>(f).style?.color;

      expect(colorOf(find.text('IN-1')), cs.primary);
      expect(colorOf(find.text(formatQuantity(5, kUomPieces))),
          context.successColor);
      expect(colorOf(find.text(formatQuantity(2, kUomPieces))), cs.error);
      expect(colorOf(find.text('Vendors')), cs.onSurfaceVariant);
      expect(colorOf(find.text('Customers')), cs.onSurfaceVariant);
      expect(colorOf(find.text('Main/Stock').first), cs.onSurface);

      final done = find.text('Done').first;
      final pill = tester.widget<Container>(
          find.ancestor(of: done, matching: find.byType(Container)).first);
      expect((pill.decoration as BoxDecoration).color, context.successColor);
      expect(colorOf(done), cs.surface);
    });
  }

  testWidgets('nearing the end asks for the next page, once', (tester) async {
    final container = await pumpScreen(
      tester,
      [for (var i = 0; i < 60; i++) move('$i')],
      hasMore: true,
    );
    expect(container.read(stockMovesFilterProvider).limit, 200);

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(container.read(stockMovesFilterProvider).limit, 400);
  });

  testWidgets('the last page asks for nothing more', (tester) async {
    final container = await pumpScreen(
      tester,
      [for (var i = 0; i < 60; i++) move('$i')],
    );

    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(container.read(stockMovesFilterProvider).limit, 200);
  });

  testWidgets('an empty history says so', (tester) async {
    await pumpScreen(tester, const []);

    expect(find.text(l10n(tester).noStockMoves), findsOneWidget);
  });

  testWidgets('a period shows as a chip in the filter bar', (tester) async {
    final container = await pumpScreen(tester, [move('a')]);
    final september =
        DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));

    container.read(stockMovesFilterProvider.notifier).setPeriod(september);
    await tester.pumpAndSettle();

    expect(find.text(stockPeriodLabel(dates, september)), findsOneWidget);
  });

  group('the ⋮ menu', () {
    testWidgets('offers sync, columns and the exports — and no delete',
        (tester) async {
      await pumpScreen(tester, [move('a')]);
      final l = l10n(tester);

      await openActions(tester);

      expect(find.text(l.syncAndRefresh), findsOneWidget);
      expect(find.text(l.columns), findsOneWidget);
      expect(find.text(l.printPdf), findsOneWidget);
      expect(find.text(l.saveAsPdf), findsOneWidget);
      expect(find.text(l.exportToExcel), findsOneWidget);
      // A move leaves only with its document.
      expect(find.text(l.actionDelete), findsNothing);
    });

    testWidgets('Sync & Refresh runs a MANUAL sync from the cloud',
        (tester) async {
      final sync = _RecordingSync();
      await pumpScreen(tester, [move('a')],
          overrides: [syncStateProvider.overrideWith(() => sync)]);

      await openActions(tester);
      await tester.tap(find.text(l10n(tester).syncAndRefresh));
      await tester.pumpAndSettle();

      expect(sync.calls, [true]);
    });

    testWidgets('Columns lists the seven, with the product locked on',
        (tester) async {
      await pumpScreen(tester, [move('a')]);
      final l = l10n(tester);

      await openActions(tester);
      await tester.tap(find.text(l.columns));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      for (final label in [
        l.colDate,
        l.colReference,
        l.colProduct,
        l.colFrom,
        l.colTo,
        l.colQuantity,
        l.colStatus,
      ]) {
        expect(find.descendant(of: dialog, matching: find.text(label)),
            findsOneWidget);
      }
      expect(find.descendant(of: dialog, matching: find.text(l.colDoneBy)),
          findsNothing);
      expect(find.descendant(of: dialog, matching: find.text(l.alwaysShown)),
          findsOneWidget);
    });

    testWidgets('hiding a column in the picker takes it off the table',
        (tester) async {
      await pumpScreen(tester, [move('a')]);
      final l = l10n(tester);

      await openActions(tester);
      await tester.tap(find.text(l.columns));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text(l.colStatus)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.actionClose));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsNothing);
      expect(find.text(l.colStatus), findsNothing);
    });

    testWidgets('an export with nothing to export says so', (tester) async {
      await pumpScreen(tester, [move('a')], overrides: exporting(_Loader()));
      final l = l10n(tester);

      await openActions(tester);
      await tester.tap(find.text(l.exportToExcel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(l.noStockMovesToExport), findsOneWidget);
    });
  });

  group('ticked rows', () {
    testWidgets('relabel the exports with their count', (tester) async {
      await pumpScreen(tester, [move('1'), move('2'), move('3')]);
      final l = l10n(tester);

      await tester.tap(find.text('N-1'));
      await tester.tap(find.text('N-3'));
      await tester.pump();
      await openActions(tester);

      expect(find.text(l.printSelectedPdf(2)), findsOneWidget);
      expect(find.text(l.saveSelectedAsPdf(2)), findsOneWidget);
      expect(find.text(l.exportSelectedToExcel(2)), findsOneWidget);
    });

    testWidgets('the header box ticks every row on screen', (tester) async {
      await pumpScreen(tester, [move('1'), move('2'), move('3')]);
      final l = l10n(tester);

      // The box is painted under an IgnorePointer; the tap lands on the
      // GestureDetector that wraps it, which is what the operator touches too.
      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pump();
      await openActions(tester);

      expect(find.text(l.exportSelectedToExcel(3)), findsOneWidget);
    });

    testWidgets('are exactly what the sheet holds — the history is not read',
        (tester) async {
      final picker = _CapturingPicker();
      FilePicker.platform = picker;
      final loader = _Loader([move('x'), move('y')]);
      await pumpScreen(tester, [move('1'), move('2'), move('3')],
          overrides: exporting(loader));
      final l = l10n(tester);

      await tester.tap(find.text('N-3'));
      await tester.tap(find.text('N-1'));
      await tester.pump();
      await openActions(tester);
      await tester.tap(find.text(l.exportSelectedToExcel(2)));
      await tester.pumpAndSettle();

      expect(loader.calls, isEmpty);
      final rows = sheetRows(picker.bytes!);
      // The header, then the two ticked rows in the order on screen.
      expect(rows, hasLength(3));
      expect(rows.skip(1).map((r) => r[1]), ['N-1', 'N-3']);
    });

    testWidgets('none ticked: the sheet holds everything the filters match',
        (tester) async {
      final picker = _CapturingPicker();
      FilePicker.platform = picker;
      final loader = _Loader([move('x'), move('y'), move('z')]);
      final container = await pumpScreen(tester, [move('1')],
          overrides: exporting(loader));
      final l = l10n(tester);
      final september =
          DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30));
      container.read(stockMovesFilterProvider.notifier).setPeriod(september);
      await tester.pumpAndSettle();

      await openActions(tester);
      await tester.tap(find.text(l.exportToExcel));
      await tester.pumpAndSettle();

      // Read once, with the period the screen is filtered by.
      expect(loader.calls, [september]);
      expect(sheetRows(picker.bytes!), hasLength(4));
    });

    testWidgets('are let go when a filter changes', (tester) async {
      await pumpScreen(tester, [move('1'), move('2')]);
      final l = l10n(tester);

      await tester.tap(find.text('N-1'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'tea');
      await tester.pump(const Duration(milliseconds: 400));
      await openActions(tester);

      expect(find.text(l.printPdf), findsOneWidget);
      expect(find.text(l.printSelectedPdf(1)), findsNothing);
    });
  });

  testWidgets('a column hidden on an earlier launch stays hidden',
      (tester) async {
    await pumpScreen(tester, [move('a')],
        prefs: {'stockMoves.visibleColumns': '{"status": false}'});

    expect(find.text('Done'), findsNothing);
    expect(find.text('Mint tea'), findsOneWidget);
  });
}
