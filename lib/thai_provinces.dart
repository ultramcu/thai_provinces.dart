/// Thailand's administrative-area data — every province (จังหวัด), district
/// (อำเภอ/เขต) and subdistrict (ตำบล/แขวง) together with its postal code — plus
/// lookup, hierarchy navigation, name search, autocomplete and validation, all
/// served from data embedded in the package (no network, no files at runtime).
///
/// Codes are the official Department of Provincial Administration (DOPA)
/// geocodes: a 2-digit province code (10–96), a 4-digit district code whose
/// first two digits are the province, and a 6-digit subdistrict code whose
/// first four digits are the district. This makes the hierarchy derivable from
/// any code and lets callers store a single integer per level.
///
/// ```dart
/// final p = provinceByCode(10); // Bangkok
/// for (final d in p!.districts) { /* ... */ }
/// final subs = byPostcode(10200); // subdistricts using a zip
/// ```
///
/// Every model is JSON-serializable and self-describing: `toJson()` emits all
/// fields (a [Province]'s region as its int `region` code), and the matching
/// `fromJson` factory rebuilds the value without any dataset lookup, so
/// `X.fromJson(x.toJson()) == x`.
///
/// ```dart
/// import 'dart:convert';
///
/// final p = provinceByCode(10)!;
/// final wire = jsonEncode(p.toJson());            // {"code":10,...,"region":2}
/// final back = Province.fromJson(jsonDecode(wire) as Map<String, dynamic>);
/// assert(back == p);
/// ```
///
/// Thai subdistrict names are not unique — many names repeat across provinces
/// (e.g. "ในเมือง") — so name lookups return lists; resolve to a single place
/// with the province/district context or a postal code.
///
/// The embedded dataset is a snapshot of github.com/kongvut/thai-province-data
/// (MIT), validated against DOPA.
library;

export 'src/data.dart'
    show
        provinces,
        districts,
        subdistricts,
        provinceByCode,
        districtByCode,
        subdistrictByCode,
        districtsOf,
        subdistrictsOf,
        byPostcode,
        postcodesOf;
export 'src/models.dart' show Province, District, Subdistrict;
export 'src/normalize.dart' show normalizeName;
export 'src/parse.dart' show ThaiAddressParseResult, parseThaiAddress;
export 'src/region.dart' show Region;
export 'src/resolve.dart'
    show
        validate,
        resolve,
        AddressQuery,
        AddressMatch,
        ThaiAddressException,
        ThaiAddressErrorKind;
export 'src/search.dart'
    show
        findProvinces,
        findDistricts,
        findSubdistricts,
        searchProvinces,
        searchDistricts,
        searchSubdistricts;
