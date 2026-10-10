import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'inventory.dart';
import 'stats.dart';

enum UpgradeGroup {
  basic('기본 능력'),
  element('원소 · 상태이상'),
  utility('편의'),
  fate('신탁');

  const UpgradeGroup(this.label);

  final String label;
}

/// 화톳불에서 잔불로 사는 영구 강화. 모든 캐릭터에 붙는다.
///
/// 레벨마다 [perLevel] 만큼 오르고, 다음 레벨 비용은 [baseCost] 에서
/// [Balance.upgradeCostGrowth] 배씩 는다.
///
/// [amplifies] 가 있는 강화는 그 능력치에 더하지 않고 곱한다: 장비 · 은총 · 특성으로 모인
/// 지금 수치를 (1 + 효과)배로 키운다. 예) 점화 축적 5% 에 원소 공명 +50% 면 7.5%.
enum Upgrade {
  maxHp(
    UpgradeGroup.basic,
    '단단한 몸',
    Balance.upgradeMaxHp,
    maxLevel: 100,
    baseCost: 30,
    stat: StatType.maxHp,
  ),
  damage(
    UpgradeGroup.basic,
    '불꽃의 힘',
    Balance.upgradeDamage,
    maxLevel: 100,
    baseCost: 40,
    stat: StatType.damage,
  ),
  moveSpeed(
    UpgradeGroup.basic,
    '가벼운 발',
    Balance.upgradeMoveSpeed,
    maxLevel: 5,
    baseCost: 40,
    stat: StatType.moveSpeed,
  ),
  armor(
    UpgradeGroup.basic,
    '재의 피부',
    Balance.upgradeArmor,
    maxLevel: 100,
    baseCost: 30,
    stat: StatType.armor,
  ),
  hpRegen(
    UpgradeGroup.basic,
    '꺼지지 않는 불씨',
    Balance.upgradeHpRegen,
    maxLevel: 5,
    baseCost: 50,
    stat: StatType.hpRegen,
  ),
  critChance(
    UpgradeGroup.basic,
    '날 선 눈',
    Balance.upgradeCritChance,
    maxLevel: 10,
    baseCost: 60,
    stat: StatType.critChance,
  ),
  critDamage(
    UpgradeGroup.basic,
    '급소 베기',
    Balance.upgradeCritDamage,
    maxLevel: 10,
    baseCost: 60,
    stat: StatType.critDamage,
  ),
  resist(
    UpgradeGroup.basic,
    '잿불 갑주',
    Balance.upgradeResist,
    maxLevel: 10,
    baseCost: 50,
    adds: {
      StatType.fireResist,
      StatType.coldResist,
      StatType.lightningResist,
      StatType.windResist,
    },
  ),
  elementDamage(
    UpgradeGroup.element,
    '원소의 불길',
    Balance.upgradeAmplify,
    maxLevel: 10,
    baseCost: 80,
    amplifies: {
      StatType.fireDamage,
      StatType.coldDamage,
      StatType.lightningDamage,
      StatType.windDamage,
    },
  ),
  elementBuildup(
    UpgradeGroup.element,
    '원소 공명',
    Balance.upgradeAmplify,
    maxLevel: 10,
    baseCost: 80,
    amplifies: {
      StatType.burnChance,
      StatType.chillChance,
      StatType.shockChance,
    },
  ),
  ailmentChance(
    UpgradeGroup.element,
    '깊은 상처',
    Balance.upgradeAmplify,
    maxLevel: 10,
    baseCost: 80,
    amplifies: {StatType.bleedChance, StatType.poisonChance},
  ),
  magnetRange(
    UpgradeGroup.utility,
    '불씨 부름',
    Balance.upgradeMagnetRange,
    maxLevel: 5,
    baseCost: 30,
    stat: StatType.magnetRange,
  ),
  xpGain(
    UpgradeGroup.utility,
    '깨달음',
    Balance.upgradeXpGain,
    maxLevel: 10,
    baseCost: 40,
    stat: StatType.xpGain,
  ),
  emberGain(
    UpgradeGroup.utility,
    '잔불 수확',
    Balance.upgradeEmberGain,
    maxLevel: 10,
    baseCost: 60,
  ),
  fateRerolls(UpgradeGroup.fate, '다시 기도하기', 1, maxLevel: 3, baseCost: 200),
  fateChoices(UpgradeGroup.fate, '만신전의 문', 1, maxLevel: 1, baseCost: 1500),
  fateLuck(
    UpgradeGroup.fate,
    '깊은 신앙',
    Balance.upgradeFateLuck,
    maxLevel: 5,
    baseCost: 150,
  );

  const Upgrade(
    this.group,
    this.title,
    this.perLevel, {
    required this.maxLevel,
    required this.baseCost,
    this.stat,
    this.adds = const {},
    this.amplifies = const {},
  });

  final UpgradeGroup group;
  final String title;
  final double perLevel;
  final int maxLevel;
  final double baseCost;

  /// 이 강화가 올리는 능력치. 능력치가 아닌 강화는 null.
  final StatType? stat;

  /// 함께 같은 양을 더하는 여러 능력치 (모든 저항처럼).
  final Set<StatType> adds;

  /// 더하지 않고 (1 + 효과)배로 키우는 능력치.
  final Set<StatType> amplifies;

  /// [stat] 에 효과를 더하는 강화인가.
  bool raises(StatType stat) => this.stat == stat || adds.contains(stat);

  /// [level] 에서 다음 레벨로 올리는 비용.
  int cost(int level) =>
      (baseCost * math.pow(Balance.upgradeCostGrowth, level)).round();

  /// [level] 일 때의 효과.
  String effect(int level) {
    final value = perLevel * level;
    if (stat case final stat?) return stat.format(value);
    return switch (this) {
      emberGain => '잔불 획득량 +${(value * 100).round()}%',
      fateRerolls => '은총 다시 뽑기 +${value.round()}회',
      fateChoices => '은총 카드 +${value.round()}장',
      fateLuck => '은총 카드 등급 운 +${(value * 100).round()}%',
      resist => '모든 원소 저항 +${(value * 100).round()}%',
      elementDamage => '원소 피해 ×${_times(value)} (화염 · 냉기 · 번개 · 바람)',
      elementBuildup => '점화 · 냉각 · 감전 축적 ×${_times(value)}',
      ailmentChance => '출혈 · 중독 확률 ×${_times(value)}',
      _ => throw StateError('$this 의 효과 문구가 없다'),
    };
  }

  /// 곱하는 배율 문구 (1.05, 1.5).
  static String _times(double value) {
    final x = 1 + value;
    return x == x.roundToDouble()
        ? '${x.round()}'
        : '${(x * 100).round() / 100}';
  }
}

/// 산 영구 강화의 레벨.
class Upgrades extends ChangeNotifier {
  Upgrades([Map<Upgrade, int>? levels]) : _levels = {...?levels};

  factory Upgrades.fromJson(Map<String, dynamic> json) => Upgrades({
    for (final upgrade in Upgrade.values)
      if (json[upgrade.name] case final int level) upgrade: level,
  });

  final Map<Upgrade, int> _levels;

  int level(Upgrade upgrade) => _levels[upgrade] ?? 0;

  /// 지금 레벨의 총 효과량.
  double value(Upgrade upgrade) => upgrade.perLevel * level(upgrade);

  /// 강화로 오른 [stat] 의 합.
  double bonus(StatType stat) => Upgrade.values
      .where((u) => u.raises(stat))
      .fold(0, (sum, u) => sum + value(u));

  /// [stat] 의 합에 곱하는 배율. 곱하는 강화가 없으면 1.
  double amplify(StatType stat) => Upgrade.values
      .where((u) => u.amplifies.contains(stat))
      .fold(1, (product, u) => product * (1 + value(u)));

  bool isMax(Upgrade upgrade) => level(upgrade) >= upgrade.maxLevel;

  int cost(Upgrade upgrade) => upgrade.cost(level(upgrade));

  bool canBuy(Upgrade upgrade, Inventory inventory) =>
      !isMax(upgrade) && inventory.ember >= cost(upgrade);

  /// [inventory] 의 잔불을 써서 한 레벨 올린다.
  void buy(Upgrade upgrade, Inventory inventory) {
    assert(canBuy(upgrade, inventory), '잔불이 모자라거나 최대 레벨이다');
    inventory.spendEmber(cost(upgrade));
    _levels[upgrade] = level(upgrade) + 1;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    for (final MapEntry(:key, :value) in _levels.entries) key.name: value,
  };
}
