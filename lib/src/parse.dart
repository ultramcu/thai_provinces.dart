import 'data.dart';
import 'models.dart';
import 'search.dart';

/// The outcome of [parseThaiAddress]: the administrative levels recognised in a
/// free-text Thai address, plus whatever free text was left over.
///
/// The parser is best-effort. Any of [province], [district], [subdistrict] and
/// [postcode] may be `null` when the input did not pin that level
/// unambiguously; the parser never guesses a level it cannot determine from the
/// text. Whatever the parser could not attribute to an administrative level —
/// typically the house number, หมู่/หมู่บ้าน, ถนน/ซอย — survives in
/// [remainder].
class ThaiAddressParseResult {
  /// Creates a result. Normally obtained from [parseThaiAddress].
  const ThaiAddressParseResult({
    this.province,
    this.district,
    this.subdistrict,
    this.postcode,
    this.remainder = '',
  });

  /// The recognised province (จังหวัด), or `null` if none could be pinned.
  final Province? province;

  /// The recognised district (อำเภอ/เขต), or `null` if none could be pinned.
  final District? district;

  /// The recognised subdistrict (ตำบล/แขวง), or `null` if none could be pinned.
  final Subdistrict? subdistrict;

  /// The 5-digit postal code found in the text, or `null` if none.
  ///
  /// This is reported *as found* in the input. On contradictory input — a
  /// marked area whose own postcode differs from the typed one — the parser
  /// trusts the marked names for the admin chain and keeps this postcode
  /// unchanged, so it may not equal the resolved area's postcode. The resolved
  /// [province]/[district]/[subdistrict] chain itself is always internally
  /// consistent.
  final int? postcode;

  /// The leftover free text (house number, road, village, …) after the matched
  /// postcode and administrative-area tokens were removed, with whitespace
  /// collapsed and trimmed. `''` when nothing is left over.
  final String remainder;

  /// Whether all three administrative levels were resolved.
  bool get isComplete =>
      province != null && district != null && subdistrict != null;

  /// Whether nothing administrative was recognised at all (no province,
  /// district, subdistrict or postcode). [remainder] may still be non-empty.
  bool get isEmpty =>
      province == null &&
      district == null &&
      subdistrict == null &&
      postcode == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThaiAddressParseResult &&
          other.province == province &&
          other.district == district &&
          other.subdistrict == subdistrict &&
          other.postcode == postcode &&
          other.remainder == remainder;

  @override
  int get hashCode =>
      Object.hash(province, district, subdistrict, postcode, remainder);

  @override
  String toString() => 'ThaiAddressParseResult('
      'province: ${province?.nameTh}, '
      'district: ${district?.nameTh}, '
      'subdistrict: ${subdistrict?.nameTh}, '
      'postcode: $postcode, '
      'remainder: "$remainder")';
}

/// Bangkok aliases that stand in for "province กรุงเทพมหานคร" (code 10).
const List<String> _bangkokAliases = [
  'กรุงเทพมหานคร',
  'กรุงเทพฯ',
  'กรุงเทพ',
  'กทม.',
  'กทม',
];

/// Province markers, longest first so "จังหวัด" wins over "จ.".
const List<String> _provinceMarkers = ['จังหวัด', 'จ.'];

/// District markers, longest first.
const List<String> _districtMarkers = ['อำเภอ', 'เขต', 'อ.'];

/// Subdistrict markers, longest first.
const List<String> _subdistrictMarkers = ['ตำบล', 'แขวง', 'ต.'];

/// Maps Thai digits ๐–๙ (U+0E50–U+0E59) onto Arabic 0–9.
String _arabicizeDigits(String s) {
  final buf = StringBuffer();
  for (final rune in s.runes) {
    if (rune >= 0x0E50 && rune <= 0x0E59) {
      buf.writeCharCode(0x30 + (rune - 0x0E50));
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}

/// A half-open span of the working string that has been consumed by a match
/// and must be excised from the remainder.
class _Span {
  _Span(this.start, this.end);
  final int start;
  final int end;
}

/// Parses a free-text Thai address into its administrative levels.
///
/// The parser combines two signals and reconciles them so they always agree:
///
///   1. **Postcode** — the first 5-digit run (Thai digits ๐–๙ are accepted and
///      normalised) that [byPostcode] recognises. Its subdistricts form a
///      candidate set; the result is pinned only to the province/district that
///      *all* of those subdistricts share, because one postcode can span
///      several districts (and occasionally provinces).
///   2. **Marked names** — tokens introduced by an area marker:
///      จังหวัด/จ. for the province (plus the Bangkok aliases กทม/กทม./กรุงเทพ/
///      กรุงเทพฯ/กรุงเทพมหานคร, all → code 10), อำเภอ/อ./เขต for the district,
///      and ตำบล/ต./แขวง for the subdistrict. Each name is resolved with the
///      package name lookups. A bare name with no marker is **not** scanned for;
///      it is left in the remainder rather than guessed at.
///
/// The signals are intersected: a subdistrict must belong to the chosen
/// district, which must belong to the chosen province, and everything must be
/// consistent with the postcode candidate set. Thai subdistrict (and district)
/// names repeat across provinces; the duplicate is resolved using the postcode
/// and the higher levels. If a level stays ambiguous it is left `null` rather
/// than guessed.
///
/// The matched postcode and consumed area tokens are removed from the input;
/// the collapsed, trimmed leftover (house number, หมู่/หมู่บ้าน, ถนน/ซอย, …) is
/// returned in [ThaiAddressParseResult.remainder].
///
/// This function never throws: malformed or unrelated input yields an
/// `isEmpty` result whose remainder is the cleaned input.
ThaiAddressParseResult parseThaiAddress(String input) {
  // Work on an Arabic-digit copy so postcode scanning is uniform; offsets line
  // up 1:1 with the original because the substitution is per-code-unit.
  final work = _arabicizeDigits(input);
  final spans = <_Span>[];

  // ---- 1. Postcode ---------------------------------------------------------
  int? postcode;
  List<Subdistrict>? postcodeCandidates;
  final zipRe = RegExp(r'\d{5}');
  for (final m in zipRe.allMatches(work)) {
    final value = int.parse(m.group(0)!);
    final subs = byPostcode(value);
    if (subs.isNotEmpty) {
      postcode = value;
      postcodeCandidates = subs;
      spans.add(_Span(m.start, m.end));
      break; // first valid postcode wins
    }
  }

  // ---- 2. Marked names -----------------------------------------------------
  // Collect candidate code sets at each level from the markers we find.
  final List<District> markedDistricts = [];
  final List<Subdistrict> markedSubdistricts = [];
  Province? markedProvince;

  // Province via Bangkok aliases (longest alias first to consume the most).
  for (final alias in _bangkokAliases) {
    final i = work.indexOf(alias);
    if (i >= 0) {
      markedProvince = provinceByCode(10);
      spans.add(_Span(i, i + alias.length));
      break;
    }
  }
  // Province via จังหวัด/จ. marker.
  if (markedProvince == null) {
    final hit = _afterMarker(work, _provinceMarkers);
    if (hit != null) {
      final ps = findProvinces(hit.name);
      if (ps.isNotEmpty) {
        markedProvince = ps.first; // province names are unique
        spans.add(hit.span);
      }
    }
  }
  // District via อำเภอ/อ./เขต.
  final dHit = _afterMarker(work, _districtMarkers);
  if (dHit != null) {
    final ds = findDistricts(dHit.name);
    if (ds.isNotEmpty) {
      markedDistricts.addAll(ds);
      spans.add(dHit.span);
    }
  }
  // Subdistrict via ตำบล/ต./แขวง.
  final sHit = _afterMarker(work, _subdistrictMarkers);
  if (sHit != null) {
    final ss = findSubdistricts(sHit.name);
    if (ss.isNotEmpty) {
      markedSubdistricts.addAll(ss);
      spans.add(sHit.span);
    }
  }

  // ---- 3. Reconcile --------------------------------------------------------
  // Start from the postcode candidate set (if any), then narrow by the marked
  // levels, keeping the hierarchy consistent. Province/district are only pinned
  // when unambiguous.
  Province? province = markedProvince;
  List<District> districtPool =
      markedDistricts.isNotEmpty ? List.of(markedDistricts) : const [];
  List<Subdistrict> subPool =
      markedSubdistricts.isNotEmpty ? List.of(markedSubdistricts) : const [];

  // If we have a postcode, it constrains every level.
  if (postcodeCandidates != null) {
    // Intersect subdistrict pool with the postcode's subdistricts.
    if (subPool.isNotEmpty) {
      final allowed = postcodeCandidates.map((s) => s.code).toSet();
      final narrowed = subPool.where((s) => allowed.contains(s.code)).toList();
      // Keep the narrowing only if it left something; otherwise the marked
      // subdistrict disagrees with the postcode — trust the marked name but
      // also keep the postcode for its own province/district pinning.
      if (narrowed.isNotEmpty) subPool = narrowed;
    } else {
      // No subdistrict named: the postcode's subdistricts are the candidates,
      // used only to pin shared higher levels (not to choose a subdistrict).
      subPool = const [];
    }

    // Intersect district pool with districts represented by the postcode.
    final pcDistricts = postcodeCandidates.map((s) => s.districtCode).toSet();
    if (districtPool.isNotEmpty) {
      final narrowed =
          districtPool.where((d) => pcDistricts.contains(d.code)).toList();
      if (narrowed.isNotEmpty) districtPool = narrowed;
    } else if (pcDistricts.length == 1) {
      // No district named, but every postcode candidate shares one district:
      // pin it (the postcode agrees on the district even though the
      // subdistrict is ambiguous).
      final d = districtByCode(pcDistricts.first);
      if (d != null) districtPool = [d];
    }

    // Pin province from the postcode if every candidate shares one and we have
    // no conflicting marked province.
    final pcProvinces =
        postcodeCandidates.map((s) => s.districtCode ~/ 100).toSet();
    if (province == null && pcProvinces.length == 1) {
      province = provinceByCode(pcProvinces.first);
    }
  }

  // Narrow district pool by province context.
  if (province != null && districtPool.isNotEmpty) {
    final narrowed =
        districtPool.where((d) => d.provinceCode == province!.code).toList();
    if (narrowed.isNotEmpty) districtPool = narrowed;
  }
  // Narrow subdistrict pool by province context.
  if (province != null && subPool.isNotEmpty) {
    final narrowed =
        subPool.where((s) => s.districtCode ~/ 100 == province!.code).toList();
    if (narrowed.isNotEmpty) subPool = narrowed;
  }
  // Narrow subdistrict pool by district context.
  if (districtPool.length == 1 && subPool.isNotEmpty) {
    final dCode = districtPool.first.code;
    final narrowed = subPool.where((s) => s.districtCode == dCode).toList();
    if (narrowed.isNotEmpty) subPool = narrowed;
  }

  // Choose the subdistrict if exactly one remains.
  Subdistrict? subdistrict = subPool.length == 1 ? subPool.first : null;

  // If a subdistrict was chosen, it implies its district and province; fill any
  // gaps and let the implied values win (they are strictly more specific).
  if (subdistrict != null) {
    final impliedDistrict = districtByCode(subdistrict.districtCode);
    if (impliedDistrict != null &&
        (districtPool.isEmpty || districtPool.length > 1)) {
      districtPool = [impliedDistrict];
    }
    province ??= provinceByCode(subdistrict.districtCode ~/ 100);
  }

  // Choose the district if exactly one remains.
  District? district = districtPool.length == 1 ? districtPool.first : null;

  // District implies province; fill the gap.
  if (district != null) {
    province ??= provinceByCode(district.provinceCode);
  }

  // Final consistency guard: drop any level that contradicts a more specific
  // one (can only happen when a marked name disagreed with the postcode).
  if (district != null &&
      province != null &&
      district.provinceCode != province.code) {
    district = null;
  }
  if (subdistrict != null) {
    if (district != null && subdistrict.districtCode != district.code) {
      subdistrict = null;
    } else if (province != null &&
        subdistrict.districtCode ~/ 100 != province.code) {
      subdistrict = null;
    }
  }

  // ---- 4. Remainder --------------------------------------------------------
  final remainder = _stripSpans(input, spans);

  return ThaiAddressParseResult(
    province: province,
    district: district,
    subdistrict: subdistrict,
    postcode: postcode,
    remainder: remainder,
  );
}

/// A marker hit: the resolved name text and the span (marker + name) to excise.
class _MarkerHit {
  _MarkerHit(this.name, this.span);
  final String name;
  final _Span span;
}

/// Finds the first occurrence of any [markers] in [work] and grabs the area
/// name immediately following it. The name runs until a delimiter: whitespace,
/// an ASCII digit, a comma, or the start of another known marker. Returns
/// `null` if no marker is present or the trailing name is empty.
_MarkerHit? _afterMarker(String work, List<String> markers) {
  for (final marker in markers) {
    // A dotted abbreviation (จ./อ./ต.) is often written with a space before the
    // name (e.g. "ต. สุเทพ"); skip that gap so the name is still captured. The
    // long markers (จังหวัด/อำเภอ/ตำบล/แขวง/เขต) bind directly to the name.
    final skipGap = marker.endsWith('.');
    var from = 0;
    while (true) {
      final i = work.indexOf(marker, from);
      if (i < 0) break;
      var nameStart = i + marker.length;
      if (skipGap) {
        while (nameStart < work.length &&
            (work[nameStart] == ' ' || work[nameStart] == '\t')) {
          nameStart++;
        }
      }
      final nameEnd = _nameEnd(work, nameStart);
      final name = work.substring(nameStart, nameEnd).trim();
      if (name.isNotEmpty) {
        return _MarkerHit(name, _Span(i, nameEnd));
      }
      from = i + marker.length;
    }
  }
  return null;
}

/// All markers across every level, used to terminate a name run so that, e.g.,
/// "ต.บางรักอ.บางรัก" splits at the second marker even without whitespace.
const List<String> _allMarkers = [
  'จังหวัด',
  'อำเภอ',
  'ตำบล',
  'แขวง',
  'เขต',
  'จ.',
  'อ.',
  'ต.',
];

/// Returns the index where a name starting at [start] ends: at the first
/// whitespace, ASCII digit, comma, or the start of another known marker.
int _nameEnd(String work, int start) {
  var i = start;
  while (i < work.length) {
    final ch = work[i];
    if (ch == ' ' ||
        ch == '\t' ||
        ch == '\n' ||
        ch == '\r' ||
        ch == ',' ||
        (ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39)) {
      break;
    }
    var hitMarker = false;
    for (final m in _allMarkers) {
      // A marker only terminates the name if it does not start at `start`
      // itself (it is the boundary to the *next* token).
      if (i > start && work.startsWith(m, i)) {
        hitMarker = true;
        break;
      }
    }
    if (hitMarker) break;
    i++;
  }
  return i;
}

/// Removes the [spans] from [original], then collapses whitespace and trims.
String _stripSpans(String original, List<_Span> spans) {
  if (spans.isEmpty) {
    return original.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).join(' ');
  }
  // Sort and merge overlapping spans, then keep the gaps between them.
  final sorted = List.of(spans)..sort((a, b) => a.start - b.start);
  final merged = <_Span>[];
  for (final s in sorted) {
    if (merged.isEmpty || s.start > merged.last.end) {
      merged.add(_Span(s.start, s.end));
    } else if (s.end > merged.last.end) {
      merged[merged.length - 1] = _Span(merged.last.start, s.end);
    }
  }
  final buf = StringBuffer();
  var cursor = 0;
  for (final s in merged) {
    if (s.start > cursor) buf.write(original.substring(cursor, s.start));
    buf.write(' '); // gap so adjacent tokens don't fuse
    cursor = s.end;
  }
  if (cursor < original.length) buf.write(original.substring(cursor));
  return buf
      .toString()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .join(' ');
}
