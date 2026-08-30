/// The REGISTER a terminal is working — Odoo's `pos.config`.
///
/// ## What a register is, and what it is not
///
/// A register is one named till: one drawer, one session at a time, one
/// Z-report. It is **not** a terminal. Several terminals may work the same
/// register at once — a Windows POS and a waiter's tablet on "Front Till" share
/// its open session, both sell into it, and either can close it.
///
/// 🚨 That is the change. A session was keyed by the terminal's own GUID, so
/// every device silently created a register of its own on first open and device
/// B could only ever *look at* device A's session. The uid below is what two
/// terminals now agree on.
///
/// ## Why it is device-scoped, not cloud-synced
///
/// Which register a terminal is working is the one setting that MUST differ
/// between terminals sharing an account — that is the entire point of having
/// more than one. A cloud-synced value would drag every device onto whichever
/// till was configured last. Stored per-terminal via [DeviceScopedSettings].
///
/// ## Why an unset register still works
///
/// [registerUidProvider] falls back to this terminal's own device GUID, and
/// [registerNameProvider] to its POS name. So an install that has never opened
/// the picker behaves exactly as it did before — its own register, its own
/// session — and the existing `PosDevice` row on the server keeps serving it.
/// Nothing has to be migrated; choosing a shared register is opting in.
///
/// ## Register name vs POS name
///
/// They are different and both are needed. The POS name
/// (`settings/device_identity.dart`, "POS1") prefixes every document number
/// this terminal issues and must stay **unique per terminal**, or two devices
/// on one register would mint colliding numbers. The register name is the
/// drawer's label. Two terminals on "Front Till" still number `POS1-…` and
/// `POS2-…`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/auth/auth_storage.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/settings/device_identity.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

/// Max length of a register name — the server column is 64.
const int kRegisterNameMaxLength = 64;

/// The uid this terminal opens and joins sessions under.
///
/// Async because the legacy fallback reads the device GUID out of secure
/// storage, exactly like `deviceUidProvider` — which this replaces everywhere a
/// SESSION is concerned. `deviceUidProvider` still exists and is still right
/// for anything that really means "this machine".
///
/// 🚨 `.select`ed to the one key.
///
/// Watching the whole settings map re-ran this future on **every** settings
/// change in the app — a theme toggle, a printer name, a COM port — because
/// `appSettingsProvider` returns a fresh `Map` each rebuild and `Map` has no
/// value equality. Measured at **two emissions per unrelated write**
/// (`AsyncLoading`, then `AsyncData` with the same string it already had), each
/// one re-entering secure storage on the fallback path and re-invalidating
/// every session provider downstream. `test/session_gate_test.dart` pins it at
/// zero.
final registerUidProvider = FutureProvider<String>((ref) async {
  final chosen = ref.watch(
    appSettingsProvider.select((s) => s[SettingKeys.registerUid] ?? ''),
  );
  if (chosen.trim().isNotEmpty) return chosen.trim();
  // Never configured: the terminal IS its own register, which is how every
  // install behaved before registers existed.
  return AuthStorage().getOrCreateDeviceId();
});

/// The register's display name, for the session header and the server row.
final registerNameProvider = FutureProvider<String>((ref) async {
  // Narrowed for the same reason as [registerUidProvider] above.
  final chosen = ref.watch(
    appSettingsProvider.select((s) => s[SettingKeys.registerName] ?? ''),
  );
  if (chosen.trim().isNotEmpty) return chosen.trim();
  return getDeviceName();
});

/// True once the operator has actually picked a register, as opposed to
/// running on the device-GUID fallback. The picker uses it to explain which
/// state a terminal is in — "this device only" reads very differently from
/// "Front Till", and they are the same code path.
final registerIsExplicitProvider = Provider<bool>(
  (ref) => ref.watch(
    appSettingsProvider.select(
      (s) => (s[SettingKeys.registerUid] ?? '').trim().isNotEmpty,
    ),
  ),
);

/// The register uid, for callers with no `Ref` — the sync engine. Mirrors
/// [registerUidProvider] exactly, including the device-GUID fallback.
Future<String> getRegisterUid() async {
  final chosen =
      (DeviceScopedSettings.overrides[SettingKeys.registerUid] ?? '').trim();
  if (chosen.isNotEmpty) return chosen;
  return AuthStorage().getOrCreateDeviceId();
}

/// The register NAME, for the same callers.
///
/// 🚨 Not `getDeviceName()`. That is the terminal's numbering prefix ("POS2")
/// and pushing it as the register name would rename a shared till to whichever
/// terminal last synced — "Front Till" becomes "POS2" the moment the tablet
/// closes the session.
Future<String> getRegisterName() async {
  final chosen =
      (DeviceScopedSettings.overrides[SettingKeys.registerName] ?? '').trim();
  if (chosen.isNotEmpty) return chosen;
  return getDeviceName();
}

/// One register as the picker shows it.
class PosRegister {
  final int id;
  final String uid;
  final String name;
  final int? liveSessionId;
  final int? liveSessionStatus;

  const PosRegister({
    required this.id,
    required this.uid,
    required this.name,
    this.liveSessionId,
    this.liveSessionStatus,
  });

  /// A register that is trading (or counting) right now. Joining it means
  /// selling into money someone else has already taken, so the picker says so.
  bool get isLive =>
      liveSessionStatus != null && PosSessionStatus.isLive(liveSessionStatus!);

  factory PosRegister.fromJson(Map<String, dynamic> json) => PosRegister(
        id: (json['id'] as num?)?.toInt() ?? 0,
        uid: (json['uid'] as String?)?.trim() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
        liveSessionId: (json['liveSessionId'] as num?)?.toInt(),
        liveSessionStatus: (json['liveSessionStatus'] as num?)?.toInt(),
      );
}

/// Every register the company has, newest state first fetch.
///
/// Online-only, deliberately: a register you have never worked has no local
/// row, and inventing one offline would let two terminals mint two registers
/// with the same name and different uids — the exact split this feature exists
/// to prevent. The picker shows the network error rather than a stale list.
final companyRegistersProvider =
    FutureProvider.autoDispose<List<PosRegister>>((ref) async {
  final companyId = ref.watch(selectedCompanyProvider)?.id;
  if (companyId == null) return const [];

  final res = await createDio().get<List<dynamic>>(
    '/PosSession/Registers',
    queryParameters: {'companyId': companyId},
  );
  return (res.data ?? const [])
      .cast<Map<String, dynamic>>()
      .map(PosRegister.fromJson)
      .toList();
});

/// Creates or renames a register, then points THIS terminal at it.
///
/// The uid is minted client-side so the call is replayable: a lost response
/// re-sends the same uid and the server upserts onto the same row instead of
/// creating a twin.
class RegisterIdentity {
  const RegisterIdentity._();

  static String sanitizeName(String raw) {
    final trimmed = raw.trim();
    return trimmed.length > kRegisterNameMaxLength
        ? trimmed.substring(0, kRegisterNameMaxLength)
        : trimmed;
  }

  /// Registers [name] with the server under [uid] (minted if absent) and stores
  /// the pair on this terminal. Returns the uid actually used.
  static Future<String> choose(
    WidgetRef ref, {
    required String name,
    String? uid,
  }) async {
    final companyId = ref.read(selectedCompanyProvider)?.id;
    if (companyId == null) {
      throw StateError('Select a company before choosing a register.');
    }
    final cleanName = sanitizeName(name);
    if (cleanName.isEmpty) {
      throw StateError('A register needs a name.');
    }
    final id = (uid == null || uid.trim().isEmpty)
        ? const Uuid().v4()
        : uid.trim();

    await createDio().post(
      '/PosSession/Register',
      queryParameters: {'companyId': companyId},
      data: {'uid': id, 'name': cleanName},
    );

    // Written only after the server accepted it. Pointing a terminal at a
    // register the server has never heard of would strand its next session
    // push behind a register that does not exist.
    final settings = ref.read(appSettingsProvider.notifier);
    await settings.set(SettingKeys.registerUid, id);
    await settings.set(SettingKeys.registerName, cleanName);
    return id;
  }

  /// Detaches this terminal from a shared register: back to its own device
  /// GUID, which is the pre-registers behaviour and always available offline.
  static Future<void> useThisDeviceOnly(WidgetRef ref) async {
    final settings = ref.read(appSettingsProvider.notifier);
    await settings.set(SettingKeys.registerUid, '');
    await settings.set(SettingKeys.registerName, '');
  }
}
