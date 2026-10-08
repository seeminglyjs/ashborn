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

  /// 수치 배율. 한 등급 오를 때마다 [Balance.rarityStatGrowth] 배.
  double get statMultiplier =>
      math.pow(Balance.rarityStatGrowth, index).toDouble();

  /// 랜덤옵션 한 칸이 붙을 확률. 최대 [Balance.maxAffixes] 칸.
  double get affixChance => Balance.affixChance[index];
}

/// 장비 파츠. 주옵션은 [mainStats] 중 하나가 무작위로 정해진다.
enum ItemType {
  head('머리', [StatType.maxHp, StatType.energyShield]),
  boots('장화', [StatType.moveSpeed, StatType.evasion]),
  twoHand('양손장비', _weaponStats, mainScale: Balance.twoHandMainScale),
  oneHand('한손장비', _weaponStats),
  gloves('장갑', [StatType.attackSpeed, StatType.critChance]),
  necklace('목걸이', [StatType.damage, StatType.critDamage]),
  ring('반지', [
    StatType.physicalReduction,
    StatType.fireResist,
    StatType.coldResist,
    StatType.lightningResist,
    StatType.windResist,
  ]),
  belt('허리띠', [StatType.armor, StatType.maxHp]),
  earring('귀걸이', [StatType.magnetRange, StatType.xpGain, StatType.hpRegen]);

  const ItemType(this.label, this.mainStats, {this.mainScale = 1});

  final String label;
  final List<StatType> mainStats;
  final double mainScale;
}

const _weaponStats = [
  StatType.physicalDamage,
  StatType.fireDamage,
  StatType.coldDamage,
  StatType.lightningDamage,
  StatType.windDamage,
];

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

/// 옵션 한 줄. 옵션마다 자기 등급이 있고, 장비 등급보다 높을 수 없다.
typedef StatRoll = ({StatType stat, double value, Rarity rarity});

/// 장비 한 개. [stats] 의 첫 줄이 주옵션(장비와 같은 등급)이다.
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
          rarity: Rarity.values.byName(s['rarity'] as String),
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
      for (final s in stats)
        {'stat': s.stat.name, 'value': s.value, 'rarity': s.rarity.name},
    ],
  };
}
