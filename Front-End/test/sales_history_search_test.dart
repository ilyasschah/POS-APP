// The sales-history search bar's free text.
//
// The period, user and customer filters are server-side — Drift is asked for a
// narrower set. This is the half that runs on what came back, and it is the
// one that decides whether a sale the operator KNOWS exists shows up. A search
// that is too narrow reads as data loss on a screen people use to settle
// disputes with customers.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/reports/sales_history_screen.dart';

void main() {
  SalesHistoryDocument doc({
    String number = 'POS1-200-000025',
    String? customer = 'Cafe Atlas',
    String? order = 'CMD-88',
    String? reference = 'BC-4471',
  }) =>
      SalesHistoryDocument(
        id: 1,
        number: number,
        customerName: customer,
        orderNumber: order,
        referenceDocumentNumber: reference,
        date: '2026-08-22T14:30:00',
        stockDate: '2026-08-22T14:30:00',
        dateCreated: '2026-08-22T14:30:00',
        total: 84,
        totalBeforeTax: 70,
        taxTotal: 14,
        discount: 0,
        paidStatus: 1,
      );

  final rows = [
    doc(),
    doc(number: 'POS2-200-000031', customer: 'Walk-in', order: null,
        reference: null),
  ];

  test('an empty query returns everything, untouched', () {
    expect(salesHistorySearch(rows, ''), same(rows));
    expect(salesHistorySearch(rows, '   '), same(rows));
  });

  test('matches the document number', () {
    expect(salesHistorySearch(rows, '000025'), hasLength(1));
    expect(salesHistorySearch(rows, 'pos'), hasLength(2));
  });

  test('matches the customer, order number and external reference', () {
    // The old search was number-only, so looking a sale up by the customer who
    // is standing at the counter found nothing.
    expect(salesHistorySearch(rows, 'atlas').single.number, rows.first.number);
    expect(salesHistorySearch(rows, 'cmd-88'), hasLength(1));
    expect(salesHistorySearch(rows, 'bc-44'), hasLength(1));
  });

  test('is case-insensitive and ignores surrounding spaces', () {
    expect(salesHistorySearch(rows, '  ATLAS '), hasLength(1));
  });

  test('a row with null customer, order and reference still matches on number',
      () {
    final sparse = [doc(customer: null, order: null, reference: null)];
    expect(salesHistorySearch(sparse, '000025'), hasLength(1));
    expect(salesHistorySearch(sparse, 'atlas'), isEmpty);
  });

  test('no match returns empty rather than everything', () {
    expect(salesHistorySearch(rows, 'zzzz'), isEmpty);
  });

  group('split pane heights', () {
    test('a normal viewport splits by the fraction', () {
      final split = salesHistorySplit(800, 0.55);

      expect(split.master, greaterThan(0));
      expect(split.detail, greaterThan(0));
      // The two bodies, their two section headers and the handle account for
      // the WHOLE height: no leftover strip under the detail table.
      expect(
        split.master +
            split.detail +
            kSalesHistoryDividerHeight +
            kSalesHistorySectionHeaderHeight * 2,
        closeTo(800, 0.001),
      );
    });

    test('a keyboard-height viewport does not throw', () {
      // The crash: clamp(150, totalHeight - 150) with the bounds crossed. An
      // on-screen keyboard leaves roughly this much of the body.
      for (final height in [300.0, 250.0, 200.0, 150.0, 90.0, 40.0, 1.0]) {
        expect(() => salesHistorySplit(height, 0.55), returnsNormally,
            reason: 'a $height px body must still lay out');
      }
    });

    test('neither pane is ever negative', () {
      for (final height in [400.0, 200.0, 120.0, 60.0, 10.0]) {
        final split = salesHistorySplit(height, 0.55);
        expect(split.master, greaterThanOrEqualTo(0), reason: '$height');
        expect(split.detail, greaterThanOrEqualTo(0), reason: '$height');
      }
    });

    test('an extreme split fraction still leaves the other pane alive', () {
      expect(salesHistorySplit(800, 0.0).master, greaterThan(0),
          reason: 'the master pane keeps its minimum');
      expect(salesHistorySplit(800, 1.0).detail, greaterThanOrEqualTo(0));
    });

    test('a zero or non-finite height collapses instead of throwing', () {
      expect(salesHistorySplit(0, 0.55), (master: 0.0, detail: 0.0));
      expect(salesHistorySplit(double.nan, 0.55), (master: 0.0, detail: 0.0));
      expect(
          salesHistorySplit(double.infinity, 0.55), (master: 0.0, detail: 0.0));
    });
  });
}
