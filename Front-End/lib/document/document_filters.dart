import 'package:flutter/material.dart';

import 'package:pos_app/document/document_model.dart';

/// What a filter narrows on. One active filter per kind: picking a second
/// customer replaces the first rather than asking for documents belonging to
/// two customers at once, which is not a question anyone asks of this screen.
enum DocumentFilterKind {
  number,
  reference,
  customer,
  user,
  docType,
  warehouse,
  paidStatus,
  period,
}

/// One applied filter — what it narrows on, what to call it in the chip, and
/// the value to match against.
@immutable
class DocumentFilter {
  const DocumentFilter({
    required this.kind,
    required this.label,
    required this.value,
    required this.icon,
  });

  final DocumentFilterKind kind;

  /// Already resolved for display ("Espèces", "ilyass chah") — the chip shows
  /// this verbatim, so the caller does the id → name lookup once, where the
  /// lists are already in hand.
  final String label;

  /// `int` for an id, `String` for a text match, `DateTimeRange` for a period.
  final Object value;

  final IconData icon;
}

/// Everything the Document Explorer is currently filtering on: the free-text
/// query plus the applied filter chips.
///
/// Immutable and self-matching on purpose — the screen holds one of these and
/// asks it whether a document belongs, instead of scattering eight nullable
/// fields and a `where` clause that has to be kept in step with them.
@immutable
class DocumentFilters {
  const DocumentFilters({this.query = '', this.filters = const []});

  /// Free text typed beside the chips. Matches document number, reference or
  /// customer name — the three things anyone types into this screen.
  final String query;

  final List<DocumentFilter> filters;

  bool get isEmpty => query.trim().isEmpty && filters.isEmpty;

  DocumentFilter? of(DocumentFilterKind kind) {
    for (final f in filters) {
      if (f.kind == kind) return f;
    }
    return null;
  }

  bool has(DocumentFilterKind kind, Object value) =>
      of(kind)?.value == value;

  /// Adds or REPLACES the filter of that kind, keeping insertion order stable
  /// so chips do not jump around as they are edited.
  DocumentFilters with_(DocumentFilter filter) {
    final next = [
      for (final f in filters)
        if (f.kind == filter.kind) filter else f,
    ];
    if (!next.any((f) => f.kind == filter.kind)) next.add(filter);
    return DocumentFilters(query: query, filters: next);
  }

  DocumentFilters without(DocumentFilterKind kind) => DocumentFilters(
        query: query,
        filters: filters.where((f) => f.kind != kind).toList(),
      );

  /// Toggles a filter off when the same value is picked again — the menu marks
  /// it with a check, so tapping it a second time has to undo it.
  DocumentFilters toggle(DocumentFilter filter) =>
      has(filter.kind, filter.value) ? without(filter.kind) : with_(filter);

  DocumentFilters withQuery(String value) =>
      DocumentFilters(query: value, filters: filters);

  /// Does this document survive every active filter?
  ///
  /// Ported verbatim from the old eight-dropdown panel, including the
  /// end-exclusive day boundary on the period and the silent skip on an
  /// unparseable date.
  bool matches(Document d) {
    for (final f in filters) {
      switch (f.kind) {
        case DocumentFilterKind.number:
          if (!_contains(d.number, f.value as String)) return false;
        case DocumentFilterKind.reference:
          if (!_contains(d.referenceDocumentNumber, f.value as String)) {
            return false;
          }
        case DocumentFilterKind.customer:
          if (d.customerId != f.value as int) return false;
        case DocumentFilterKind.user:
          if (d.userId != f.value as int) return false;
        case DocumentFilterKind.docType:
          if (d.documentTypeId != f.value as int) return false;
        case DocumentFilterKind.warehouse:
          if (d.warehouseId != f.value as int) return false;
        case DocumentFilterKind.paidStatus:
          if (d.paidStatus != f.value as int) return false;
        case DocumentFilterKind.period:
          if (!_inPeriod(d, f.value as DateTimeRange)) return false;
      }
    }

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return _contains(d.number, q) ||
        _contains(d.referenceDocumentNumber, q) ||
        _contains(d.customerName, q);
  }

  static bool _contains(String? haystack, String needle) =>
      (haystack ?? '').toLowerCase().contains(needle.toLowerCase());

  static bool _inPeriod(Document d, DateTimeRange range) {
    try {
      final dt = DateTime.parse(d.date);
      // End of the selected day, not its midnight — a range of 1–5 August has
      // to include a sale rung up at 17:40 on the 5th.
      final end = range.end.add(const Duration(days: 1));
      return !dt.isBefore(range.start) && dt.isBefore(end);
    } catch (_) {
      // An unparseable date never removes a row: the operator would have no way
      // to find it again.
      return true;
    }
  }
}
