// 밸런스 계산기 모델: 게임을 돌리지 않고 공식만으로 스테이지마다의 벽과 진행 속도를 추정한다.
//
// 수치는 모두 실제 게임 코드(Balance, Stage, WaveSystem, Item, WeaponId)에서 가져온다.
// 그래서 lib/data/balance.dart 를 바꾸면 계산도 저절로 따라간다.
//
// 모델이 빼먹는 것 (시뮬레이터로만 볼 수 있는 것): 피하며 싸우는 움직임, 둘러싸여 죽는 위험,
// 장비 드랍 운, 보조 무기 · 은총 카드, 상태이상 연쇄. 이런 것은 [Calibration] 의 보정값 하나로 뭉쳐서
// 시뮬레이터 결과에 맞춘다.
import 'dart:math' as math;

import 'package:ashborn/data/balance.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/class_passives.dart';
import 'package:ashborn/data/enemies.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/stages.dart';
import 'package:ashborn/data/stats.dart';
import 'package:ashborn/data/weapons.dart';
import 'package:ashborn/systems/loot_system.dart';
import 'package:ashborn/systems/wave_system.dart';

/// 시뮬레이터 결과에 맞춘 보정값. 바꾸면 calc_test.dart 의 진행 예측을 시뮬레이터 칸과 다시 맞춘다.
abstract final class Calibration {
  /// 이론 피해 중 실제로 보스에게 들어가는 비율. 피하느라 못 때리는 시간, 빗나가는 투사체,
  /// 그리고 계산에 없는 죽을 위험까지 여기에 뭉쳐 있다 (시뮬레이터 4시간 결과에 맞춘 값).
  static const double uptime = 0.25;

  /// 한 런은 스테이지를 이어서 가며 레벨업 · 은총 카드 · 보조 무기로 계속 강해진다.
  /// 런 첫 스테이지 보스 때의 배율과, 그 런에서 스테이지를 하나 깰 때마다 더해지는 배율.
  static const double runPower = 1.6;
  static const double runGrowth = 0.15;

  /// 런 중에 얻는 보조 무기(공용 무기 · 다른 전용 무기)가 보스에게 넣는 초당 타격 수와 한 타 기본 피해.
  /// 장비의 더해지는 피해 · 피해 증가는 이 타격에도 붙는다.
  static const double otherHits = 3;
  static const double otherBase = 15;

  /// 런 안 공격 속도 배율 (날랜 손 · 은총 카드).
  static const double runAttackSpeed = 1.3;

  /// 웨이브로 나온 적 중 실제로 잡는 비율.
  static const double killRate = 0.9;

  /// 장비 등급: 처음엔 노말에서 시작해 보스를 잡을 때마다 (보스 상자 · 타락 드랍) 오르고,
  /// [rarityMax] 에서 멈춘다 (소수면 두 등급 사이).
  static const double rarityStart = 0.5;
  static const double rarityPerBoss = 0.06;
  static const double rarityMax = 3;

  /// 보스를 잡는 데 걸리는 시간 (졸개 수 · 스테이지 시간 계산용, 초).
  static const double bossFight = 45;

  /// 한 판 끝나고 정비 · 다시 출정하는 데 드는 시간 (분).
  static const double runOverhead = 1;

  static double rarity(int bosses) =>
      (rarityStart + rarityPerBoss * bosses).clamp(0, rarityMax).toDouble();
}

/// 장착 칸 10개 (반지 · 귀걸이 둘, 양손 대신 한손 둘로 친다).
const _slots = [
  ItemType.head,
  ItemType.necklace,
  ItemType.earring,
  ItemType.earring,
  ItemType.oneHand,
  ItemType.oneHand,
  ItemType.gloves,
  ItemType.belt,
  ItemType.ring,
  ItemType.ring,
  ItemType.boots,
];

/// 장비 10칸이 주는 공격 능력치 기댓값.
class GearPower {
  GearPower({required this.level, required this.enhance, required this.rarity});

  /// 장비 레벨 (떨어진 스테이지 레벨), 강화 단계, 등급 (소수면 두 등급 사이).
  final int level;
  final int enhance;
  final double rarity;

  double get _enhance =>
      math.pow(Balance.enhanceStatGrowth, enhance).toDouble();
  double get _rarity => math.pow(Balance.rarityStatGrowth, rarity).toDouble();

  double _value(StatType stat, double scale) =>
      stat.roll *
      scale *
      (stat.percent
          ? 1
          : math.pow(Balance.itemLevelGrowth, level - 1).toDouble()) *
      _enhance;

  /// 모든 장비의 [stat] 기댓값 합: 주옵션(고를 수 있으면 공격 쪽) + 랜덤옵션.
  double total(StatType stat) {
    var sum = 0.0;
    final grade = Rarity.values[rarity.floor().clamp(0, 5)];
    final affixes = Balance.maxAffixes * grade.affixChance;
    // 옵션 한 줄의 평균 등급 배율.
    var affixGrade = 0.0;
    for (final r in Rarity.values) {
      affixGrade += LootSystem.affixRarityChance(r, grade) * r.statMultiplier;
    }
    for (final type in _slots) {
      final weapon = type == ItemType.oneHand || type == ItemType.twoHand;
      if (weapon) {
        // 무기 칸 주옵션은 다섯 속성 중 무엇이든 같은 '더해지는 피해' 라 물리 하나로 모아 센다.
        if (stat == StatType.physicalDamage) {
          sum += _value(stat, type.mainScale) * _rarity;
        }
      } else if (type.mainStats.contains(stat)) {
        sum += _value(stat, type.mainScale) * _rarity / type.mainStats.length;
      }
      sum +=
          affixes /
          (StatType.values.length - 1) *
          _value(stat, Balance.affixScale) *
          affixGrade;
    }
    return sum;
  }

  /// 타격마다 더해지는 고정 피해 (다섯 속성 합. 무기 칸 주옵션은 물리로 모아 셈).
  double get addedDamage =>
      total(StatType.physicalDamage) +
      [
        StatType.fireDamage,
        StatType.coldDamage,
        StatType.lightningDamage,
        StatType.windDamage,
      ].fold(0.0, (s, t) => s + total(t));
}

/// 캐릭터 기본 무기의 보스(큰 단일 대상) 상대 성능. 최대 레벨, 각성 전.
class WeaponModel {
  WeaponModel(this.character, {this.mastery = 0});

  final CharacterDef character;

  /// 직업 패시브 레벨 (셋 모두 같은 레벨로 친다).
  final int mastery;

  WeaponId get id => character.startWeapon;
  static const level = WeaponId.maxLevel;

  double get _cooldownBase => switch (id) {
    WeaponId.greatsword => Balance.greatswordCooldown,
    WeaponId.emberOrb => Balance.emberOrbCooldown,
    WeaponId.fireCrossbow => Balance.crossbowCooldown,
    _ => throw UnimplementedError('$id'),
  };

  /// 직업 패시브가 주는 것.
  double _class(ClassPassive p) =>
      p.owner == character.id ? p.value(mastery) : 0;
  double _class2(ClassPassive p) =>
      p.owner == character.id ? p.value2(mastery) : 0;

  /// 한 번 쓸 때 대상에게 들어가는 타격 수와 무기 기본 피해 (레벨 배율 포함), 쓰는 간격(초).
  /// 공격 속도 [attackSpeed] 는 장비 · 런 패시브 합.
  /// [power] 는 장비 피해까지 포함한 한 타 전체에 붙는 배율 (대검의 무게).
  ({double hits, double base, double interval, double power}) cycle(
    double attackSpeed,
  ) {
    final cooldown =
        _cooldownBase *
        (1 - id.total(WeaponStat.cooldown, level)) *
        character.cooldownMultiplier /
        attackSpeed;
    final damage = id.damageMultiplier(level);
    final echo = 1 + _class(ClassPassive.spellEcho);
    switch (id) {
      case WeaponId.greatsword:
        final combo =
            id.total(WeaponStat.combo, level) +
            _class(ClassPassive.swordMastery);
        // 기술 셋을 차례로 쓰니 평균 기술 피해, 콤보로 이어지는 기술 수는 c + c².
        const avg =
            (Balance.thrustDamage + Balance.swingDamage + Balance.slamDamage) /
            3;
        final extra = combo + combo * combo;
        final onslaught = _onslaughtUptime(combo);
        final interval =
            (cooldown * (1 - onslaught * (1 - Balance.onslaughtCooldown)) +
            extra * Balance.comboDelay);
        const power =
            (Balance.thrustPower + Balance.swingPower + Balance.slamPower) / 3;
        return (
          hits: 1 + extra,
          base: avg * damage,
          interval: interval,
          power: power,
        );
      case WeaponId.emberOrb:
        final bolts = 1 + id.total(WeaponStat.count, level);
        // 부채꼴로 퍼져 보스(반지름 40)에 맞는 구체 수 (거리 200 기준).
        final hit = _fanHits(bolts.round(), Balance.emberOrbSpread);
        // 과열: 네 번째 시전마다 화염구 하나 (피해 ×2).
        final overheat = Balance.overheatDamage / Balance.overheatEvery;
        return (
          hits: (hit + overheat) * echo,
          base: Balance.emberOrbDamage * damage,
          interval: cooldown,
          power: 1.0,
        );
      case WeaponId.fireCrossbow:
        final arrows = 1 + id.total(WeaponStat.count, level);
        final hit = _fanHits(arrows.round(), Balance.stormSpread);
        final volley = 1 + id.total(WeaponStat.combo, level);
        // 저격: 네 번째 사격마다 피해 ×2.5.
        final sniper =
            (Balance.sniperEvery - 1 + Balance.sniperDamage) /
            Balance.sniperEvery;
        return (
          hits: hit * volley * sniper,
          base: Balance.crossbowDamage * damage,
          interval: cooldown,
          power: 1.0,
        );
      default:
        throw UnimplementedError('$id');
    }
  }

  /// 부채꼴로 [count] 발 쏠 때 거리 200 에서 반지름 40 보스에 맞는 수.
  static double _fanHits(int count, double spread) {
    var hits = 0;
    for (var i = 0; i < count; i++) {
      final offset = (i - (count - 1) / 2).abs() * spread * 200;
      if (offset <= Balance.bossRadius + 6) hits++;
    }
    return hits.toDouble();
  }

  /// 맹공이 켜져 있는 시간 비율. 콤보 판정 사슬을 짧게 굴려 본다 (난수 고정, 결정적).
  double _onslaughtUptime(double combo) {
    final random = math.Random(7);
    var streak = 0;
    var time = 0.0;
    var on = 0.0;
    var left = 0.0;
    const step = 1.0;
    for (var i = 0; i < 20000; i++) {
      for (var k = 0; k < 2; k++) {
        if (random.nextDouble() >= combo) {
          streak = 0;
          break;
        }
        streak++;
        if (streak >= Balance.onslaughtStreak) {
          streak = 0;
          left = Balance.onslaughtDuration + _class2(ClassPassive.swordMastery);
        }
      }
      final dt = left > 0 ? step * Balance.onslaughtCooldown : step;
      if (left > 0) on += dt;
      left -= dt;
      time += dt;
    }
    return on / time;
  }

  /// [gear] 를 낀 이 캐릭터가 런에서 [depth] 스테이지를 깬 뒤 보스 상대로 내는 초당 피해.
  double bossDps(GearPower gear, {int depth = 0}) {
    final attackSpeed =
        (1 +
            gear.total(StatType.attackSpeed) +
            _class(ClassPassive.momentum) * 0.6) *
        Calibration.runAttackSpeed;
    final c = cycle(attackSpeed);
    final crit = math.min(
      1.0,
      gear.total(StatType.critChance) + _class(ClassPassive.weakSpot),
    );
    final critMult =
        Balance.critMultiplier +
        gear.total(StatType.critDamage) +
        _class2(ClassPassive.weakSpot);
    // 기본 무기 + 보조 무기의 초당 (기본 피해 + 더해지는 피해).
    final raw =
        (c.base + gear.addedDamage) * c.power * c.hits / c.interval +
        (Calibration.otherBase + gear.addedDamage) *
            Calibration.otherHits *
            attackSpeed;
    return raw *
        (1 + gear.total(StatType.damage)) *
        Calibration.runPower *
        (1 + Calibration.runGrowth * depth) *
        (1 + crit * (critMult - 1)) *
        Calibration.uptime;
  }
}

/// 스테이지 하나의 적 강도와 보상.
class StageModel {
  StageModel(this.stage);

  final Stage stage;

  double get minionHpStart => WaveSystem.enemyHp(0) * stage.enemyHpMultiplier;
  double get minionHpEnd =>
      WaveSystem.enemyHp(Balance.stageDuration) * stage.enemyHpMultiplier;

  double get bossHp => minionHpEnd * Balance.bossHpMultiplier;

  double get bossDamage =>
      Balance.enemyContactDamage *
      stage.enemyDamageMultiplier *
      Balance.bossDamageMultiplier;

  /// 스테이지 시간과 보스전 동안 나오는 졸개 수 기댓값 (떼는 셋, 분열은 새끼 둘 포함).
  /// 보스가 나온 뒤에도 웨이브는 계속된다.
  double get spawned {
    var total = 0.0;
    const dt = 0.5;
    const end = Balance.stageDuration + Calibration.bossFight;
    for (var t = 0.0; t < end; t += dt) {
      final kinds = WaveSystem.unlocked(stage.region, t);
      final weight = kinds.fold(0, (s, k) => s + k.weight);
      var perPick = 0.0;
      for (final k in kinds) {
        final bodies = switch (k.behavior) {
          EnemyBehavior.swarm => Balance.swarmPack.toDouble(),
          EnemyBehavior.splitter => 1.0 + Balance.splitCount,
          _ => 1.0,
        };
        perPick += k.weight / weight * bodies;
      }
      total +=
          WaveSystem.batchSize(t) / WaveSystem.spawnInterval(t) * dt * perPick;
    }
    return total;
  }

  double get kills => spawned * Calibration.killRate;

  /// 이 스테이지를 한 번 깨면 얻는 강화석 · 골드 (처치 + 보스).
  double get stones =>
      kills * Balance.stoneDropChance * stage.dropChanceMultiplier +
      Balance.bossStones +
      stage.corruption;

  double get gold =>
      kills * Balance.killGold * stage.level +
      Balance.stageClearGold * stage.level * stage.dropChanceMultiplier;
}

/// [stage] 보스를 제한 시간 안에 잡는 데 필요한 최소 강화 단계. 최대 강화로도 안 되면 null.
/// 런에서 [depth] 스테이지를 깬 뒤 (기본: 1스테이지부터 쭉 올라온 경우), 장비 등급 [rarity].
int? requiredEnhance(
  WeaponModel weapon,
  Stage stage, {
  int? depth,
  double rarity = Calibration.rarityMax,
}) {
  final boss = StageModel(stage).bossHp;
  for (var e = 0; e <= Balance.maxEnhance; e++) {
    final gear = GearPower(level: stage.level, enhance: e, rarity: rarity);
    final dps = weapon.bossDps(gear, depth: depth ?? stage.index);
    if (boss / dps <= Balance.bossTimeLimit) return e;
  }
  return null;
}

/// 플레이 시간에 따른 진행 예측. 시뮬레이터의 봇처럼 런마다 1스테이지부터 벽까지 오르고,
/// 깰 때마다 · 런이 끝날 때마다 모은 강화석 · 골드로 장비 10칸을 고르게 강화한다.
/// 돌려주는 것: 스테이지마다 그 스테이지를 처음 깬 누적 분.
List<double> progression(
  WeaponModel weapon, {
  int stages = 40,
  double budget = 480,
}) {
  final reached = <double>[];
  var minutes = 0.0;
  var stones = 0.0;
  var gold = 0.0;
  var enhance = 0;
  var bosses = 0;
  var gearLevel = 1;
  final stageMinutes =
      (Balance.stageDuration +
          Calibration.bossFight +
          Balance.stageClearDelay) /
      60;

  void spend() {
    while (enhance < Balance.maxEnhance) {
      final item = Item(
        type: ItemType.ring,
        rarity: Rarity.values[Calibration.rarity(bosses).round().clamp(0, 5)],
        stats: const [],
        level: gearLevel,
      )..enhance = enhance;
      final s = item.enhanceStones * _slots.length;
      final g = item.enhanceGold * _slots.length;
      if (stones < s || gold < g) return;
      stones -= s;
      gold -= g;
      enhance++;
    }
  }

  while (minutes < budget && reached.length < stages) {
    final before = reached.length;
    // 한 런: 1스테이지부터 보스를 제한 시간 안에 못 잡는 곳까지.
    for (var i = 0; i < stages && minutes < budget; i++) {
      final stage = Stage(i);
      final model = StageModel(stage);
      final gear = GearPower(
        level: gearLevel,
        enhance: enhance,
        rarity: Calibration.rarity(bosses),
      );
      final ttk = model.bossHp / weapon.bossDps(gear, depth: i);
      if (ttk > Balance.bossTimeLimit) {
        // 벽: 보스 시간 동안 버티며 졸개만 잡고 끝난다.
        minutes += stageMinutes + Balance.bossTimeLimit / 60;
        stones +=
            model.kills * Balance.stoneDropChance * stage.dropChanceMultiplier;
        gold += model.kills * Balance.killGold * stage.level;
        break;
      }
      minutes += stageMinutes;
      stones += model.stones;
      gold += model.gold;
      bosses++;
      gearLevel = math.max(gearLevel, stage.level);
      if (i >= reached.length) reached.add(minutes);
      spend();
    }
    minutes += Calibration.runOverhead;
    spend();
    // 더 나아갈 수 없으면 (강화도 끝) 멈춘다.
    if (reached.length == before && enhance >= Balance.maxEnhance) break;
  }
  return reached;
}
