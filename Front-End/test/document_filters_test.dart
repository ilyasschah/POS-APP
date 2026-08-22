// The Document Explorer's search state.
//
// This is the whole contract of the unified search bar: a chip is only honest
// if the row set behind it actually narrows the way the chip says. A filter
// that silently matches nothing hides documents the operator knows exist, and
// one that silently matches everything is a chip that lies.
import 'package:flutter/material.dart' show DateTimeRange, Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/document/document_filters.dart';
import 'package:pos_app/document/document_model.dart';

void main() {
  Document doc({
    int id = 1,
    String number = 'POS1-200-000025',
    int customerId = 7,
    String? customerName = 'Cafe Atlas',
    int userId = 9,
    int documentTypeId = 2,
    int warehouseId = 1,
    int paidStatus = 1,
    String date = '2026-08-22T14:30:00',
    String? reference = 'BC-4471',
  }) =>
      Document(
        id: id,
        number: number,
        userId: userId,
        customerId: customerId,
        customerName: customerName,
        companyId: 25,
        documentTypeId: documentTypeId,
        warehouseId: warehouseId,
        date: date,
        total: 84,
        referenceDocumentNumber: reference,
        paidStatus: paidStatus,
      );

  DocumentFilter filter(DocumentFilterKind kind, Object value) => DocumentFilter(
        kind: kind,
        label: '$value',
        value: value,
        icon: Icons.circle,
      );

  group('no filters', () {
    test('everything matches', () {
      const filters = DocumentFilters();
      expect(filters.isEmpty, isTrue);
      expect(filters.matches(doc()), isTrue);
    });
  });

  group('free-text query', () {
    test('matches number, reference or customer, case-insensitively', () {
      expect(const DocumentFilters(query: 'pos1').matches(doc()), isTrue);
      expect(const DocumentFilters(query: 'bc-44').matches(doc()), isTrue);
      expect(const DocumentFilters(query: 'atlas').matches(doc()), isTrue);
      expect(const DocumentFilters(query: 'nothing').matches(doc()), isFalse);
    });

    test('whitespace alone is not a filter', () {
      const filters = DocumentFilters(query: '   ');
      expect(filters.isEmpty, isTrue);
      expect(filters.matches(doc(number: 'X', customerName: null,
              reference: null)),
          isTrue);
    });

    test('a document with no reference or customer still matches on number',
        () {
      final d = doc(customerName: null, reference: null);
      expect(const DocumentFilters(query: '000025').matches(d), isTrue);
      expect(const DocumentFilters(query: 'atlas').matches(d), isFalse);
    });
  });

  group('chip filters', () {
    test('each kind narrows on its own field', () {
      const empty = DocumentFilters();
      expect(
        empty.with_(filter(DocumentFilterKind.customer, 7)).matches(doc()),
        isTrue,
      );
      expect(
        empty.with_(filter(DocumentFilterKind.customer, 8)).matches(doc()),
        isFalse,
      );
      expect(
        empty.with_(filter(DocumentFilterKind.paidStatus, 0)).matches(doc()),
        isFalse,
      );
      expect(
        empty.with_(filter(DocumentFilterKind.warehouse, 1)).matches(doc()),
        isTrue,
      );
      expect(
        empty.with_(filter(DocumentFilterKind.user, 99)).matches(doc()),
        isFalse,
      );
      expect(
        empty.with_(filter(DocumentFilterKind.docType, 2)).matches(doc()),
        isTrue,
      );
    });

    test('number and reference chips are contains, not equals', () {
      const empty = DocumentFilters();
      expect(
        empty.with_(filter(DocumentFilterKind.number, '000025')).matches(doc()),
        isTrue,
      );
      expect(
        empty.with_(filter(DocumentFilterKind.reference, 'bc')).matches(doc()),
        isTrue,
        reason: 'a reference search is case-insensitive',
      );
    });

    test('filters compose — every one must hold', () {
      final filters = const DocumentFilters()
          .with_(filter(DocumentFilterKind.customer, 7))
          .with_(filter(DocumentFilterKind.paidStatus, 1));
      expect(filters.matches(doc()), isTrue);
      expect(filters.matches(doc(paidStatus: 0)), isFalse);
    });

    test('a second value of the same kind REPLACES the first', () {
      final filters = const DocumentFilters()
          .with_(filter(DocumentFilterKind.customer, 7))
          .with_(filter(DocumentFilterKind.customer, 8));

      expect(filters.filters, hasLength(1));
      expect(filters.matches(doc(customerId: 8)), isTrue);
      expect(filters.matches(doc(customerId: 7)), isFalse);
    });

    test('toggle removes the chip when the same value is picked again', () {
      final f = filter(DocumentFilterKind.paidStatus, 1);
      final on = const DocumentFilters().toggle(f);
      expect(on.filters, hasLength(1));
      expect(on.toggle(f).filters, isEmpty);
    });

    test('removing one chip leaves the others', () {
      final filters = const DocumentFilters()
          .with_(filter(DocumentFilterKind.customer, 7))
          .with_(filter(DocumentFilterKind.user, 9))
          .without(DocumentFilterKind.customer);

      expect(filters.of(DocumentFilterKind.customer), isNull);
      expect(filters.of(DocumentFilterKind.user), isNotNull);
    });
  });

  group('period', () {
    DocumentFilters period(DateTime start, DateTime end) =>
        const DocumentFilters().with_(DocumentFilter(
          kind: DocumentFilterKind.period,
          label: 'range',
          value: DateTimeRange(start: start, end: end),
          icon: Icons.date_range,
        ));

    test('includes a sale rung up late on the LAST day of the range', () {
      // The end date is a day, not a midnight — 17:40 on the 22nd is inside a
      // range that ends on the 22nd.
      final filters = period(DateTime(2026, 8, 1), DateTime(2026, 8, 22));
      expect(filters.matches(doc(date: '2026-08-22T17:40:00')), isTrue);
    });

    test('excludes the day after and the day before', () {
      final filters = period(DateTime(2026, 8, 1), DateTime(2026, 8, 22));
      expect(filters.matches(doc(date: '2026-08-23T00:05:00')), isFalse);
      expect(filters.matches(doc(date: '2026-07-31T23:55:00')), isFalse);
    });

    test('a single-day range matches that day', () {
      final filters = period(DateTime(2026, 8, 22), DateTime(2026, 8, 22));
      expect(filters.matches(doc(date: '2026-08-22T09:00:00')), isTrue);
    });

    test('an unparseable date is never filtered out', () {
      final filters = period(DateTime(2026, 8, 1), DateTime(2026, 8, 22));
      expect(filters.matches(doc(date: 'not-a-date')), isTrue,
          reason: 'hiding it would leave the operator no way to find it');
    });
  });

  group('query and chips together', () {
    test('both must hold', () {
      final filters = const DocumentFilters(query: 'atlas')
          .with_(filter(DocumentFilterKind.paidStatus, 1));

      expect(filters.matches(doc()), isTrue);
      expect(filters.matches(doc(paidStatus: 0)), isFalse);
      expect(filters.matches(doc(customerName: 'Someone else')), isFalse);
    });

    test('withQuery keeps the chips', () {
      final filters = const DocumentFilters()
          .with_(filter(DocumentFilterKind.user, 9))
          .withQuery('inv');

      expect(filters.query, 'inv');
      expect(filters.of(DocumentFilterKind.user), isNotNull);
    });
  });
}
