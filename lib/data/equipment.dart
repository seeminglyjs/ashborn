import 'dart:math' as math;
import 'dart:ui';

import 'balance.dart';
import 'stats.dart';
import 'transcend.dart';

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

  /// 이 등급 장비가 갈 수 있는 최대 초월 단계. 0이면 초월할 수 없다.
  int get maxTranscend => Balance.maxTranscend[index];
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
/// [hand1] 은 오른손(주로 쓰는 손), [hand2] 는 왼손. 양손장비는 오른손에 끼고 왼손을 비운다.
enum EquipSlot {
  head('머리', ItemType.head),
  necklace('목걸이', ItemType.necklace),
  earring1('귀걸이', ItemType.earring),
  earring2('귀걸이', ItemType.earring),
  hand1('오른손', ItemType.oneHand),
  hand2('왼손', ItemType.oneHand),
  gloves('장갑', ItemType.gloves),
  belt('허리띠', ItemType.belt),
  ring1('반지', ItemType.ring),
  ring2('반지', ItemType.ring),
  boots('장화', ItemType.boots);

  const EquipSlot(this.label, this.type);

  final String label;
  final ItemType type;

  /// 같은 이름의 칸이 둘일 때 어느 쪽인지 붙인 이름 (장비 화면에서 왼쪽 · 오른쪽 줄).
  String get place => switch (this) {
    earring1 || ring1 => '왼쪽 $label',
    earring2 || ring2 => '오른쪽 $label',
    _ => label,
  };

  bool accepts(ItemType item) =>
      item == type || (this == hand1 && item == ItemType.twoHand);
}

/// 고유 등급 장비에만 붙는 특수 효과. 같은 효과는 겹치지 않는다.
enum UniqueEffect {
  phoenix('불사조의 재'),
  emberBurst('잿불 폭발'),
  chainLightning('연쇄 번개'),
  frostArmor('서리 갑옷'),
  berserk('광전사의 분노');

  const UniqueEffect(this.label);

  final String label;

  String get description => switch (this) {
    phoenix => '쓰러지면 런마다 한 번, 체력 ${_p(Balance.phoenixHp)}로 되살아난다',
    emberBurst => '적을 처치하면 ${_p(Balance.emberBurstChance)} 확률로 주변에 화염 폭발',
    chainLightning =>
      '타격 시 ${_p(Balance.chainLightningChance)} 확률로 '
          '가까운 적 ${Balance.chainLightningTargets}명에게 번개',
    frostArmor =>
      '피격 시 주변 적의 이동 속도 ${_p(Balance.frostArmorSlow)} 감소 '
          '(${Balance.frostArmorDuration.round()}초)',
    berserk => '잃은 체력 1%당 피해 ${Balance.berserkScale.round()}% 증가',
  };

  static String _p(double v) => '${(v * 100).round()}%';
}

/// 옵션 한 줄. 옵션마다 자기 등급이 있고, 장비 등급보다 높을 수 없다.
typedef StatRoll = ({StatType stat, double value, Rarity rarity});

/// 장비 한 개. [stats] 의 첫 줄이 주옵션(장비와 같은 등급)이다.
///
/// [level] 은 떨어진 스테이지 레벨이고, [enhance] 는 강화석과 골드로 올리는 강화 단계다.
/// [transcends] 는 초월할 때마다 하나씩 붙는 초월 옵션이다.
class Item {
  Item({
    required this.type,
    required this.rarity,
    required this.stats,
    this.effect,
    this.level = 1,
    this.enhance = 0,
    List<TranscendRoll>? transcends,
  }) : transcends = transcends ?? [];

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
    effect: switch (json['effect']) {
      final String name => UniqueEffect.values.byName(name),
      _ => null,
    },
    level: json['level'] as int,
    enhance: json['enhance'] as int,
    transcends: [
      for (final t in json['transcends'] as List? ?? const [])
        (
          option: TranscendOption.values.byName(t['option'] as String),
          value: (t['value'] as num).toDouble(),
        ),
    ],
  );

  final ItemType type;
  final Rarity rarity;
  final List<StatRoll> stats;

  /// 고유 등급만 갖는다.
  final UniqueEffect? effect;

  final int level;
  int enhance;
  final List<TranscendRoll> transcends;

  String get name =>
      '${rarity.label} ${type.label}${enhance > 0 ? ' +$enhance' : ''}'
      '${transcends.isNotEmpty ? ' ★${transcends.length}' : ''}';

  bool get isMaxEnhance => enhance >= Balance.maxEnhance;

  /// 영웅 이상이고 아직 초월 단계가 남았는가. 실제로 하려면
  /// [Balance.transcendEnhance] 이상 강화해야 한다.
  bool get canEverTranscend => transcends.length < rarity.maxTranscend;

  bool get canTranscend =>
      canEverTranscend && enhance >= Balance.transcendEnhance;

  /// 다음 초월에 드는 초월석, 골드, 성공 확률.
  int get transcendStones => Balance.transcendStones[transcends.length];
  int get transcendGold =>
      (Balance.transcendGold *
              math.pow(Balance.transcendGoldGrowth, transcends.length) *
              _levelFactor)
          .round();
  double get transcendChance => Balance.transcendChances[transcends.length];

  /// 이 장비의 [option] 초월 수치. 없으면 0.
  double transcend(TranscendOption option) => transcends
      .where((t) => t.option == option)
      .fold(0, (sum, t) => sum + t.value);

  /// 강화를 반영한 옵션 수치.
  List<StatRoll> get effectiveStats => statsAt(enhance);

  /// 강화 단계가 [enhance] 일 때의 옵션 수치.
  List<StatRoll> statsAt(int enhance) {
    final scale = math.pow(Balance.enhanceStatGrowth, enhance);
    return [
      for (final s in stats)
        (stat: s.stat, value: s.value * scale, rarity: s.rarity),
    ];
  }

  double get _levelFactor => 1 + Balance.emberPerItemLevel * (level - 1);

  /// 다음 강화에 드는 강화석.
  int get enhanceStones =>
      Balance.enhanceStones + Balance.enhanceStonesPerStep * enhance;

  /// 다음 강화에 드는 골드.
  int get enhanceGold =>
      (Balance.enhanceGold *
              math.pow(Balance.enhanceGoldGrowth, enhance) *
              math.pow(Balance.enhanceRarityGrowth, rarity.index) *
              _levelFactor)
          .round();

  /// 다음 강화가 성공할 확률.
  double get enhanceChance => Balance.enhanceChances[enhance];

  /// 분해하면 얻는 잔불.
  int get salvageValue =>
      (Balance.salvageEmber *
              math.pow(Balance.salvageRarityGrowth, rarity.index) *
              _levelFactor *
              (1 + enhance * 0.5))
          .round();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'rarity': rarity.name,
    'stats': [
      for (final s in stats)
        {'stat': s.stat.name, 'value': s.value, 'rarity': s.rarity.name},
    ],
    if (effect != null) 'effect': effect!.name,
    'level': level,
    'enhance': enhance,
    if (transcends.isNotEmpty)
      'transcends': [
        for (final t in transcends) {'option': t.option.name, 'value': t.value},
      ],
  };
}
