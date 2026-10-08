import 'balance.dart';

/// 패시브와 장비가 올려 주는 능력치.
enum StatType {
  maxHp('최대 체력', roll: Balance.rollMaxHp, step: 1),
  moveSpeed('이동 속도', roll: Balance.rollMoveSpeed, percent: true),
  magnetRange('획득 범위', roll: Balance.rollMagnetRange, percent: true),
  damage('공격력', roll: Balance.rollDamage, percent: true),
  attackSpeed('공격 속도', roll: Balance.rollAttackSpeed, percent: true),
  defense('방어력', roll: Balance.rollDefense, step: 1),
  hpRegen('초당 회복', roll: Balance.rollHpRegen, step: 0.1),
  xpGain('경험치 획득', roll: Balance.rollXpGain, percent: true);

  const StatType(
    this.label, {
    required this.roll,
    this.percent = false,
    this.step = 0.01,
  });

  final String label;

  /// true 면 값이 비율(0.1 = 10%)이다.
  final bool percent;

  /// 노말 장비 주옵션의 기준 수치.
  final double roll;

  /// 장비 수치를 이 단위로 반올림한다.
  final double step;

  String format(double value) {
    if (percent) return '$label +${(value * 100).round()}%';
    final text = step < 1 ? value.toStringAsFixed(1) : '${value.round()}';
    return '$label +$text';
  }
}
