/// Leading Thai administrative-area prefixes stripped by [normalizeName] so
/// that, for example, "อำเภอเมืองเชียงใหม่" and "เมืองเชียงใหม่" (or "เขตพระนคร"
/// and "พระนคร") compare equal. Longer prefixes are listed first so the most
/// specific one is matched.
const List<String> _thaiPrefixes = [
  'กิ่งอำเภอ',
  'จังหวัด',
  'อำเภอ',
  'ตำบล',
  'แขวง',
  'เขต',
  'อ.',
  'ต.',
];

/// Leading English (RTGS) administrative-area prefixes stripped by
/// [normalizeName]. They are compared against the already-lowercased string, so
/// they are listed in lowercase here. Each carries its trailing space so it
/// only matches when used as a real prefix word.
const List<String> _englishPrefixes = [
  'changwat ',
  'amphoe ',
  'khwaeng ',
  'tambon ',
  'khet ',
];

/// Matches any run of (Unicode) whitespace.
final RegExp _whitespace = RegExp(r'\s+');

/// Canonicalizes an administrative-area name for matching. It:
///
///   - trims surrounding whitespace and collapses internal runs of whitespace
///     to a single ASCII space,
///   - lowercases the string (affecting only the ASCII/Latin parts; Thai has
///     no case), and
///   - strips a single leading Thai or English administrative prefix
///     ("จังหวัด"/"changwat ", "อำเภอ"/"อ."/"amphoe ", "เขต"/"khet ",
///     "ตำบล"/"ต."/"tambon ", "แขวง"/"khwaeng ", "กิ่งอำเภอ").
///
/// A prefix is never stripped when it constitutes the entire remaining name, so
/// the district name "เมือง" is preserved rather than reduced to "".
///
/// Unlike the Go original this does NOT apply Unicode NFC normalization: the
/// Dart core library ships no NFC implementation, and the embedded dataset is
/// already NFC, so composed/decomposed folding is unnecessary in practice.
/// Everything else (whitespace, casing, prefix stripping) is identical.
String normalizeName(String s) {
  // Collapse whitespace: split on any whitespace run, drop empties (which also
  // trims the ends) and rejoin with a single ASCII space.
  s = s.split(_whitespace).where((p) => p.isNotEmpty).join(' ');
  if (s.isEmpty) return '';

  // Lowercase for case-insensitive EN matching; harmless for Thai.
  s = s.toLowerCase();

  return _stripPrefix(s);
}

/// Removes a single leading admin prefix from an already
/// lowercased/whitespace-collapsed string, unless doing so would empty it.
String _stripPrefix(String s) {
  // English prefixes already include a trailing space, so a non-empty
  // remainder is guaranteed when they match.
  for (final p in _englishPrefixes) {
    if (s.startsWith(p)) {
      final rest = s.substring(p.length).trim();
      if (rest.isNotEmpty) return rest;
      return s;
    }
  }
  for (final p in _thaiPrefixes) {
    if (s.startsWith(p) && s.length > p.length) {
      final rest = s.substring(p.length).trim();
      if (rest.isNotEmpty) return rest;
    }
  }
  return s;
}
