import 'dart:math' as math;

import '../components/player/player.dart';
import '../data/balance.dart';
import '../data/damage.dart';
import '../data/equipment.dart';
import '../data/fates.dart';
import '../data/stats.dart';
import '../data/upgrades.dart';
import '../data/weapons.dart';
import '../game/world/run_world.dart';
import 'level_system.dart';
import 'loot_system.dart';

/// 이번 런에서 받은 신의 은총. 런이 끝나면 사라진다.
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

  /// 은총으로 얻은 [effect] 의 세기. 없으면 0, 같은 효과는 가장 높은 등급만 친다.
  double effectPower(UniqueEffect effect) => taken
      .where((f) => f.card.effect == effect)
      .fold(0, (best, f) => math.max(best, f.power));

  /// 원소 은총이 모든 공격에 더하는 [type] 피해. 무기 기본 피해에 대한 비율이고 겹치면 더한다.
  double extraDamage(DamageType type) => taken
      .where((f) => f.card.element == type)
      .fold(0, (sum, f) => sum + f.extraDamage);

  /// 오시리스의 부활마다 한 번씩 되살아날 때의 체력 비율.
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

/// 신의 은총 카드 추첨과 적용.
abstract final class FateSystem {
  /// 지금 고를 의미가 있는 카드인지. 이미 가진 효과는 더 높은 등급으로만 다시 나온다.
  static bool available(Fate fate, Player player) => switch (fate.card) {
    FateCard.smithsTouch => player.weapons.any(
      (w) => w.level < WeaponId.maxLevel,
    ),
    FateCard.newArms => WeaponId.poolFor(
      player.character.id,
    ).any((id) => player.weapon(id) == null),
    FateCard(effect: final effect?) => player.effectPower(effect) < fate.power,
    _ => true,
  };

  /// 카드 [Balance.fateChoices] 장 (화톳불 강화로 늘어난다). 종류는 같은 종류
  /// 상한 안에서 고르게 뽑고, 그 종류에서 등급과 카드를 뽑는다. 한 번에 같은 카드는 없다.
  static List<Fate> roll(Player player, math.Random random) {
    final upgrades = player.game.upgrades;
    final count = math.min(
      Balance.fateChoices + upgrades.value(Upgrade.fateChoices).round(),
      Balance.maxCardChoices,
    );
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

  /// [type] 카드 한 장을 뽑을 때 저주 카드끼리, 또는 저주 아닌 카드끼리 고르는 무리.
  /// 저주가 없는 종류는 저주 추첨과 상관없이 모든 카드다.
  static List<FateCard> _pool(FateType type, bool curse) {
    final cards = FateCard.values.where((c) => c.type == type).toList();
    return cards.any((c) => c.curse == curse)
        ? cards.where((c) => c.curse == curse).toList()
        : cards;
  }

  /// 카드 [count] 장 중 [type] 카드의 평균 장수. [roll] 처럼 매 장마다 상한이 차지 않은
  /// 종류 중 하나를 같은 확률로 고른다 (어느 종류든 뽑을 카드가 남아 있을 때 기준).
  static double expectedTypeCount(FateType type, int count) {
    double expect(Map<FateType, int> counts, int left) {
      final open = FateType.values
          .where((t) => (counts[t] ?? 0) < t.limit)
          .toList();
      if (left == 0 || open.isEmpty) return (counts[type] ?? 0).toDouble();
      return open.fold<double>(
            0,
            (sum, t) =>
                sum + expect({...counts, t: (counts[t] ?? 0) + 1}, left - 1),
          ) /
          open.length;
    }

    return expect(const {}, count);
  }

  /// [card] 의 종류가 골라졌을 때 그 한 장이 [card] 로 나올 확률 (등급은 모두 더한다).
  /// 손에 든 카드 · 가진 효과 · 더 얻을 수 없는 무기로 빠지는 카드가 없을 때 기준이며,
  /// [_draw] 와 같은 순서로 계산한다. 확률표가 이 값을 그대로 보여 준다.
  static double cardChance(FateCard card, {double luck = 0}) {
    final hasCurse = FateCard.values.any((c) => c.type == card.type && c.curse);
    final poolChance = !hasCurse
        ? 1.0
        : card.curse
        ? Balance.fateCurseChance
        : 1 - Balance.fateCurseChance;
    final pool = _pool(card.type, card.curse);
    final floor = pool.map((c) => c.minRarity.index).reduce(math.min);
    var chance = 0.0;
    for (final rolled in Rarity.values) {
      final p = LootSystem.rarityChance(
        rolled,
        luck: luck,
        ratio: Balance.fateRarityRatio,
        highScale: 1,
      );
      final rarity = math.max(rolled.index, floor);
      if (card.minRarity.index > rarity) continue;
      final candidates = pool.where((c) => c.minRarity.index <= rarity).length;
      chance += p / candidates;
    }
    return poolChance * chance;
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
      highScale: 1,
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
        final missing = WeaponId.poolFor(player.character.id)
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
