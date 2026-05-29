## 0.2.0

- JSON serialization for every model. `Province`, `District`, `Subdistrict` and
  `AddressMatch` gain a `toJson()` that emits all fields (self-describing) and a
  `fromJson` factory that reconstructs purely from the map — no dataset lookup.
  A `Province`'s region is serialized as its integer `region` code (1..6) and
  rebuilt via `Region.fromCode`; `AddressMatch` nests the province/district/
  subdistrict JSON. Round-trip guarantee: `X.fromJson(x.toJson()) == x`
  (including through a real `jsonEncode`/`jsonDecode` string).
- Every `fromJson` factory throws a `FormatException` — naming the offending
  class and key — on any malformed input (an unknown region code, or a missing
  or wrongly-typed key), so all decode failures share one catchable type.
- Integer fields accept a whole-number `double` (e.g. `2.0`) in addition to an
  `int`, for tolerance of JSON producers that emit integral values as doubles.

## 0.1.1

- Shorten the package description to pub.dev's 60–180 char range (pub points 150→160). No code changes.

## 0.1.0

- Initial release. Pure-Dart port of `go-thaiaddress`.
- Embedded dataset: 77 provinces, 928 districts, 7,452 subdistricts with postal
  codes and six regions, served offline (no network, no files at runtime).
- Lookup by official DOPA geocode: `provinceByCode`, `districtByCode`,
  `subdistrictByCode`.
- Hierarchy navigation on the models (`Province.districts`, `District.province`,
  `District.subdistricts`, `District.postcodes`, `Subdistrict.district`,
  `Subdistrict.province`) and via `districtsOf`, `subdistrictsOf`,
  `byPostcode`, `postcodesOf`.
- Name layer: `normalizeName` (whitespace collapse, lowercasing, admin-prefix
  stripping), exact finders (`findProvinces`/`findDistricts`/`findSubdistricts`)
  and prefix autocomplete (`searchProvinces`/`searchDistricts`/
  `searchSubdistricts`).
- Validation and resolution: `validate`, `resolve` with `AddressQuery`,
  `AddressMatch` and `ThaiAddressException`.
