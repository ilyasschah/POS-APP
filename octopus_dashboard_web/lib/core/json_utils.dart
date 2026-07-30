/// Defensive JSON coercion helpers.
///
/// The backend is loosely typed in places — numeric fields arrive as `int` or
/// `double` depending on the value, and nullable columns come through as
/// `null`. These helpers keep every model's `fromJson` free of repetitive
/// casting and immune to those variations.
library;

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

double asDouble(Object? value, [double fallback = 0]) =>
    asDoubleOrNull(value) ?? fallback;

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int asInt(Object? value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;

bool? asBoolOrNull(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return null;
}

bool asBool(Object? value, [bool fallback = false]) =>
    asBoolOrNull(value) ?? fallback;

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  final s = value is String ? value : value.toString();
  return s.isEmpty ? null : s;
}

String asString(Object? value, [String fallback = '']) =>
    asStringOrNull(value) ?? fallback;

/// Safely reads a list of JSON objects from a decoded payload.
List<T> asList<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}
