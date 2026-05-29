import 'dart:convert';

import 'package:thai_provinces/thai_provinces.dart';
import 'package:test/test.dart';

bool _isSorted(List<int> xs) {
  for (var i = 1; i < xs.length; i++) {
    if (xs[i - 1] > xs[i]) return false;
  }
  return true;
}

void main() {
  group('data smoke', () {
    test('counts 77 / 928 / 7452', () {
      expect(provinces().length, 77);
      expect(districts().length, 928);
      expect(subdistricts().length, 7452);
    });

    test('provinceByCode(10) is Bangkok, region central', () {
      final bkk = provinceByCode(10);
      expect(bkk, isNotNull);
      expect(bkk!.nameEn, 'Bangkok');
      expect(bkk.nameTh, 'กรุงเทพมหานคร');
      expect(bkk.region, Region.central);
    });

    test('districtByCode(1001).provinceCode == 10', () {
      final d = districtByCode(1001);
      expect(d, isNotNull);
      expect(d!.provinceCode, 10);
    });

    test('subdistrictByCode(100101) district 1001, postcode 10200', () {
      final s = subdistrictByCode(100101);
      expect(s, isNotNull);
      expect(s!.districtCode, 1001);
      expect(s.postcode, 10200);
      // sub -> province walks up correctly.
      expect(s.province?.code, 10);
    });

    test('subdistrictByCode(500101) belongs to district 5001', () {
      final s = subdistrictByCode(500101);
      expect(s, isNotNull);
      expect(s!.districtCode, 5001);
    });

    test('unknown codes return null', () {
      expect(provinceByCode(99), isNull);
      expect(districtByCode(9999), isNull);
      expect(subdistrictByCode(999999), isNull);
    });

    test('byPostcode(10200) is non-empty', () {
      expect(byPostcode(10200), isNotEmpty);
    });

    test('referential integrity: every district -> province resolves', () {
      for (final d in districts()) {
        expect(provinceByCode(d.provinceCode), isNotNull,
            reason: 'district ${d.code} orphan province ${d.provinceCode}');
      }
    });

    test('referential integrity: every subdistrict -> district resolves', () {
      for (final s in subdistricts()) {
        expect(districtByCode(s.districtCode), isNotNull,
            reason: 'subdistrict ${s.code} orphan district ${s.districtCode}');
      }
    });

    test('lists are ordered by code', () {
      expect(_isSorted(provinces().map((p) => p.code).toList()), isTrue);
      expect(_isSorted(districts().map((d) => d.code).toList()), isTrue);
      expect(_isSorted(subdistricts().map((s) => s.code).toList()), isTrue);
    });

    test('returned lists are unmodifiable', () {
      expect(() => provinces().add(provinces().first), throwsUnsupportedError);
    });
  });

  group('hierarchy navigation', () {
    test('Chiang Mai (50) has 25 districts', () {
      final cm = provinceByCode(50);
      expect(cm, isNotNull);
      expect(cm!.districts.length, 25);
    });

    test('District.province / subdistricts / postcodes', () {
      final d = districtByCode(5001)!;
      expect(d.province?.code, 50);
      expect(d.subdistricts, isNotEmpty);
      expect(d.postcodes, isNotEmpty);
      expect(_isSorted(d.postcodes), isTrue);
    });

    test('districtsOf / subdistrictsOf unknown -> empty', () {
      expect(districtsOf(99), isEmpty);
      expect(subdistrictsOf(9999), isEmpty);
      expect(postcodesOf(9999), isEmpty);
    });
  });

  group('normalizeName', () {
    final cases = <List<String>>[
      // Whitespace handling.
      ['  Bangkok  ', 'bangkok'],
      ['Chiang   Mai', 'chiang mai'],
      ['Nakhon\tSi\nThammarat', 'nakhon si thammarat'],
      ['', ''],
      ['   \t\n ', ''],
      // Lowercasing.
      ['MUEANG CHIANG MAI', 'mueang chiang mai'],
      // Thai prefix stripping.
      ['จังหวัดเชียงใหม่', 'เชียงใหม่'],
      ['อำเภอเมืองเชียงใหม่', 'เมืองเชียงใหม่'],
      ['อ.จอมทอง', 'จอมทอง'],
      ['ตำบลในเมือง', 'ในเมือง'],
      ['ต.สุเทพ', 'สุเทพ'],
      ['เขตพระนคร', 'พระนคร'],
      ['แขวงพระบรมมหาราชวัง', 'พระบรมมหาราชวัง'],
      ['กิ่งอำเภอทุ่งช้าง', 'ทุ่งช้าง'],
      // English prefix stripping (case-insensitive via prior lowercasing).
      ['Changwat Chiang Mai', 'chiang mai'],
      ['Amphoe Mueang Chiang Mai', 'mueang chiang mai'],
      ['Khet Phra Nakhon', 'phra nakhon'],
      ['Tambon Nai Mueang', 'nai mueang'],
      ['Khwaeng Phra Borom Maha Ratchawang', 'phra borom maha ratchawang'],
      ['aMpHoE Chom Thong', 'chom thong'],
      // Do NOT strip a prefix that is the whole string.
      ['เมือง', 'เมือง'],
      ['เขต', 'เขต'],
      ['อำเภอ', 'อำเภอ'],
      ['ตำบล', 'ตำบล'],
      ['Khet', 'khet'],
      ['Amphoe', 'amphoe'],
      // Only one leading prefix is stripped.
      ['ตำบลตำบล', 'ตำบล'],
    ];

    for (final c in cases) {
      test('normalizeName(${c[0].replaceAll('\n', r'\n')}) == ${c[1]}', () {
        expect(normalizeName(c[0]), c[1]);
      });
    }

    test('spec equivalences', () {
      expect(normalizeName('อำเภอเมืองเชียงใหม่'), 'เมืองเชียงใหม่');
      expect(normalizeName('เขตพระนคร'), 'พระนคร');
      expect(normalizeName('อำเภอเมืองเชียงใหม่'),
          normalizeName('เมืองเชียงใหม่'));
      expect(normalizeName('เขตพระนคร'), normalizeName('พระนคร'));
    });
  });

  group('find*', () {
    test('findProvinces exact / prefix-tolerant / empty', () {
      expect(findProvinces('เชียงใหม่').map((p) => p.code), [50]);
      expect(findProvinces('Chiang Mai').map((p) => p.code), [50]);
      expect(findProvinces('chiang mai').map((p) => p.code), [50]);
      expect(findProvinces('Changwat Chiang Mai').map((p) => p.code), [50]);
      expect(findProvinces('จังหวัดเชียงใหม่').map((p) => p.code), [50]);
      expect(findProvinces('Bangkok').map((p) => p.code), [10]);
      expect(findProvinces('กรุงเทพมหานคร').map((p) => p.code), [10]);
      expect(findProvinces(''), isEmpty);
      expect(findProvinces('   '), isEmpty);
      expect(findProvinces('Atlantis'), isEmpty);
    });

    test('findDistricts handles เขต/อำเภอ prefixes and EN', () {
      for (final q in [
        'เขตพระนคร',
        'พระนคร',
        'Khet Phra Nakhon',
        'Phra Nakhon',
        'phra nakhon',
      ]) {
        expect(findDistricts(q).any((d) => d.code == 1001), isTrue,
            reason: 'findDistricts($q) should include 1001');
      }
      for (final q in [
        'เมืองเชียงใหม่',
        'อำเภอเมืองเชียงใหม่',
        'Mueang Chiang Mai',
      ]) {
        final got = findDistricts(q);
        expect(got.length, 1);
        expect(got.first.code, 5001);
      }
      expect(findDistricts(''), isEmpty);
      expect(findDistricts('   '), isEmpty);
    });

    test('findSubdistricts duplicate names (ในเมือง)', () {
      final dup = findSubdistricts('ในเมือง');
      expect(dup.length, greaterThan(1));
      expect(dup.length, 22);
      expect(_isSorted(dup.map((s) => s.code).toList()), isTrue);
      // ตำบล prefix must not change the result.
      expect(findSubdistricts('ตำบลในเมือง').length, dup.length);
      // Bangkok แขวง by EN name.
      expect(
          findSubdistricts('Phra Borom Maha Ratchawang')
              .any((s) => s.code == 100101),
          isTrue);
      expect(findSubdistricts(''), isEmpty);
    });
  });

  group('search* (autocomplete)', () {
    test('searchProvinces prefix EN/TH and empty', () {
      final got = searchProvinces('Chiang').map((p) => p.code).toList();
      expect(got, contains(50));
      expect(got, contains(57));
      expect(_isSorted(got), isTrue);
      expect(searchProvinces('เชียง').map((p) => p.code), contains(50));
      expect(searchProvinces(''), isEmpty);
      expect(searchProvinces('   '), isEmpty);
    });

    test('searchDistricts prefix', () {
      final got = searchDistricts('Mueang Chiang').map((d) => d.code).toList();
      expect(got, contains(5001));
      expect(_isSorted(got), isTrue);
      expect(searchDistricts(''), isEmpty);
    });

    test('searchSubdistricts prefix', () {
      final got = searchSubdistricts('ในเมือง');
      expect(got.length, greaterThanOrEqualTo(22));
      expect(_isSorted(got.map((s) => s.code).toList()), isTrue);
      expect(searchSubdistricts(''), isEmpty);
    });
  });

  group('validate', () {
    test('happy paths do not throw', () {
      expect(() => validate(10, 1001, 100101), returnsNormally);
      expect(() => validate(50, 5001, 500101), returnsNormally);
    });

    test('province not found', () {
      expect(
          () => validate(99, 1001, 100101),
          throwsA(isA<ThaiAddressException>()
              .having((e) => e.kind, 'kind', ThaiAddressErrorKind.notFound)));
    });

    test('district not found', () {
      expect(
          () => validate(10, 9999, 100101),
          throwsA(isA<ThaiAddressException>()
              .having((e) => e.kind, 'kind', ThaiAddressErrorKind.notFound)));
    });

    test('subdistrict not found', () {
      expect(
          () => validate(10, 1001, 999999),
          throwsA(isA<ThaiAddressException>()
              .having((e) => e.kind, 'kind', ThaiAddressErrorKind.notFound)));
    });

    test('zero codes are not found', () {
      expect(() => validate(10, 1001, 0), throwsA(isA<ThaiAddressException>()));
      expect(
          () => validate(10, 0, 100101), throwsA(isA<ThaiAddressException>()));
      expect(() => validate(0, 1001, 100101),
          throwsA(isA<ThaiAddressException>()));
    });

    test('district in wrong province -> inconsistent', () {
      expect(
          () => validate(50, 1001, 100101),
          throwsA(isA<ThaiAddressException>().having(
              (e) => e.kind, 'kind', ThaiAddressErrorKind.inconsistent)));
    });

    test('subdistrict in wrong district -> inconsistent', () {
      expect(
          () => validate(10, 1002, 100101),
          throwsA(isA<ThaiAddressException>().having(
              (e) => e.kind, 'kind', ThaiAddressErrorKind.inconsistent)));
    });
  });

  group('resolve', () {
    test('subdistrict + district + province -> exactly one (400101)', () {
      final got = resolve(const AddressQuery(
        subdistrict: 'ในเมือง',
        district: 'เมืองขอนแก่น',
        province: 'ขอนแก่น',
      ));
      expect(got.length, 1);
      expect(got.first.subdistrict.code, 400101);
      expect(got.first.district.code, 4001);
      expect(got.first.province.code, 40);
    });

    test('same query with prefixes and EN resolves identically', () {
      final got = resolve(const AddressQuery(
        subdistrict: 'ตำบลในเมือง',
        district: 'Amphoe Mueang Khon Kaen',
        province: 'Changwat Khon Kaen',
      ));
      expect(got.length, 1);
      expect(got.first.subdistrict.code, 400101);
    });

    test('postcode + subdistrict narrows to one', () {
      final got =
          resolve(const AddressQuery(subdistrict: 'ในเมือง', postcode: 40000));
      expect(got.length, 1);
      expect(got.first.subdistrict.code, 400101);
    });

    test('postcode only returns all matches, code-ordered', () {
      final got = resolve(const AddressQuery(postcode: 10200));
      final want = byPostcode(10200);
      expect(got.length, want.length);
      for (var i = 0; i < got.length; i++) {
        expect(got[i].subdistrict.code, want[i].code);
      }
      expect(_isSorted(got.map((m) => m.subdistrict.code).toList()), isTrue);
    });

    test('ambiguous subdistrict + province narrows', () {
      final all = resolve(const AddressQuery(subdistrict: 'ในเมือง'));
      expect(all.length, 22);
      final narrowed = resolve(
          const AddressQuery(subdistrict: 'ในเมือง', province: 'ขอนแก่น'));
      expect(narrowed.length, lessThan(all.length));
    });

    test('not-found cases throw notFound', () {
      expect(
          () => resolve(const AddressQuery(subdistrict: 'ไม่มีจริง')),
          throwsA(isA<ThaiAddressException>()
              .having((e) => e.kind, 'kind', ThaiAddressErrorKind.notFound)));
      expect(
          () => resolve(const AddressQuery(
              subdistrict: 'ในเมือง', province: 'เชียงใหม่')),
          throwsA(isA<ThaiAddressException>()));
      expect(
          () => resolve(
              const AddressQuery(subdistrict: 'ในเมือง', postcode: 99999)),
          throwsA(isA<ThaiAddressException>()));
      expect(() => resolve(const AddressQuery(postcode: 99999)),
          throwsA(isA<ThaiAddressException>()));
    });

    test('no usable field throws', () {
      expect(() => resolve(const AddressQuery()),
          throwsA(isA<ThaiAddressException>()));
      expect(() => resolve(const AddressQuery(province: 'ขอนแก่น')),
          throwsA(isA<ThaiAddressException>()));
      expect(
          () => resolve(const AddressQuery(
              district: 'เมืองขอนแก่น', province: 'ขอนแก่น')),
          throwsA(isA<ThaiAddressException>()));
      expect(() => resolve(const AddressQuery(subdistrict: '   ')),
          throwsA(isA<ThaiAddressException>()));
    });
  });

  group('json serialization', () {
    // Round-trips through a real jsonEncode -> jsonDecode string, which is the
    // contract advertised in the docs. Decoding always yields a fresh map of
    // Dart-native types, so this exercises the fromJson casts honestly.
    Map<String, dynamic> wire(Map<String, dynamic> json) =>
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

    test('every province round-trips through a JSON string', () {
      for (final p in provinces()) {
        final back = Province.fromJson(wire(p.toJson()));
        expect(back, p);
        expect(back.hashCode, p.hashCode);
      }
    });

    test('every district round-trips through a JSON string', () {
      for (final d in districts()) {
        expect(District.fromJson(wire(d.toJson())), d);
      }
    });

    test('every subdistrict round-trips through a JSON string', () {
      for (final s in subdistricts()) {
        expect(Subdistrict.fromJson(wire(s.toJson())), s);
      }
    });

    test('AddressMatch nests and round-trips, == and hashCode hold', () {
      final m = resolve(const AddressQuery(
        subdistrict: 'ในเมือง',
        district: 'เมืองขอนแก่น',
        province: 'ขอนแก่น',
      )).first;
      final back = AddressMatch.fromJson(wire(m.toJson()));
      expect(back, m);
      expect(back.hashCode, m.hashCode);
    });

    test('region is emitted as its integer code, not the enum name', () {
      final bkk = provinceByCode(10)!; // Bangkok, region central (code 2)
      expect(bkk.toJson(), {
        'code': 10,
        'nameTh': 'กรุงเทพมหานคร',
        'nameEn': 'Bangkok',
        'region': 2,
      });
      expect(jsonEncode(bkk.toJson()), contains('"region":2'));
    });

    test('district / subdistrict / AddressMatch wire shapes are pinned', () {
      // Literal expected maps (not derived from toJson) so a renamed or extra
      // serialized key that == happens to ignore is still caught.
      expect(districtByCode(1001)!.toJson(), {
        'code': 1001,
        'provinceCode': 10,
        'nameTh': 'เขตพระนคร',
        'nameEn': 'Khet Phra Nakhon',
      });
      expect(subdistrictByCode(100101)!.toJson(), {
        'code': 100101,
        'districtCode': 1001,
        'nameTh': 'พระบรมมหาราชวัง',
        'nameEn': 'Phra Borom Maha Ratchawang',
        'postcode': 10200,
      });
      final match = resolve(const AddressQuery(
        subdistrict: 'พระบรมมหาราชวัง',
        postcode: 10200,
      )).first;
      expect(match.toJson(), {
        'province': {
          'code': 10,
          'nameTh': 'กรุงเทพมหานคร',
          'nameEn': 'Bangkok',
          'region': 2,
        },
        'district': {
          'code': 1001,
          'provinceCode': 10,
          'nameTh': 'เขตพระนคร',
          'nameEn': 'Khet Phra Nakhon',
        },
        'subdistrict': {
          'code': 100101,
          'districtCode': 1001,
          'nameTh': 'พระบรมมหาราชวัง',
          'nameEn': 'Phra Borom Maha Ratchawang',
          'postcode': 10200,
        },
      });
    });

    test('Province.fromJson throws FormatException on an unknown region code',
        () {
      expect(
        () => Province.fromJson(
            {'code': 10, 'nameTh': 'x', 'nameEn': 'y', 'region': 99}),
        throwsFormatException,
      );
    });

    test('a missing required key throws FormatException', () {
      expect(
        () => Province.fromJson({'code': 10, 'nameTh': 'x', 'nameEn': 'y'}),
        throwsFormatException,
      );
      expect(
        () => District.fromJson(
            {'code': 1001, 'nameTh': 'x', 'nameEn': 'y'}), // no provinceCode
        throwsFormatException,
      );
      expect(
        () => AddressMatch.fromJson(
            {'province': provinceByCode(10)!.toJson()}), // no district
        throwsFormatException,
      );
    });

    test('a wrongly-typed key throws FormatException (not a raw TypeError)',
        () {
      expect(
        () => Province.fromJson(
            {'code': 'ten', 'nameTh': 'x', 'nameEn': 'y', 'region': 2}),
        throwsFormatException,
      );
      expect(
        () => Subdistrict.fromJson({
          'code': 100101,
          'districtCode': 1001,
          'nameTh': 'x',
          'nameEn': 'y',
          'postcode': 'not-a-number',
        }),
        throwsFormatException,
      );
    });

    test('integer fields accept a whole-number double', () {
      final p = Province.fromJson({
        'code': 10.0,
        'nameTh': 'กรุงเทพมหานคร',
        'nameEn': 'Bangkok',
        'region': 2.0,
      });
      expect(p, provinceByCode(10));
    });

    test('a non-integral double for an integer field throws FormatException',
        () {
      expect(
        () => Province.fromJson(
            {'code': 10.5, 'nameTh': 'x', 'nameEn': 'y', 'region': 2}),
        throwsFormatException,
      );
    });
  });
}
