/// `recordE2EUser` / `loadE2EUsers` — the till-user handoff between tests.
///
/// ```dart
/// // in 10_create_users
/// await recordE2EUser(ctx, user);
///
/// // in 11_security_rules
/// final users = await loadE2EUsers();   // the pair 10 made, newest run
/// ```
///
/// ## Why the credentials file and not the database
///
/// The database knows a user's access level, but it does **not** know their
/// PASSWORD or the PIN this suite chose for them — both are generated per run
/// and exist nowhere else. A later test that wants to actually SIGN IN as one of
/// them needs those, so they go where the company's own login already lives.
///
/// 🚨 That file holds plaintext credentials and is git-ignored. These are E2E
/// users on a dev company; nothing here belongs on a real one.
library;

import 'dart:convert';
import 'dart:io';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// One till user as `10_create_users` left it.
class E2EUser {
  const E2EUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    required this.pin,
    required this.accessLevel,
    this.runTag = '',
  });

  final int userId;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;

  /// The PIN this suite set for them ON THIS DEVICE.
  ///
  /// 🚨 `setDevicePin` stores a PIN per USER **and per DEVICE**, so this value
  /// is only meaningful on the terminal that created it. On a different machine
  /// the pad opens in CREATE mode again and this PIN is simply what the test
  /// will set there too.
  final String pin;

  /// `0` Admin — universal access. `1` Cashier — subject to the security rules.
  final int accessLevel;

  final String runTag;

  bool get isAdmin => accessLevel == 0;

  /// What the user card on the PIN screen is labelled with.
  String get displayName => '$firstName $lastName'.trim();

  String get accessLevelName => isAdmin ? 'Admin' : 'Cashier';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'password': password,
        'pin': pin,
        'accessLevel': accessLevel,
        'accessLevelName': accessLevelName,
      };

  static E2EUser fromJson(Map<String, dynamic> j) => E2EUser(
        userId: j['userId'] as int,
        firstName: (j['firstName'] as String?) ?? '',
        lastName: (j['lastName'] as String?) ?? '',
        username: j['username'] as String,
        email: (j['email'] as String?) ?? '',
        password: (j['password'] as String?) ?? '',
        pin: (j['pin'] as String?) ?? kPosPin,
        accessLevel: (j['accessLevel'] as int?) ?? 1,
        runTag: (j['runTag'] as String?) ?? '',
      );
}

/// Writes [user] into `pos-credentials.json`, under the linked company.
///
/// Newest first, tagged with the run that made it — the same shape the customer
/// and catalogue blocks use.
Future<void> recordE2EUser(E2EContext ctx, E2EUser user) async {
  final file = File(kCredentialsPath);
  final entries =
      (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  final company =
      entries.where((e) => e['companyId'] == ctx.company.companyId).firstOrNull;
  if (company == null) {
    throw StateError(
      'Cannot record a user for company ${ctx.company.companyId} — it is not '
      'in ${file.absolute.path}',
    );
  }

  final existing = (company['users'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  company['users'] = [
    {
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runTag': kRunTag,
      ...user.toJson(),
    },
    // 🚨 Drop any earlier record of the SAME username rather than stacking one.
    // The username carries the run tag so collisions are rare, but a re-run that
    // reused a name would otherwise leave two entries with different PINs and
    // `loadE2EUsers` would pick whichever sorted first.
    ...existing.where((e) => e['username'] != user.username),
  ];

  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(entries)}\n',
  );
  step('Recorded user ${user.username} (${user.accessLevelName}) to '
      '${file.absolute.path}');
}

/// The users created by the most recent `10_create_users` run.
///
/// 🚨 Scoped to ONE run tag, not "the newest few". `10` creates a PAIR — an
/// admin and a cashier — and the point of `11` is to sign in as both. Taking the
/// newest two entries would silently mix a cashier from today with an admin from
/// last week, whose PIN on this device may be something else entirely.
///
/// Resolves the LINKED company by default, for the reason `loadE2ECatalog`
/// documents: the newest company in the file is not the one this terminal is on.
Future<List<E2EUser>> loadE2EUsers({int? companyId}) async {
  final file = File(kCredentialsPath);
  if (!file.existsSync()) {
    throw StateError('No credentials at ${file.absolute.path}');
  }

  final entries =
      (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();

  final wanted = companyId ?? await linkedCompanyId();
  final company = wanted == null
      ? entries.firstOrNull
      : entries.where((e) => e['companyId'] == wanted).firstOrNull;

  final recorded = (company?['users'] as List?)?.cast<Map<String, dynamic>>();
  if (recorded == null || recorded.isEmpty) {
    throw StateError(
      'No till users recorded for company ${wanted ?? '(unlinked)'} in\n'
      '${file.absolute.path}\n'
      'They carry the PIN and password this suite chose, which exist nowhere '
      'else. Create them first:\n'
      '    flutter test integration_test/10_create_users_test.dart -d windows',
    );
  }

  final newestRun = recorded.first['runTag'] as String?;
  return recorded
      .where((e) => e['runTag'] == newestRun)
      .map(E2EUser.fromJson)
      .toList();
}
