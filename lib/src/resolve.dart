import 'data.dart';
import 'models.dart';
import 'normalize.dart';
import 'search.dart';

/// The kind of failure carried by a [ThaiAddressException].
enum ThaiAddressErrorKind {
  /// A referenced code, or a free-text query, matched no administrative area.
  notFound,

  /// Codes exist individually but do not form a valid hierarchy (a district not
  /// in the named province, or a subdistrict not in the named district).
  inconsistent,
}

/// Thrown by [validate] (and [resolve]) when an address cannot be confirmed.
///
/// [kind] distinguishes a missing code/name ([ThaiAddressErrorKind.notFound])
/// from an internally inconsistent hierarchy
/// ([ThaiAddressErrorKind.inconsistent]); [message] names the offending code.
class ThaiAddressException implements Exception {
  /// Creates an exception with the given [message] and [kind].
  const ThaiAddressException(this.message, this.kind);

  /// Human-readable description naming the offending code or field.
  final String message;

  /// Whether the failure was a missing code/name or an inconsistent hierarchy.
  final ThaiAddressErrorKind kind;

  @override
  String toString() => 'ThaiAddressException: $message';
}

/// Verifies that the three codes name a real, internally consistent place.
///
/// It throws nothing only when all of the following hold:
///
///   - [provinceCode] exists,
///   - [districtCode] exists and `districtCode ~/ 100 == provinceCode`,
///   - [subdistrictCode] exists and `subdistrictCode ~/ 100 == districtCode`.
///
/// All three codes are required; this is deliberately strict. A zero (or
/// otherwise unknown) [subdistrictCode] is treated as not found, not as "skip".
///
/// Throws a [ThaiAddressException] with kind
/// [ThaiAddressErrorKind.notFound] (a code does not exist) or
/// [ThaiAddressErrorKind.inconsistent] (codes exist but the hierarchy is
/// wrong); the message names the offending code.
void validate(int provinceCode, int districtCode, int subdistrictCode) {
  if (provinceByCode(provinceCode) == null) {
    throw ThaiAddressException(
        'province $provinceCode: not found', ThaiAddressErrorKind.notFound);
  }

  final d = districtByCode(districtCode);
  if (d == null) {
    throw ThaiAddressException(
        'district $districtCode: not found', ThaiAddressErrorKind.notFound);
  }
  if (d.provinceCode != provinceCode) {
    throw ThaiAddressException(
        'district $districtCode belongs to province ${d.provinceCode}, '
        'not $provinceCode',
        ThaiAddressErrorKind.inconsistent);
  }

  final s = subdistrictByCode(subdistrictCode);
  if (s == null) {
    throw ThaiAddressException('subdistrict $subdistrictCode: not found',
        ThaiAddressErrorKind.notFound);
  }
  if (s.districtCode != districtCode) {
    throw ThaiAddressException(
        'subdistrict $subdistrictCode belongs to district ${s.districtCode}, '
        'not $districtCode',
        ThaiAddressErrorKind.inconsistent);
  }
}

/// A free-text address to resolve.
///
/// Any combination of fields may be set; `null`/empty names and a `null`
/// postcode are treated as "unspecified". The name fields are matched after
/// normalization (see [normalizeName]), so admin prefixes such as "ตำบล",
/// "อำเภอ", "เขต" and their English forms are tolerated.
class AddressQuery {
  /// Creates a query. All fields are optional.
  const AddressQuery({
    this.subdistrict,
    this.district,
    this.province,
    this.postcode,
  });

  /// ตำบล/แขวง name (Thai or English).
  final String? subdistrict;

  /// อำเภอ/เขต name (Thai or English).
  final String? district;

  /// จังหวัด name (Thai or English).
  final String? province;

  /// 5-digit postal code, or `null` if unknown.
  final int? postcode;

  @override
  String toString() =>
      'AddressQuery(subdistrict: $subdistrict, district: $district, '
      'province: $province, postcode: $postcode)';
}

/// A fully-qualified place: a subdistrict together with the district and
/// province it belongs to.
class AddressMatch {
  /// Creates a match from its three resolved levels.
  const AddressMatch({
    required this.province,
    required this.district,
    required this.subdistrict,
  });

  /// The owning province.
  final Province province;

  /// The owning district.
  final District district;

  /// The matched subdistrict.
  final Subdistrict subdistrict;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressMatch &&
          other.province == province &&
          other.district == district &&
          other.subdistrict == subdistrict;

  @override
  int get hashCode => Object.hash(province, district, subdistrict);

  @override
  String toString() => 'AddressMatch(${province.nameEn} > ${district.nameEn} > '
      '${subdistrict.nameEn})';
}

/// Turns a free-text [AddressQuery] into zero or more fully-qualified
/// [AddressMatch]es, ordered by subdistrict code.
///
/// It starts from the most specific signal available: if [AddressQuery.subdistrict]
/// is given it uses the matching subdistricts as candidates; otherwise, if
/// [AddressQuery.postcode] is given, it uses every subdistrict with that
/// postcode. Candidates are then filtered by any of district, province and
/// postcode that were supplied (each compared by normalized name, or by exact
/// value for the postcode). Every surviving candidate is expanded into an
/// [AddressMatch] by walking its codes up to the owning district and province.
///
/// Throws a [ThaiAddressException] with kind [ThaiAddressErrorKind.notFound]:
///   - if no usable field is set (no subdistrict name and no postcode), or
///   - if usable fields are set but nothing matches.
///
/// District/province alone (without a subdistrict name or postcode) are not
/// enough to drive resolution, because [resolve] always resolves down to a
/// subdistrict; use [searchDistricts]/[districtsOf] for province- or
/// district-level queries.
List<AddressMatch> resolve(AddressQuery q) {
  final hasSub = normalizeName(q.subdistrict ?? '').isNotEmpty;
  final postcode = q.postcode ?? 0;
  if (!hasSub && postcode == 0) {
    throw const ThaiAddressException(
        'resolve: need at least a subdistrict name or a postcode',
        ThaiAddressErrorKind.notFound);
  }

  // Build the candidate set from the most specific available signal.
  final candidates =
      hasSub ? findSubdistricts(q.subdistrict!) : byPostcode(postcode);

  final wantDistrict = normalizeName(q.district ?? '');
  final wantProvince = normalizeName(q.province ?? '');

  final out = <AddressMatch>[];
  for (final s in candidates) {
    if (postcode != 0 && s.postcode != postcode) continue;

    final d = districtByCode(s.districtCode);
    if (d == null) continue;
    if (wantDistrict.isNotEmpty &&
        normalizeName(d.nameTh) != wantDistrict &&
        normalizeName(d.nameEn) != wantDistrict) {
      continue;
    }

    final p = provinceByCode(d.provinceCode);
    if (p == null) continue;
    if (wantProvince.isNotEmpty &&
        normalizeName(p.nameTh) != wantProvince &&
        normalizeName(p.nameEn) != wantProvince) {
      continue;
    }

    out.add(AddressMatch(province: p, district: d, subdistrict: s));
  }

  if (out.isEmpty) {
    throw const ThaiAddressException(
        'no matching address', ThaiAddressErrorKind.notFound);
  }
  // Candidates come from code-ordered indexes, so out is already ordered by
  // subdistrict code.
  return out;
}
