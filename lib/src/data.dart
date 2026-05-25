import 'dart:convert';

import 'data/areas_data.g.dart';
import 'models.dart';
import 'region.dart';

/// Holds the parsed dataset and its lookup indexes. Built once, on first use,
/// by [_load].
class _Store {
  _Store({
    required this.provinces,
    required this.districts,
    required this.subdistricts,
    required this.provinceByCode,
    required this.districtByCode,
    required this.subdistrictByCode,
    required this.districtsByProvince,
    required this.subdistrictsByDistrict,
    required this.byPostcode,
  });

  final List<Province> provinces;
  final List<District> districts;
  final List<Subdistrict> subdistricts;

  final Map<int, Province> provinceByCode;
  final Map<int, District> districtByCode;
  final Map<int, Subdistrict> subdistrictByCode;

  final Map<int, List<District>> districtsByProvince;
  final Map<int, List<Subdistrict>> subdistrictsByDistrict;
  final Map<int, List<Subdistrict>> byPostcode;
}

_Store? _data;

/// Parses [areasJson] once and builds every index. Subsequent calls return the
/// cached store.
_Store _load() {
  final cached = _data;
  if (cached != null) return cached;

  final Map<String, dynamic> j = json.decode(areasJson) as Map<String, dynamic>;

  final provinces = <Province>[];
  final districts = <District>[];
  final subdistricts = <Subdistrict>[];

  final provinceByCode = <int, Province>{};
  final districtByCode = <int, District>{};
  final subdistrictByCode = <int, Subdistrict>{};

  final districtsByProvince = <int, List<District>>{};
  final subdistrictsByDistrict = <int, List<Subdistrict>>{};
  final byPostcode = <int, List<Subdistrict>>{};

  for (final raw in (j['provinces'] as List)) {
    final m = raw as Map<String, dynamic>;
    final p = Province(
      code: m['code'] as int,
      nameTh: m['th'] as String,
      nameEn: m['en'] as String,
      // Unknown region codes fall back to central; the dataset only uses 1..6.
      region: Region.fromCode(m['region'] as int) ?? Region.central,
    );
    provinces.add(p);
    provinceByCode[p.code] = p;
  }

  for (final raw in (j['districts'] as List)) {
    final m = raw as Map<String, dynamic>;
    final d = District(
      code: m['code'] as int,
      provinceCode: m['province'] as int,
      nameTh: m['th'] as String,
      nameEn: m['en'] as String,
    );
    districts.add(d);
    districtByCode[d.code] = d;
    (districtsByProvince[d.provinceCode] ??= <District>[]).add(d);
  }

  for (final raw in (j['subdistricts'] as List)) {
    final m = raw as Map<String, dynamic>;
    final s = Subdistrict(
      code: m['code'] as int,
      districtCode: m['district'] as int,
      nameTh: m['th'] as String,
      nameEn: m['en'] as String,
      postcode: m['zip'] as int,
    );
    subdistricts.add(s);
    subdistrictByCode[s.code] = s;
    (subdistrictsByDistrict[s.districtCode] ??= <Subdistrict>[]).add(s);
    (byPostcode[s.postcode] ??= <Subdistrict>[]).add(s);
  }

  // Keep every list ordered by code for stable, deterministic output.
  provinces.sort((a, b) => a.code - b.code);
  districts.sort((a, b) => a.code - b.code);
  subdistricts.sort((a, b) => a.code - b.code);
  for (final v in districtsByProvince.values) {
    v.sort((a, b) => a.code - b.code);
  }
  for (final v in subdistrictsByDistrict.values) {
    v.sort((a, b) => a.code - b.code);
  }
  for (final v in byPostcode.values) {
    v.sort((a, b) => a.code - b.code);
  }

  final store = _Store(
    provinces: provinces,
    districts: districts,
    subdistricts: subdistricts,
    provinceByCode: provinceByCode,
    districtByCode: districtByCode,
    subdistrictByCode: subdistrictByCode,
    districtsByProvince: districtsByProvince,
    subdistrictsByDistrict: subdistrictsByDistrict,
    byPostcode: byPostcode,
  );
  _data = store;
  return store;
}

/// All 77 provinces, ordered by code.
List<Province> provinces() => List.unmodifiable(_load().provinces);

/// Every district, ordered by code.
List<District> districts() => List.unmodifiable(_load().districts);

/// Every subdistrict, ordered by code.
List<Subdistrict> subdistricts() => List.unmodifiable(_load().subdistricts);

/// Looks up a province by its 2-digit code, or `null` if unknown.
Province? provinceByCode(int code) => _load().provinceByCode[code];

/// Looks up a district by its 4-digit code, or `null` if unknown.
District? districtByCode(int code) => _load().districtByCode[code];

/// Looks up a subdistrict by its 6-digit code, or `null` if unknown.
Subdistrict? subdistrictByCode(int code) => _load().subdistrictByCode[code];

/// The districts in a province (by 2-digit code), ordered by code. Empty if
/// the province is unknown.
List<District> districtsOf(int provinceCode) =>
    List.unmodifiable(_load().districtsByProvince[provinceCode] ?? const []);

/// The subdistricts in a district (by 4-digit code), ordered by code. Empty if
/// the district is unknown.
List<Subdistrict> subdistrictsOf(int districtCode) =>
    List.unmodifiable(_load().subdistrictsByDistrict[districtCode] ?? const []);

/// Every subdistrict that uses the given 5-digit postal code, ordered by code.
/// A postal code commonly maps to many subdistricts.
List<Subdistrict> byPostcode(int postcode) =>
    List.unmodifiable(_load().byPostcode[postcode] ?? const []);

/// The distinct postal codes used within a district (by 4-digit code), ordered
/// ascending. Empty if the district is unknown.
List<int> postcodesOf(int districtCode) {
  final subs = _load().subdistrictsByDistrict[districtCode];
  if (subs == null || subs.isEmpty) return const [];
  final seen = <int>{};
  final zips = <int>[];
  for (final s in subs) {
    if (seen.add(s.postcode)) zips.add(s.postcode);
  }
  zips.sort();
  return zips;
}
