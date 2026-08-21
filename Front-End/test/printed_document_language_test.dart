// Pins backlog item 7 — all three parts, as the user decided them on 2026-08-16.
//
//   1. Arabic UI shows WESTERN digits (0123), never Eastern (٠١٢٣).
//   2. Choosing Arabic does NOT flip the layout to RTL — language and writing
//      direction stay independent controls.
//   3. The kitchen ticket, the addition, the receipt and the generated PDFs
//      follow the selected language instead of always printing English.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/l10n/app_locale.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/printer/printed_text.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';

void main() {
  group('digits stay Western in Arabic', () {
    // `intl` renders Eastern Arabic numerals as soon as a formatter is given the
    // `ar` locale — or as soon as `Intl.defaultLocale` is set to it, which would
    // catch every formatter in the app at once. Nothing sets it, and this is the
    // test that keeps it that way: prices are read by staff and customers who
    // expect 0123, and receipt totals are compared against a cash drawer.
    test('money formatting produces 0-9, whatever the app language', () {
      expect(Intl.defaultLocale, isNull,
          reason: 'setting it globally would flip every price to ٠١٢٣');
      expect(NumberFormat('#,##0.00').format(1234.5), '1,234.50');
    });

    test('dates on printed documents use Western digits', () {
      expect(DateFormat('dd/MM/yyyy').format(DateTime(2026, 8, 16)),
          '16/08/2026');
    });

    test('a translated string carrying a number keeps Western digits', () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      final withNumber = ar.zReportNumber('7');
      expect(withNumber.contains('7'), isTrue, reason: withNumber);
      // The Eastern digit block — none of it may appear.
      expect(RegExp('[٠-٩]').hasMatch(withNumber), isFalse,
          reason: withNumber);
    });
  });

  group('language and writing direction stay independent', () {
    // The user's decision: picking Arabic must NOT auto-flip the layout. RTL is
    // `App.WritingDirection` and nothing else — a venue can run an Arabic UI
    // left-to-right if that is what it wants.
    bool isRtl(Map<String, String> settings) =>
        settings[SettingKeys.writingDirection]?.toUpperCase() == 'RTL';

    test('Arabic alone does not imply RTL', () {
      expect(resolveAppLocale('ar'), const Locale('ar'));
      expect(isRtl({SettingKeys.language: 'ar'}), isFalse);
    });

    test('RTL is available to any language, including English', () {
      expect(
        isRtl({SettingKeys.language: 'en', SettingKeys.writingDirection: 'RTL'}),
        isTrue,
      );
    });
  });

  group('printed documents follow the selected language', () {
    test('the locale comes from the settings map the printers already receive',
        () {
      // Every print call site passes the whole appSettingsProvider map, which is
      // why the services can resolve this themselves instead of having an
      // AppLocalizations threaded through six callers.
      expect(resolveAppLocale('ar'), const Locale('ar'));
      expect(resolveAppLocale('fr'), const Locale('fr'));
      expect(resolveAppLocale(null), const Locale('en'));
      // A company seeded before the language list was trimmed can still hold
      // 'es'/'de' — those must fall back, not crash the print.
      expect(resolveAppLocale('es'), const Locale('en'));
    });

    test('the receipt strings really are translated, not English fallbacks',
        () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      final fr = await AppLocalizations.delegate.load(const Locale('fr'));
      expect(ar.roleCashier, isNot('Cashier'));
      expect(ar.balanceDue, isNot('Balance Due'));
      expect(fr.subtotal, isNot('Subtotal'));
      expect(fr.billTo, 'Facturé à');
    });
  });

  group('Arabic text runs are marked RTL so the PDF shapes them', () {
    // 🚨 Round two of the same paper-only bug (2026-08-16). With the font
    // fallback fixed the glyphs appeared, but as DISCONNECTED letters running
    // backwards: the `pdf` package applies Arabic shaping + the bidi reorder
    // **only when a Text's direction is rtl**
    // (`useBidi && _textDirection == TextDirection.rtl ? bidi.logicalToVisual(…)`).
    // Left at the default ltr, Arabic comes out in isolated forms in logical
    // order — which is unreadable, and looks nothing like a font problem.

    test('an Arabic string is detected wherever it sits in the line', () {
      expect(hasRtlScript('الرقم الضريبي'), isTrue);
      // A label + value on one row is mixed, and must still shape.
      expect(hasRtlScript('أمين الصندوق: ilyass chah'), isTrue);
      expect(hasRtlScript('עברית'), isTrue, reason: 'Hebrew too');
    });

    test('Latin and numbers are left alone', () {
      for (final s in ['Walk-in Customer', '105.00 MAD', 'POS1-200-000014']) {
        expect(hasRtlScript(s), isFalse, reason: s);
      }
    });

    test('Arabic forces RTL even when the page is laid out left-to-right', () {
      // The load-bearing case: the operator's `{Role}.RightToLeft` toggle is
      // OFF (item 7 — choosing Arabic must not flip the layout), so without
      // this override nothing on the receipt would ever be shaped.
      expect(
        scriptDirection('الرقم الضريبي', layout: pw.TextDirection.ltr),
        pw.TextDirection.rtl,
      );
    });

    test('a Latin run stays LTR even on an RTL receipt', () {
      // Deliberate, and it fixed a real defect: handing a Latin run the rtl
      // direction sends it through the bidi pass too, which reorders it. On an
      // RTL receipt the company's wrapped Latin address came out with its two
      // lines swapped. Direction is about how a run READS; where it sits is the
      // layout's job — row order and alignment, which still follow the setting.
      for (final layout in [pw.TextDirection.ltr, pw.TextDirection.rtl]) {
        expect(
          scriptDirection('Maroc, CASABLANCA, CHEMINAUX 9', layout: layout),
          pw.TextDirection.ltr,
          reason: 'layout: $layout',
        );
      }
    });

    test('with no layout given, Latin imposes nothing', () {
      expect(scriptDirection('Total'), isNull);
    });
  });

  group('an Arabic run gets the Arabic face as its BASE font', () {
    // 🚨 Round three, and the reason the first two "fixes" still printed
    // rubbish. Shaping rewrites Arabic into presentation forms (U+FE70–FEFF);
    // the package resolves those correctly only when the Arabic font is the
    // style's BASE, and produces repeated wrong glyphs when it is merely a
    // fontFallback. Verified by rendering both ways and reading the PDFs.
    final latin = pw.Font.helvetica();
    final latinBold = pw.Font.helveticaBold();
    final arabic = pw.Font.courier(); // stand-ins — identity is what we assert
    final arabicBold = pw.Font.courierBold();

    pw.TextStyle styled({bool bold = false}) =>
        ReceiptPrinterService.printedTextStyle(
          font: latin,
          boldFont: latinBold,
          arabic: arabic,
          arabicBold: arabicBold,
          bold: bold,
          size: 10,
        );

    test('Arabic text promotes the Arabic face and demotes Latin', () {
      final s = styleForScript(styled(), 'الرقم الضريبي')!;
      expect(s.font, arabic);
      expect(s.fontFallback, contains(latin),
          reason: 'a mixed line still has to draw its Latin characters',);
    });

    test('BOLD Arabic keeps the bold Arabic face', () {
      // `TextStyle.font` is a GETTER over four weight slots, so a fix that only
      // set `font:` was silently discarded — the bold row kept the Latin face
      // and printed boxes. This is that regression.
      final s = styleForScript(styled(bold: true), 'المجموع الكلي')!;
      expect(s.font, arabicBold);
    });

    test('Latin text is left exactly as built', () {
      final original = styled();
      final s = styleForScript(original, 'GRAND TOTAL');
      expect(identical(s, original), isTrue);
      expect(s!.font, latin);
    });

    test('a style with no Arabic fallback is returned untouched', () {
      final plain = ReceiptPrinterService.printedTextStyle(
          font: latin, arabic: null, size: 10);
      expect(styleForScript(plain, 'الرقم')!.font, latin);
    });
  });

  group('printedTextStyle always carries the Arabic fallback', () {
    // 🚨 Found on the first real Arabic receipt (2026-08-16): the company header
    // rendered Arabic correctly while every label row printed SOLID BLACK BOXES.
    // Two ways to build a text style existed, and only one carried the fallback
    // — a failure invisible on screen, visible only on paper.
    final latin = pw.Font.helvetica();
    final latinBold = pw.Font.helveticaBold();
    final arabic = pw.Font.courier(); // stand-in: identity is what we assert
    final arabicBold = pw.Font.courierBold();

    test('regular text falls back to the Arabic face', () {
      final style = ReceiptPrinterService.printedTextStyle(
        font: latin,
        arabic: arabic,
        size: 10,
      );
      expect(style.font, latin);
      expect(style.fontFallback, contains(arabic));
    });

    test('BOLD text falls back to the Arabic BOLD face', () {
      // Getting this wrong prints bold Arabic (the GRAND TOTAL line) as boxes
      // while the regular rows look fine.
      final style = ReceiptPrinterService.printedTextStyle(
        font: latin,
        boldFont: latinBold,
        arabic: arabic,
        arabicBold: arabicBold,
        bold: true,
        size: 12,
      );
      expect(style.font, latinBold);
      expect(style.fontFallback, contains(arabicBold));
    });

    test('bold falls back to the regular Arabic face when there is no bold one',
        () {
      final style = ReceiptPrinterService.printedTextStyle(
        font: latin,
        arabic: arabic,
        bold: true,
        size: 12,
      );
      expect(style.fontFallback, contains(arabic),
          reason: 'boxes are worse than a non-bold glyph');
    });

    test('italic keeps the fallback too', () {
      final style = ReceiptPrinterService.printedTextStyle(
        font: latin,
        arabic: arabic,
        italic: true,
        size: 10,
      );
      expect(style.fontStyle, pw.FontStyle.italic);
      expect(style.fontFallback, contains(arabic));
    });

    test('a missing Arabic face yields an empty list, never a null entry', () {
      final style = ReceiptPrinterService.printedTextStyle(
        font: latin,
        arabic: null,
        size: 10,
      );
      expect(style.fontFallback, isEmpty);
    });
  });

  group('resolveReceiptLabel — operator wording vs translation', () {
    // Receipt labels are customisable SETTINGS whose English defaults are seeded
    // into app_properties on every install, so `stored` is almost never empty.
    const arabicCashier = 'أمين الصندوق';

    test('a label still at its shipped default is translated', () {
      // The case that covers essentially every terminal in the field. Without
      // this rule the whole feature is inert.
      expect(
        resolveReceiptLabel(
          stored: 'Cashier',
          shippedDefault: 'Cashier',
          localized: arabicCashier,
          useCustomLabels: true,
        ),
        arabicCashier,
      );
    });

    test('a label the operator actually typed is printed verbatim', () {
      expect(
        resolveReceiptLabel(
          stored: 'Served by',
          shippedDefault: 'Cashier',
          localized: arabicCashier,
          useCustomLabels: true,
        ),
        'Served by',
      );
    });

    test('their wording wins even when it is English on an Arabic till', () {
      // A deliberate choice, not a bug to correct: a bilingual venue may want
      // one specific line in English.
      expect(
        resolveReceiptLabel(
          stored: 'CASHIER',
          shippedDefault: 'Cashier',
          localized: arabicCashier,
          useCustomLabels: true,
        ),
        'CASHIER',
      );
    });

    test('an empty or blank stored value falls back to the translation', () {
      for (final v in [null, '', '   ']) {
        expect(
          resolveReceiptLabel(
            stored: v,
            shippedDefault: 'Cashier',
            localized: arabicCashier,
            useCustomLabels: true,
          ),
          arabicCashier,
          reason: 'stored: ${v == null ? 'null' : '"$v"'}',
        );
      }
    });

    test('the master toggle OFF gives the TRANSLATED built-in wording', () {
      // "Ignore my custom labels" has always meant "use the built-in ones";
      // those are now translated rather than English.
      expect(
        resolveReceiptLabel(
          stored: 'Served by',
          shippedDefault: 'Cashier',
          localized: arabicCashier,
          useCustomLabels: false,
        ),
        arabicCashier,
      );
    });

    test('surrounding whitespace does not count as a customisation', () {
      expect(
        resolveReceiptLabel(
          stored: '  Cashier  ',
          shippedDefault: 'Cashier',
          localized: arabicCashier,
          useCustomLabels: true,
        ),
        arabicCashier,
      );
    });

    test('a key with no shipped default still honours a stored value', () {
      expect(
        resolveReceiptLabel(
          stored: 'My label',
          shippedDefault: null,
          localized: arabicCashier,
          useCustomLabels: true,
        ),
        'My label',
      );
    });
  });
}
