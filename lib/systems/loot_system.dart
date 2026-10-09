import 'dart:math' as math;

import '../data/balance.dart';
import '../data/equipment.dart';
import '../data/stages.dart';
import '../data/stats.dart';

/// 장비 드랍과 생성.
abstract final class LootSystem {
  /// 장비가 떨어졌을 때 그 등급이 나올 확률. [luck] · [ratio] 는 [rollRarity] 와 같다.
  static double rarityChance(
    Rarity rarity, {
    double luck = 0,
    double ratio = Balance.rarityDropRatio,
  }) => _chance(rarity, Rarity.unique, _luckyRatio(ratio, luck));

  /// 보스 상자 장비 한 개가 [rarity] 등급일 확률. 레어 미만은 레어로 올라간다.
  static double bossChestChance(Rarity rarity, {double luck = 0}) =>
      switch (rarity) {
        Rarity.normal => 0,
        Rarity.rare =>
          rarityChance(Rarity.normal, luck: luck) +
              rarityChance(Rarity.rare, luck: luck),
        _ => rarityChance(rarity, luck: luck),
      };

  /// [item] 등급 장비의 옵션 한 줄이 [rarity] 등급일 확률.
  static double affixRarityChance(Rarity rarity, Rarity item) =>
      _chance(rarity, item, Balance.affixRarityRatio);

  /// [stage] 에서 적 하나를 처치했을 때. 대부분은 null.
  /// 장비 레벨은 스테이지 레벨이고, 타락 단계가 높을수록 자주, 좋게 떨어진다.
  /// [chanceMultiplier] 는 저주처럼 드랍 확률만 키우는 배율.
  static Item? rollDrop(
    math.Random random, [
    Stage stage = Stage.first,
    double chanceMultiplier = 1,
  ]) =>
      random.nextDouble() <
          Balance.itemDropChance * stage.dropChanceMultiplier * chanceMultiplier
      ? generate(
          random,
          level: stage.level,
          rarity: rollRarity(random, luck: stage.rarityLuck),
        )
      : null;

  /// 보스 상자: 최소 [Rarity.rare] 장비 [Balance.bossChestItems] 개.
  static List<Item> bossChest(math.Random random, Stage stage) => [
    for (var i = 0; i < Balance.bossChestItems; i++)
      generate(
        random,
        level: stage.level,
        rarity:
            Rarity.values[math.max(
              Rarity.rare.index,
              rollRarity(random, luck: stage.rarityLuck).index,
            )],
      ),
  ];

  /// [luck] 만큼 높은 등급 가중치가 커진다 (타락 보상).
  /// [ratio] 는 한 등급 오를 때마다 줄어드는 가중치 배율.
  static Rarity rollRarity(
    math.Random random, {
    double luck = 0,
    double ratio = Balance.rarityDropRatio,
  }) => _roll(random, Rarity.unique, _luckyRatio(ratio, luck));

  static double _luckyRatio(double ratio, double luck) =>
      math.min(ratio * (1 + luck), Balance.maxRarityRatio);

  /// 옵션 등급. 장비 등급 [cap] 을 넘지 않는다.
  static Rarity rollAffixRarity(math.Random random, Rarity cap) =>
      _roll(random, cap, Balance.affixRarityRatio);

  /// 옵션 칸마다 등급별 확률로 붙는다. 0개부터 최대 [Balance.maxAffixes] 개.
  static int rollAffixCount(math.Random random, Rarity rarity) =>
      [for (var i = 0; i < Balance.maxAffixes; i++) random.nextDouble()]
          .where((r) => r < rarity.affixChance)
          .length;

  static Item generate(
    math.Random random, {
    ItemType? type,
    Rarity? rarity,
    int level = 1,
  }) {
    final itemType =
        type ?? ItemType.values[random.nextInt(ItemType.values.length)];
    final itemRarity = rarity ?? rollRarity(random);
    double roll(StatType stat, double scale, Rarity grade) {
      final variance = 1 + (random.nextDouble() * 2 - 1) * Balance.statVariance;
      final levelScale = stat.percent
          ? 1
          : math.pow(Balance.itemLevelGrowth, level - 1);
      final raw =
          stat.roll * scale * grade.statMultiplier * levelScale * variance;
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
      effect: itemRarity == Rarity.unique
          ? UniqueEffect.values[random.nextInt(UniqueEffect.values.length)]
          : null,
      level: level,
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
