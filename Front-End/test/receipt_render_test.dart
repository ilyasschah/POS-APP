// Builds a real receipt, both layout directions, in both languages.
//
// 🚨 Why this exists: FOUR consecutive Arabic bugs shipped on this document
// (backlog item 7) — missing font fallback, unshaped text, the Arabic face left
// as a fallback instead of the base, and a `copyWith(font:)` that was silently
// a no-op. Every one of them type-checked, passed every unit test, and was
// wrong only on paper. Nothing in the suite had ever executed the receipt
// builder end to end.
//
// This cannot assert that Arabic *reads* correctly — that needs eyes on a page,
// and the rendered PDFs were reviewed by hand. What it does guarantee is that
// the builder runs, in every configuration, and produces a real document. A
// crash or a blank page in the RTL path now fails here instead of at a till.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/customer/customer_model.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';
import 'package:pos_app/reports/z_report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> receiptBytes({
    required String language,
    required bool rightToLeft,
    bool isGuestCheck = false,
  }) async {
    final pdf = await ReceiptPrinterService().buildCartReceipt(
      company: Company(
        id: 25,
        name: 'FUTUR3',
        address: 'Maroc, CASABLANCA, rouches noires, CHEMINAUX 9 RUE 1 BLOCK 6',
        phoneNumber: '0669097409',
        taxNumber: '27272727',
      ),
      cashier: User(
        id: 9,
        companyId: 25,
        firstName: 'ilyass',
        lastName: 'chah',
        accessLevel: 0,
        isEnabled: true,
      ),
      customer: Customer(id: 1, code: 'C000', name: 'Walk-in Customer'),
      orderNumber: 'POS1-200-000014',
      documentNumber: 'POS1-200-000014',
      printTime: DateTime(2026, 8, 16, 13),
      items: [
        CartItem(
          cartItemId: 'a',
          posOrderId: 0,
          productId: 58,
          quantity: 1,
          price: 105,
          productName: 'Test2',
          measurementUnit: 'kg',
          appliedTaxes: const [],
        ),
      ],
      subtotal: 75,
      totalDiscount: 0,
      totalTax: 15,
      grandTotal: 90,
      currencySymbol: 'MAD',
      paymentTypeName: 'Espèces',
      amountPaid: 90,
      isGuestCheck: isGuestCheck,
      roleSettings: {
        ...kSettingDefaults,
        SettingKeys.language: language,
        'Receipt.RightToLeft': '$rightToLeft',
      },
    );
    return (await pdf.save()).length;
  }

  for (final language in ['en', 'fr', 'ar']) {
    for (final rtl in [false, true]) {
      test('receipt builds in $language, RightToLeft=$rtl', () async {
        // A page that failed to lay out still "saves" — as a near-empty file.
        expect(await receiptBytes(language: language, rightToLeft: rtl),
            greaterThan(2000));
      });
    }
  }

  test('the guest check (addition) builds too', () async {
    expect(
      await receiptBytes(language: 'ar', rightToLeft: false, isGuestCheck: true),
      greaterThan(2000),
    );
  });

  test('an Arabic receipt is heavier than an English one', () async {
    // Proves the Arabic FACE is actually embedded rather than the text silently
    // falling back to Latin metrics — the shape the first bug took.
    final en = await receiptBytes(language: 'en', rightToLeft: false);
    final ar = await receiptBytes(language: 'ar', rightToLeft: false);
    expect(ar, greaterThan(en));
  });

  group('the Z-report follows the printer configuration', () {
    // 🚨 It used to hardcode roll80, a 10pt margin and the bundled Latin face,
    // and print through `Printing.layoutPdf` — so paper size, margins, font,
    // font scale, Copies, the chosen printer and RTL were ALL ignored. A 58mm
    // till printed an 80mm layout.
    Future<int> zBytes(Map<String, String> extra) async {
      final pdf = await ReceiptPrinterService().buildZReport(
        ZReportModel(
          id: 1,
          companyId: 25,
          number: 1,
          dateCreated: DateTime(2026, 8, 16, 22, 7, 15),
          fromDocumentId: 1,
          toDocumentId: 16,
          totalSales: 91455,
          totalReturns: 0,
          totalCashIn: 0,
          totalCashOut: 0,
          discountsGranted: 0,
          taxableTotal: 91320,
          totalTax: 135,
          grandTotal: 91455,
          documentCount: 16,
          paymentSummaries: const [],
        ),
        'MAD',
        roleSettings: {...kSettingDefaults, SettingKeys.language: 'ar', ...extra},
      );
      return (await pdf.save()).length;
    }

    test('58mm and 80mm produce different documents', () async {
      final narrow = await zBytes({'Receipt.PaperSize': '58mm'});
      final wide = await zBytes({'Receipt.PaperSize': '80mm'});
      expect(narrow, isNot(wide), reason: 'paper size was being ignored');
    });

    test('right-to-left produces a different document', () async {
      final ltr = await zBytes({'Receipt.RightToLeft': 'false'});
      final rtl = await zBytes({'Receipt.RightToLeft': 'true'});
      expect(ltr, isNot(rtl));
    });

    test('the font scale is applied', () async {
      final small = await zBytes({'Receipt.FontSize': '80'});
      final big = await zBytes({'Receipt.FontSize': '140'});
      expect(small, isNot(big));
    });
  });
}
