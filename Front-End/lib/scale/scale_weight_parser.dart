/// A single weight sample read from a serial weighing scale.
class ScaleReading {
  /// The numeric weight, in whatever unit the scale reported.
  ///
  /// No unit conversion is performed — see [unit]. A scale configured to emit
  /// grams reports `1234`, not `1.234`.
  final double weight;

  /// The unit token the scale emitted (`kg`, `g`, `lb`, `oz`), lowercased, or
  /// null when the scale streams a bare number.
  final String? unit;

  /// Whether the scale reported a settled reading.
  ///
  /// Scales that emit a status token (`ST` = stable, `US` = unstable) drive this
  /// directly. Scales that stream a bare number carry no status, so the reading
  /// is treated as stable — otherwise a working scale would never settle.
  final bool stable;

  const ScaleReading({
    required this.weight,
    required this.stable,
    this.unit,
  });
}

/// Matches a signed decimal, tolerating whitespace between the sign and the
/// digits (`"+  1.234"` — the padding CAS/Toledo scales use to right-align).
final _numberRe = RegExp(r'([-+])?\s*(\d+(?:\.\d+)?)');

/// `ST`/`US` as standalone tokens, so the `st` inside a word can't match.
final _stableRe = RegExp(r'(?:^|[,\s])(ST|US)(?:[,\s]|$)', caseSensitive: false);

/// Anchored at end-of-line rather than on a `\b` boundary: scales emit `1.234kg`
/// with no separator, and there is no word boundary between `4` and `k`.
final _unitRe = RegExp(r'(kg|g|lb|oz)\.?\s*$', caseSensitive: false);

/// Control characters (STX/ETX/CR/LF and friends) that frame scale frames.
final _controlRe = RegExp(r'[\x00-\x1F\x7F]');

/// Parses one line streamed by a serial weighing scale.
///
/// Deliberately tolerant, because retail scales differ: it looks for a status
/// token, a signed decimal, and a trailing unit, in any surrounding noise.
/// Handles the common continuous-mode formats:
///
///   `ST,GS,+  1.234kg`   → 1.234 kg, stable    (CAS / Toledo / Aclas)
///   `US,NT,-  0.100 kg`  → -0.100 kg, unstable
///   `  1.234 kg`         → 1.234 kg, stable
///   `1.234`              → 1.234, stable, unit null
///
/// Returns null when the line carries no parseable number, which is the normal
/// case for the partial/garbage frames you get when you first attach to a port.
/// Callers should simply ignore nulls rather than treat them as errors.
ScaleReading? parseScaleWeight(String line) {
  final cleaned = line.replaceAll(_controlRe, ' ').trim();
  if (cleaned.isEmpty) return null;

  final number = _numberRe.firstMatch(cleaned);
  if (number == null) return null;

  final magnitude = double.tryParse(number.group(2)!);
  if (magnitude == null) return null;

  final weight = number.group(1) == '-' ? -magnitude : magnitude;

  // Absent a status token the scale has no notion of stability, so don't
  // withhold the reading — only an explicit `US` marks it unsettled.
  final status = _stableRe.firstMatch(cleaned)?.group(1)?.toUpperCase();

  return ScaleReading(
    weight: weight,
    stable: status != 'US',
    unit: _unitRe.firstMatch(cleaned)?.group(1)?.toLowerCase(),
  );
}
