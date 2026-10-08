import 'balance.dart';

/// 능력치 분류. 장비 화면에서 묶어서 보여 준다.
enum StatGroup {
  survival('생존'),
  offense('공격'),
  ailment('상태이상'),
  defense('방어'),
  resistance('피해 감소'),
  utility('편의');

  const StatGroup(this.label);

  final String label;
}

/// 패시브와 장비가 올려 주는 능력치.
enum StatType {
  // 생존
  maxHp('최대 체력', StatGroup.survival, roll: Balance.rollMaxHp, step: 1),
  hpRegen('체력 재생', StatGroup.survival, roll: Balance.rollHpRegen, step: 0.1),
  lifeSteal(
    '생명력 흡수',
    StatGroup.survival,
    roll: Balance.rollLifeSteal,
    percent: true,
    step: 0.001,
  ),

  // 공격: 원소 피해는 모든 타격에 고정치로 더해진다.
  physicalDamage(
    '물리 피해',
    StatGroup.offense,
    roll: Balance.rollAddedDamage,
    step: 1,
  ),
  fireDamage(
    '화염 피해',
    StatGroup.offense,
    roll: Balance.rollAddedDamage,
    step: 1,
  ),
  coldDamage(
    '냉기 피해',
    StatGroup.offense,
    roll: Balance.rollAddedDamage,
    step: 1,
  ),
  lightningDamage(
    '번개 피해',
    StatGroup.offense,
    roll: Balance.rollAddedDamage,
    step: 1,
  ),
  windDamage(
    '바람 피해',
    StatGroup.offense,
    roll: Balance.rollAddedDamage,
    step: 1,
  ),
  damage('피해 증가', StatGroup.offense, roll: Balance.rollDamage, percent: true),
  attackSpeed(
    '공격 속도',
    StatGroup.offense,
    roll: Balance.rollAttackSpeed,
    percent: true,
  ),
  critChance(
    '치명타 확률',
    StatGroup.offense,
    roll: Balance.rollCritChance,
    percent: true,
  ),
  critDamage(
    '치명타 피해',
    StatGroup.offense,
    roll: Balance.rollCritDamage,
    percent: true,
  ),

  // 상태이상: 확률은 해당 속성 피해가 섞인 타격에만 적용된다 (중독은 모든 타격).
  bleedChance(
    '출혈 확률',
    StatGroup.ailment,
    roll: Balance.rollAilmentChance,
    percent: true,
  ),
  burnChance(
    '화상 확률',
    StatGroup.ailment,
    roll: Balance.rollAilmentChance,
    percent: true,
  ),
  poisonChance(
    '중독 확률',
    StatGroup.ailment,
    roll: Balance.rollAilmentChance,
    percent: true,
  ),
  shockChance(
    '감전 확률',
    StatGroup.ailment,
    roll: Balance.rollAilmentChance,
    percent: true,
  ),
  chillChance(
    '동상 확률',
    StatGroup.ailment,
    roll: Balance.rollAilmentChance,
    percent: true,
  ),
  bleedDamage(
    '출혈 피해',
    StatGroup.ailment,
    roll: Balance.rollAilmentDamage,
    percent: true,
  ),
  burnDamage(
    '화상 피해',
    StatGroup.ailment,
    roll: Balance.rollAilmentDamage,
    percent: true,
  ),
  poisonDamage(
    '중독 피해',
    StatGroup.ailment,
    roll: Balance.rollAilmentDamage,
    percent: true,
  ),
  shockEffect(
    '감전 효과',
    StatGroup.ailment,
    roll: Balance.rollAilmentDamage,
    percent: true,
  ),

  // 방어
  armor('방어력', StatGroup.defense, roll: Balance.rollArmor, step: 1),
  evasion('회피', StatGroup.defense, roll: Balance.rollEvasion, percent: true),
  energyShield(
    '에너지 보호막',
    StatGroup.defense,
    roll: Balance.rollEnergyShield,
    step: 1,
  ),

  // 피해 감소
  physicalReduction(
    '물리 피해 감소',
    StatGroup.resistance,
    roll: Balance.rollPhysicalReduction,
    percent: true,
  ),
  fireResist(
    '화염 저항',
    StatGroup.resistance,
    roll: Balance.rollResist,
    percent: true,
  ),
  coldResist(
    '냉기 저항',
    StatGroup.resistance,
    roll: Balance.rollResist,
    percent: true,
  ),
  lightningResist(
    '번개 저항',
    StatGroup.resistance,
    roll: Balance.rollResist,
    percent: true,
  ),
  windResist(
    '바람 저항',
    StatGroup.resistance,
    roll: Balance.rollResist,
    percent: true,
  ),

  // 편의
  moveSpeed(
    '이동 속도',
    StatGroup.utility,
    roll: Balance.rollMoveSpeed,
    percent: true,
  ),
  magnetRange(
    '획득 범위',
    StatGroup.utility,
    roll: Balance.rollMagnetRange,
    percent: true,
  ),
  xpGain('경험치 획득', StatGroup.utility, roll: Balance.rollXpGain, percent: true);

  const StatType(
    this.label,
    this.group, {
    required this.roll,
    this.percent = false,
    this.step = 0.01,
  });

  final String label;
  final StatGroup group;

  /// true 면 값이 비율(0.1 = 10%)이다.
  final bool percent;

  /// 노말 등급 기준 수치.
  final double roll;

  /// 장비 수치를 이 단위로 반올림한다.
  final double step;

  String format(double value) => '$label ${formatValue(value)}';

  /// 부호를 붙인 수치. 음수는 비교 표시에서 쓴다.
  String formatValue(double value) {
    final sign = value < 0 ? '-' : '+';
    final v = value.abs();
    if (percent) {
      final p = v * 100;
      return '$sign${p >= 10 || p == p.roundToDouble() ? p.round() : p.toStringAsFixed(1)}%';
    }
    return '$sign${step < 1 ? v.toStringAsFixed(1) : v.round()}';
  }
}
