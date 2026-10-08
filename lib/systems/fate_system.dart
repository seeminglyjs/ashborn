import 'dart:math' as math;

import '../components/player/player.dart';
import '../data/balance.dart';
import '../data/equipment.dart';
import '../data/fates.dart';
import '../data/stats.dart';
import '../data/upgrades.dart';
import '../data/weapons.dart';
import '../game/world/run_world.dart';
import 'level_system.dart';
import 'loot_system.dart';

/// 이번 런에서 고른 운명. 런이 끝나면 사라진다.
class RunFate {
  final taken = <Fate>[];

  /// 남은 다시 뽑기 횟수.
  int rerolls = Balance.fateRerolls;

  Iterable<Fate> _of(FateCard card) => taken.where((f) => f.card == card);

  double bonus(StatType stat) =>
      taken.fold(0, (sum, fate) => sum + (fate.stats[stat] ?? 0));

  Set<UniqueEffect> get effects => {
    for (final fate in taken) ?fate.card.effect,
  };

  /// 운명으로 얻은 [effect] 의 세기. 없으면 0, 같은 효과는 가장 높은 등급만 친다.
  double effectPower(UniqueEffect effect) => taken
      .where((f) => f.card.effect == effect)
      .fold(0, (best, f) => math.max(best, f.power));

  /// 불사조의 깃털마다 한 번씩 되살아날 때의 체력 비율.
  List<double> get reviveHps => [
    for (final fate in _of(FateCard.phoenixFeather)) fate.reviveHp,
  ];

  double get enemyHpMultiplier =>
      math.pow(Balance.curseEnemyHp, _of(FateCard.thickAsh).length).toDouble();
  double get enemyDamageMultiplier => math
      .pow(Balance.curseEnemyDamage, _of(FateCard.bloodOath).length)
      .toDouble();

  /// 저주 보상은 곱하고, 보상 카드는 더한다.
  double get emberMultiplier =>
      _product(FateCard.thickAsh) * (1 + _sum(FateCard.emberCollector));
  double get dropMultiplier =>
      _product(FateCard.bloodOath) * (1 + _sum(FateCard.treasureHunter));

  double _product(FateCard card) =>
      _of(card).fold(1, (product, f) => product * (1 + f.amount));
  double _sum(FateCard card) => _of(card).fold(0, (sum, f) => sum + f.amount);
}

/// 운명 카드 추첨과 적용.
abstract final class FateSystem {
  /// 지금 고를 의미가 있는 카드인지. 이미 가진 효과는 더 높은 등급으로만 다시 나온다.
  static bool available(Fate fate, Player player) => switch (fate.card) {
    FateCard.smithsTouch => player.weapons.any(
      (w) => w.level < WeaponId.maxLevel,
    ),
    FateCard.newArms => player.weapons.length < WeaponId.values.length,
    FateCard(effect: final effect?) => player.effectPower(effect) < fate.power,
    _ => true,
  };

  /// 카드 [Balance.fateChoices] 장 (화톳불 강화로 늘어난다). 종류는 같은 종류
  /// 상한 안에서 고르게 뽑고, 그 종류에서 등급과 카드를 뽑는다. 한 번에 같은 카드는 없다.
  static List<Fate> roll(Player player, math.Random random) {
    final upgrades = player.game.upgrades;
    final count =
        Balance.fateChoices + upgrades.value(Upgrade.fateChoices).round();
    final luck =
        player.world.stage.rarityLuck + upgrades.value(Upgrade.fateLuck);
    final hand = <Fate>[];
    while (hand.length < count) {
      final types =
          FateType.values
              .where(
                (t) => hand.where((f) => f.card.type == t).length < t.limit,
              )
              .toList()
            ..shuffle(random);
      Fate? fate;
      for (final type in types) {
        fate = _draw(type, hand, player, random, luck);
        if (fate != null) break;
      }
      if (fate == null) break;
      hand.add(fate);
    }
    return hand;
  }

  /// [type] 카드 한 장. 등급을 먼저 뽑고, 그 등급으로 나올 수 있는 카드 중에서 고른다.
  /// 뽑은 등급이 이 종류 카드의 최소 등급보다 낮으면 최소 등급으로 올린다.
  static Fate? _draw(
    FateType type,
    List<Fate> hand,
    Player player,
    math.Random random,
    double luck,
  ) {
    var cards = FateCard.values
        .where((c) => c.type == type && hand.every((f) => f.card != c))
        .toList();
    final curse = random.nextDouble() < Balance.fateCurseChance;
    if (cards.any((c) => c.curse == curse)) {
      cards = cards.where((c) => c.curse == curse).toList();
    }
    if (cards.isEmpty) return null;

    var rarity = LootSystem.rollRarity(
      random,
      luck: luck,
      ratio: Balance.fateRarityRatio,
    );
    final floor = cards
        .map((c) => c.minRarity)
        .reduce((a, b) => a.index <= b.index ? a : b);
    if (rarity.index < floor.index) rarity = floor;

    final fates = [
      for (final card in cards)
        if (card.minRarity.index <= rarity.index) Fate(card, rarity),
    ].where((f) => available(f, player)).toList();
    return fates.isEmpty ? null : fates[random.nextInt(fates.length)];
  }

  static void apply(Fate fate, RunWorld world) {
    world.fate.taken.add(fate);
    final player = world.player;
    final random = world.game.random;
    switch (fate.card) {
      case FateCard.breather:
        player.heal(player.maxHp * fate.amount);
      case FateCard.emberGather:
        world.bankEmber(bonus: (fate.amount * world.stage.level).round());
      case FateCard.smithsTouch:
        final weapons = player.weapons
            .where((w) => w.level < WeaponId.maxLevel)
            .toList();
        final weapon = weapons[random.nextInt(weapons.length)];
        for (var i = 0; i < fate.weaponLevels; i++) {
          if (weapon.level < WeaponId.maxLevel) weapon.levelUp();
        }
      case FateCard.newArms:
        final missing = WeaponId.values
            .where((id) => player.weapon(id) == null)
            .toList();
        final id = missing[random.nextInt(missing.length)];
        for (
          var i = 0;
          i < math.min(fate.newWeaponLevel, WeaponId.maxLevel);
          i++
        ) {
          player.gainWeapon(id);
        }
      case FateCard.ashFlood:
        final stats = world.game.stats;
        var xp = stats.xpToNext.value - stats.xp.value;
        for (var i = 1; i < fate.levels; i++) {
          xp += LevelSystem.xpToNext(stats.level.value + i);
        }
        world.gainXp(xp);
      default:
        break;
    }
    player.syncMaxHp();
  }
}
