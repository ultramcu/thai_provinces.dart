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
