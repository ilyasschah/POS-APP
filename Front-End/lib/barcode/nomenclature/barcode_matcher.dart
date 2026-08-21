import 'package:pos_app/barcode/nomenclature/barcode_rule.dart';

/// Matches a scanned barcode against the company's nomenclature.
///
/// A direct port of `Back-End/Web-POS.Api/Services/BarcodeRuleMatcher.cs` — the
/// POS decodes scale labels offline, so this cannot live behind an endpoint.
/// Any fix here belongs in the C# file too.
///
/// Pattern syntax:
/// * a digit matches itself
/// * `.` matches any single character
/// * `{N…D…}` marks the embedded numeric value. Each `N`/`D` is one digit
///   position and `D` positions are decimals, so `{NNDDD}` is five digits with
///   three decimals and `00350` decodes to `0.350`.
///
/// Matching is prefix-based: the pattern `22` matches any barcode starting 22.

/// Returns the first enabled rule whose pattern matches [barcode], or null.
BarcodeMatch? matchBarcode(String? barcode, List<BarcodeRule> rules) {
  if (barcode == null || barcode.trim().isEmpty) return null;

  final code = barcode.trim();

  final ordered = rules.where((r) => r.isEnabled).toList()
    ..sort((a, b) {
      final bySequence = a.sequence.compareTo(b.sequence);
      return bySequence != 0 ? bySequence : a.id.compareTo(b.id);
    });

  for (final rule in ordered) {
    final match = tryMatchRule(code, rule);
    if (match != null) return match;
  }

  return null;
}

/// Tests one rule. Split out so the settings screen can preview a pattern
/// against a sample barcode without building a whole nomenclature.
BarcodeMatch? tryMatchRule(String barcode, BarcodeRule rule) {
  if (!_encodingAccepts(barcode, rule.encoding)) return null;

  final pattern = rule.pattern;

  // A bare ".*" is the conventional catch-all.
  if (pattern == '.*') {
    return BarcodeMatch(rule: rule, productKey: barcode, value: 0);
  }

  final open = pattern.indexOf('{');
  final close = open >= 0 ? pattern.indexOf('}', open + 1) : -1;

  // No embedded value: the pattern is a plain prefix test.
  if (open < 0 || close < 0) {
    return _prefixMatches(barcode, pattern, 0)
        ? BarcodeMatch(rule: rule, productKey: barcode, value: 0)
        : null;
  }

  final head = pattern.substring(0, open);
  final placeholder = pattern.substring(open + 1, close);
  final tail = pattern.substring(close + 1);

  // Every N/D is one digit position. Anything else inside the braces is a
  // malformed pattern — refuse rather than silently mis-decoding.
  final decimals = RegExp('[Dd]').allMatches(placeholder).length;
  final width = RegExp('[NnDd]').allMatches(placeholder).length;
  if (width == 0 || width != placeholder.length) return null;

  // A trailing "*" means "and anything after", so it is not position checked.
  final tailPattern = tail.replaceAll('*', '');

  if (barcode.length < head.length + width + tailPattern.length) return null;
  if (!_prefixMatches(barcode, head, 0)) return null;

  final digits = barcode.substring(head.length, head.length + width);
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;

  if (!_prefixMatches(barcode, tailPattern, head.length + width)) return null;

  final raw = int.parse(digits);
  final value = raw / _pow10(decimals);

  // Blank the value digits so every weight of one product resolves to the same
  // lookup key — this is why the product's stored barcode carries zeros there.
  var key = barcode.substring(0, head.length) +
      '0' * width +
      barcode.substring(head.length + width);

  // The scale recomputes the trailing check digit for every weight, so the tail
  // copied above still carries the ORIGINAL label's digit — which would make
  // 350 g and 2.750 kg of one product produce two different keys and fail every
  // lookup but the first. Recomputing it over the zeroed body makes it canonical.
  if (rule.encoding == BarcodeEncoding.ean13 ||
      rule.encoding == BarcodeEncoding.upcA) {
    key = withCheckDigit(key.substring(0, key.length - 1));
  }

  return BarcodeMatch(rule: rule, productKey: key, value: value);
}

/// Builds a barcode that [rule] decodes back to [value] for [productKey] — the
/// inverse of [tryMatchRule].
///
/// 🚨 Exists for the barcode SIMULATOR, and that is a real need rather than a
/// convenience: a price- or weight-embedded label cannot be typed by hand
/// (getting the check digit right over a body you just edited is the whole
/// problem), and a scale is not always on the desk when the decode path needs
/// testing. Same file as the matcher on purpose — an encoder that drifts from
/// the decoder produces labels the till refuses, which looks exactly like a
/// scanner fault.
///
/// Returns null when the rule embeds nothing, when [value] does not fit the
/// rule's digit positions, or when [productKey] is too short to carry them.
String? buildBarcodeForRule(BarcodeRule rule, String productKey, double value) {
  final pattern = rule.pattern;
  final open = pattern.indexOf('{');
  final close = open >= 0 ? pattern.indexOf('}', open + 1) : -1;
  if (open < 0 || close < 0) return null;

  final head = pattern.substring(0, open);
  final placeholder = pattern.substring(open + 1, close);

  final decimals = RegExp('[Dd]').allMatches(placeholder).length;
  final width = RegExp('[NnDd]').allMatches(placeholder).length;
  if (width == 0 || width != placeholder.length) return null;

  if (value < 0) return null;
  final encoded = (value * _pow10(decimals)).round();
  final digits = encoded.toString();
  // 5 positions cannot carry 1 234.56 — say so instead of truncating into a
  // label that scans as some other amount entirely.
  if (digits.length > width) return null;

  final key = productKey.trim();
  if (key.length < head.length + width) return null;

  var out = key.substring(0, head.length) +
      digits.padLeft(width, '0') +
      key.substring(head.length + width);

  // The scale recomputes the check digit for every weight; so must we, or the
  // label carries the key's digit over a body that no longer matches it.
  if (rule.encoding == BarcodeEncoding.ean13 ||
      rule.encoding == BarcodeEncoding.upcA) {
    out = withCheckDigit(out.substring(0, out.length - 1));
  }

  // Prove it round-trips rather than trusting the arithmetic: a simulator that
  // emits a barcode the till cannot read is worse than no simulator.
  return tryMatchRule(out, rule) == null ? null : out;
}

/// The barcode to STORE on a product so [rule] can decode its labels: the
/// rule's fixed digits, the product's own id in the wildcard positions, and
/// ZEROS where the scale writes the value.
///
/// 🚨 The zeros are the whole point and the commonest setup mistake. Every
/// label the scale prints for one product differs in those positions, so the
/// till blanks them back out to find the product ([tryMatchRule] returns that
/// as `productKey`). A product stored with a real weight baked in is findable
/// by exactly one label and by no other.
///
/// Returns null when the rule embeds nothing, has no wildcard positions to
/// carry a product id, or cannot produce a valid code of its own symbology.
String? buildProductKeyForRule(BarcodeRule rule, int productId) {
  final pattern = rule.pattern;
  final open = pattern.indexOf('{');
  final close = open >= 0 ? pattern.indexOf('}', open + 1) : -1;
  if (open < 0 || close < 0) return null;

  final head = pattern.substring(0, open);
  final placeholder = pattern.substring(open + 1, close);
  final width = RegExp('[NnDd]').allMatches(placeholder).length;
  if (width == 0 || width != placeholder.length) return null;

  final slots = head.split('').where((c) => c == '.').length;
  // A pattern with no wildcards addresses ONE barcode, not a catalogue.
  if (slots == 0) return null;

  // Right-aligned so the digits that actually differ between products — the
  // low ones — are the ones that survive a narrow slot.
  final digits = productId.abs().toString();
  final fill = digits.length >= slots
      ? digits.substring(digits.length - slots)
      : digits.padLeft(slots, '0');

  var next = 0;
  final body = StringBuffer();
  for (final c in head.split('')) {
    body.write(c == '.' ? fill[next++] : c);
  }
  body.write('0' * width);

  var key = body.toString();

  if (rule.encoding == BarcodeEncoding.ean13 ||
      rule.encoding == BarcodeEncoding.upcA) {
    final target = rule.encoding == BarcodeEncoding.ean13 ? 13 : 12;
    // The pattern may or may not spell out the check-digit position; either
    // way the digit itself is computed, never taken from the pattern.
    if (key.length == target) key = key.substring(0, target - 1);
    if (key.length != target - 1) return null;
    key = withCheckDigit(key);
  }

  // It has to decode under its own rule, and carry no value — otherwise it is
  // not a product key, it is a label for one particular weight.
  final check = tryMatchRule(key, rule);
  if (check == null || check.value != 0) return null;
  return key;
}

/// A plain in-store EAN-13 for [productId] — a product barcode for something
/// that has none, printable on a shelf label.
///
/// 🚨 Prefix `20`. The `2` range is the one GS1 reserves for in-store use, so
/// it can never collide with a manufacturer's real code, and the `0` keeps it
/// clear of the scale prefixes the default nomenclature claims (`22` weight,
/// `25` price). A "plain" barcode that happened to start 22 would be decoded as
/// a weight label and put a quantity of 0.000 in the cart.
String buildInternalEan13(int productId) {
  final digits = productId.abs().toString();
  final tail = digits.length > 10
      ? digits.substring(digits.length - 10)
      : digits.padLeft(10, '0');
  return withCheckDigit('20$tail');
}

/// Compares [pattern] against [barcode] from [offset], treating '.' as a wildcard.
bool _prefixMatches(String barcode, String pattern, int offset) {
  if (pattern.isEmpty) return true;
  if (barcode.length < offset + pattern.length) return false;

  for (var i = 0; i < pattern.length; i++) {
    final p = pattern[i];
    if (p == '.') continue;
    if (barcode[offset + i] != p) return false;
  }

  return true;
}

/// Length and check-digit gate for the fixed symbologies.
bool _encodingAccepts(String barcode, BarcodeEncoding encoding) {
  switch (encoding) {
    case BarcodeEncoding.ean13:
      return barcode.length == 13 &&
          RegExp(r'^\d+$').hasMatch(barcode) &&
          hasValidCheckDigit(barcode);
    case BarcodeEncoding.upcA:
      return barcode.length == 12 &&
          RegExp(r'^\d+$').hasMatch(barcode) &&
          hasValidCheckDigit(barcode);
    case BarcodeEncoding.any:
      return true;
  }
}

/// Modulo-10 check digit shared by EAN-13 and UPC-A.
bool hasValidCheckDigit(String barcode) {
  if (barcode.length < 2 || !RegExp(r'^\d+$').hasMatch(barcode)) return false;
  return withCheckDigit(barcode.substring(0, barcode.length - 1)) == barcode;
}

/// Appends the modulo-10 check digit to a barcode body.
///
/// Weights alternate 3 and 1 counting from the RIGHT, which makes one rule
/// correct for both EAN-13 and UPC-A without special-casing the length.
String withCheckDigit(String body) {
  var sum = 0;
  for (var i = body.length - 1; i >= 0; i--) {
    final digit = body.codeUnitAt(i) - 0x30;
    final positionFromRight = body.length - i; // 1, 2, 3, …
    sum += positionFromRight.isOdd ? digit * 3 : digit;
  }

  return '$body${(10 - sum % 10) % 10}';
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
