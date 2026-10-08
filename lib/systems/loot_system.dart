import 'dart:math' as math;

import '../data/balance.dart';
import '../data/equipment.dart';
import '../data/stats.dart';

/// 장비 드랍과 생성.
abstract final class LootSystem {
  static final _totalWeight = Rarity.values.fold(
    0.0,
    (sum, r) => sum + r.dropWeight,
  );

  /// 장비가 떨어졌을 때 그 등급이 나올 확률.
  static double rarityChance(Rarity rarity) => rarity.dropWeight / _totalWeight;

  /// 적 하나를 처치했을 때. 대부분은 null.
  static Item? rollDrop(math.Random random) =>
      random.nextDouble() < Balance.itemDropChance ? generate(random) : null;

  static Rarity rollRarity(math.Random random) {
    var pick = random.nextDouble() * _totalWeight;
    for (final rarity in Rarity.values) {
      pick -= rarity.dropWeight;
      if (pick < 0) return rarity;
    }
    return Rarity.normal;
  }

  static Item generate(math.Random random, {ItemType? type, Rarity? rarity}) {
    final itemType =
        type ?? ItemType.values[random.nextInt(ItemType.values.length)];
    final itemRarity = rarity ?? rollRarity(random);
    double roll(StatType stat, double scale) {
      final variance = 1 + (random.nextDouble() * 2 - 1) * Balance.statVariance;
      final raw = stat.roll * scale * itemRarity.statMultiplier * variance;
      return math.max(1, (raw / stat.step).round()) * stat.step;
    }

    final affixes =
        StatType.values.where((s) => s != itemType.mainStat).toList()
          ..shuffle(random);
    return Item(
      type: itemType,
      rarity: itemRarity,
      stats: [
        (
          stat: itemType.mainStat,
          value: roll(itemType.mainStat, itemType.mainScale),
        ),
        for (final stat in affixes.take(itemRarity.affixCount))
          (stat: stat, value: roll(stat, Balance.affixScale)),
      ],
    );
  }
}
