// Runnable example: `dart run example/example.dart`.
import 'package:thai_provinces/thai_provinces.dart';

void main() {
  // 1. Look up by official DOPA code and read Thai/English names + region.
  final bangkok = provinceByCode(10);
  if (bangkok != null) {
    print('${bangkok.nameTh} / ${bangkok.nameEn} — ${bangkok.region.nameEn}');
    // กรุงเทพมหานคร / Bangkok — Central
  }

  // 2. Navigate the hierarchy: province -> districts -> subdistricts.
  final chiangMai = provinceByCode(50);
  if (chiangMai != null) {
    print('${chiangMai.nameEn} has ${chiangMai.districts.length} districts');
    final muang = chiangMai.districts.first;
    print('  first district: ${muang.nameTh} (${muang.code})');
    print('  postcodes: ${muang.postcodes}');
  }

  // 3. Walk back up from a subdistrict.
  final s = subdistrictByCode(100101);
  if (s != null) {
    print('${s.nameTh} -> ${s.district?.nameTh} -> ${s.province?.nameTh}');
  }

  // 4. Find by postal code (one zip commonly covers several subdistricts).
  print('Subdistricts using 50200:');
  for (final sub in byPostcode(50200)) {
    print('  ${sub.nameEn}, ${sub.province?.nameEn}');
  }

  // 5. Autocomplete (normalized prefix search).
  final hits = searchProvinces('เชียง');
  print('Provinces starting with "เชียง": '
      '${hits.map((p) => p.nameTh).join(', ')}');

  // 6. Resolve a free-text address to a concrete place.
  try {
    final matches = resolve(const AddressQuery(
      subdistrict: 'ในเมือง',
      district: 'เมืองขอนแก่น',
      province: 'ขอนแก่น',
    ));
    final m = matches.first;
    print('Resolved: ${m.subdistrict.code} ${m.subdistrict.nameEn} '
        '(${m.subdistrict.postcode})');
    // Resolved: 400101 Nai Mueang (40000)
  } on ThaiAddressException catch (e) {
    print('No match: ${e.message}');
  }

  // 7. Validate a province/district/subdistrict code triple.
  try {
    validate(10, 1001, 100101);
    print('10/1001/100101 is valid');
  } on ThaiAddressException catch (e) {
    print('invalid: ${e.message}');
  }
}
