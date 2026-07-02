import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/company/company_model.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/database/database_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';

class CurrentUserNotifier extends Notifier<User?> {
  @override
  User? build() => null;

  void setUser(User user) => state = user;
  void logout() {
    state = null;
    // Drop the per-user token and revert to the device token so the next login
    // starts clean and no stale cashier identity lingers on outgoing requests.
    ref.read(authStorageProvider).resetActiveToDevice();
  }
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, User?>(
  () => CurrentUserNotifier(),
);

/// Enabled users for the current company, streamed from Drift. This is what
/// the login picker watches — keeping it offline-only is what makes a cold
/// launch with no network actually show user cards instead of a 10-second
/// spinner waiting for a Dio timeout.
///
/// On a brand-new install with zero synced users, the stream yields `[]` and
/// the picker shows "No enabled users found." That's the right offline UX
/// for first-install — the user must connect once to seed the local DB.
final allUsersProvider = StreamProvider<List<User>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return Stream.value(const []);

  final query = db.select(db.usersTable)
    ..where((t) => t.companyId.equals(companyId))
    ..where((t) => t.isEnabled.equals(true));

  return query.watch().map((rows) => rows.map(User.fromDrift).toList());
});

/// Admin user list — streams from the local Drift cache with NO isEnabled
/// filter, so disabled users remain visible after toggling.
///
/// The companion [seedUsersFromApiProvider] runs a background full-fetch on
/// screen open and upserts API rows into Drift without deleting anything, so
/// users added on other devices appear without a full sync cycle.
final allUsersAdminProvider = StreamProvider.autoDispose<List<User>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const Stream.empty();

  return (db.select(db.usersTable)
        ..where((t) => t.companyId.equals(companyId)))
      .watch()
      .map((rows) => rows.map(User.fromDrift).toList());
});

/// Fetches all users from the API (no watermark, no isEnabled filter) and
/// upserts them into Drift. Does NOT delete existing rows, so users that were
/// disabled via the toggle (and written to Drift locally) remain in the list.
///
/// Called as a fire-and-forget side-effect when the admin Users tab opens.
final seedUsersFromApiProvider =
    FutureProvider.autoDispose.family<void, int>((ref, companyId) async {
  try {
    final db = ref.read(appDatabaseProvider);
    final storage = ref.read(authStorageProvider);
    final deviceId = await storage.getOrCreateDeviceId();
    final jwt = await storage.getJwt();
    final dio = createDio();
    // Include the JWT when available so the request succeeds on secured endpoints.
    if (jwt != null) {
      dio.options.headers['Authorization'] = 'Bearer $jwt';
    }
    final res = await dio.get<List<dynamic>>(
      '/Users/GetAllUsers',
      queryParameters: {
        'companyId': companyId,
        'deviceId': deviceId,
        'includeDisabled': true, // admin panel needs all users
      },
    );
    final rows = (res.data ?? const []).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return;

    await db.batch((b) {
      for (final json in rows) {
        final firstName = _nullIfBlank(json['firstName'] as String?);
        final lastName  = _nullIfBlank(json['lastName']  as String?);
        final username  = _nullIfBlank(json['username']  as String?);
        final display   = [firstName, lastName]
            .whereType<String>()
            .join(' ')
            .trim();
        b.insert(
          db.usersTable,
          UsersTableCompanion(
            id:           Value(json['id'] as int),
            companyId:    Value(json['companyId'] as int? ?? companyId),
            name:         Value(display.isEmpty ? (username ?? '') : display),
            firstName:    Value(firstName),
            lastName:     Value(lastName),
            username:     Value(username),
            email:        Value(json['email'] as String?),
            pinHash:      Value(json['hashedPin'] as String?),
            role:         Value(json['accessLevel'] as int? ?? 0),
            isEnabled:    Value(_parseBool(json['isEnabled'])),
            lastModified: Value(_parseDate(json['lastModified'])),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  } on DioException {
    // Offline — leave Drift unchanged.
  }
});

bool _parseBool(dynamic v) {
  if (v is bool) return v;
  if (v is int)  return v != 0;
  return true;
}

DateTime _parseDate(dynamic v) =>
    DateTime.tryParse(v as String? ?? '')?.toUtc() ?? DateTime.now().toUtc();

/// Converts an empty-or-whitespace string to null so Drift never stores "".
String? _nullIfBlank(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// Live stream of the currently logged-in user's Drift row.
///
/// Unlike [currentUserProvider] (a static object set at login), this
/// re-emits whenever the `users` table row changes — e.g. after a sync
/// populates the new email/username/firstName/lastName columns, or after
/// an admin edits the user's profile. UserInfoScreen watches this so it
/// always shows fresh data without requiring a re-login.
///
/// Emits `null` when no user is logged in, or the row has been deleted.
final liveCurrentUserProvider = StreamProvider.autoDispose<User?>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return const Stream.empty();

  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.usersTable)
        ..where((t) => t.id.equals(userId)))
      .watchSingleOrNull()
      .map((row) => row != null ? User.fromDrift(row) : null);
});

final authServiceProvider = Provider((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;
  AuthService(this._ref);

  /// Loads the selected company with a three-step fallback chain:
  ///   1. API (`/Company/GetById`) — authoritative when online. Result also
  ///      written through to Drift so future offline cold-starts have fresh
  ///      data even before the first full sync runs.
  ///   2. Drift `companies` cache — used when the API call fails (offline).
  ///      Receipts then print with real branding instead of the stub.
  ///   3. Stub `Company(id, name: 'Branch #N')` — last resort on first
  ///      install with no network.
  Future<void> loadFallbackCompany(int fallbackId) async {
    final db = _ref.read(appDatabaseProvider);

    // 1. Try the API.
    try {
      final dio = createDio();
      final res = await dio.get(
        '/Company/GetById',
        queryParameters: {'id': fallbackId},
      );
      final company = Company.fromJson(res.data as Map<String, dynamic>);
      _ref.read(selectedCompanyProvider.notifier).update(company);

      // Best-effort cache refresh — don't await; selection shouldn't wait
      // on a local write. Failures here are non-fatal: pullCompany during
      // the next sync will catch up.
      _writeCompanyToDrift(db, company).catchError((_) {});
      return;
    } catch (_) {
      // Fall through to Drift.
    }

    // 2. Try the Drift cache.
    try {
      final row = await (db.select(db.companiesTable)
            ..where((t) => t.id.equals(fallbackId)))
          .getSingleOrNull();
      if (row != null) {
        _ref
            .read(selectedCompanyProvider.notifier)
            .update(Company.fromDrift(row));
        return;
      }
    } catch (_) {
      // Fall through to stub.
    }

    // 3. Stub fallback.
    _ref
        .read(selectedCompanyProvider.notifier)
        .update(Company(id: fallbackId, name: 'Branch #$fallbackId'));
  }

  /// Best-effort write-through after a successful loadFallbackCompany API
  /// hit. Only the lean fields the receipt printer needs are persisted.
  /// `localLogoPath` is intentionally left null — pullCompany during the
  /// next sync handles the disk write via ImageSyncHelper. This path is
  /// just the immediate cache so the next offline cold-start has name +
  /// tax number + phone even before the first full sync runs.
  Future<void> _writeCompanyToDrift(AppDatabase db, Company c) {
    return db.into(db.companiesTable).insertOnConflictUpdate(
          CompaniesTableCompanion(
            id: Value(c.id),
            name: Value(c.name),
            taxNumber: Value(c.taxNumber),
            address: Value(c.address),
            phone: Value(c.phoneNumber),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> setDevicePin({
    required int userId,
    required int companyId,
    required String pin,
  }) async {
    final storage = _ref.read(authStorageProvider);
    final deviceId = await storage.getOrCreateDeviceId();
    final dio = createDio();

    await dio.post(
      '/UserDevicePins/SetDevicePin',
      queryParameters: {'companyId': companyId},
      data: {'userId': userId, 'deviceId': deviceId, 'pin': pin},
    );

    // Persist the hash locally so hasPinForThisDevice is true on the next
    // login — without this, Drift still has null and the PIN creation prompt
    // appears again every time. Uses the same algorithm as the backend:
    // base64( SHA-256( UTF-8(pin) ) ).
    final hashedPin = base64Encode(sha256.convert(utf8.encode(pin)).bytes);
    final db = _ref.read(appDatabaseProvider);
    await (db.update(db.usersTable)..where((t) => t.id.equals(userId)))
        .write(UsersTableCompanion(pinHash: Value(hashedPin)));
  }

  /// Exchanges the durable device token for a per-user token so the backend sees
  /// the CURRENT cashier's identity + role (not the device owner's). Best-effort:
  /// offline / no device token / any error leaves the active token unchanged, so
  /// the app keeps working on the device token as before. Call at PIN login.
  Future<void> exchangeUserToken(int userId) async {
    final storage = _ref.read(authStorageProvider);
    final deviceJwt = await storage.getDeviceJwt();
    if (deviceJwt == null || deviceJwt.isEmpty) return; // nothing to exchange with

    try {
      final dio = createDio();
      // Present the device token explicitly (overrides the interceptor's active
      // token, which may still be a previous user's).
      dio.options.headers['Authorization'] = 'Bearer $deviceJwt';
      final res = await dio.post(
        '/Auth/UserToken',
        queryParameters: {'userId': userId},
      );
      final data = res.data;
      final token = data is Map ? data['token'] as String? : null;
      if (token != null && token.isNotEmpty) {
        await storage.saveJwt(token); // becomes the active token for all requests
      }
    } on DioException {
      // Offline or server unavailable — keep the current active token.
    }
  }
}

final userManagementProvider = Provider((ref) => UserManagementService());

class UserManagementService {
  Future<void> updateSecurityKey(int companyId, String name, int level) async {
    final dio = createDio();
    await dio.patch(
      '/SecurityKeys/Update',
      queryParameters: {'companyId': companyId},
      data: {'name': name, 'level': level},
    );
  }

  Future<void> deleteUser(int companyId, int userId) async {
    final dio = createDio();
    await dio.delete(
      '/Users/Delete',
      queryParameters: {'id': userId, 'companyId': companyId},
    );
  }

  Future<void> toggleUserStatus(
    int companyId,
    int userId,
    bool isEnabled,
  ) async {
    final dio = createDio();
    await dio.patch(
      '/Users/UpdateUser',
      queryParameters: {'companyId': companyId},
      data: {'id': userId, 'isEnabled': isEnabled},
    );
  }

  Future<void> addUser(int companyId, Map<String, dynamic> userData) async {
    final dio = createDio();
    await dio.post(
      '/Users/Add',
      queryParameters: {'companyId': companyId},
      data: userData,
    );
  }

  Future<void> updateUser(int companyId, Map<String, dynamic> userData) async {
    final dio = createDio();
    await dio.patch(
      '/Users/UpdateUser',
      queryParameters: {'companyId': companyId},
      data: userData,
    );
  }

  Future<void> adminResetPassword(
    int companyId,
    int userId,
    String newPassword,
  ) async {
    final dio = createDio();
    await dio.patch(
      '/Users/AdminResetPassword',
      queryParameters: {'companyId': companyId},
      data: {'userId': userId, 'newPassword': newPassword},
    );
  }
}
