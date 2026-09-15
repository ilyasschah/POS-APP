import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../api/octopus_api.dart';
import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/document.dart';
import '../../models/document_lookups.dart';
import '../../models/product.dart';
import '../../models/stock.dart';
import '../../models/user.dart';
import '../auth/auth_controller.dart';
import 'document_draft.dart';

class DocumentsController extends AsyncController<List<SalesDocument>> {
  @override
  Future<List<SalesDocument>> fetch(CancelToken cancelToken) =>
      api.fetchDocuments(cancelToken: cancelToken);

  /// Deletes [document] and reloads the list. Errors propagate so the confirm
  /// dialog can show the server's own message.
  Future<void> deleteDocument(SalesDocument document) async {
    await api.deleteDocument(id: document.id);
    await load();
  }
}

final documentsProvider =
    NotifierProvider<DocumentsController, ScreenState<List<SalesDocument>>>(
      DocumentsController.new,
    );

/// Line items for a single document, fetched on demand when its detail page
/// opens.
///
/// Auto-disposed so leaving the page releases the data and re-entering fetches
/// fresh rows. Riverpod 3 retries failed providers with exponential backoff by
/// default; that's disabled here so a genuine failure shows its error once
/// instead of silently re-firing forever.
final documentItemsProvider =
    FutureProvider.family<List<DocumentLineItem>, int>((ref, documentId) async {
      final api = ref.watch(apiProvider);
      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel('detail page closed'));

      return api.fetchDocumentItems(
        documentId: documentId,
        cancelToken: cancelToken,
      );
    }, isAutoDispose: true, retry: (_, _) => null);

/// Everything the document editor picks from, fetched in parallel when it
/// opens and released when it closes — a price or a warehouse renamed since
/// last time is picked up on the next open.
final documentLookupsProvider = FutureProvider<DocumentLookups>((ref) async {
  final api = ref.watch(apiProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('document editor closed'));

  // Future.wait rather than a record's `.wait`: that one wraps a failure in a
  // ParallelWaitError, and the editor would show its toString instead of the
  // server's message.
  final results = await Future.wait<Object>([
    api.fetchDocumentTypes(cancelToken: cancelToken),
    api.fetchCustomers(cancelToken: cancelToken),
    api.fetchWarehouses(cancelToken: cancelToken),
    api.fetchTaxes(cancelToken: cancelToken),
    api.fetchUsers(cancelToken: cancelToken),
    api.fetchProducts(cancelToken: cancelToken),
    api.fetchStocks(cancelToken: cancelToken),
  ]);
  return DocumentLookups(
    types: results[0] as List<DocumentTypeOption>,
    customers: [
      for (final c in results[1] as List<CustomerOption>)
        if (c.isEnabled) c,
    ],
    warehouses: results[2] as List<WarehouseOption>,
    taxes: [
      for (final t in results[3] as List<TaxOption>)
        if (t.isEnabled) t,
    ],
    users: [
      for (final u in results[4] as List<StaffUser>)
        if (u.isEnabled) u,
    ],
    products: [
      for (final p in results[5] as List<Product>)
        if (p.isEnabled) p,
    ],
    stocks: results[6] as List<StockEntry>,
  );
}, isAutoDispose: true, retry: (_, _) => null);

/// An existing document's lines as editor lines, each with the tax the server
/// holds on it — the tax lives in its own table, one request per line.
Future<List<DraftLine>> loadDraftLines(
  OctopusApi api,
  SalesDocument document,
  DocumentLookups lookups,
) async {
  final items = await api.fetchDocumentItems(documentId: document.id);
  final taxIds = await Future.wait([
    for (final item in items)
      api.fetchDocumentItemTaxIds(documentItemId: item.id),
  ]);
  final isCount =
      lookups.typeById(document.documentTypeId)?.isInventoryCount ??
      document.documentTypeId == DocumentTypeIds.inventoryCount;
  return [
    for (var i = 0; i < items.length; i++)
      DraftLine.fromServer(
        items[i],
        lookups: lookups,
        isInventoryCount: isCount,
        taxId: taxIds[i].firstOrNull,
      ),
  ];
}

/// Pushes a draft to the server, step by step, in the order stock needs.
///
/// 🚨 Built to be run again after a failure. It keeps its own copy of what the
/// SERVER holds and reports it after every step that succeeds — the header's
/// new id, each line pushed, each tax — so pressing Save a second time picks up
/// where the first attempt stopped instead of creating the document, or a line
/// and the stock it moves, twice.
class DocumentSaver {
  const DocumentSaver(this.api);

  final OctopusApi api;

  /// Saves [draft].
  ///
  /// [server] is what the server already holds of this document: the document
  /// as loaded when editing, or what an interrupted earlier attempt got
  /// through. Null when nothing has been saved yet. Lines are matched to it by
  /// [DraftLine.key], which is what tells a changed or removed line from a kept
  /// one.
  Future<DocumentDraft> save(
    DocumentDraft draft, {
    DocumentDraft? server,
    required void Function(DocumentDraft draft, DocumentDraft server) onProgress,
  }) async {
    var current = draft;
    var held = server ?? draft.copyWith(lines: const []);
    void report() => onProgress(current, held);
    void settle(DraftLine line) {
      current = current.withLine(line);
      held = held.withLine(line);
      report();
    }

    // 1. The header — created once, then updated on every later attempt, so a
    // field changed after a failed first try still reaches the server.
    if (current.id == null) {
      final id = await api.createDocument(current.createJson());
      current = current.copyWith(id: id);
    } else {
      await api.updateDocument(current.updateJson());
    }
    held = current.copyWith(lines: held.lines);
    report();
    final documentId = current.id!;

    // 2. Lines removed in the editor. The server gives their stock back.
    final kept = {for (final line in current.lines) line.key};
    for (final line in [...held.lines]) {
      if (kept.contains(line.key)) continue;
      final id = line.serverId;
      if (id != null) {
        await _ignoringMissing(() => api.deleteDocumentItem(id: id));
      }
      held = held.withoutLine(line.key);
      report();
    }

    // 3. New and changed lines, each followed by its tax.
    for (final key in [for (final line in current.lines) line.key]) {
      var line = current.lines.firstWhere((l) => l.key == key);
      final was = held.lines.where((l) => l.key == key).firstOrNull;
      var retax = false;

      if (was?.serverId == null) {
        final id = await api.addDocumentItem(line.toCreateJson(documentId));
        line = line.copyWith(serverId: id, pushedTaxId: null);
        settle(line);
      } else if (line.differsFrom(was!)) {
        final updated = line.copyWith(
          serverId: was.serverId,
          pushedTaxId: was.pushedTaxId,
        );
        await api.updateDocumentItem(updated.toUpdateJson(documentId));
        line = updated;
        settle(line);
        // The tax row stores its own amount, computed from the line as it
        // was. Re-adding the tax is what recomputes it.
        retax = was.pushedTaxId != null;
      }

      final onServer = line.pushedTaxId;
      final wanted = line.tax?.id;
      if (!retax && onServer == wanted) continue;
      final itemId = line.serverId!;
      if (onServer != null) {
        await _ignoringMissing(
          () => api.deleteDocumentItemTax(documentItemId: itemId, taxId: onServer),
        );
        line = line.copyWith(pushedTaxId: null);
        settle(line);
      }
      if (wanted != null) {
        await api.addDocumentItemTax(documentItemId: itemId, taxId: wanted);
        line = line.copyWith(pushedTaxId: wanted);
        settle(line);
      }
    }

    // 4. The total, now that every line is where it belongs. The server never
    // derives it from the lines — the editor always has.
    await api.updateDocument({'id': documentId, 'total': current.total});
    return current;
  }

  /// A delete that finds nothing to delete has already done its job — the
  /// first attempt got that far before failing.
  static Future<void> _ignoringMissing(Future<void> Function() call) async {
    try {
      await call();
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }
}
