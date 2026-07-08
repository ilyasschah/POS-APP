import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-terminal UI ergonomics (font scale, cart-panel width) persisted ON-DEVICE
/// with SharedPreferences. These are deliberately NOT stored in the cloud-synced
/// app properties: they're physical-screen preferences for one terminal, so a
/// cashier resizing the cart or bumping the font on one POS must never change
/// the layout on another POS sharing the same company.
///
/// Each notifier seeds synchronously with a default so the first frame renders,
/// then hydrates from disk once SharedPreferences resolves.

const _kFontScaleKey = 'ui.fontScale';
const _kCartWidthKey = 'ui.cartWidth';

const double kFontScaleDefault = 1.0;
const double kFontScaleMin = 0.8;
const double kFontScaleMax = 1.3;

const double kCartWidthDefault = 350.0;
const double kCartWidthMin = 250.0;

/// Base class for a single locally-persisted `double` preference.
abstract class _LocalDoublePref extends Notifier<double> {
  String get _key;
  double get _fallback;
  double clampValue(double v);

  @override
  double build() {
    _load();
    return _fallback;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_key);
    if (stored != null) state = clampValue(stored);
  }

  /// Update the in-memory value only (e.g. live during a drag). Call [persist]
  /// to write it to disk.
  void set(double v) => state = clampValue(v);

  /// Flush the current value to disk.
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }

  /// Update and persist in one step (e.g. a slider's onChangeEnd).
  Future<void> setAndPersist(double v) async {
    set(v);
    await persist();
  }
}

class _FontScaleNotifier extends _LocalDoublePref {
  @override
  String get _key => _kFontScaleKey;
  @override
  double get _fallback => kFontScaleDefault;
  @override
  double clampValue(double v) => v.clamp(kFontScaleMin, kFontScaleMax);
}

class _CartWidthNotifier extends _LocalDoublePref {
  @override
  String get _key => _kCartWidthKey;
  @override
  double get _fallback => kCartWidthDefault;
  // Upper bound is screen-dependent, so the menu screen clamps to half the
  // window width at use-time; here we only enforce the lower bound.
  @override
  double clampValue(double v) => v < kCartWidthMin ? kCartWidthMin : v;
}

/// Global font scale (1.0 = default), applied as a MediaQuery textScaler in
/// main.dart. Local to this terminal.
final fontScaleProvider =
    NotifierProvider<_FontScaleNotifier, double>(_FontScaleNotifier.new);

/// Width (px) of the resizable cart panel on the menu screen. Local to this
/// terminal.
final cartWidthProvider =
    NotifierProvider<_CartWidthNotifier, double>(_CartWidthNotifier.new);
