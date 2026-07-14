import 'dart:convert';

/// A user-defined printer entry shown in Settings → Printers.
///
/// Each printer owns a settings **prefix** (e.g. `Receipt`, `Kitchen`, or
/// `Printer.<uuid>` for user-added ones). Every hardware setting is stored as a
/// flat application property keyed `"<prefix>.<suffix>"` (PrinterName, PaperSize,
/// Copies, Margin*, Header, Footer, CashDrawer.*, …) — exactly the scheme the
/// existing hardware panel already reads/writes — so a new printer reuses all of
/// it just by handing over its prefix.
///
/// The list itself is persisted as a JSON array under
/// `SettingKeys.printersList` (an application property), so it syncs offline-first
/// across devices like every other setting.
class PrinterConfig {
  /// Settings-key prefix. Immutable identity of the printer.
  final String prefix;

  /// User-facing label (renamable).
  final String name;

  /// Whether this printer participates in printing.
  final bool enabled;

  /// The two seed printers (Receipt, Kitchen) are the ones the current print
  /// pipeline routes to, so they can be renamed/reconfigured but not deleted.
  final bool builtin;

  const PrinterConfig({
    required this.prefix,
    required this.name,
    this.enabled = true,
    this.builtin = false,
  });

  // The printer group this printer prints is stored separately, as the flat
  // per-printer setting `SettingKeys.rolePrinterGroupId(prefix)`, so the
  // hardware panel edits it like every other per-printer key.

  PrinterConfig copyWith({String? name, bool? enabled}) => PrinterConfig(
        prefix: prefix,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        'name': name,
        'enabled': enabled,
        'builtin': builtin,
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> j) => PrinterConfig(
        prefix: (j['prefix'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        enabled: (j['enabled'] ?? true) as bool,
        builtin: (j['builtin'] ?? false) as bool,
      );

  /// The two built-in printers the current pipeline already uses. Surfaced when
  /// the stored list is empty so a fresh device shows the real Receipt/Kitchen
  /// configuration instead of a blank screen.
  static const List<PrinterConfig> builtins = [
    PrinterConfig(
        prefix: 'Receipt', name: 'Receipt', enabled: true, builtin: true),
    PrinterConfig(
        prefix: 'Kitchen', name: 'Kitchen ticket', enabled: true, builtin: true),
  ];

  /// Parses the stored list, always returning a GROWABLE list (callers append).
  /// Falls back to [builtins] when nothing is stored yet, and repairs a stored
  /// list that lost a built-in (so Receipt/Kitchen can never disappear).
  static List<PrinterConfig> listFromJson(String? jsonStr) {
    List<PrinterConfig> list;
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      list = [...builtins];
    } else {
      try {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        list = decoded
            .map((j) => PrinterConfig.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        list = [...builtins];
      }
    }
    // Guarantee the built-ins are always present (prepended, preserving order).
    for (final b in builtins.reversed) {
      if (!list.any((p) => p.prefix == b.prefix)) list.insert(0, b);
    }
    return list;
  }

  static String listToJson(List<PrinterConfig> printers) =>
      jsonEncode(printers.map((p) => p.toJson()).toList());
}
