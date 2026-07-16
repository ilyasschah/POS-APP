import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/printer/pdf_file_name.dart';

void main() {
  group('pdfSafeName', () {
    test('strips every character Windows rejects in a file name', () {
      // ':' is the one that matters most — a clock reads HH:MM.
      expect(pdfSafeName(r'a\b/c:d*e?f"g<h>i|j'), 'a-b-c-d-e-f-g-h-i-j');
    });

    test('keeps characters that are legal, including # and spaces', () {
      expect(pdfSafeName('TALABIA #008'), 'TALABIA #008');
    });

    test('drops a trailing dot or space, which Windows also rejects', () {
      expect(pdfSafeName('Order 1. '), 'Order 1');
    });

    test('never returns an empty name', () {
      expect(pdfSafeName('   '), 'Print');
      expect(pdfSafeName('///'), isNot(isEmpty));
    });
  });

  group('orderPdfName', () {
    test('is the order name plus HH-mm of the print time', () {
      expect(
        orderPdfName('TALABIA #008', DateTime(2026, 7, 16, 14, 32)),
        'TALABIA #008_14-32',
      );
    });

    test('zero-pads the clock so names sort', () {
      expect(
        orderPdfName('ORD- A7', DateTime(2026, 7, 16, 9, 5)),
        'ORD- A7_09-05',
      );
    });

    test('sanitizes an operator-typed order name', () {
      expect(
        orderPdfName('Table 3/4', DateTime(2026, 7, 16, 14, 32)),
        'Table 3-4_14-32',
      );
    });
  });

  test('documentPdfName is the bare document number', () {
    expect(documentPdfName('POS1-200-000004'), 'POS1-200-000004');
  });

  test('stockPdfName is INV-YYYY-MM-DD', () {
    expect(stockPdfName(DateTime(2026, 7, 16)), 'INV-2026-07-16');
  });

  group('reportPdfName', () {
    test('carries the report label and its date range', () {
      expect(
        reportPdfName(
            'Sales by Product', DateTime(2026, 7, 1), DateTime(2026, 7, 16)),
        'Sales by Product_2026-07-01_2026-07-16',
      );
    });

    test('collapses a single-day range to one date', () {
      expect(
        reportPdfName('Refunds', DateTime(2026, 7, 16, 0, 0),
            DateTime(2026, 7, 16, 23, 59)),
        'Refunds_2026-07-16',
      );
    });
  });

  test('no helper emits a .pdf extension — the platform appends it', () {
    final names = [
      orderPdfName('A1', DateTime(2026, 7, 16, 14, 32)),
      documentPdfName('POS1-200-000004'),
      stockPdfName(DateTime(2026, 7, 16)),
      reportPdfName('Refunds', DateTime(2026, 7, 1), DateTime(2026, 7, 16)),
    ];
    for (final n in names) {
      expect(n, isNot(endsWith('.pdf')), reason: '"$n" would print as .pdf.pdf');
    }
  });
}
