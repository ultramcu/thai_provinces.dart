// Internal helpers for the `fromJson` factories. Not exported.
//
// They give every malformed-input failure one catchable type — [FormatException]
// — with the offending class and key named, instead of leaking a raw, contextless
// `TypeError` from a bare `as` cast. Integer fields also accept a whole-number
// `double` (e.g. `2.0`), which some JSON producers emit for integral values.

/// Reads an integer field, accepting an int or a whole-number double.
///
/// Throws a [FormatException] (naming [where] and [key]) when the key is
/// missing/null, is not a number, or is a non-integral double.
int reqInt(Map<String, dynamic> json, String key, String where) {
  final v = json[key];
  if (v == null) {
    throw FormatException('$where: missing required key "$key"');
  }
  if (v is int) return v;
  if (v is double && v.isFinite && v == v.roundToDouble()) return v.toInt();
  throw FormatException(
      '$where: key "$key" must be an integer, got ${v.runtimeType}');
}

/// Reads a string field. Throws a [FormatException] (naming [where] and [key])
/// when the key is missing/null or is not a [String].
String reqString(Map<String, dynamic> json, String key, String where) {
  final v = json[key];
  if (v == null) {
    throw FormatException('$where: missing required key "$key"');
  }
  if (v is String) return v;
  throw FormatException(
      '$where: key "$key" must be a string, got ${v.runtimeType}');
}

/// Reads a nested JSON-object field. Throws a [FormatException] (naming [where]
/// and [key]) when the key is missing/null or is not a `Map<String, dynamic>`.
Map<String, dynamic> reqMap(
    Map<String, dynamic> json, String key, String where) {
  final v = json[key];
  if (v == null) {
    throw FormatException('$where: missing required key "$key"');
  }
  if (v is Map<String, dynamic>) return v;
  throw FormatException(
      '$where: key "$key" must be a JSON object, got ${v.runtimeType}');
}
