import 'dart:math' as math;

import 'balance.dart';
import 'equipment.dart';
import 'stats.dart';

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
///
/// 카드는 뽑힐 때마다 장비와 같은 등급을 갖는다 ([Fate]). [minRarity] 보다 낮은
/// 등급으로는 나오지 않고, 그 위로 한 등급마다 수치가 커진다.
enum FateCard {
  hardenedAsh(FateType.stat, Rarity.normal, '단단한 재'),
  ashWind(FateType.stat, Rarity.normal, '재바람의 잔향'),
  sharpEmber(FateType.stat, Rarity.normal, '날 선 불씨'),
  emberPull(FateType.stat, Rarity.normal, '불씨 자석'),
  ashArmor(FateType.stat, Rarity.normal, '재의 갑옷'),
  quickHands(FateType.stat, Rarity.rare, '빠른 손'),
  hawkEye(FateType.stat, Rarity.rare, '매의 눈'),
  bloodThirst(FateType.stat, Rarity.hero, '피의 갈증'),
  ashLord(FateType.stat, Rarity.legend, '재의 군주'),
  burningPrice(FateType.stat, Rarity.normal, '타오르는 대가'),
  smithsTouch(FateType.skill, Rarity.rare, '대장장이의 손길'),
  newArms(FateType.skill, Rarity.rare, '낯선 무기'),
  emberBurst(FateType.skill, Rarity.hero, '잿불 폭발'),
  frostArmor(FateType.skill, Rarity.hero, '서리 갑옷'),
  chainLightning(FateType.skill, Rarity.hero, '연쇄 번개'),
  phoenixFeather(FateType.skill, Rarity.legend, '불사조의 깃털'),
  berserk(FateType.skill, Rarity.legend, '광전사의 분노'),
  breather(FateType.reward, Rarity.normal, '숨 고르기'),
  emberGather(FateType.reward, Rarity.normal, '잔불 줍기'),
  learningEmber(FateType.reward, Rarity.normal, '배움의 불씨'),
  emberCollector(FateType.reward, Rarity.rare, '잔불 수집가'),
  treasureHunter(FateType.reward, Rarity.rare, '보물 사냥꾼'),
  ashFlood(FateType.reward, Rarity.rare, '재의 홍수'),
  thickAsh(FateType.reward, Rarity.normal, '짙어지는 재'),
  bloodOath(FateType.reward, Rarity.normal, '피의 맹세');

  const FateCard(this.type, this.minRarity, this.title);

  final FateType type;
  final Rarity minRarity;
  final String title;

  /// 저주: 고정된 페널티와 등급만큼 커지는 보상을 함께 준다.
  bool get curse =>
      this == burningPrice || this == thickAsh || this == bloodOath;

  /// 고유 장비와 같은 특수 효과. 등급이 높을수록 세다.
  UniqueEffect? get effect => switch (this) {
    emberBurst => UniqueEffect.emberBurst,
    frostArmor => UniqueEffect.frostArmor,
    chainLightning => UniqueEffect.chainLightning,
    berserk => UniqueEffect.berserk,
    _ => null,
  };

  /// [minRarity] 등급일 때의 기본 수치. 등급마다 [Fate.power] 배가 된다.
  double get base => switch (this) {
    hardenedAsh => Balance.fateMaxHp,
    ashWind => Balance.fateMoveSpeed,
    sharpEmber => Balance.fateDamage,
    emberPull => Balance.fateMagnetRange,
    ashArmor => Balance.fateArmor,
    quickHands => Balance.fateAttackSpeed,
    hawkEye => Balance.fateCritChance,
    bloodThirst => Balance.fateLifeSteal,
    ashLord => Balance.fateLordDamage,
    burningPrice => Balance.curseDamage,
    breather => Balance.fateHeal,
    emberGather => Balance.fateEmber,
    learningEmber => Balance.fateXpGain,
    emberCollector => Balance.fateEmberGain,
    treasureHunter => Balance.fateDropGain,
    thickAsh => Balance.curseEmberGain,
    bloodOath => Balance.curseDropGain,
    _ => 1,
  };
}

/// 뽑힌 운명 카드 한 장: 카드와 그 등급.
class Fate {
  Fate(this.card, this.rarity) : assert(rarity.index >= card.minRarity.index);

  final FateCard card;
  final Rarity rarity;

  int get _steps => rarity.index - card.minRarity.index;

  /// 최소 등급 대비 수치 배율.
  double get power => math.pow(Balance.fateRarityGrowth, _steps).toDouble();

  /// 레벨처럼 정수로 늘어나는 효과의 덤. 최소 등급 위로 두 등급마다 1.
  int get extra => _steps ~/ 2;

  double get amount => card.base * power;

  /// 런 동안 오르는 능력치.
  Map<StatType, double> get stats => switch (card) {
    FateCard.hardenedAsh => {StatType.maxHp: amount},
    FateCard.ashWind => {StatType.moveSpeed: amount},
    FateCard.sharpEmber => {StatType.damage: amount},
    FateCard.emberPull => {StatType.magnetRange: amount},
    FateCard.ashArmor => {StatType.armor: amount},
    FateCard.quickHands => {StatType.attackSpeed: amount},
    FateCard.hawkEye => {StatType.critChance: amount},
    FateCard.bloodThirst => {StatType.lifeSteal: amount},
    FateCard.learningEmber => {StatType.xpGain: amount},
    FateCard.ashLord => {
      StatType.damage: amount,
      StatType.maxHp: Balance.fateLordMaxHp * power,
    },
    FateCard.burningPrice => {
      StatType.maxHp: Balance.curseMaxHp,
      StatType.damage: amount,
    },
    _ => const {},
  };

  int get weaponLevels => Balance.fateWeaponLevels + extra;
  int get newWeaponLevel => 1 + extra;
  int get levels => Balance.fateLevels + extra;

  /// 불사조의 깃털로 되살아날 때 체력 비율.
  double get reviveHp => math.min(1, Balance.phoenixHp * power);

  String get description => switch (card) {
    FateCard.breather => '체력 ${_p(math.min(1, amount))} 회복',
    FateCard.emberGather => '잔불을 바로 얻는다 (스테이지 레벨 × ${amount.round()})',
    FateCard.emberCollector => '잔불 획득량 +${_p(amount)}',
    FateCard.treasureHunter => '장비 드랍 확률 +${_p(amount)}',
    FateCard.smithsTouch => '가진 무기 하나가 바로 +$weaponLevels레벨',
    FateCard.newArms => '아직 없는 무기 하나를 $newWeaponLevel레벨로 얻는다',
    FateCard.ashFlood => '바로 $levels레벨 오른다',
    FateCard.phoenixFeather => '쓰러지면 한 번 더, 체력 ${_p(reviveHp)}로 되살아난다',
    FateCard.emberBurst =>
      '처치 시 ${_p(Balance.emberBurstChance)} 확률로 주변에 '
          '화염 피해 ${(Balance.emberBurstDamage * power).round()}',
    FateCard.chainLightning =>
      '타격 시 ${_p(Balance.chainLightningChance)} 확률로 가까운 적 '
          '${Balance.chainLightningTargets}명에게 피해의 '
          '${_p(Balance.chainLightningRatio * power)} 번개',
    FateCard.frostArmor =>
      '피격 시 주변 적의 이동 속도 ${_p(Balance.frostArmorSlow)} 감소 '
          '(${(Balance.frostArmorDuration * power).toStringAsFixed(1)}초)',
    FateCard.berserk =>
      '잃은 체력 1%당 피해 ${(Balance.berserkScale * power).toStringAsFixed(1)}% 증가',
    FateCard.thickAsh =>
      '적 체력 +${_p(Balance.curseEnemyHp - 1)}, 잔불 획득량 +${_p(amount)}',
    FateCard.bloodOath =>
      '적 피해 +${_p(Balance.curseEnemyDamage - 1)}, 장비 드랍 확률 +${_p(amount)}',
    _ => stats.entries.map((e) => e.key.format(e.value)).join(', '),
  };

  static String _p(double v) => '${(v * 100).round()}%';

  @override
  bool operator ==(Object other) =>
      other is Fate && other.card == card && other.rarity == rarity;

  @override
  int get hashCode => Object.hash(card, rarity);

  @override
  String toString() => 'Fate(${card.name}, ${rarity.name})';
}
