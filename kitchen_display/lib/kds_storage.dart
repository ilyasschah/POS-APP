import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'kds_models.dart';

/// Immutable snapshot of the pairing between this Kitchen Display and a POS.
/// Persisted so the binding survives app restarts and works fully offline —
/// once paired, the KDS never needs the network to know which POS owns it.
class PairingInfo {
  final bool paired;
  final int companyId;
  final String token;
  final String posName;
  final String posIp;
  final int posPort;

  const PairingInfo({
    required this.paired,
    required this.companyId,
    required this.token,
    required this.posName,
    required this.posIp,
    required this.posPort,
  });

  static const empty = PairingInfo(
    paired: false,
    companyId: 0,
    token: '',
    posName: '',
    posIp: '',
    posPort: 0,
  );
}

/// Thin persistence wrapper over SharedPreferences. Holds the pairing record
/// and the last order snapshot the POS pushed, so a freshly-launched (or
/// offline) KDS shows the kitchen immediately without any server round-trip.
class KdsStorage {
  static const _kPaired = 'kds.paired';
  static const _kCompanyId = 'kds.companyId';
  static const _kToken = 'kds.token';
  static const _kPosName = 'kds.posName';
  static const _kPosIp = 'kds.posIp';
  static const _kPosPort = 'kds.posPort';
  static const _kOrders = 'kds.orders';
  static const _kLanguage = 'kds.language';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<PairingInfo> loadPairing() async {
    final p = await _sp;
    return PairingInfo(
      paired: p.getBool(_kPaired) ?? false,
      companyId: p.getInt(_kCompanyId) ?? 0,
      token: p.getString(_kToken) ?? '',
      posName: p.getString(_kPosName) ?? '',
      posIp: p.getString(_kPosIp) ?? '',
      posPort: p.getInt(_kPosPort) ?? 0,
    );
  }

  Future<PairingInfo> savePairing({
    required int companyId,
    required String token,
    required String posName,
    required String posIp,
    required int posPort,
  }) async {
    final p = await _sp;
    await p.setBool(_kPaired, true);
    await p.setInt(_kCompanyId, companyId);
    await p.setString(_kToken, token);
    await p.setString(_kPosName, posName);
    await p.setString(_kPosIp, posIp);
    await p.setInt(_kPosPort, posPort);
    return PairingInfo(
      paired: true,
      companyId: companyId,
      token: token,
      posName: posName,
      posIp: posIp,
      posPort: posPort,
    );
  }

  Future<void> clearPairing() async {
    final p = await _sp;
    await p.remove(_kPaired);
    await p.remove(_kCompanyId);
    await p.remove(_kToken);
    await p.remove(_kPosName);
    await p.remove(_kPosIp);
    await p.remove(_kPosPort);
    await p.remove(_kOrders);
    // 🚨 The LANGUAGE deliberately survives an unpair. It belongs to the person
    // standing in front of the screen, not to the till it happens to be bound
    // to — making the cook re-pick Arabic every time the display is re-paired
    // is precisely the friction this feature exists to remove.
  }

  /// The language code chosen on this display, if one ever was.
  ///
  /// Returns null rather than a default so the caller can tell "never set" from
  /// "set to English"; `resolveKdsLocale` turns either into a real locale.
  Future<String?> loadLanguage() async => (await _sp).getString(_kLanguage);

  Future<void> saveLanguage(String code) async =>
      (await _sp).setString(_kLanguage, code);

  Future<List<KitchenOrder>> loadOrders() async {
    final p = await _sp;
    final raw = p.getString(_kOrders);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => KitchenOrder.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrders(List<KitchenOrder> orders) async {
    final p = await _sp;
    await p.setString(
      _kOrders,
      jsonEncode(orders.map((o) => o.toJson()).toList()),
    );
  }
}
