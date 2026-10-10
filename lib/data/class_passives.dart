import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'balance.dart';
import 'characters.dart';
import 'inventory.dart';
import 'weapons.dart';

/// 고유 스킬 특성이 그 스킬에 더해 주는 것.
enum SkillBonus {
  /// 피해 배율 (+0.1 = 10%).
  damage,

  /// 범위 배율.
  area,

  /// 쿨다운 감소율.
  cooldown,

  /// 지속 시간 배율 (묶는 시간 · 회오리가 버티는 시간).
  duration,

  /// 속도 배율 (날아가는 · 도는 속도).
  speed,

  /// 전투 함성 뒤 받는 피해 감소 추가 (%p).
  guard,

  /// 그물 감속 추가 (%p).
  slow,
}

/// 직업마다 여섯씩 있는 특성. 특성 포인트(숙련 레벨)로 올리고 런이 끝나도 남는다 ([Mastery]).
///
/// 앞의 셋은 직업 전체를 강하게 하는 공통 특성, 뒤의 셋은 고유 스킬 하나([skill])만
/// 강하게 하는 스킬 특성이다 ([bonus] · [bonus2] 를 그 스킬에 더한다).
///
/// 수치는 1레벨 값 [_base] 에 레벨마다 [_perLevel] 이 더해진다. 둘째 수치가 있는 패시브는
/// [_base2] · [_perLevel2] 를 쓴다.
enum ClassPassive {
  parry(
    CharacterId.knight,
    '튕겨내기',
    '맞을 때 확률로 공격을 막아 내고, 공격한 적에게 받을 뻔한 피해의 몇 배를 되돌려 준다',
    Balance.parryChance,
    Balance.parryChancePerLevel,
    Balance.parryReflect,
    Balance.parryReflectPerLevel,
  ),
  swordMastery(
    CharacterId.knight,
    '연격의 달인',
    '대검 콤보 확률과 맹공 지속 시간이 늘어난다',
    Balance.swordMasteryCombo,
    Balance.swordMasteryComboPerLevel,
    Balance.swordMasteryOnslaught,
    Balance.swordMasteryOnslaughtPerLevel,
  ),
  ironWill(
    CharacterId.knight,
    '강철 의지',
    '받는 모든 피해가 줄어든다',
    Balance.ironWill,
    Balance.ironWillPerLevel,
  ),
  affinity(
    CharacterId.witch,
    '원소 친화',
    '화염 · 냉기 · 번개가 더 빨리 쌓이고 점화 피해가 늘어난다',
    Balance.affinityBuildup,
    Balance.affinityBuildupPerLevel,
    Balance.affinityIgnite,
    Balance.affinityIgnitePerLevel,
  ),
  spellEcho(
    CharacterId.witch,
    '잔향 시전',
    '무기가 발동할 때 확률로 곧바로 한 번 더 발동한다',
    Balance.spellEcho,
    Balance.spellEchoPerLevel,
  ),
  ashVeil(
    CharacterId.witch,
    '재의 장막',
    '피해를 한 번 막아 내는 장막이 일정 시간마다 다시 생긴다',
    Balance.ashVeil,
    Balance.ashVeilPerLevel,
  ),
  envenom(
    CharacterId.hunter,
    '맹독 바르기',
    '모든 공격에 중독 확률이 붙고 중독 피해가 늘어난다',
    Balance.envenomChance,
    Balance.envenomChancePerLevel,
    Balance.envenomDamage,
    Balance.envenomDamagePerLevel,
  ),
  momentum(
    CharacterId.hunter,
    '질주 사격',
    '움직이는 동안 공격 속도가 오른다',
    Balance.momentum,
    Balance.momentumPerLevel,
  ),
  weakSpot(
    CharacterId.hunter,
    '급소 노리기',
    '치명타 확률과 치명타 피해가 오른다',
    Balance.weakSpotChance,
    Balance.weakSpotChancePerLevel,
    Balance.weakSpotDamage,
    Balance.weakSpotDamagePerLevel,
  ),

  // 고유 스킬 특성.
  quake.skill(
    CharacterId.knight,
    '대지의 울림',
    '대지 강타가 더 세고 넓게 퍼진다',
    Balance.quakeDamage,
    Balance.quakeDamagePerLevel,
    Balance.quakeArea,
    Balance.quakeAreaPerLevel,
    skill: WeaponId.earthSlam,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.area,
  ),
  judge.skill(
    CharacterId.knight,
    '심판관',
    '심판의 일격이 더 세고 넓게 벤다',
    Balance.judgeDamage,
    Balance.judgeDamagePerLevel,
    Balance.judgeArea,
    Balance.judgeAreaPerLevel,
    skill: WeaponId.cleave,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.area,
  ),
  rally.skill(
    CharacterId.knight,
    '불굴의 함성',
    '전투 함성을 더 자주 외치고, 외친 뒤 받는 피해가 더 줄어든다',
    Balance.rallyCooldown,
    Balance.rallyCooldownPerLevel,
    Balance.rallyGuard,
    Balance.rallyGuardPerLevel,
    skill: WeaponId.warCry,
    bonus: SkillBonus.cooldown,
    bonus2: SkillBonus.guard,
  ),
  starfall.skill(
    CharacterId.witch,
    '별똥 부르기',
    '운석 낙하가 더 세고 넓게 터진다',
    Balance.starfallDamage,
    Balance.starfallDamagePerLevel,
    Balance.starfallArea,
    Balance.starfallAreaPerLevel,
    skill: WeaponId.meteor,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.area,
  ),
  firestorm.skill(
    CharacterId.witch,
    '불바람',
    '화염 회오리가 더 세고 오래 버틴다',
    Balance.firestormDamage,
    Balance.firestormDamagePerLevel,
    Balance.firestormDuration,
    Balance.firestormDurationPerLevel,
    skill: WeaponId.fireTornado,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.duration,
  ),
  pact.skill(
    CharacterId.witch,
    '정령 계약',
    '잔불 정령이 더 세고 빠르게 돈다',
    Balance.pactDamage,
    Balance.pactDamagePerLevel,
    Balance.pactSpeed,
    Balance.pactSpeedPerLevel,
    skill: WeaponId.emberSpirits,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.speed,
  ),
  trapper.skill(
    CharacterId.hunter,
    '덫 장인',
    '불씨 덫이 더 세고 넓게 터진다',
    Balance.trapperDamage,
    Balance.trapperDamagePerLevel,
    Balance.trapperArea,
    Balance.trapperAreaPerLevel,
    skill: WeaponId.emberMine,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.area,
  ),
  bladeRain.skill(
    CharacterId.hunter,
    '칼날 비',
    '투척 단검이 더 세고 빠르게 날아간다',
    Balance.bladeDamage,
    Balance.bladeDamagePerLevel,
    Balance.bladeSpeed,
    Balance.bladeSpeedPerLevel,
    skill: WeaponId.throwingKnives,
    bonus: SkillBonus.damage,
    bonus2: SkillBonus.speed,
  ),
  netter.skill(
    CharacterId.hunter,
    '사냥 그물',
    '올가미 그물이 더 오래, 더 단단히 묶는다',
    Balance.netterDuration,
    Balance.netterDurationPerLevel,
    Balance.netterSlow,
    Balance.netterSlowPerLevel,
    skill: WeaponId.snareNet,
    bonus: SkillBonus.duration,
    bonus2: SkillBonus.slow,
  );

  const ClassPassive(
    this.owner,
    this.label,
    this.description,
    this._base,
    this._perLevel, [
    this._base2 = 0,
    this._perLevel2 = 0,
  ]) : skill = null,
       bonus = null,
       bonus2 = null;

  const ClassPassive.skill(
    this.owner,
    this.label,
    this.description,
    this._base,
    this._perLevel,
    this._base2,
    this._perLevel2, {
    required WeaponId this.skill,
    required SkillBonus this.bonus,
    required SkillBonus this.bonus2,
  });

  final CharacterId owner;
  final String label;
  final String description;

  /// 고유 스킬 특성이 강하게 하는 스킬. 공통 특성은 null.
  final WeaponId? skill;
  final SkillBonus? bonus;
  final SkillBonus? bonus2;

  bool get isSkillTrait => skill != null;

  /// [skill] 에 [kind] 로 더해 주는 수치 ([level] 기준). 해당 없으면 0.
  double skillBonus(WeaponId weapon, SkillBonus kind, int level) {
    if (skill != weapon) return 0;
    return (bonus == kind ? value(level) : 0) +
        (bonus2 == kind ? value2(level) : 0);
  }

  final double _base;
  final double _perLevel;
  final double _base2;
  final double _perLevel2;

  static const int maxLevel = Balance.classPassiveMaxLevel;

  /// [character] 의 직업 패시브.
  static List<ClassPassive> of(CharacterId character) =>
      values.where((p) => p.owner == character).toList();

  /// [level] 일 때 첫째 수치. 0레벨이면 0.
  double value(int level) => level <= 0 ? 0 : _base + _perLevel * (level - 1);

  /// [level] 일 때 둘째 수치 (없는 패시브는 0).
  double value2(int level) =>
      level <= 0 ? 0 : _base2 + _perLevel2 * (level - 1);

  /// [level] 일 때 효과 한 줄.
  String effect(int level) {
    final a = value(level);
    final b = value2(level);
    return switch (this) {
      parry => '확률 ${_p(a)} · 되돌려 주는 피해 ×${b.toStringAsFixed(2)}',
      swordMastery => '콤보 확률 +${_p(a)} · 맹공 +${b.toStringAsFixed(2)}초',
      ironWill => '받는 피해 -${_p(a)}',
      affinity => '원소 축적 +${_p(a)} · 점화 피해 +${_p(b)}',
      spellEcho => '한 번 더 발동 ${_p(a)}',
      ashVeil => '${a.toStringAsFixed(0)}초마다 피해 1회 무효',
      envenom => '중독 확률 +${_p(a)} · 중독 피해 +${_p(b)}',
      momentum => '움직이는 동안 공격 속도 +${_p(a)}',
      weakSpot => '치명타 확률 +${_p(a)} · 치명타 피해 +${_p(b)}',
      quake || judge || starfall || trapper => '피해 +${_p(a)} · 범위 +${_p(b)}',
      rally => '쿨다운 -${_p(a)} · 함성 뒤 받는 피해 -${_p(b)} 추가',
      firestorm => '피해 +${_p(a)} · 지속 시간 +${_p(b)}',
      pact => '피해 +${_p(a)} · 회전 속도 +${_p(b)}',
      bladeRain => '피해 +${_p(a)} · 단검 속도 +${_p(b)}',
      netter => '묶는 시간 +${_p(a)} · 감속 +${_p(b)} 추가',
    };
  }

  static String _p(double v) {
    final p = v * 100;
    return '${p == p.roundToDouble() ? p.round() : p.toStringAsFixed(1)}%';
  }
}

/// 직업 숙련: 캐릭터마다 쌓는 숙련 경험치와, 숙련 레벨로 얻은 포인트를 직업 패시브에 쓴 기록.
///
/// 숙련 레벨 하나마다 포인트 하나. 런에서 모은 경험치가 숙련 경험치로 쌓여, 많이 플레이한
/// 캐릭터일수록 강해진다. 포인트는 골드를 내고 되돌릴 수 있다 ([reset]).
class Mastery extends ChangeNotifier {
  Mastery();

  factory Mastery.fromJson(Map<String, dynamic> json) {
    final mastery = Mastery();
    (json['xp'] as Map<String, dynamic>? ?? const {}).forEach((name, xp) {
      final id = CharacterId.values.asNameMap()[name];
      if (id != null) mastery._xp[id] = (xp as num).toDouble();
    });
    final passives = json['passives'] as Map<String, dynamic>? ?? const {};
    passives.forEach((name, level) {
      final passive = ClassPassive.values.asNameMap()[name];
      if (passive != null) mastery._levels[passive] = level as int;
    });
    return mastery;
  }

  final _xp = <CharacterId, double>{};
  final _levels = <ClassPassive, int>{};

  /// 숙련 레벨 상한: 한 직업의 특성을 모두 최대로 올릴 만큼.
  static int get maxLevel =>
      ClassPassive.maxLevel * ClassPassive.of(CharacterId.knight).length;

  /// 숙련 레벨 [level] 에서 다음 레벨까지 필요한 경험치.
  static double xpToNext(int level) =>
      Balance.masteryXpBase *
      math.pow(Balance.masteryXpGrowth, level).toDouble();

  double xp(CharacterId character) => _xp[character] ?? 0;

  /// [character] 의 숙련 레벨과, 그 레벨에서 다음 레벨까지 모은 경험치.
  ({int level, double into, double next}) progress(CharacterId character) {
    var rest = xp(character);
    var level = 0;
    while (level < maxLevel && rest >= xpToNext(level)) {
      rest -= xpToNext(level);
      level++;
    }
    return (level: level, into: rest, next: xpToNext(level));
  }

  int level(CharacterId character) => progress(character).level;

  int passiveLevel(ClassPassive passive) => _levels[passive] ?? 0;

  /// [character] 가 패시브에 쓴 포인트.
  int spent(CharacterId character) =>
      ClassPassive.of(character).fold(0, (sum, p) => sum + passiveLevel(p));

  /// 남은 포인트.
  int points(CharacterId character) => level(character) - spent(character);

  void addXp(CharacterId character, double amount) {
    if (amount <= 0) return;
    _xp[character] = xp(character) + amount;
    notifyListeners();
  }

  bool canRaise(ClassPassive passive) =>
      points(passive.owner) > 0 &&
      passiveLevel(passive) < ClassPassive.maxLevel;

  void raise(ClassPassive passive) {
    assert(canRaise(passive), '포인트가 없거나 최대 레벨이다');
    _levels[passive] = passiveLevel(passive) + 1;
    notifyListeners();
  }

  /// [character] 의 포인트를 모두 되돌리는 골드.
  int resetCost(CharacterId character) =>
      spent(character) * Balance.masteryResetGold;

  bool canReset(CharacterId character, Inventory inventory) =>
      spent(character) > 0 && inventory.gold >= resetCost(character);

  /// 골드를 내고 [character] 의 패시브 포인트를 모두 되돌린다.
  void reset(CharacterId character, Inventory inventory) {
    assert(canReset(character, inventory), '되돌릴 포인트가 없거나 골드가 모자란다');
    inventory.spendGold(resetCost(character));
    for (final p in ClassPassive.of(character)) {
      _levels.remove(p);
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'xp': {for (final MapEntry(:key, :value) in _xp.entries) key.name: value},
    'passives': {
      for (final MapEntry(:key, :value) in _levels.entries)
        if (value > 0) key.name: value,
    },
  };
}
