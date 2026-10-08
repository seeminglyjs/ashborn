import 'dart:math' as math;

import '../data/balance.dart';
import '../data/equipment.dart';
import '../data/stats.dart';

/// 장비 드랍과 생성.
abstract final class LootSystem {
  /// 장비가 떨어졌을 때 그 등급이 나올 확률.
  static double rarityChance(Rarity rarity) =>
      _chance(rarity, Rarity.unique, Balance.rarityDropRatio);

  /// [item] 등급 장비의 옵션 한 줄이 [rarity] 등급일 확률.
  static double affixRarityChance(Rarity rarity, Rarity item) =>
      _chance(rarity, item, Balance.affixRarityRatio);

  /// 적 하나를 처치했을 때. 대부분은 null.
  static Item? rollDrop(math.Random random) =>
      random.nextDouble() < Balance.itemDropChance ? generate(random) : null;

  static Rarity rollRarity(math.Random random) =>
      _roll(random, Rarity.unique, Balance.rarityDropRatio);

  /// 옵션 등급. 장비 등급 [cap] 을 넘지 않는다.
  static Rarity rollAffixRarity(math.Random random, Rarity cap) =>
      _roll(random, cap, Balance.affixRarityRatio);

  /// 옵션 칸마다 등급별 확률로 붙는다. 0개부터 최대 [Balance.maxAffixes] 개.
  static int rollAffixCount(math.Random random, Rarity rarity) =>
      [for (var i = 0; i < Balance.maxAffixes; i++) random.nextDouble()]
          .where((r) => r < rarity.affixChance)
          .length;

  static Item generate(math.Random random, {ItemType? type, Rarity? rarity}) {
    final itemType =
        type ?? ItemType.values[random.nextInt(ItemType.values.length)];
    final itemRarity = rarity ?? rollRarity(random);
    double roll(StatType stat, double scale, Rarity grade) {
      final variance = 1 + (random.nextDouble() * 2 - 1) * Balance.statVariance;
      final raw = stat.roll * scale * grade.statMultiplier * variance;
      return math.max(1, (raw / stat.step).round()) * stat.step;
    }

    StatRoll affix(StatType stat) {
      final grade = rollAffixRarity(random, itemRarity);
      return (
        stat: stat,
        value: roll(stat, Balance.affixScale, grade),
        rarity: grade,
      );
    }

    final main = itemType.mainStats[random.nextInt(itemType.mainStats.length)];
    final affixes = StatType.values.where((s) => s != main).toList()
      ..shuffle(random);
    return Item(
      type: itemType,
      rarity: itemRarity,
      stats: [
        (
          stat: main,
          value: roll(main, itemType.mainScale, itemRarity),
          rarity: itemRarity,
        ),
        for (final stat in affixes.take(rollAffixCount(random, itemRarity)))
          affix(stat),
      ],
    );
  }

  static double _weight(Rarity rarity, double ratio) =>
      math.pow(ratio, rarity.index).toDouble();

  static double _total(Rarity cap, double ratio) => Rarity.values
      .take(cap.index + 1)
      .fold(0.0, (sum, r) => sum + _weight(r, ratio));

  static double _chance(Rarity rarity, Rarity cap, double ratio) =>
      rarity.index > cap.index
      ? 0
      : _weight(rarity, ratio) / _total(cap, ratio);

  static Rarity _roll(math.Random random, Rarity cap, double ratio) {
    var pick = random.nextDouble() * _total(cap, ratio);
    for (final rarity in Rarity.values.take(cap.index + 1)) {
      pick -= _weight(rarity, ratio);
      if (pick < 0) return rarity;
    }
    return Rarity.normal;
  }
}
