/// Region is one of Thailand's six conventional geographic regions, as used by
/// the Royal Society's classification.
///
/// The integer [code] (1..6) matches the numbering used in the upstream
/// dataset: 1 = North, 2 = Central, 3 = Northeast, 4 = West, 5 = East,
/// 6 = South.
enum Region {
  /// ภาคเหนือ
  north(1, 'ภาคเหนือ', 'North'),

  /// ภาคกลาง
  central(2, 'ภาคกลาง', 'Central'),

  /// ภาคตะวันออกเฉียงเหนือ (อีสาน)
  northeast(3, 'ภาคตะวันออกเฉียงเหนือ', 'Northeast'),

  /// ภาคตะวันตก
  west(4, 'ภาคตะวันตก', 'West'),

  /// ภาคตะวันออก
  east(5, 'ภาคตะวันออก', 'East'),

  /// ภาคใต้
  south(6, 'ภาคใต้', 'South');

  const Region(this.code, this.nameTh, this.nameEn);

  /// The dataset's 1-based region code (North = 1 … South = 6).
  final int code;

  /// The Thai region name, e.g. "ภาคกลาง".
  final String nameTh;

  /// The English region name, e.g. "Central".
  final String nameEn;

  /// Returns the [Region] whose [code] equals [code], or `null` if no region
  /// uses that code.
  static Region? fromCode(int code) {
    for (final r in Region.values) {
      if (r.code == code) return r;
    }
    return null;
  }
}
