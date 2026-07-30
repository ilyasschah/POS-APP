import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_controller.dart';
import '../../core/screen_state.dart';
import '../../models/document.dart';
import '../auth/auth_controller.dart';

class DocumentsController extends AsyncController<List<SalesDocument>> {
  @override
  Future<List<SalesDocument>> fetch(CancelToken cancelToken) =>
      api.fetchDocuments(cancelToken: cancelToken);
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
