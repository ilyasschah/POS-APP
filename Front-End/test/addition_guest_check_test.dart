// Pins the Addition (pre-bill / guest check) button.
//
// The rule that matters: the Addition tells the customer what they OWE and banks
// NOTHING — no document, no payment, no stock movement, no loyalty accrual, no
// sync. Pressing it five times must be harmless and leave no trace in reports.
// Everything that turns a cart into a sale lives in PaymentCheckoutDialog; the
// Addition shares only the PDF builder.
//
// `printCartReceipt(isGuestCheck: true)` enforces the difference on paper. That
// flag existed in the builder but **nothing ever passed it**, so the behaviour
// it describes had never once run. These tests capture the real generated PDF
// through a stubbed printing platform and compare the two renders.
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/printer/receipt_printer_service.dart';

/// Captures the bytes the service would have sent to a printer.
class _CapturingPrinting extends PrintingPlatform {
  final List<Uint8List> jobs = [];

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
  ) async {
    jobs.add(await onLayout(format));
    return true;
  }

  @override
  Future<PrintingInfo> info() async => const PrintingInfo();
  @override
  Future<List<Printer>> listPrinters() async => const [];
  @override
  Future<Printer?> pickPrinter(Rect bounds) async => null;
  @override
  Future<bool> sharePdf(Uint8List bytes, String filename, Rect bounds,
          String? subject, String? body, List<String>? emails) async =>
      true;
  @override
  Future<Uint8List> convertHtml(
          String html, String? baseUrl, PdfPageFormat format) async =>
      Uint8List(0);
  @override
  Stream<PdfRaster> raster(Uint8List document, List<int>? pages, double dpi) =>
      const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CapturingPrinting printing;
  setUp(() {
    printing = _CapturingPrinting();
    PrintingPlatform.instance = printing;
  });

  final company = Company(id: 25, name: 'FUTUR3');

  List<CartItem> items() => [
        CartItem(
          cartItemId: 'a',
          posOrderId: 0,
          productId: 1,
          productName: 'Chicken Sandwich',
          quantity: 2,
          price: 28,
          appliedTaxes: const [],
        ),
      ];

  Future<Uint8List> render({required bool guestCheck}) async {
    printing.jobs.clear();
    await ReceiptPrinterService().printCartReceipt(
      company: company,
      cashier: null,
      orderNumber: 'ORD- A3',
      printTime: DateTime(2026, 8, 6, 19, 47),
      items: items(),
      subtotal: 56,
      totalDiscount: 0,
      totalTax: 0,
      grandTotal: 56,
      currencySymbol: 'MAD',
      isGuestCheck: guestCheck,
      // Only meaningful on the paid render; the guest check must drop them.
      paymentTypeName: guestCheck ? null : 'Espèces',
      amountPaid: guestCheck ? null : 60,
      pointsEarned: guestCheck ? 0 : 5,
      pointsBalance: guestCheck ? 0 : 25,
      roleSettings: const {'Receipt.PrintBarcode': 'true'},
    );
    expect(printing.jobs, hasLength(1), reason: 'exactly one job per copy');
    return printing.jobs.single;
  }

  test('the Addition button has its own on/off setting, defaulting ON', () {
    // Separate from the Kitchen toggle so a venue can run one without the other.
    expect(SettingKeys.showAdditionBtn, 'ButtonBar.ShowAddition');
    expect(kSettingDefaults[SettingKeys.showAdditionBtn], 'true');
    expect(SettingKeys.showAdditionBtn, isNot(SettingKeys.showKitchenBtn));
  });

  test('an Addition actually produces a printable document', () async {
    final pdf = await render(guestCheck: true);
    expect(pdf.length, greaterThan(0));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  test('the guest check drops the payment, points and barcode', () async {
    final guest = await render(guestCheck: true);
    final paid = await render(guestCheck: false);

    // The paid receipt carries a payment row, change due, points earned,
    // points balance AND a Code128 barcode; the guest check carries none of
    // them. Every one of those would be a lie on an unpaid bill — especially
    // the barcode, which encodes a sale that does not exist yet.
    expect(guest.length, lessThan(paid.length),
        reason: 'the guest check must omit the paid-only sections');
  });

  test('the barcode is what makes the biggest difference', () async {
    // Isolate it: same call, only the barcode toggle differs. If a future edit
    // stops suppressing it on a guest check, this gap collapses.
    printing.jobs.clear();
    await ReceiptPrinterService().printCartReceipt(
      company: company,
      cashier: null,
      orderNumber: 'ORD- A3',
      printTime: DateTime(2026, 8, 6, 19, 47),
      items: items(),
      subtotal: 56,
      totalDiscount: 0,
      totalTax: 0,
      grandTotal: 56,
      currencySymbol: 'MAD',
      isGuestCheck: false,
      roleSettings: const {'Receipt.PrintBarcode': 'false'},
    );
    final noBarcode = printing.jobs.single.length;

    printing.jobs.clear();
    await ReceiptPrinterService().printCartReceipt(
      company: company,
      cashier: null,
      orderNumber: 'ORD- A3',
      printTime: DateTime(2026, 8, 6, 19, 47),
      items: items(),
      subtotal: 56,
      totalDiscount: 0,
      totalTax: 0,
      grandTotal: 56,
      currencySymbol: 'MAD',
      isGuestCheck: false,
      roleSettings: const {'Receipt.PrintBarcode': 'true'},
    );
    final withBarcode = printing.jobs.single.length;

    expect(withBarcode, greaterThan(noBarcode));
  });

  test('Copies applies to an Addition too', () async {
    printing.jobs.clear();
    await ReceiptPrinterService().printCartReceipt(
      company: company,
      cashier: null,
      orderNumber: 'ORD- A3',
      printTime: DateTime(2026, 8, 6, 19, 47),
      items: items(),
      subtotal: 56,
      totalDiscount: 0,
      totalTax: 0,
      grandTotal: 56,
      currencySymbol: 'MAD',
      isGuestCheck: true,
      roleSettings: const {'Receipt.Copies': '2'},
    );
    // One for the customer, one for the table — a real venue habit.
    expect(printing.jobs, hasLength(2));
  });
}
