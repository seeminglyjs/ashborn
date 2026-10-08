import 'balance.dart';

/// 자동 공격 무기 정의. 레벨마다 피해가 늘고 [bonusLabel] 이 주기적으로 는다.
enum WeaponId {
  flameBlade('불꽃 대검', '주변을 도는 불꽃 칼날', '칼날'),
  emberOrb('잔불 구체', '가장 가까운 적을 노리는 불씨', '구체'),
  fireCrossbow('화염 석궁', '적을 꿰뚫는 불화살', '관통');

  const WeaponId(this.label, this.description, this.bonusLabel);

  final String label;
  final String description;
  final String bonusLabel;

  static const int maxLevel = Balance.weaponMaxLevel;

  static double damageMultiplier(int level) =>
      1 + Balance.weaponDamagePerLevel * (level - 1);

  /// 1레벨 대비 늘어난 칼날 수, 구체 수, 관통 수.
  int bonusCount(int level) => switch (this) {
    flameBlade || emberOrb => (level - 1) ~/ 2,
    fireCrossbow => level - 1,
  };

  /// [level] 이 되면 얻는 효과.
  String upgradeText(int level) {
    final percent = (Balance.weaponDamagePerLevel * 100).round();
    final bonus = bonusCount(level) > bonusCount(level - 1);
    return '피해 +$percent%${bonus ? ', $bonusLabel +1' : ''}';
  }
}
