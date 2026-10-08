import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'inventory.dart';
import 'stats.dart';

enum UpgradeGroup {
  basic('기본 능력'),
  utility('편의'),
  fate('운명 조작');

  const UpgradeGroup(this.label);

  final String label;
}

/// 화톳불에서 잔불로 사는 영구 강화. 모든 캐릭터에 붙는다.
///
/// 레벨마다 [perLevel] 만큼 오르고, 다음 레벨 비용은 [baseCost] 에서
/// [Balance.upgradeCostGrowth] 배씩 는다.
enum Upgrade {
  maxHp(
    UpgradeGroup.basic,
    '단단한 몸',
    Balance.upgradeMaxHp,
    maxLevel: 10,
    baseCost: 30,
    stat: StatType.maxHp,
  ),
  damage(
    UpgradeGroup.basic,
    '불꽃의 힘',
    Balance.upgradeDamage,
    maxLevel: 10,
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
    maxLevel: 10,
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
  fateRerolls(UpgradeGroup.fate, '운명 거스르기', 1, maxLevel: 3, baseCost: 200),
  fateChoices(UpgradeGroup.fate, '넓어진 시야', 1, maxLevel: 1, baseCost: 1500),
  fateLuck(
    UpgradeGroup.fate,
    '별의 가호',
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
  });

  final UpgradeGroup group;
  final String title;
  final double perLevel;
  final int maxLevel;
  final double baseCost;

  /// 이 강화가 올리는 능력치. 능력치가 아닌 강화는 null.
  final StatType? stat;

  /// [level] 에서 다음 레벨로 올리는 비용.
  int cost(int level) =>
      (baseCost * math.pow(Balance.upgradeCostGrowth, level)).round();

  /// [level] 일 때의 효과.
  String effect(int level) {
    final value = perLevel * level;
    if (stat case final stat?) return stat.format(value);
    return switch (this) {
      emberGain => '잔불 획득량 +${(value * 100).round()}%',
      fateRerolls => '운명 다시 뽑기 +${value.round()}회',
      fateChoices => '운명 카드 +${value.round()}장',
      fateLuck => '운명 카드 등급 운 +${(value * 100).round()}%',
      _ => throw StateError('$this 의 효과 문구가 없다'),
    };
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
      .where((u) => u.stat == stat)
      .fold(0, (sum, u) => sum + value(u));

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
