import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/reports/sales_history_screen.dart';

/// The sales-history "POS" column used to render `doc.warehouseName`, which is
/// a different thing entirely — a sale rung on POS1 sourced from the "Main"
/// warehouse showed "Main". The column now reads the terminal name off the
/// document number's own prefix, so it stays correct for documents pulled from
/// other terminals too.
void main() {
  group('posNameFromDocumentNumber', () {
    test('reads the terminal prefix off a checkout document number', () {
      expect(posNameFromDocumentNumber('POS1-200-000026', 'ORDER #001'), 'POS1');
      expect(posNameFromDocumentNumber('CAISSE1-200-000045', 'ORD- A5'),
          'CAISSE1');
    });

    test('a manual document has no terminal, even though its number looks alike',
        () {
      // Server-numbered (`/Document/GetNextNumber`). Same PREFIX-ddd-dddddd
      // shape as a checkout number, so only orderNumber can tell them apart —
      // matching on the shape alone would invent a terminal called "26".
      expect(posNameFromDocumentNumber('26-100-000001', null), isNull);
      expect(posNameFromDocumentNumber('26-100-000001', ''), isNull);
    });

    test('an unrecognised number yields no terminal rather than a guess', () {
      expect(posNameFromDocumentNumber('DOC-261234567890', 'ORD- A1'), isNull);
      expect(posNameFromDocumentNumber('(Pending sync)', 'ORD- A1'), isNull);
      expect(posNameFromDocumentNumber('—', 'ORD- A1'), isNull);
    });

    test('the prefix keeps the sanitized device-name shape', () {
      // _sanitizeDevicePrefix: uppercase A-Z0-9, max 12 — a lowercase or
      // over-long prefix cannot have been issued by this app.
      expect(posNameFromDocumentNumber('pos1-200-000026', 'ORD- A1'), isNull);
      expect(
        posNameFromDocumentNumber('THIRTEENCHARS-200-000026', 'ORD- A1'),
        isNull,
      );
      expect(
        posNameFromDocumentNumber('TWELVECHARSX-200-000026', 'ORD- A1'),
        'TWELVECHARSX',
      );
    });
  });
}
