import 'dart:ui';

import 'balance.dart';
import 'equipment.dart';
import 'stats.dart';

/// 운명 카드 등급. 저주는 페널티와 보상을 함께 준다.
enum FateTier {
  common('일반', Color(0xFFD8D2CC)),
  rare('희귀', Color(0xFF4A9EFF)),
  heroic('영웅', Color(0xFFB36BFF)),
  legendary('전설', Color(0xFFFFC94A)),
  curse('저주', Color(0xFFE8463A));

  const FateTier(this.label, this.color);

  final String label;
  final Color color;

  double get weight => Balance.fateTierWeights[index];
}

/// 스테이지를 클리어하면 고르는 운명 카드. 효과는 그 런이 끝날 때까지 간다.
enum FateCard {
  hardenedAsh(FateTier.common, '단단한 재'),
  ashWind(FateTier.common, '재바람의 잔향'),
  sharpEmber(FateTier.common, '날 선 불씨'),
  emberPull(FateTier.common, '불씨 자석'),
  ashArmor(FateTier.common, '재의 갑옷'),
  breather(FateTier.common, '숨 고르기'),
  emberGather(FateTier.common, '잔불 줍기'),
  smithsTouch(FateTier.rare, '대장장이의 손길'),
  newArms(FateTier.rare, '낯선 무기'),
  quickHands(FateTier.rare, '빠른 손'),
  hawkEye(FateTier.rare, '매의 눈'),
  ashFlood(FateTier.rare, '재의 홍수'),
  emberBurst(FateTier.heroic, '잿불 폭발'),
  frostArmor(FateTier.heroic, '서리 갑옷'),
  chainLightning(FateTier.heroic, '연쇄 번개'),
  bloodThirst(FateTier.heroic, '피의 갈증'),
  phoenixFeather(FateTier.legendary, '불사조의 깃털'),
  berserk(FateTier.legendary, '광전사의 분노'),
  ashLord(FateTier.legendary, '재의 군주'),
  thickAsh(FateTier.curse, '짙어지는 재'),
  bloodOath(FateTier.curse, '피의 맹세'),
  burningPrice(FateTier.curse, '타오르는 대가');

  const FateCard(this.tier, this.title);

  final FateTier tier;
  final String title;

  /// 런 동안 오르는 능력치.
  Map<StatType, double> get stats => switch (this) {
    hardenedAsh => const {StatType.maxHp: Balance.fateMaxHp},
    ashWind => const {StatType.moveSpeed: Balance.fateMoveSpeed},
    sharpEmber => const {StatType.damage: Balance.fateDamage},
    emberPull => const {StatType.magnetRange: Balance.fateMagnetRange},
    ashArmor => const {StatType.armor: Balance.fateArmor},
    quickHands => const {StatType.attackSpeed: Balance.fateAttackSpeed},
    hawkEye => const {StatType.critChance: Balance.fateCritChance},
    bloodThirst => const {StatType.lifeSteal: Balance.fateLifeSteal},
    ashLord => const {
      StatType.damage: Balance.fateLordDamage,
      StatType.maxHp: Balance.fateLordMaxHp,
    },
    burningPrice => const {
      StatType.maxHp: Balance.curseMaxHp,
      StatType.damage: Balance.curseDamage,
    },
    _ => const {},
  };

  /// 고유 장비와 같은 특수 효과. 이미 가진 효과는 다시 나오지 않는다.
  UniqueEffect? get effect => switch (this) {
    emberBurst => UniqueEffect.emberBurst,
    frostArmor => UniqueEffect.frostArmor,
    chainLightning => UniqueEffect.chainLightning,
    berserk => UniqueEffect.berserk,
    _ => null,
  };

  String get description => switch (this) {
    breather => '체력을 모두 회복한다',
    emberGather => '잔불을 바로 얻는다 (스테이지 레벨 × ${Balance.fateEmber.round()})',
    smithsTouch => '가진 무기 하나가 바로 +${Balance.fateWeaponLevels}레벨',
    newArms => '아직 없는 무기 하나를 얻는다',
    ashFlood => '바로 ${Balance.fateLevels}레벨 오른다',
    phoenixFeather =>
      '쓰러지면 한 번 더, 체력 ${(Balance.phoenixHp * 100).round()}%로 되살아난다',
    thickAsh =>
      '적 체력 ${_percent(Balance.curseEnemyHp)}, '
          '잔불 획득량 ×${Balance.curseEmber.round()}',
    bloodOath =>
      '적 피해 ${_percent(Balance.curseEnemyDamage)}, '
          '장비 드랍 확률 ×${Balance.curseDrop.round()}',
    _ =>
      effect?.description ??
          stats.entries.map((e) => e.key.format(e.value)).join(', '),
  };

  static String _percent(double multiplier) =>
      '+${((multiplier - 1) * 100).round()}%';
}
