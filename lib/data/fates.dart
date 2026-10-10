import 'dart:math' as math;

import 'package:flutter/material.dart' show Color, IconData, Icons;

import 'balance.dart';
import 'damage.dart';
import 'equipment.dart';
import 'stats.dart';

// 화면에는 "신의 은총"으로 보인다. 코드 이름(Fate, FateCard 등)은 예전 이름 "운명"을 그대로 쓴다.

/// 은총 카드 종류. 한 번에 같은 종류는 [limit] 장까지만 나온다.
enum FateType {
  stat('스탯', Balance.fateTypeLimit),
  skill('스킬', Balance.fateTypeLimit),
  reward('보상', Balance.fateRewardLimit);

  const FateType(this.label, this.limit);

  final String label;
  final int limit;
}

/// 은총을 내리는 신의 영역. 카드의 색과 아이콘이 된다.
enum GraceDomain {
  fire('화염', Color(0xFFFF7A3D), Icons.local_fire_department),
  cold('냉기', Color(0xFF8FD3FF), Icons.ac_unit),
  lightning('번개', Color(0xFFFFE066), Icons.bolt),
  wind('바람', Color(0xFF9EE6C4), Icons.air),
  earth('대지', Color(0xFFC9955C), Icons.terrain),
  life('생명', Color(0xFF7FD67F), Icons.spa),
  fortune('풍요', Color(0xFFE8C887), Icons.diamond),
  death('죽음', Color(0xFFB98CFF), Icons.dark_mode);

  const GraceDomain(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// 신이 속한 신화.
enum Myth {
  greek('그리스'),
  norse('북유럽'),
  egyptian('이집트'),
  hindu('힌두'),
  japanese('일본'),
  slavic('슬라브'),
  celtic('켈트'),
  aztec('아즈텍'),
  chinese('중국'),
  polynesian('폴리네시아'),
  mesopotamian('메소포타미아');

  const Myth(this.label);

  final String label;
}

/// 은총을 내리는 신. [lore] 는 실제 신화 내용에 맞춘 한 줄 소개.
class God {
  const God(this.name, this.myth, this.lore);

  final String name;
  final Myth myth;
  final String lore;
}

/// 스테이지를 클리어하면 고르는 신의 은총 카드. 효과는 그 런이 끝날 때까지 간다.
///
/// 카드는 뽑힐 때마다 장비와 같은 등급을 갖는다 ([Fate]). [minRarity] 보다 낮은
/// 등급으로는 나오지 않고, 그 위로 한 등급마다 수치가 커진다.
enum FateCard {
  // 스탯
  hardenedAsh(
    FateType.stat,
    Rarity.normal,
    GraceDomain.life,
    God('이둔', Myth.norse, '신들을 늙지 않게 하는 황금 사과를 지키는 젊음의 여신'),
    '이둔의 황금 사과',
  ),
  ashWind(
    FateType.stat,
    Rarity.normal,
    GraceDomain.wind,
    God('헤르메스', Myth.greek, '날개 달린 샌들로 하늘을 가르는 신들의 전령'),
    '헤르메스의 날개 샌들',
  ),
  sharpEmber(
    FateType.stat,
    Rarity.normal,
    GraceDomain.fire,
    God('펠레', Myth.polynesian, '하와이 킬라우에아 화산에 사는 불과 용암의 여신'),
    '펠레의 용암',
  ),
  emberPull(
    FateType.stat,
    Rarity.normal,
    GraceDomain.fortune,
    God('다이코쿠텐', Myth.japanese, '보물 자루와 요술 망치를 든 칠복신, 복을 쓸어 담는다'),
    '다이코쿠텐의 보물 자루',
  ),
  ashArmor(
    FateType.stat,
    Rarity.normal,
    GraceDomain.earth,
    God('비샤몬텐', Myth.japanese, '갑옷을 두르고 창과 보탑을 든 북방의 수호 무신'),
    '비샤몬텐의 갑옷',
  ),
  quickHands(
    FateType.stat,
    Rarity.rare,
    GraceDomain.lightning,
    God('라이진', Myth.japanese, '등에 멘 북을 두드려 천둥과 번개를 부르는 뇌신'),
    '라이진의 천둥북',
  ),
  hawkEye(
    FateType.stat,
    Rarity.rare,
    GraceDomain.wind,
    God('호루스', Myth.egyptian, '매의 머리를 한 하늘의 신, 그의 눈은 모든 것을 본다'),
    '호루스의 눈',
  ),
  bloodThirst(
    FateType.stat,
    Rarity.hero,
    GraceDomain.earth,
    God('세크메트', Myth.egyptian, '라의 눈에서 태어난 사자 머리의 전쟁 여신, 피에 굶주렸다'),
    '세크메트의 갈증',
  ),
  ashLord(
    FateType.stat,
    Rarity.legend,
    GraceDomain.fire,
    God('라', Myth.egyptian, '태양의 배를 타고 날마다 하늘을 건너는 태양신'),
    '라의 태양 원반',
  ),
  burningPrice(
    FateType.stat,
    Rarity.normal,
    GraceDomain.death,
    God('세트', Myth.egyptian, '사막과 폭풍, 혼돈의 신. 형 오시리스를 죽였다'),
    '세트의 대가',
  ),
  frostVeil(
    FateType.stat,
    Rarity.normal,
    GraceDomain.cold,
    God('칼리아흐', Myth.celtic, '지팡이로 땅을 얼려 겨울을 부르는 노파 여신'),
    '칼리아흐의 겨울 장막',
  ),
  thunderAxe(
    FateType.stat,
    Rarity.normal,
    GraceDomain.lightning,
    God('페룬', Myth.slavic, '참나무 위에서 번개 도끼를 던지는 슬라브의 천둥신'),
    '페룬의 도끼',
  ),
  galeStep(
    FateType.stat,
    Rarity.normal,
    GraceDomain.wind,
    God('엔릴', Myth.mesopotamian, '하늘과 땅을 갈라놓은 바람과 폭풍의 신'),
    '엔릴의 폭풍',
  ),
  oathShield(
    FateType.stat,
    Rarity.normal,
    GraceDomain.earth,
    God('티르', Myth.norse, '전쟁과 맹세의 신, 펜리르를 묶으려 한 손을 내주었다'),
    '티르의 맹세',
  ),
  renewal(
    FateType.stat,
    Rarity.normal,
    GraceDomain.life,
    God('하우메아', Myth.polynesian, '몇 번이고 젊은 몸으로 다시 태어나는 하와이의 출산과 풍요의 여신'),
    '하우메아의 새 생명',
  ),

  // 스킬
  smithsTouch(
    FateType.skill,
    Rarity.rare,
    GraceDomain.fire,
    God('헤파이스토스', Myth.greek, '화산 속 대장간에서 신들의 무기를 벼린 대장장이 신'),
    '헤파이스토스의 망치',
  ),
  newArms(
    FateType.skill,
    Rarity.rare,
    GraceDomain.earth,
    God('루', Myth.celtic, '모든 기예에 능한 신, 빗나가지 않는 창을 지녔다'),
    '루의 무기고',
  ),
  emberBurst(
    FateType.skill,
    Rarity.hero,
    GraceDomain.fire,
    God('수르트', Myth.norse, '무스펠헤임의 불의 거인, 라그나로크에 불꽃 검으로 세상을 태운다'),
    '수르트의 불꽃 검',
  ),
  frostArmor(
    FateType.skill,
    Rarity.hero,
    GraceDomain.cold,
    God('스카디', Myth.norse, '눈 덮인 산에서 스키를 타고 활을 쏘는 겨울과 사냥의 여신'),
    '스카디의 서리',
  ),
  chainLightning(
    FateType.skill,
    Rarity.hero,
    GraceDomain.lightning,
    God('제우스', Myth.greek, '키클롭스가 벼린 벼락을 던지는 올림포스의 주신'),
    '제우스의 벼락',
  ),
  phoenixFeather(
    FateType.skill,
    Rarity.legend,
    GraceDomain.life,
    God('오시리스', Myth.egyptian, '세트에게 죽임당한 뒤 되살아나 저승을 다스리는 부활의 신'),
    '오시리스의 부활',
  ),
  berserk(
    FateType.skill,
    Rarity.legend,
    GraceDomain.death,
    God('칼리', Myth.hindu, '해골 목걸이를 걸고 악마를 베어 넘기는 파괴와 시간의 여신'),
    '칼리의 분노',
  ),
  fireGrace(
    FateType.skill,
    Rarity.rare,
    GraceDomain.fire,
    God('아그니', Myth.hindu, '제단의 불이 되어 사람의 제물을 신들에게 나르는 불의 신'),
    '아그니의 제단 불',
  ),
  coldGrace(
    FateType.skill,
    Rarity.rare,
    GraceDomain.cold,
    God('키오네', Myth.greek, '북풍 보레아스의 딸, 눈의 여신'),
    '키오네의 눈보라',
  ),
  lightningGrace(
    FateType.skill,
    Rarity.rare,
    GraceDomain.lightning,
    God('토르', Myth.norse, '천둥과 번개의 신, 묠니르를 휘두른다'),
    '토르의 묠니르',
  ),
  windGrace(
    FateType.skill,
    Rarity.rare,
    GraceDomain.wind,
    God('후진', Myth.japanese, '바람 자루를 메고 다니며 바람을 풀어놓는 풍신'),
    '후진의 바람 자루',
  ),
  warGrace(
    FateType.skill,
    Rarity.rare,
    GraceDomain.earth,
    God('아레스', Myth.greek, '피와 격전을 즐기는 전쟁의 신'),
    '아레스의 창',
  ),

  // 보상
  breather(
    FateType.reward,
    Rarity.normal,
    GraceDomain.life,
    God('신농', Myth.chinese, '온갖 풀을 직접 맛보아 약초를 가려낸 농업과 의약의 신'),
    '신농의 약초',
  ),
  emberGather(
    FateType.reward,
    Rarity.normal,
    GraceDomain.fortune,
    God('조공명', Myth.chinese, '검은 호랑이를 타고 재물을 불러들이는 재신'),
    '조공명의 금화',
  ),
  learningEmber(
    FateType.reward,
    Rarity.normal,
    GraceDomain.fortune,
    God('가네샤', Myth.hindu, '코끼리 머리를 한 지혜와 행운의 신, 앞길의 장애를 걷어 낸다'),
    '가네샤의 지혜',
  ),
  emberCollector(
    FateType.reward,
    Rarity.rare,
    GraceDomain.fortune,
    God('락슈미', Myth.hindu, '연꽃 위에서 손으로 금화를 흘려보내는 부와 행운의 여신'),
    '락슈미의 연꽃',
  ),
  treasureHunter(
    FateType.reward,
    Rarity.rare,
    GraceDomain.fortune,
    God('티케', Myth.greek, '풍요의 뿔을 안고 도시와 사람의 행운을 다스리는 여신'),
    '티케의 풍요의 뿔',
  ),
  ashFlood(
    FateType.reward,
    Rarity.rare,
    GraceDomain.life,
    God('다그다', Myth.celtic, '아무리 퍼내도 마르지 않는 가마솥을 지닌 풍요의 아버지 신'),
    '다그다의 가마솥',
  ),
  thickAsh(
    FateType.reward,
    Rarity.normal,
    GraceDomain.death,
    God('하데스', Myth.greek, '저승의 왕이자 땅속 모든 보화의 주인'),
    '하데스의 계약',
  ),
  bloodOath(
    FateType.reward,
    Rarity.normal,
    GraceDomain.death,
    God('믹틀란테쿠틀리', Myth.aztec, '죽은 자들의 땅 믹틀란을 다스리는 해골 모습의 신'),
    '믹틀란테쿠틀리의 맹세',
  );

  const FateCard(this.type, this.minRarity, this.domain, this.god, this.title);

  final FateType type;
  final Rarity minRarity;

  /// 신의 영역. 카드 색과 아이콘이 된다.
  final GraceDomain domain;

  /// 은총을 내리는 신.
  final God god;

  /// 은총 이름.
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

  /// 원소 은총: 모든 공격에 무기 기본 피해(장비 고정 피해 · 배율 적용 전)의 [Fate.amount] 만큼
  /// 이 속성 피해를 더한다.
  DamageType? get element => switch (this) {
    fireGrace => DamageType.fire,
    coldGrace => DamageType.cold,
    lightningGrace => DamageType.lightning,
    windGrace => DamageType.wind,
    warGrace => DamageType.physical,
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
    frostVeil => Balance.fateEnergyShield,
    thunderAxe => Balance.fateCritDamage,
    galeStep => Balance.fateEvasion,
    oathShield => Balance.fatePhysicalReduction,
    renewal => Balance.fateHpRegen,
    fireGrace ||
    coldGrace ||
    lightningGrace ||
    windGrace ||
    warGrace => Balance.fateElementDamage,
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

/// 원소 은총이 함께 올려 주는 상태이상 능력치: 물리는 출혈 확률, 화염 · 냉기 · 번개는
/// 점화 · 냉각 · 감전 축적. 바람은 이동 속도를 준다.
StatType _elementBonus(DamageType element) => switch (element) {
  DamageType.fire => StatType.burnChance,
  DamageType.cold => StatType.chillChance,
  DamageType.lightning => StatType.shockChance,
  DamageType.physical => StatType.bleedChance,
  DamageType.wind => StatType.moveSpeed,
};

/// 뽑힌 은총 카드 한 장: 카드와 그 등급.
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

  /// 원소 은총이 더하는 속성 피해 비율. 원소 은총이 아니면 0.
  double get extraDamage => card.element == null ? 0 : amount;

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
    FateCard.frostVeil => {StatType.energyShield: amount},
    FateCard.thunderAxe => {StatType.critDamage: amount},
    FateCard.galeStep => {StatType.evasion: amount},
    FateCard.oathShield => {StatType.physicalReduction: amount},
    FateCard.renewal => {StatType.hpRegen: amount},
    FateCard.ashLord => {
      StatType.damage: amount,
      StatType.maxHp: Balance.fateLordMaxHp * power,
    },
    FateCard.burningPrice => {
      StatType.maxHp: Balance.curseMaxHp,
      StatType.damage: amount,
    },
    FateCard(element: DamageType.wind) => {
      StatType.moveSpeed: Balance.fateWindMoveSpeed * power,
    },
    FateCard(element: DamageType.physical) => {
      StatType.bleedChance: Balance.fateElementAilment * power,
    },
    FateCard(element: final element?) => {
      _elementBonus(element): Balance.fateElementBuildup * power,
    },
    _ => const {},
  };

  int get weaponLevels => Balance.fateWeaponLevels + extra;
  int get newWeaponLevel => 1 + extra;
  int get levels => Balance.fateLevels + extra;

  /// 오시리스의 부활로 되살아날 때 체력 비율.
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
    FateCard(element: final element?) =>
      '모든 공격에 피해의 ${_p(amount)}만큼 ${element.label} 피해 추가 · '
          '${stats.entries.map((e) => e.key.format(e.value)).join(', ')}',
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
