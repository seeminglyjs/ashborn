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

/// 운명 카드 종류. 한 번에 같은 종류는 [limit] 장까지만 나온다.
enum FateType {
  stat('스탯', Balance.fateTypeLimit),
  skill('스킬', Balance.fateTypeLimit),
  reward('보상', Balance.fateRewardLimit);

  const FateType(this.label, this.limit);

  final String label;
  final int limit;
}

/// 스테이지를 클리어하면 고르는 운명 카드. 효과는 그 런이 끝날 때까지 간다.
enum FateCard {
  hardenedAsh(FateTier.common, FateType.stat, '단단한 재'),
  ashWind(FateTier.common, FateType.stat, '재바람의 잔향'),
  sharpEmber(FateTier.common, FateType.stat, '날 선 불씨'),
  emberPull(FateTier.common, FateType.stat, '불씨 자석'),
  ashArmor(FateTier.common, FateType.stat, '재의 갑옷'),
  breather(FateTier.common, FateType.reward, '숨 고르기'),
  emberGather(FateTier.common, FateType.reward, '잔불 줍기'),
  learningEmber(FateTier.common, FateType.reward, '배움의 불씨'),
  emberCollector(FateTier.rare, FateType.reward, '잔불 수집가'),
  treasureHunter(FateTier.rare, FateType.reward, '보물 사냥꾼'),
  smithsTouch(FateTier.rare, FateType.skill, '대장장이의 손길'),
  newArms(FateTier.rare, FateType.skill, '낯선 무기'),
  quickHands(FateTier.rare, FateType.stat, '빠른 손'),
  hawkEye(FateTier.rare, FateType.stat, '매의 눈'),
  ashFlood(FateTier.rare, FateType.reward, '재의 홍수'),
  emberBurst(FateTier.heroic, FateType.skill, '잿불 폭발'),
  frostArmor(FateTier.heroic, FateType.skill, '서리 갑옷'),
  chainLightning(FateTier.heroic, FateType.skill, '연쇄 번개'),
  bloodThirst(FateTier.heroic, FateType.stat, '피의 갈증'),
  phoenixFeather(FateTier.legendary, FateType.skill, '불사조의 깃털'),
  berserk(FateTier.legendary, FateType.skill, '광전사의 분노'),
  ashLord(FateTier.legendary, FateType.stat, '재의 군주'),
  thickAsh(FateTier.curse, FateType.reward, '짙어지는 재'),
  bloodOath(FateTier.curse, FateType.reward, '피의 맹세'),
  burningPrice(FateTier.curse, FateType.stat, '타오르는 대가');

  const FateCard(this.tier, this.type, this.title);

  final FateTier tier;
  final FateType type;
  final String title;

  /// 런 동안 오르는 능력치.
  Map<StatType, double> get stats => switch (this) {
    hardenedAsh => const {StatType.maxHp: Balance.fateMaxHp},
    ashWind => const {StatType.moveSpeed: Balance.fateMoveSpeed},
    learningEmber => const {StatType.xpGain: Balance.fateXpGain},
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
    emberCollector => '잔불 획득량 ${_percent(1 + Balance.fateEmberGain)}',
    treasureHunter => '장비 드랍 확률 ${_percent(1 + Balance.fateDropGain)}',
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
