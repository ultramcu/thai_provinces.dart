import 'data.dart';
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
