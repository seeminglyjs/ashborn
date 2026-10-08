import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';
import 'stats.dart';

/// 장비 등급. 노말이 가장 낮고 고유가 가장 높다.
enum Rarity {
  normal('노말', Color(0xFFB8B8B8)),
  rare('레어', Color(0xFF4A90E2)),
  hero('영웅', Color(0xFFA35BE0)),
  legend('전설', Color(0xFFF5A623)),
  epic('에픽', Color(0xFFE8463A)),
  unique('고유', Color(0xFF2EE6C6));

  const Rarity(this.label, this.color);

  final String label;
  final Color color;

  /// 드랍 가중치. 한 등급 오를 때마다 [Balance.rarityDropRatio] 배로 줄어든다.
  double get dropWeight => math.pow(Balance.rarityDropRatio, index).toDouble();

  /// 수치 배율. 한 등급 오를 때마다 [Balance.rarityStatGrowth] 배.
  double get statMultiplier =>
      math.pow(Balance.rarityStatGrowth, index).toDouble();

  /// 주옵션 외 추가옵션 수. 노말 0개에서 고유 5개.
  int get affixCount => index;
}

/// 장비 파츠와 그 주옵션.
enum ItemType {
  head('머리', StatType.maxHp),
  boots('장화', StatType.moveSpeed),
  twoHand('양손장비', StatType.damage, mainScale: Balance.twoHandMainScale),
  oneHand('한손장비', StatType.damage),
  gloves('장갑', StatType.attackSpeed),
  necklace('목걸이', StatType.xpGain),
  ring('반지', StatType.hpRegen),
  belt('허리띠', StatType.defense),
  earring('귀걸이', StatType.magnetRange);

  const ItemType(this.label, this.mainStat, {this.mainScale = 1});

  final String label;
  final StatType mainStat;
  final double mainScale;
}

/// 장비를 끼는 칸. 반지, 귀걸이, 한손장비는 두 칸에 낄 수 있다.
/// 양손장비는 [hand1] 에 끼고 [hand2] 를 비운다.
enum EquipSlot {
  head('머리', ItemType.head),
  necklace('목걸이', ItemType.necklace),
  earring1('귀걸이 1', ItemType.earring),
  earring2('귀걸이 2', ItemType.earring),
  hand1('주 손', ItemType.oneHand),
  hand2('보조 손', ItemType.oneHand),
  gloves('장갑', ItemType.gloves),
  belt('허리띠', ItemType.belt),
  ring1('반지 1', ItemType.ring),
  ring2('반지 2', ItemType.ring),
  boots('장화', ItemType.boots);

  const EquipSlot(this.label, this.type);

  final String label;
  final ItemType type;

  bool accepts(ItemType item) =>
      item == type || (this == hand1 && item == ItemType.twoHand);
}

typedef StatRoll = ({StatType stat, double value});

/// 장비 한 개. [stats] 의 첫 줄이 주옵션이다.
class Item {
  Item({required this.type, required this.rarity, required this.stats});

  factory Item.fromJson(Map<String, dynamic> json) => Item(
    type: ItemType.values.byName(json['type'] as String),
    rarity: Rarity.values.byName(json['rarity'] as String),
    stats: [
      for (final s in json['stats'] as List)
        (
          stat: StatType.values.byName(s['stat'] as String),
          value: (s['value'] as num).toDouble(),
        ),
    ],
  );

  final ItemType type;
  final Rarity rarity;
  final List<StatRoll> stats;

  String get name => '${rarity.label} ${type.label}';

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'rarity': rarity.name,
    'stats': [
      for (final s in stats) {'stat': s.stat.name, 'value': s.value},
    ],
  };
}
