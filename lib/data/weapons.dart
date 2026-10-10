import 'balance.dart';
import 'characters.dart';
import 'damage.dart';
import 'passives.dart';

/// 무기 레벨업으로 오르는 성질.
enum WeaponStat {
  damage,

  /// 칼날 · 구체 · 화살처럼 한 번에 나가는 수.
  count,
  area,

  /// 쿨다운 감소율 (0.1 = 10% 짧아짐).
  cooldown,
  pierce,
  speed,
  duration,

  /// 콤보 확률 (강철 대검). 0.1 = 10%p.
  combo,
}

/// 한 레벨에 오르는 성질과 양 (비율 성질은 0.2 = 20%).
typedef WeaponUpgrade = Map<WeaponStat, double>;

/// 자동 공격 무기 정의. 레벨마다 [upgrades] 의 서로 다른 성질이 오른다.
/// 무기 기본 피해는 [damageType] 이고, 장비의 속성 피해가 따로 더해진다.
///
/// [owner] 가 있으면 그 캐릭터 전용, null 이면 모든 캐릭터가 얻을 수 있다.
/// 최대 레벨에서 [catalyst] 패시브를 갖고 있으면 [awakenedLabel] 로 각성할 수 있다.
enum WeaponId {
  greatsword(
    '강철 대검',
    '가장 가까운 적을 찌른다. 레벨이 오르면 휘두르기 · 내려찍기를 익히고 콤보로 잇는다',
    '콤보',
    DamageType.physical,
    owner: CharacterId.knight,
    catalyst: PassiveId.vitality,
    awakenedLabel: '거신의 대검',
    upgrades: [
      {WeaponStat.combo: 0.15},
      {WeaponStat.combo: 0.05},
      {WeaponStat.combo: 0.05},
      {WeaponStat.damage: 0.25},
      {WeaponStat.combo: 0.05, WeaponStat.area: 0.15},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.combo: 0.05, WeaponStat.damage: 0.3},
    ],
    perks: {
      Balance.swingLevel: '휘두르기 습득',
      Balance.slamLevel: '내려찍기 습득',
      Balance.onslaughtLevel: '맹공 습득',
    },
  ),
  earthSlam(
    '대지 강타',
    '주변 땅을 내려쳐 적에게 피해를 주고 날려 보내는 충격파',
    '파동',
    DamageType.physical,
    owner: CharacterId.knight,
    catalyst: PassiveId.ironSkin,
    awakenedLabel: '지진',
    upgrades: [
      {WeaponStat.damage: 0.25},
      {WeaponStat.area: 0.15},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.damage: 0.25},
      {WeaponStat.area: 0.2},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.damage: 0.4},
    ],
  ),
  cleave(
    '심판의 일격',
    '가장 가까운 적 쪽을 넓게 베어 가르는 반달 참격',
    '참격',
    DamageType.physical,
    owner: CharacterId.knight,
    catalyst: PassiveId.fury,
    awakenedLabel: '심판의 검',
    upgrades: [
      {WeaponStat.damage: 0.2},
      {WeaponStat.area: 0.15},
      {WeaponStat.count: 1},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.damage: 0.3},
      {WeaponStat.area: 0.2},
      {WeaponStat.count: 1, WeaponStat.damage: 0.2},
    ],
  ),
  warCry(
    '전투 함성',
    '주변 적에게 피해를 주고 느리게 묶는 함성. 외친 뒤 잠시 받는 피해가 줄어든다',
    '함성',
    DamageType.physical,
    owner: CharacterId.knight,
    catalyst: PassiveId.ironSkin,
    awakenedLabel: '전쟁의 포효',
    upgrades: [
      {WeaponStat.area: 0.15},
      {WeaponStat.damage: 0.25},
      {WeaponStat.duration: 0.3},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.area: 0.15, WeaponStat.damage: 0.2},
      {WeaponStat.duration: 0.3},
      {WeaponStat.damage: 0.4, WeaponStat.cooldown: 0.1},
    ],
  ),
  emberOrb(
    '잔불 구체',
    '가장 가까운 적을 노리는 불씨. 레벨이 오르면 과열을 익혀 큰 화염구를 섞어 쏜다',
    '구체',
    DamageType.fire,
    owner: CharacterId.witch,
    catalyst: PassiveId.magnetism,
    awakenedLabel: '유성 잔불',
    upgrades: [
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.2},
      {WeaponStat.cooldown: 0.1},
      {WeaponStat.count: 1},
      {WeaponStat.pierce: 1},
      {WeaponStat.damage: 0.25},
      {WeaponStat.count: 1, WeaponStat.speed: 0.2},
    ],
    perks: {Balance.overheatLevel: '과열 습득'},
  ),
  meteor(
    '운석 낙하',
    '화면 안의 적 머리 위로 떨어지는 불덩이',
    '운석',
    DamageType.fire,
    owner: CharacterId.witch,
    catalyst: PassiveId.wisdom,
    awakenedLabel: '유성우',
    upgrades: [
      {WeaponStat.damage: 0.2},
      {WeaponStat.count: 1},
      {WeaponStat.area: 0.2},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.3},
      {WeaponStat.area: 0.2, WeaponStat.count: 1},
    ],
  ),
  fireTornado(
    '화염 회오리',
    '사방으로 떠돌며 닿는 적을 태우는 회오리',
    '회오리',
    DamageType.fire,
    owner: CharacterId.witch,
    catalyst: PassiveId.haste,
    awakenedLabel: '화염 폭풍',
    upgrades: [
      {WeaponStat.duration: 0.25},
      {WeaponStat.damage: 0.2},
      {WeaponStat.count: 1},
      {WeaponStat.area: 0.2},
      {WeaponStat.speed: 0.2, WeaponStat.duration: 0.25},
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.35},
    ],
  ),
  emberSpirits(
    '잔불 정령',
    '몸 주변을 돌며 닿는 적을 태우는 불덩이 정령',
    '정령',
    DamageType.fire,
    owner: CharacterId.witch,
    catalyst: PassiveId.regrowth,
    awakenedLabel: '불새 정령',
    upgrades: [
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.25},
      {WeaponStat.speed: 0.2},
      {WeaponStat.count: 1},
      {WeaponStat.area: 0.2},
      {WeaponStat.damage: 0.3},
      {WeaponStat.count: 1, WeaponStat.damage: 0.2},
    ],
  ),
  fireCrossbow(
    '사냥 석궁',
    '적을 꿰뚫는 강철 화살. 레벨이 오르면 연사 · 저격을 익힌다',
    '화살',
    DamageType.physical,
    owner: CharacterId.hunter,
    catalyst: PassiveId.swiftness,
    awakenedLabel: '폭풍 석궁',
    upgrades: [
      {WeaponStat.combo: 0.15, WeaponStat.damage: 0.1},
      {WeaponStat.cooldown: 0.1},
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.25, WeaponStat.combo: 0.05},
      {WeaponStat.pierce: 2},
      {WeaponStat.speed: 0.2, WeaponStat.cooldown: 0.1, WeaponStat.combo: 0.05},
      {WeaponStat.count: 1, WeaponStat.damage: 0.2},
    ],
    perks: {Balance.volleyLevel: '연사 습득', Balance.sniperLevel: '저격 습득'},
  ),
  emberMine(
    '불씨 덫',
    '발밑에 묻어 두면 적이 밟을 때 터지는 덫',
    '덫',
    DamageType.fire,
    owner: CharacterId.hunter,
    catalyst: PassiveId.keenEye,
    awakenedLabel: '연쇄 폭뢰',
    upgrades: [
      {WeaponStat.damage: 0.2},
      {WeaponStat.area: 0.2},
      {WeaponStat.count: 1},
      {WeaponStat.cooldown: 0.15},
      {WeaponStat.damage: 0.3},
      {WeaponStat.count: 1},
      {WeaponStat.area: 0.2, WeaponStat.damage: 0.2},
    ],
  ),
  throwingKnives(
    '투척 단검',
    '가장 가까운 적에게 빠르게 연달아 던지는 단검',
    '단검',
    DamageType.physical,
    owner: CharacterId.hunter,
    catalyst: PassiveId.haste,
    awakenedLabel: '칼날 폭풍',
    upgrades: [
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.2},
      {WeaponStat.pierce: 1},
      {WeaponStat.count: 1},
      {WeaponStat.cooldown: 0.15},
      {WeaponStat.damage: 0.3},
      {WeaponStat.count: 1, WeaponStat.pierce: 1},
    ],
  ),
  snareNet(
    '올가미 그물',
    '가까운 적 무리에 그물을 던져 묶어 두고 지속 피해를 준다',
    '그물',
    DamageType.physical,
    owner: CharacterId.hunter,
    catalyst: PassiveId.swiftness,
    awakenedLabel: '가시 그물',
    upgrades: [
      {WeaponStat.area: 0.15},
      {WeaponStat.duration: 0.3},
      {WeaponStat.count: 1},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.damage: 0.3, WeaponStat.area: 0.15},
      {WeaponStat.duration: 0.3},
      {WeaponStat.count: 1, WeaponStat.damage: 0.3},
    ],
  ),
  ashAura(
    '잿불 고리',
    '몸 주변의 적을 계속 태우는 잿불의 고리',
    '고리',
    DamageType.fire,
    catalyst: PassiveId.regrowth,
    awakenedLabel: '지옥불 고리',
    upgrades: [
      {WeaponStat.area: 0.15},
      {WeaponStat.damage: 0.25},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.area: 0.15},
      {WeaponStat.damage: 0.3},
      {WeaponStat.area: 0.2},
      {WeaponStat.damage: 0.4},
    ],
  ),
  thunder(
    '낙뢰',
    '화면 안의 적들에게 내리꽂히는 벼락',
    '벼락',
    DamageType.lightning,
    catalyst: PassiveId.brutality,
    awakenedLabel: '신의 심판',
    upgrades: [
      {WeaponStat.count: 1},
      {WeaponStat.damage: 0.25},
      {WeaponStat.cooldown: 0.12},
      {WeaponStat.count: 1},
      {WeaponStat.area: 0.3},
      {WeaponStat.damage: 0.3},
      {WeaponStat.count: 2},
    ],
  ),
  chakram(
    '회전 차크람',
    '적을 가르며 날아갔다 손으로 돌아오는 원반',
    '원반',
    DamageType.physical,
    catalyst: PassiveId.spread,
    awakenedLabel: '쌍월륜',
    upgrades: [
      {WeaponStat.damage: 0.2},
      {WeaponStat.speed: 0.2},
      {WeaponStat.count: 1},
      {WeaponStat.area: 0.25},
      {WeaponStat.damage: 0.3},
      {WeaponStat.cooldown: 0.15},
      {WeaponStat.count: 1, WeaponStat.damage: 0.2},
    ],
  );

  const WeaponId(
    this.label,
    this.description,
    this.countLabel,
    this.damageType, {
    this.owner,
    required this.catalyst,
    required this.awakenedLabel,
    required this.upgrades,
    this.perks = const {},
  });

  final String label;
  final String description;

  /// [WeaponStat.count] 이 오를 때 카드에 쓰는 이름 ('칼날 +1').
  final String countLabel;
  final DamageType damageType;

  /// 전용 무기의 주인. null 이면 공용.
  final CharacterId? owner;

  /// 각성에 필요한 패시브.
  final PassiveId catalyst;
  final String awakenedLabel;

  /// 2레벨부터 최대 레벨까지 레벨마다 오르는 것. 길이는 [maxLevel] - 1.
  final List<WeaponUpgrade> upgrades;

  /// 레벨마다 새로 익히는 기술 (카드 맨 앞에 쓴다).
  final Map<int, String> perks;

  static const int maxLevel = Balance.weaponMaxLevel;

  /// [character] 가 레벨업 카드로 얻을 수 있는 무기: 그 캐릭터 전용 무기와 공용 무기.
  static List<WeaponId> poolFor(CharacterId character) => [
    for (final id in values)
      if (id.owner == null || id.owner == character) id,
  ];

  /// [level] 까지 [stat] 이 오른 합.
  double total(WeaponStat stat, int level) {
    var sum = 0.0;
    for (var i = 0; i < level - 1 && i < upgrades.length; i++) {
      sum += upgrades[i][stat] ?? 0;
    }
    return sum;
  }

  /// [level] 까지의 피해 배율 (각성 제외).
  double damageMultiplier(int level) => 1 + total(WeaponStat.damage, level);

  /// [level] 이 되면 얻는 효과.
  String upgradeText(int level) {
    final up = upgrades[level - 2];
    String pct(double v) => '${(v * 100).round()}%';
    return [
      ?perks[level],
      for (final MapEntry(key: stat, value: v) in up.entries)
        switch (stat) {
          WeaponStat.damage => '피해 +${pct(v)}',
          WeaponStat.count => '$countLabel +${v.round()}',
          WeaponStat.area => '범위 +${pct(v)}',
          WeaponStat.cooldown => '쿨다운 -${pct(v)}',
          WeaponStat.pierce => '관통 +${v.round()}',
          WeaponStat.speed => '속도 +${pct(v)}',
          WeaponStat.duration => '지속 시간 +${pct(v)}',
          WeaponStat.combo =>
            '${this == fireCrossbow ? '연사' : '콤보'} 확률 +${pct(v)}',
        },
    ].join(', ');
  }

  /// 각성하면 얻는 효과.
  String get awakenedDescription {
    final damage = '피해 ×${Balance.awakenDamageMultiplier}';
    return switch (this) {
      greatsword =>
        '$damage, 범위 ×${Balance.titanArea}, '
            '콤보 확률 +${(Balance.titanCombo * 100).round()}%',
      earthSlam => '$damage, 한 박자 뒤 더 넓은 여진이 한 번 더 퍼진다',
      cleave => '$damage, 앞뒤를 함께 베고 참격이 더 크다',
      warCry => '$damage, 함성이 적을 밀쳐 내고 더 오래 묶는다',
      emberSpirits => '$damage, 정령이 하나 더 늘고 닿은 적에게 불이 더 빨리 붙는다',
      snareNet => '$damage, 그물에 가시가 돋아 묶인 적에게 계속 피해를 준다',
      emberOrb =>
        '$damage, 맞힌 자리에서 터져 주변 적에게 '
            '${(Balance.meteorRatio * 100).round()}% 피해',
      meteor => '$damage, 운석이 떨어진 자리가 잠시 불타오른다',
      fireTornado => '$damage, 회오리가 더 커지고 가까운 적을 쫓아간다',
      fireCrossbow =>
        '$damage, 화살 ${Balance.stormArrows}발을 부채꼴로, '
            '관통 +${Balance.stormPierceBonus}',
      emberMine => '$damage, 덫이 터지면 주변에 작은 폭발이 이어진다',
      throwingKnives => '$damage, 앞뒤 양옆 네 방향으로 함께 던진다',
      ashAura => '$damage, 고리가 넓어지고 닿은 적을 얼려 느리게 한다',
      thunder => '$damage, 벼락이 가까운 적 둘에게 튄다',
      chakram => '$damage, 원반이 하나 더 날아가고 더 크다',
    };
  }
}
