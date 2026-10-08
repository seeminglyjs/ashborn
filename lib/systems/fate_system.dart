import 'dart:math' as math;

import '../components/player/player.dart';
import '../data/balance.dart';
import '../data/equipment.dart';
import '../data/fates.dart';
import '../data/stats.dart';
import '../data/weapons.dart';
import '../game/world/run_world.dart';
import 'level_system.dart';

/// 이번 런에서 고른 운명. 런이 끝나면 사라진다.
class RunFate {
  final taken = <FateCard>[];

  /// 남은 다시 뽑기 횟수.
  int rerolls = Balance.fateRerolls;

  int _count(FateCard card) => taken.where((c) => c == card).length;

  double _stack(double multiplier, FateCard card) =>
      math.pow(multiplier, _count(card)).toDouble();

  double bonus(StatType stat) =>
      taken.fold(0, (sum, card) => sum + (card.stats[stat] ?? 0));

  Set<UniqueEffect> get effects => {for (final card in taken) ?card.effect};

  /// 불사조의 깃털로 얻은 부활 횟수.
  int get revives => _count(FateCard.phoenixFeather);

  double get enemyHpMultiplier =>
      _stack(Balance.curseEnemyHp, FateCard.thickAsh);
  double get emberMultiplier =>
      _stack(Balance.curseEmber, FateCard.thickAsh) *
      (1 + Balance.fateEmberGain * _count(FateCard.emberCollector));
  double get enemyDamageMultiplier =>
      _stack(Balance.curseEnemyDamage, FateCard.bloodOath);
  double get dropMultiplier =>
      _stack(Balance.curseDrop, FateCard.bloodOath) *
      (1 + Balance.fateDropGain * _count(FateCard.treasureHunter));
}

/// 운명 카드 추첨과 적용.
abstract final class FateSystem {
  /// 지금 고를 의미가 있는 카드인지.
  static bool available(FateCard card, Player player) => switch (card) {
    FateCard.smithsTouch => player.weapons.any(
      (w) => w.level < WeaponId.maxLevel,
    ),
    FateCard.newArms => player.weapons.length < WeaponId.values.length,
    _ => !player.effects.contains(card.effect),
  };

  /// 종류를 고르게 먼저 뽑고, 그 종류에서 등급을 가중치로, 그 등급에서 카드를 뽑는다.
  /// 한 번에 같은 카드는 없고, 같은 종류는 [FateType.limit] 장까지.
  static List<FateCard> roll(Player player, math.Random random) {
    final pool = FateCard.values.where((c) => available(c, player)).toList();
    final hand = <FateCard>[];
    while (hand.length < Balance.fateChoices) {
      pool.removeWhere(
        (c) => hand.where((h) => h.type == c.type).length >= c.type.limit,
      );
      if (pool.isEmpty) break;
      final types = {for (final card in pool) card.type}.toList();
      final type = types[random.nextInt(types.length)];
      final ofType = pool.where((c) => c.type == type);
      final tiers = {for (final card in ofType) card.tier}.toList();
      var pick = random.nextDouble() * tiers.fold(0.0, (s, t) => s + t.weight);
      final tier = tiers.firstWhere(
        (t) => (pick -= t.weight) < 0,
        orElse: () => tiers.last,
      );
      final cards = ofType.where((c) => c.tier == tier).toList();
      final card = cards[random.nextInt(cards.length)];
      hand.add(card);
      pool.remove(card);
    }
    return hand;
  }

  static void apply(FateCard card, RunWorld world) {
    world.fate.taken.add(card);
    final player = world.player;
    final random = world.game.random;
    switch (card) {
      case FateCard.breather:
        player.heal(player.maxHp);
      case FateCard.emberGather:
        world.bankEmber(bonus: (Balance.fateEmber * world.stage.level).round());
      case FateCard.smithsTouch:
        final weapons = player.weapons
            .where((w) => w.level < WeaponId.maxLevel)
            .toList();
        final weapon = weapons[random.nextInt(weapons.length)];
        for (var i = 0; i < Balance.fateWeaponLevels; i++) {
          if (weapon.level < WeaponId.maxLevel) weapon.levelUp();
        }
      case FateCard.newArms:
        final missing = WeaponId.values
            .where((id) => player.weapon(id) == null)
            .toList();
        player.gainWeapon(missing[random.nextInt(missing.length)]);
      case FateCard.ashFlood:
        final stats = world.game.stats;
        var xp = stats.xpToNext.value - stats.xp.value;
        for (var i = 1; i < Balance.fateLevels; i++) {
          xp += LevelSystem.xpToNext(stats.level.value + i);
        }
        world.gainXp(xp);
      default:
        break;
    }
    player.syncMaxHp();
  }
}
