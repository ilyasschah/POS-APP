import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';

/// Result of the "does my company still exist?" probe. `unknown` = offline or a
/// transient error → never acted on (an offline terminal must keep working).
enum CompanyExistence { exists, deleted, unknown }

/// Probes the server for the company. The backend returns 200 with a null/empty
/// body when the company has been deleted — that (and only that) means "gone".
/// Any thrown error is offline/transient → [CompanyExistence.unknown], so a
/// legitimate offline terminal is never treated as revoked.
Future<CompanyExistence> checkCompanyExists(int companyId) async {
  try {
    final dio = createDio();
    final res = await dio.get(
      '/Company/GetById',
      queryParameters: {'id': companyId},
    );
    final data = res.data;
    final gone = data == null || (data is Map && data.isEmpty);
    return gone ? CompanyExistence.deleted : CompanyExistence.exists;
  } catch (_) {
    return CompanyExistence.unknown;
  }
}

/// Set to `true` when a sync detects — via a definitive server response — that
/// this terminal's company/tenant no longer exists (deleted in the admin
/// portal). The app shell ([MainLayout]) watches this and routes back to the
/// master login, unlinking the device. NEVER set on an offline/transient error,
/// so a network blip can't kick a legitimate offline terminal out.
class AccountRevokedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markRevoked() => state = true;
  void reset() => state = false;
}

final accountRevokedProvider =
    NotifierProvider<AccountRevokedNotifier, bool>(AccountRevokedNotifier.new);
