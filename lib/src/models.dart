import 'data.dart';
import 'json_helpers.dart';
import 'region.dart';

/// A Thai province (จังหวัด).
///
/// Bangkok (code 10) is administratively a special area but is modelled as a
/// province here.
class Province {
  /// Creates a province. Normally obtained via [provinceByCode] or
  /// [provinces]; constructed directly only when building the dataset.
  const Province({
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.region,
  });

  /// Official 2-digit DOPA code, 10–96.
  final int code;

  /// Thai name, e.g. "กรุงเทพมหานคร".
  final String nameTh;

  /// English name, e.g. "Bangkok".
  final String nameEn;

  /// The geographic region this province belongs to.
  final Region region;

  /// A self-describing JSON map of this province.
  ///
  /// The [region] is emitted as its integer [Region.code] under the key
  /// `region`. The map is round-trippable via [Province.fromJson].
  Map<String, dynamic> toJson() => {
        'code': code,
        'nameTh': nameTh,
        'nameEn': nameEn,
        'region': region.code,
      };

  /// Rebuilds a [Province] purely from a [toJson] map, with no dataset lookup.
  ///
  /// The `region` value must be a valid [Region.code] (1..6). Any malformed
  /// input — an unknown region code, or a missing or wrongly-typed key —
  /// throws a [FormatException] naming the offending key.
  factory Province.fromJson(Map<String, dynamic> json) {
    const where = 'Province.fromJson';
    final regionCode = reqInt(json, 'region', where);
    final region = Region.fromCode(regionCode);
    if (region == null) {
      throw FormatException('$where: unknown region code '
          '$regionCode (expected 1..6)');
    }
    return Province(
      code: reqInt(json, 'code', where),
      nameTh: reqString(json, 'nameTh', where),
      nameEn: reqString(json, 'nameEn', where),
      region: region,
    );
  }

  /// The districts of this province, ordered by code. Empty for an unknown
  /// province.
  List<District> get districts => districtsOf(code);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Province &&
          other.code == code &&
          other.nameTh == nameTh &&
          other.nameEn == nameEn &&
          other.region == region;

  @override
  int get hashCode => Object.hash(code, nameTh, nameEn, region);

  @override
  String toString() => 'Province($code, $nameTh / $nameEn, ${region.nameEn})';
}

/// A Thai district: อำเภอ in most provinces, เขต in Bangkok.
class District {
  /// Creates a district. Normally obtained via [districtByCode],
  /// [districts] or [Province.districts].
  const District({
    required this.code,
    required this.provinceCode,
    required this.nameTh,
    required this.nameEn,
  });

  /// Official 4-digit DOPA code; `code ~/ 100 == provinceCode`.
  final int code;

  /// The owning province's 2-digit code.
  final int provinceCode;

  /// Thai name (the อำเภอ/เขต sense comes from the source naming).
  final String nameTh;

  /// English name.
  final String nameEn;

  /// A self-describing JSON map of this district. Round-trippable via
  /// [District.fromJson].
  Map<String, dynamic> toJson() => {
        'code': code,
        'provinceCode': provinceCode,
        'nameTh': nameTh,
        'nameEn': nameEn,
      };

  /// Rebuilds a [District] purely from a [toJson] map, with no dataset lookup.
  /// A missing or wrongly-typed key throws a [FormatException] naming the key.
  factory District.fromJson(Map<String, dynamic> json) {
    const where = 'District.fromJson';
    return District(
      code: reqInt(json, 'code', where),
      provinceCode: reqInt(json, 'provinceCode', where),
      nameTh: reqString(json, 'nameTh', where),
      nameEn: reqString(json, 'nameEn', where),
    );
  }

  /// The province this district belongs to, or `null` if unknown.
  Province? get province => provinceByCode(provinceCode);

  /// The subdistricts of this district, ordered by code. Empty for an unknown
  /// district.
  List<Subdistrict> get subdistricts => subdistrictsOf(code);

  /// The distinct postal codes used within this district, ascending.
  List<int> get postcodes => postcodesOf(code);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is District &&
          other.code == code &&
          other.provinceCode == provinceCode &&
          other.nameTh == nameTh &&
          other.nameEn == nameEn;

  @override
  int get hashCode => Object.hash(code, provinceCode, nameTh, nameEn);

  @override
  String toString() => 'District($code, $nameTh / $nameEn, prov $provinceCode)';
}

/// A Thai subdistrict: ตำบล in most provinces, แขวง in Bangkok.
class Subdistrict {
  /// Creates a subdistrict. Normally obtained via [subdistrictByCode],
  /// [subdistricts], [District.subdistricts] or [byPostcode].
  const Subdistrict({
    required this.code,
    required this.districtCode,
    required this.nameTh,
    required this.nameEn,
    required this.postcode,
  });

  /// Official 6-digit DOPA code; `code ~/ 100 == districtCode`.
  final int code;

  /// The owning district's 4-digit code.
  final int districtCode;

  /// Thai name.
  final String nameTh;

  /// English name.
  final String nameEn;

  /// 5-digit Thai postal code (รหัสไปรษณีย์).
  final int postcode;

  /// A self-describing JSON map of this subdistrict. Round-trippable via
  /// [Subdistrict.fromJson].
  Map<String, dynamic> toJson() => {
        'code': code,
        'districtCode': districtCode,
        'nameTh': nameTh,
        'nameEn': nameEn,
        'postcode': postcode,
      };

  /// Rebuilds a [Subdistrict] purely from a [toJson] map, with no dataset
  /// lookup. A missing or wrongly-typed key throws a [FormatException] naming
  /// the key.
  factory Subdistrict.fromJson(Map<String, dynamic> json) {
    const where = 'Subdistrict.fromJson';
    return Subdistrict(
      code: reqInt(json, 'code', where),
      districtCode: reqInt(json, 'districtCode', where),
      nameTh: reqString(json, 'nameTh', where),
      nameEn: reqString(json, 'nameEn', where),
      postcode: reqInt(json, 'postcode', where),
    );
  }

  /// The district this subdistrict belongs to, or `null` if unknown.
  District? get district => districtByCode(districtCode);

  /// The province this subdistrict belongs to, or `null` if unknown.
  Province? get province => provinceByCode(districtCode ~/ 100);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subdistrict &&
          other.code == code &&
          other.districtCode == districtCode &&
          other.nameTh == nameTh &&
          other.nameEn == nameEn &&
          other.postcode == postcode;

  @override
  int get hashCode => Object.hash(code, districtCode, nameTh, nameEn, postcode);

  @override
  String toString() =>
      'Subdistrict($code, $nameTh / $nameEn, dist $districtCode, $postcode)';
}
