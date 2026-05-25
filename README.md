# thai_provinces

ข้อมูลเขตการปกครองของประเทศไทย (จังหวัด/อำเภอ/ตำบล พร้อมรหัสไปรษณีย์) สำหรับภาษา Dart ฝังข้อมูลมาในตัว ค้นหา/เติมคำอัตโนมัติ/ตรวจสอบที่อยู่ได้ทันที ไม่ต้องต่อเน็ต ไม่พึ่ง Flutter

A pure-Dart, MIT-licensed library of Thailand's administrative areas — 77
provinces (จังหวัด), 928 districts (อำเภอ/เขต), and 7,452 subdistricts (ตำบล/แขวง)
with postal codes — fully embedded, with lookup, hierarchy navigation,
autocomplete, validation, and address resolution. No network or files at
runtime, and **no Flutter dependency** (works in CLI, server and Flutter alike).

## Install

```yaml
dependencies:
  thai_provinces: ^0.1.0
```

```sh
dart pub add thai_provinces
```

Requires Dart SDK 3.0+.

## Features

- **Embedded dataset** — zero network/filesystem access at runtime; parsed once,
  lazily, on first use.
- **Complete coverage** — 77 provinces, 928 districts, 7,452 subdistricts, postcodes.
- **Official DOPA geocodes** — 2-digit provinces (10–96), 4-digit districts,
  6-digit subdistricts; the hierarchy is derivable
  (`districtCode ~/ 100 == provinceCode`, `subCode ~/ 100 == districtCode`).
- **Lookups by code** and **hierarchy navigation** (parent/child both ways).
- **Postal-code lookups** — subdistricts by postcode, or postcodes of a district.
- **Name search & autocomplete** — exact (normalized) find plus prefix search.
- **Validation** of a province/district/subdistrict triple.
- **Address resolution** — match free-form fragments (plus an optional postcode)
  to concrete `Province`/`District`/`Subdistrict` results.
- **Thai + English names** for every area, plus six regions.

## Quick start

### Look up by code and read names

```dart
import 'package:thai_provinces/thai_provinces.dart';

final p = provinceByCode(10);          // nullable; null if unknown
print('${p!.nameTh} / ${p.nameEn}');   // กรุงเทพมหานคร / Bangkok
print(p.region.nameEn);                // Central
```

### Navigate the hierarchy

```dart
final cm = provinceByCode(50);         // เชียงใหม่ / Chiang Mai

for (final d in cm!.districts) {
  print('${d.code} ${d.nameTh}');
  for (final s in d.subdistricts) {
    print('  ${s.code} ${s.nameTh} (${s.postcode})');
  }
}

// Walk back up from a subdistrict (nullable parents):
final s = subdistrictByCode(100101);
print('${s!.nameTh} -> ${s.district?.nameTh} -> ${s.province?.nameTh}');
```

### Find by postal code

```dart
for (final s in byPostcode(50200)) {
  print('${s.nameTh}, ${s.district?.nameTh}, ${s.province?.nameTh}');
}

// All postcodes within a district:
print(postcodesOf(5001)); // e.g. [50200, 50300, ...]
```

### Autocomplete (prefix search)

```dart
for (final s in searchSubdistricts('สุเทพ')) {
  print('${s.nameTh} — ${s.district?.nameTh}, ${s.province?.nameTh}');
}
```

### Resolve a full address

```dart
try {
  final matches = resolve(const AddressQuery(
    subdistrict: 'สุเทพ',
    district: 'เมืองเชียงใหม่',
    province: 'เชียงใหม่',
    postcode: 50200,
  ));
  for (final m in matches) {
    print('${m.province.nameTh} > ${m.district.nameTh} > '
        '${m.subdistrict.nameTh} (${m.subdistrict.postcode})');
  }
} on ThaiAddressException catch (e) {
  // no match / ambiguous / no usable field
  print(e.message);
}
```

### Validate a code triple

```dart
try {
  validate(50, 5001, 500101);
} on ThaiAddressException catch (e) {
  print('invalid address codes: ${e.message} (${e.kind})');
}
```

## Caveat: duplicate names

Many subdistrict names repeat across different provinces (e.g. "ในเมือง" occurs
in 22 provinces), so name-based lookups (`findSubdistricts`,
`searchSubdistricts`) return a **`List`**, not a single result. Disambiguate
with district/province context or a postcode — `resolve(AddressQuery(...))` is
built for exactly this.

Note also that Bangkok uses เขต/แขวง terminology (its district names carry the
"เขต" sense), and that postal codes attach at the subdistrict level — a single
district can span several postcodes.

## Notes on normalization (NFC)

`normalizeName` trims and collapses whitespace, lowercases (ASCII/Latin only;
Thai has no case), and strips one leading admin prefix
(จังหวัด/อำเภอ/อ./ตำบล/ต./เขต/แขวง/กิ่งอำเภอ and English changwat/amphoe/khet/
tambon/khwaeng). Unlike the Go original it does **not** apply Unicode NFC: the
Dart core library ships no NFC implementation, and the embedded dataset is
already NFC, so composed/decomposed folding is unnecessary in practice.

## Data source & license

This library is MIT-licensed (see [`LICENSE`](LICENSE)).

The embedded dataset is a reshaped snapshot of
[`github.com/kongvut/thai-province-data`](https://github.com/kongvut/thai-province-data)
by Kongvut Sangkla, used under the MIT License, with district codes validated
against the Department of Provincial Administration (DOPA) dataset. Official
two-digit province codes were derived and the field layout slimmed, but it is
the same underlying data.

This package is a faithful pure-Dart port of the Go library
[`go-thaiaddress`](https://github.com/ultramcu/go-thaiaddress).
