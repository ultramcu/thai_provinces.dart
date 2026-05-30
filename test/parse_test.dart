// test/parse_test.dart
//
// Blind test suite for the public `parseThaiAddress` API contract.
// Authored against the PUBLIC CONTRACT + dataset GROUND TRUTH only;
// the implementation (lib/src/parse.dart) was NOT read.
//
// All asserted codes/postcodes were confirmed against the embedded dataset
// (lib/src/data/areas_data.g.dart). Dataset facts used:
//
//   Bangkok chain:
//     province 10  = กรุงเทพมหานคร / Bangkok
//     district 1001 = เขตพระนคร / Khet Phra Nakhon  (province 10)
//     subdistrict 100101 = พระบรมมหาราชวัง  (district 1001, zip 10200)
//
//   Chiang Mai chain:
//     province 50  = เชียงใหม่ / Chiang Mai
//     district 5001 = เมืองเชียงใหม่ / Mueang Chiang Mai  (province 50)
//     subdistrict 500108 = สุเทพ / Suthep  (district 5001, zip 50200)
//
//   Postcode 50200 -> 3 subdistricts, ALL in district 5001 / province 50
//     (single district, multiple subdistricts) — used for the postcode-only
//     district-pin / subdistrict-null case.
//
//   Postcode 10110 -> spans TWO districts 1033 (เขตคลองเตย) and 1039 (เขตวัฒนา),
//     both in province 10 — used for province-pinned / district-null case.
//
//   Subdistrict name หนองบัว occurs in 25 different provinces — used for the
//     ambiguous-repeated-name case.

import 'package:thai_provinces/thai_provinces.dart';
import 'package:test/test.dart';

void main() {
  group('parseThaiAddress - totality / never throws', () {
    // FAIL-BEFORE: if the parser throws on garbage / empty / digit-only /
    // marker-only input, these tests throw instead of returning a result.
    final inputs = <String>[
      '',
      '   ',
      'hello world',
      'this is not a thai address at all',
      '1234567890', // long digit run, not a 5-digit token
      'อำเภอ ตำบล จังหวัด', // bare markers, no names
      '99999', // 5 digits but not a real postcode
      'ก',
      '\n\t  \n',
    ];
    for (final s in inputs) {
      test('does not throw on: ${jsonSafe(s)}', () {
        expect(() => parseThaiAddress(s), returnsNormally);
      });
    }
  });

  group('parseThaiAddress - empty / garbage classification', () {
    test('empty string => isEmpty, remainder empty', () {
      // FAIL-BEFORE: if isEmpty wrongly considered postcode-only or returned a
      // non-empty remainder for '', this fails.
      final r = parseThaiAddress('');
      expect(r.isEmpty, isTrue);
      expect(r.isComplete, isFalse);
      expect(r.province, isNull);
      expect(r.district, isNull);
      expect(r.subdistrict, isNull);
      expect(r.postcode, isNull);
      expect(r.remainder, isEmpty);
    });

    test('pure garbage => isEmpty, garbage survives as remainder', () {
      // FAIL-BEFORE: if the parser hallucinated an area from random words, or
      // dropped the unmatched words from remainder, this fails.
      final r = parseThaiAddress('hello world');
      expect(r.isEmpty, isTrue);
      expect(r.province, isNull);
      expect(r.district, isNull);
      expect(r.subdistrict, isNull);
      expect(r.postcode, isNull);
      // remainder holds the leftover free text (whitespace-collapsed).
      expect(r.remainder.toLowerCase(), contains('hello'));
      expect(r.remainder.toLowerCase(), contains('world'));
    });

    test('isEmpty is false once any level OR postcode is set', () {
      // FAIL-BEFORE: if isEmpty ignored postcode and only looked at the three
      // name levels, a postcode-only parse would wrongly report isEmpty.
      final r = parseThaiAddress('10200');
      expect(r.postcode, 10200);
      expect(r.isEmpty, isFalse);
    });
  });

  group('parseThaiAddress - full Bangkok address with markers', () {
    // dataset: 100101 พระบรมมหาราชวัง / 1001 เขตพระนคร / 10 กรุงเทพมหานคร / zip 10200
    const input =
        '123/45 ถนนหน้าพระลาน แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200';

    test('resolves the complete Bangkok chain to exact codes', () {
      // FAIL-BEFORE: if the parser ignored the เขต/แขวง markers, mis-pinned the
      // province, or failed to combine name+postcode, any of these codes is
      // wrong or null and the test fails.
      final r = parseThaiAddress(input);
      expect(r.isComplete, isTrue);
      expect(r.province?.code, 10);
      expect(r.district?.code, 1001);
      expect(r.subdistrict?.code, 100101);
      expect(r.postcode, 10200);
      expect(r.isEmpty, isFalse);
    });

    test('remainder keeps house/road text and drops area words + postcode', () {
      // FAIL-BEFORE: if area marker words/names or the postcode leaked into the
      // remainder, or the house/road text was discarded, this fails.
      final r = parseThaiAddress(input);
      expect(r.remainder, contains('123/45'));
      expect(r.remainder, contains('หน้าพระลาน')); // road name survives
      // matched area tokens & postcode are removed:
      expect(r.remainder, isNot(contains('แขวง')));
      expect(r.remainder, isNot(contains('เขต')));
      expect(r.remainder, isNot(contains('พระบรมมหาราชวัง')));
      expect(r.remainder, isNot(contains('พระนคร')));
      expect(r.remainder, isNot(contains('กรุงเทพมหานคร')));
      expect(r.remainder, isNot(contains('10200')));
      // remainder is trimmed.
      expect(r.remainder, equals(r.remainder.trim()));
    });
  });

  group('parseThaiAddress - upcountry with ตำบล/อำเภอ/จังหวัด', () {
    // dataset: 500108 สุเทพ / 5001 เมืองเชียงใหม่ / 50 เชียงใหม่ / zip 50200
    const input =
        '99 หมู่ 2 ตำบลสุเทพ อำเภอเมืองเชียงใหม่ จังหวัดเชียงใหม่ 50200';

    test('resolves the complete Chiang Mai chain to exact codes', () {
      // FAIL-BEFORE: if ตำบล/อำเภอ/จังหวัด markers were not recognized, or the
      // province/district/subdistrict were mis-resolved, this fails.
      final r = parseThaiAddress(input);
      expect(r.isComplete, isTrue);
      expect(r.province?.code, 50);
      expect(r.district?.code, 5001);
      expect(r.subdistrict?.code, 500108);
      expect(r.postcode, 50200);
    });

    test('remainder preserves หมู่ / house number, drops area words', () {
      // FAIL-BEFORE: if หมู่/house number were dropped, or the area names/marker
      // words/postcode survived, this fails.
      final r = parseThaiAddress(input);
      expect(r.remainder, contains('99'));
      expect(r.remainder, contains('หมู่'));
      expect(r.remainder, isNot(contains('ตำบล')));
      expect(r.remainder, isNot(contains('อำเภอ')));
      expect(r.remainder, isNot(contains('จังหวัด')));
      expect(r.remainder, isNot(contains('สุเทพ')));
      expect(r.remainder, isNot(contains('เมืองเชียงใหม่')));
      expect(r.remainder, isNot(contains('50200')));
    });
  });

  group('parseThaiAddress - abbreviated markers', () {
    // Same Chiang Mai chain, abbreviated ต./อ./จ. form must resolve identically.
    const abbr = 'ต.สุเทพ อ.เมืองเชียงใหม่ จ.เชียงใหม่ 50200';

    test('abbreviations resolve same chain as full markers', () {
      // FAIL-BEFORE: if the parser only matched the long ตำบล/อำเภอ/จังหวัด
      // markers and not ต./อ./จ., levels go null and the test fails.
      final r = parseThaiAddress(abbr);
      expect(r.isComplete, isTrue);
      expect(r.province?.code, 50);
      expect(r.district?.code, 5001);
      expect(r.subdistrict?.code, 500108);
      expect(r.postcode, 50200);
    });

    test('กทม. / กรุงเทพฯ alias resolves to province 10', () {
      // FAIL-BEFORE: if the กทม/กรุงเทพฯ aliases were not mapped to province 10,
      // province is null and the test fails.
      for (final alias in const ['กทม.', 'กรุงเทพฯ', 'กรุงเทพมหานคร']) {
        final r = parseThaiAddress('แขวงพระบรมมหาราชวัง เขตพระนคร $alias');
        expect(r.province?.code, 10, reason: 'alias=$alias');
        expect(r.district?.code, 1001, reason: 'alias=$alias');
      }
    });
  });

  group('parseThaiAddress - space after a dotted marker', () {
    test('ต. / อ. / จ. with a space before the name resolve the chain', () {
      // Thai users often write a space after the dotted abbreviation.
      // FAIL-BEFORE: if the name reader stops at the space right after `ต.`,
      // the name is empty and every level goes null.
      final r = parseThaiAddress(
        'ต. สุเทพ อ. เมืองเชียงใหม่ จ. เชียงใหม่ 50200',
      );
      expect(r.isComplete, isTrue);
      expect(r.province?.code, 50);
      expect(r.district?.code, 5001);
      expect(r.subdistrict?.code, 500108);
      expect(r.postcode, 50200);
    });

    test('dangling dotted marker at end-of-string never throws', () {
      // FAIL-BEFORE: skipping spaces after a dotted marker must not run past
      // the end of the string when nothing follows.
      for (final s in const ['ต.สุเทพ', 'อ. ', 'จ.', 'ต. ']) {
        expect(() => parseThaiAddress(s), returnsNormally, reason: s);
      }
    });
  });

  group('parseThaiAddress - names only (no postcode)', () {
    test('resolves full Bangkok chain without a postcode token', () {
      // FAIL-BEFORE: if the parser relied on a postcode to pin levels, dropping
      // the postcode would leave province/district/subdistrict null.
      final r = parseThaiAddress(
        'แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร',
      );
      expect(r.province?.code, 10);
      expect(r.district?.code, 1001);
      expect(r.subdistrict?.code, 100101);
      expect(r.isComplete, isTrue);
      expect(r.postcode, isNull);
    });
  });

  group('parseThaiAddress - postcode only', () {
    test('postcode 50200 pins province+district, leaves subdistrict null', () {
      // dataset: zip 50200 -> 3 subdistricts, ALL in district 5001 / province 50.
      // FAIL-BEFORE: if the parser guessed one of the 3 subdistricts, or failed
      // to pin the shared district/province, this fails.
      final r = parseThaiAddress('50200');
      expect(r.postcode, 50200);
      expect(r.province?.code, 50);
      expect(r.district?.code, 5001);
      expect(r.subdistrict, isNull); // ambiguous: 3 candidates -> not guessed
      expect(r.isComplete, isFalse);
      expect(r.isEmpty, isFalse);
    });

    test('postcode 10110 spans 2 districts: province pinned, district null',
        () {
      // dataset: zip 10110 -> districts 1033 (เขตคลองเตย) and 1039 (เขตวัฒนา),
      // both province 10. Province is the only shared level.
      // FAIL-BEFORE: if the parser picked one of the two districts (guessing) or
      // failed to pin the shared province, this fails.
      final r = parseThaiAddress('10110');
      expect(r.postcode, 10110);
      expect(r.province?.code, 10);
      expect(r.district, isNull); // ambiguous across 1033/1039 -> not guessed
      expect(r.subdistrict, isNull);
    });
  });

  group('parseThaiAddress - Thai-digit postcode', () {
    test('๑๐๒๐๐ parses identically to 10200', () {
      // FAIL-BEFORE: if Thai numerals ๐-๙ were not normalized to Arabic digits,
      // the postcode is unrecognized and the whole parse degrades.
      final arabic = parseThaiAddress(
        'แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200',
      );
      final thai = parseThaiAddress(
        'แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร ๑๐๒๐๐',
      );
      expect(thai.postcode, 10200);
      expect(thai.postcode, arabic.postcode);
      expect(thai.province?.code, arabic.province?.code);
      expect(thai.district?.code, arabic.district?.code);
      expect(thai.subdistrict?.code, arabic.subdistrict?.code);
      expect(thai.isComplete, arabic.isComplete);
    });

    test('bare Thai-digit postcode ๕๐๒๐๐ resolves like 50200', () {
      final r = parseThaiAddress('๕๐๒๐๐');
      expect(r.postcode, 50200);
      expect(r.province?.code, 50);
      expect(r.district?.code, 5001);
    });
  });

  group('parseThaiAddress - consistency / pinning rules', () {
    test('postcode + matching names yield consistent complete result', () {
      // FAIL-BEFORE: if postcode and names were resolved independently and not
      // cross-checked, a consistent input could still drop a level.
      final r = parseThaiAddress(
        'ต.สุเทพ อ.เมืองเชียงใหม่ จ.เชียงใหม่ 50200',
      );
      expect(r.isComplete, isTrue);
      expect(r.province?.code, 50);
      expect(r.district?.code, 5001);
      expect(r.subdistrict?.code, 500108);
      // subdistrict's own postcode must agree with the parsed postcode.
      expect(r.subdistrict?.postcode, r.postcode);
    });
  });

  group('parseThaiAddress - ambiguous repeated subdistrict name', () {
    test('bare repeated subdistrict name หนองบัว without context => null sub',
        () {
      // dataset: subdistrict name หนองบัว appears in 25 provinces. With no
      // district/province/postcode context the subdistrict level is undecidable.
      // FAIL-BEFORE: if the parser picked the first/arbitrary หนองบัว match
      // instead of leaving it null, this fails. Must never throw.
      final r = parseThaiAddress('หนองบัว');
      expect(r.subdistrict, isNull);
      // higher levels are also undecidable here -> remain null, classified empty.
      expect(r.province, isNull);
      expect(r.district, isNull);
      expect(r.isEmpty, isTrue);
    });
  });
}

/// Renders control-char-bearing inputs safely for test descriptions.
String jsonSafe(String s) => s.replaceAll('\n', r'\n').replaceAll('\t', r'\t');
