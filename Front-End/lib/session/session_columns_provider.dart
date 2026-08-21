import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/l10n/app_localizations.dart';

/// One column the Sessions list is able to render.
///
/// [mandatory] columns are always visible and are not offered as a toggle, so
/// the table can never be emptied down to rows nothing identifies.
class SessionColumnDef {
  const SessionColumnDef(
    this.key,
    this.label, {
    this.defaultVisible = false,
    this.mandatory = false,
    this.numeric = false,
  });

  final String key;

  /// English fallback only — **not** what the table renders. The visible text
  /// comes from [sessionColumnLabel]; see the note on [kSessionColumns].
  final String label;

  final bool defaultVisible;
  final bool mandatory;
  final bool numeric;
}

/// The full, ordered catalogue of columns the Sessions list can display, every
/// one of them read from the local Drift row so the choice costs no network.
///
/// 🚨 [SessionColumnDef.key] is the column's **identity**: it gates rendering
/// and is the JSON key persisted to SharedPreferences, so it must never be
/// translated. `label` is a `const` English fallback — the table and the picker
/// both render [sessionColumnLabel] instead, because a `const` list cannot
/// reach `AppLocalizations` (that needs a BuildContext).
///
/// Mirrors `kProductColumns` deliberately: one pattern for every grid in the
/// app means a cashier who has learned to hide a column on Products already
/// knows how to do it here.
const kSessionColumns = <SessionColumnDef>[
  SessionColumnDef('id', 'Session ID', defaultVisible: true, mandatory: true),
  SessionColumnDef('pos', 'Point of Sale', defaultVisible: true),
  SessionColumnDef('openedBy', 'Opened By', defaultVisible: true),
  SessionColumnDef('opening', 'Opening Date', defaultVisible: true),
  SessionColumnDef('closing', 'Closing Date', defaultVisible: true),
  SessionColumnDef('closedBy', 'Closed By'),
  SessionColumnDef('duration', 'Duration'),
  SessionColumnDef('starting', 'Starting Balance',
      defaultVisible: true, numeric: true),
  SessionColumnDef('ending', 'Ending Balance',
      defaultVisible: true, numeric: true),
  SessionColumnDef('theoretical', 'Theoretical Closing',
      defaultVisible: true, numeric: true),
  SessionColumnDef('difference', 'Difference', numeric: true),
  SessionColumnDef('status', 'Status', defaultVisible: true),
];

/// Localized header for a [SessionColumnDef.key]. Falls back to the `const`
/// English `label` for any key without a translation, so a column added later
/// still renders something rather than a blank header.
String sessionColumnLabel(BuildContext context, String key) {
  final l = AppLocalizations.of(context);
  return switch (key) {
    'id' => l.sessionColId,
    'pos' => l.sessionColPos,
    'openedBy' => l.sessionColOpenedBy,
    'opening' => l.sessionColOpening,
    'closing' => l.sessionColClosing,
    'closedBy' => l.sessionClosedBy,
    'duration' => l.sessionDuration,
    'starting' => l.sessionColStarting,
    'ending' => l.sessionColEnding,
    'theoretical' => l.sessionColTheoretical,
    'difference' => l.sessionDifference,
    'status' => l.sessionColStatus,
    _ => kSessionColumns
        .firstWhere(
          (c) => c.key == key,
          orElse: () => const SessionColumnDef('', ''),
        )
        .label,
  };
}

const _kPrefsKey = 'sessions.visibleColumns';

/// Visible-column preferences for the Sessions list, persisted on-device with
/// SharedPreferences so the choice survives restarts and works fully offline.
///
/// 🚨 Device-local on purpose, like every other grid's: which columns a
/// terminal shows is a property of that terminal's screen — a 10-inch tablet
/// and a 24-inch till do not want the same six columns — not something to
/// impose company-wide from the cloud.
final sessionVisibleColumnsProvider =
    NotifierProvider<SessionVisibleColumnsNotifier, Map<String, bool>>(
  SessionVisibleColumnsNotifier.new,
);

class SessionVisibleColumnsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    // Seed synchronously with defaults so the table renders immediately, then
    // hydrate from disk once SharedPreferences resolves.
    _load();
    return _defaults();
  }

  Map<String, bool> _defaults() => {
        for (final c in kSessionColumns) c.key: c.defaultVisible || c.mandatory,
      };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final merged = _merge(raw);
    if (merged != null) state = merged;
  }

  /// Merge a persisted JSON blob over the defaults. A column added in a later
  /// app version falls back to its default visibility; mandatory columns stay
  /// on regardless of what was stored.
  Map<String, bool>? _merge(String raw) {
    try {
      final stored = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final result = _defaults();
      for (final c in kSessionColumns) {
        if (c.mandatory) continue;
        if (stored.containsKey(c.key)) result[c.key] = stored[c.key] == true;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> setVisible(String key, bool value) async {
    final col = kSessionColumns.firstWhere(
      (c) => c.key == key,
      orElse: () => const SessionColumnDef('', ''),
    );
    if (col.key.isEmpty || col.mandatory) return;

    state = {...state, key: value};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state));
  }

  /// Restore the out-of-the-box column selection.
  Future<void> resetToDefaults() async {
    state = _defaults();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state));
  }
}
