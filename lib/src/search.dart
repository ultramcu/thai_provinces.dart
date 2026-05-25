import 'data.dart';
import 'models.dart';
import 'normalize.dart';

/// Returns every province whose Thai or English name matches [name] exactly
/// after normalization (see [normalizeName]), ordered by code. An
/// empty/whitespace query returns `[]`. Multiple results are possible only in
/// theory for provinces (names are unique), but the list form keeps the API
/// uniform with the district and subdistrict finders.
List<Province> findProvinces(String name) {
  final q = normalizeName(name);
  if (q.isEmpty) return const [];
  return [
    for (final p in provinces())
      if (normalizeName(p.nameTh) == q || normalizeName(p.nameEn) == q) p,
  ];
}

/// Returns every district whose Thai or English name matches [name] exactly
/// after normalization, ordered by code. Because [normalizeName] strips the
/// "เขต"/"khet " and "อำเภอ"/"amphoe " prefixes, "เขตพระนคร", "พระนคร" and
/// "อำเภอพระนคร" all match the same district. An empty/whitespace query returns
/// `[]`. District names repeat across provinces, so several matches are common.
List<District> findDistricts(String name) {
  final q = normalizeName(name);
  if (q.isEmpty) return const [];
  return [
    for (final d in districts())
      if (normalizeName(d.nameTh) == q || normalizeName(d.nameEn) == q) d,
  ];
}

/// Returns every subdistrict whose Thai or English name matches [name] exactly
/// after normalization, ordered by code. An empty/whitespace query returns
/// `[]`. Subdistrict names are highly non-unique (e.g. "ในเมือง" occurs in 22
/// provinces), so this commonly returns many results; disambiguate with
/// [resolve] using province/district/postcode context.
List<Subdistrict> findSubdistricts(String name) {
  final q = normalizeName(name);
  if (q.isEmpty) return const [];
  return [
    for (final s in subdistricts())
      if (normalizeName(s.nameTh) == q || normalizeName(s.nameEn) == q) s,
  ];
}

/// Returns every province whose normalized Thai or English name begins with the
/// normalized [prefix], ordered by code. Intended for autocomplete. An
/// empty/whitespace prefix returns `[]` (rather than every province).
List<Province> searchProvinces(String prefix) {
  final q = normalizeName(prefix);
  if (q.isEmpty) return const [];
  return [
    for (final p in provinces())
      if (normalizeName(p.nameTh).startsWith(q) ||
          normalizeName(p.nameEn).startsWith(q))
        p,
  ];
}

/// Returns every district whose normalized Thai or English name begins with the
/// normalized [prefix], ordered by code. An empty/whitespace prefix returns
/// `[]`.
List<District> searchDistricts(String prefix) {
  final q = normalizeName(prefix);
  if (q.isEmpty) return const [];
  return [
    for (final d in districts())
      if (normalizeName(d.nameTh).startsWith(q) ||
          normalizeName(d.nameEn).startsWith(q))
        d,
  ];
}

/// Returns every subdistrict whose normalized Thai or English name begins with
/// the normalized [prefix], ordered by code. An empty/whitespace prefix returns
/// `[]`.
List<Subdistrict> searchSubdistricts(String prefix) {
  final q = normalizeName(prefix);
  if (q.isEmpty) return const [];
  return [
    for (final s in subdistricts())
      if (normalizeName(s.nameTh).startsWith(q) ||
          normalizeName(s.nameEn).startsWith(q))
        s,
  ];
}
