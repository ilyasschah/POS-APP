import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_app/api/api_client.dart';

/// Result of the "does my company still exist?" probe. `unknown` = offline or a
/// transient error → never acted on (an offline terminal must keep working).
enum CompanyExistence { exists, deleted, unknown }

/// Probes the server for the company.
///
/// 🚨 **[CompanyExistence.deleted] used to be unreachable, so deleting a company
/// in the admin portal was invisible to every terminal.** The old code assumed
/// *"the backend returns 200 with a null/empty body when the company has been
/// deleted"*. It does not: `GetCompanyByIdQuery` throws `KeyNotFoundException`,
/// which `ExceptionHandlingMiddleware` maps to **404**. Dio raises on a 404, so
/// the blanket `catch` returned `unknown` every time — `markRevoked()` was never
/// called, and terminals kept trading on their local mirror of a company that no
/// longer existed, syncing into errors forever. That is the operator-visible
/// half of *"I deleted the company and its data is still there"*.
///
/// Only a **404** proves absence. Every other failure is treated as unknown, on
/// purpose:
///  * `401` — our token expired; `SessionExpiry` owns that, and treating it as
///    "deleted" would wipe a live terminal over a routine re-login.
///  * `500` / `503` — the server is unwell (the 503 is explicitly the
///    "database unreachable, retry" signal). The company may be perfectly fine.
///  * no response — offline. An offline terminal must keep working.
Future<CompanyExistence> checkCompanyExists(int companyId) async {
  try {
    final dio = createDio();
    final res = await dio.get(
      '/Company/GetById',
      queryParameters: {'id': companyId},
    );
    // Kept as a belt-and-braces read: an older/patched API that answers 200 with
    // an empty body still resolves correctly.
    final data = res.data;
    final gone = data == null || (data is Map && data.isEmpty);
    return gone ? CompanyExistence.deleted : CompanyExistence.exists;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return CompanyExistence.deleted;
    return CompanyExistence.unknown;
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

/// Set when the server reports this TERMINAL was removed from the account by an
/// admin (User info → Active devices → revoke).
///
/// ⚠️ Deliberately separate from [accountRevokedProvider], and it must NOT purge
/// the local database. A deleted *company* means the data should be gone from
/// every terminal; a revoked *device* means only that this terminal has to prove
/// itself again — the company is still the operator's, and any sale sitting here
/// unpushed is still real money that must survive to be synced after they sign
/// back in. Wiping it would turn a routine admin action into data loss.
class DeviceRevokedNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// [message] is the server's explanation, shown on the master-login screen.
  void markRevoked(String message) => state = message;
  void reset() => state = null;
}

final deviceRevokedProvider =
    NotifierProvider<DeviceRevokedNotifier, String?>(DeviceRevokedNotifier.new);
