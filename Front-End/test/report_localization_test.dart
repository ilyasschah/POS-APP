// The reports module was the last thing still handed to a customer in English:
// 36 report PDFs, their CSV exports and the Stock Report all printed hardcoded
// column headers. These pin that translation.
//
// The failure mode worth guarding is the one l10n_test.dart already names — a
// key added to app_en.arb and forgotten in app_fr.arb / app_ar.arb. gen-l10n
// does not fail on that; it silently emits the ENGLISH string for the missing
// locale, so a French operator gets a report with English headers and nothing
// in the build says a word. One report key going missing is invisible; the
// whole-file key-set check below is what makes it loud.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/l10n/app_localizations.dart';

void main() {
  Future<AppLocalizations> load(WidgetTester tester, String code) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  Map<String, String> arb(String locale) {
    final raw = File('lib/l10n/app_$locale.arb').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in json.entries)
        // '@@locale' and the '@key' metadata blocks are not translatable text.
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };
  }

  group('every string ships in every locale', () {
    test('app_fr.arb and app_ar.arb define exactly the keys app_en.arb does',
        () {
      final en = arb('en').keys.toSet();
      for (final locale in ['fr', 'ar']) {
        final other = arb(locale).keys.toSet();
        expect(
          en.difference(other),
          isEmpty,
          reason: 'app_$locale.arb is MISSING these keys, so gen-l10n will '
              'silently print the English text for them',
        );
        expect(
          other.difference(en),
          isEmpty,
          reason: 'app_$locale.arb defines keys app_en.arb does not — these '
              'are dead, or the English one was renamed',
        );
      }
    });

    test('no report string is left as its English text in fr or ar', () {
      final en = arb('en');
      // Terms that are genuinely identical across these languages, so an equal
      // value is a correct translation rather than a forgotten one.
      const sameInFrench = {
        'rptColDocument', // "Document" is the same word in French
        'rptPageOf', // "Page {page} / {total}" needs no translation
      };
      for (final locale in ['fr', 'ar']) {
        final other = arb(locale);
        final untranslated = [
          for (final key in en.keys)
            if (key.startsWith('rpt') &&
                !(locale == 'fr' && sameInFrench.contains(key)) &&
                en[key] == other[key])
              key,
        ];
        expect(
          untranslated,
          isEmpty,
          reason: 'these report keys still read as English in app_$locale.arb',
        );
      }
    });
  });

  group('report headers reach the PDF builders translated', () {
    testWidgets('French', (tester) async {
      final l = await load(tester, 'fr');
      expect(l.rptTitleSalesByProduct, 'VENTES PAR PRODUIT');
      expect(l.rptTitleStockReport, 'RAPPORT DE STOCK');
      expect(l.rptColTotalBeforeDisc, 'Total avant remise');
      expect(l.rptColUom, 'UdM');
      expect(l.rptFastMoving, 'Rotation rapide');
      expect(l.rptTotalsRow, 'TOTAUX');
      // Parameterised summary lines keep their argument.
      expect(l.rptTotalDiscounted('12,50'), contains('12,50'));
      expect(l.rptPageOf('2', '7'), 'Page 2 / 7');
      expect(l.rptProductCount(1), '1 produit');
      expect(l.rptProductCount(4), '4 produits');
    });

    testWidgets('Arabic', (tester) async {
      final l = await load(tester, 'ar');
      expect(l.rptTitleSalesByProduct, 'المبيعات حسب المنتج');
      expect(l.rptTitleStockReport, 'تقرير المخزون');
      expect(l.rptColUom, 'وحدة القياس');
      expect(l.rptColCredit, 'دائن');
      expect(l.rptPageOf('2', '7'), contains('2'));
      // Arabic pluralises on six categories, not two.
      expect(l.rptProductCount(2), 'منتجان');
      expect(l.rptProductCount(3), contains('منتجات'));
    });

    testWidgets('English is the text the reports printed before', (
      tester,
    ) async {
      final l = await load(tester, 'en');
      expect(l.rptTitleSalesByProduct, 'SALES BY PRODUCT');
      expect(l.rptTitleDiscountsGranted, 'DISCOUNTS GRANTED (AFTER TAX)');
      expect(l.rptColUom, 'UOM');
      expect(l.rptProductCount(1), '1 product');
      expect(l.rptProductCount(9), '9 products');
    });
  });

  test('no report column name can break a CSV row', () {
    // Column names go into the export as one comma-separated line. A French or
    // Arabic name containing a comma or a quote would shift every column in the
    // sheet, so _csvHeader quotes each field — this asserts the inputs that
    // quoting has to survive stay sane, and that none is blank.
    for (final locale in ['en', 'fr', 'ar']) {
      arb(locale).forEach((key, value) {
        if (!key.startsWith('rptCol')) return;
        expect(value.trim(), isNotEmpty, reason: '$key in $locale is blank');
        expect(
          value,
          isNot(contains('\n')),
          reason: '$key in $locale has a newline, which ends the CSV row early',
        );
      });
    }
  });

  group('the report PDFs route every run through printedText', () {
    // 🚨 The bug this catches, seen on paper 2026-08-29: the reports printed
    // Arabic with `pw.Text`, which gets no textDirection, so the `pdf` package
    // skipped its shaping + bidi pass entirely. Every Arabic heading came out
    // as isolated letters running backwards (تقرير المخزون → نوزخملا ريرقت).
    // The machinery to prevent it already existed in printer/printed_text.dart
    // and is covered by printed_document_language_test.dart — the reports just
    // never used it. Nothing else can see this: it compiles, it analyzes, it
    // renders a valid PDF, and every other test passes.
    String source(String path) => File(path).readAsStringSync();

    const reports = 'lib/reports/reports_screen.dart';
    const stock = 'lib/stock/stock_screen.dart';

    // Comments in these files legitimately mention the widget by name.
    int uses(String src, String needle) => RegExp(RegExp.escape(needle))
        .allMatches(src.replaceAll(RegExp(r'^\s*//.*$', multiLine: true), ''))
        .length;

    test('no bare pw.Text survives in either file', () {
      for (final path in [reports, stock]) {
        expect(uses(source(path), 'pw.Text('), 0,
            reason: '$path still builds text the pdf package will not shape — '
                'use printedText() from printer/printed_text.dart');
      }
    });

    test('no bare pw.RichText survives — a TextSpan carries no direction', () {
      for (final path in [reports, stock]) {
        expect(uses(source(path), 'pw.RichText('), 0,
            reason: '$path still uses RichText; split it into two printedText '
                'runs so each picks its own script direction');
      }
    });

    test('every report table builds its cells as widgets', () {
      final src = source(reports);
      final tables = uses(src, 'pw.TableHelper.fromTextArray(');
      expect(tables, 36, reason: 'the report count changed — update this test');
      // fromTextArray renders a plain-string cell with a bare, direction-less
      // pw.Text; it uses a cell verbatim only when it already is a widget.
      expect(uses(src, 'cellBuilder:'), tables,
          reason: 'a table without a cellBuilder prints unshaped Arabic data');
      expect(uses(src, 'headers: _cells('), tables,
          reason: 'a table with plain-string headers prints unshaped Arabic '
              'column names');
    });

    test('the report styles name the Arabic face, not just the page theme', () {
      // styleForScript can only promote Arabic to the base font if the style
      // lists it in fontFallback; a style inheriting fonts from the theme
      // leaves that empty and the promotion silently does nothing.
      expect(source(reports), contains('fontFallback: [bold ? arabicBold : arabic]'));
      expect(source(stock), contains('fontFallback: [isBold ? arabicBold : arabic]'));
    });

    test('no printed label bakes its own colon', () {
      // 🚨 A colon is a NEUTRAL character. Written into an Arabic label run the
      // bidi pass moves it to that run's visual LEFT end, so the pair printed
      // as `:الشركة FUTUR3` — the colon detached on the far side of the label
      // instead of introducing the value. It has to be its own run, which is
      // what _hdrPair / _sheetPair / printedPair's `separator` do.
      const printed = [
        reports,
        stock,
        'lib/printer/receipt_printer_service.dart',
        'lib/printer/invoice_pdf_service.dart',
      ];
      for (final path in printed) {
        final offenders = RegExp(r'\$\{l(10n)?\.\w+\}:')
            .allMatches(source(path))
            .map((m) => m.group(0))
            .toSet();
        expect(offenders, isEmpty,
            reason: '$path builds a label with the colon inside the run; pass '
                'the label alone and let the helper add the separator');
      }
    });

    test('no label and value share a single run', () {
      // The other half of the same bug: one run holding an Arabic label and a
      // Latin value comes out with the Latin reversed
      // (ilyasschah18@gmail.com -> moc.liamg@81hahcssayli).
      final offenders = RegExp(r"printedText\(\s*'\$\{l\.\w+\}[^']*\$")
          .allMatches(source(reports))
          .map((m) => m.group(0))
          .toList();
      expect(offenders, isEmpty,
          reason: 'split these into two runs with _hdrPair');
    });
  });
}
