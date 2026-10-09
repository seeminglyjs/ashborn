// 밸런스 측정용 자동 플레이 봇. 실제 게임 코드를 헤드리스로 돌린다.
import 'dart:math' as math;

import 'package:ashborn/components/enemies/boss.dart';
import 'package:ashborn/components/pickups/ash_shard.dart';
import 'package:ashborn/components/pickups/item_drop.dart';
import 'package:ashborn/components/pickups/pickup.dart';
import 'package:ashborn/data/characters.dart';
import 'package:ashborn/data/equipment.dart';
import 'package:ashborn/data/fates.dart';
import 'package:ashborn/data/inventory.dart';
import 'package:ashborn/data/upgrades.dart';
import 'package:ashborn/game/ashborn_game.dart';
import 'package:ashborn/systems/level_system.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

/// 시뮬레이션 프레임 간격 (30fps).
const dt = 1 / 30;

/// 런 하나의 결과.
class RunResult {
  RunResult(this.startStage);

  final int startStage;
  int deathStage = -1;
  double deathStageTime = 0;
  bool diedToBoss = false;
  double seconds = 0;
  int level = 1;
  int kills = 0;
  int gold = 0, stones = 0, ember = 0, transcendStones = 0;
  int cleared = 0;

  /// 스테이지 → 클리어까지 걸린 시간, 클리어 때 남은 체력 비율.
  final stageTimes = <int, double>{};
  final hpAtClear = <int, double>{};
}

/// 봇 실력. [react] 초마다 한 번 방향을 다시 정하고, [reach] 안의 적만 피하며,
/// [greed] 만큼 적이 있어도 경험치 쪽으로 끌린다.
class Skill {
  const Skill(
    this.name, {
    required this.react,
    required this.reach,
    required this.greed,
  });

  final String name;
  final double react;
  final double reach;
  final double greed;

  static const skilled = Skill('skilled', react: 0, reach: 170, greed: 0.5);
  static const normal = Skill('normal', react: 0.15, reach: 140, greed: 0.8);
  static const casual = Skill('casual', react: 0.3, reach: 110, greed: 1.2);
  static const all = [skilled, normal, casual];
}

/// 런 하나를 자동으로 플레이한다: 적을 피하고, 경험치를 줍고,
/// 레벨업 · 운명 카드를 고른다.
class Bot {
  Bot(this.game, this.random, {this.skill = Skill.normal}) {
    for (final name in [
      AshbornGame.levelUpOverlay,
      AshbornGame.stageClearOverlay,
      AshbornGame.gameOverOverlay,
    ]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
  }

  final AshbornGame game;
  final math.Random random;
  final Skill skill;

  /// 스테이지를 깰 때마다 (런 중 장비 정비).
  void Function()? onClear;

  /// 스테이지를 깰 때마다 한 줄씩 남긴다.
  void Function(String)? log;

  Pickup? _target;
  int _frame = 0;
  double _sinceSteer = 0;

  /// 쓰러지거나, 보스 제한 시간이 지나거나, [maxStages] 를 깨거나,
  /// [maxSeconds] 가 지날 때까지 돈다.
  Future<RunResult> run({int maxStages = 40, double maxSeconds = 7200}) async {
    final r = RunResult(game.world.stage.index);
    var stageStart = 0.0;
    var lastStage = game.world.stage.index;
    final inv = game.inventory;
    final gold0 = inv.gold, stones0 = inv.stones, ember0 = inv.ember;
    final transcend0 = inv.transcendStones;
    while (true) {
      final w = game.world;
      if (w.player.isDead ||
          game.overlays.isActive(AshbornGame.gameOverOverlay)) {
        break;
      }
      if (game.overlays.isActive(AshbornGame.levelUpOverlay)) {
        game.chooseLevelUp(_pickLevelUp(game.levelUpOptions.value));
        continue;
      }
      if (game.overlays.isActive(AshbornGame.stageClearOverlay)) {
        r.stageTimes[w.stage.index] = r.seconds - stageStart;
        r.hpAtClear[w.stage.index] = w.player.hp / w.player.maxHp;
        r.cleared++;
        onClear?.call();
        log?.call(
          '  clear ${w.stage.index + 1} in '
          '${(r.seconds - stageStart).round()}s '
          'hp ${(w.player.hp / w.player.maxHp * 100).round()}% '
          'lv ${game.stats.level.value}',
        );
        if (r.cleared >= maxStages) break;
        game.chooseFate(_pickFate(game.fateOptions.value));
        continue;
      }
      if (w.stage.index != lastStage) {
        lastStage = w.stage.index;
        stageStart = r.seconds;
      }
      _steer();
      game.update(dt);
      await game.ready();
      r.seconds += dt;
      if (r.seconds > maxSeconds) break;
    }
    final w = game.world;
    return r
      ..deathStage = w.stage.index
      ..deathStageTime = w.stageTime
      ..diedToBoss = w.boss != null
      ..level = game.stats.level.value
      ..kills = game.stats.kills.value
      ..gold = inv.gold - gold0
      ..stones = inv.stones - stones0
      ..ember = inv.ember - ember0
      ..transcendStones = inv.transcendStones - transcend0;
  }

  LevelUpOption _pickLevelUp(List<LevelUpOption> options) {
    int score(LevelUpOption o) => switch (o) {
      AwakenOption() => 3,
      WeaponOption() => 2,
      PassiveOption() => 1,
    };
    final best = options.map(score).reduce(math.max);
    final top = options.where((o) => score(o) == best).toList();
    return top[random.nextInt(top.length)];
  }

  Fate _pickFate(List<Fate> options) {
    double score(Fate f) =>
        f.rarity.index +
        (f.card.curse ? -3 : 0) +
        (f.card.type == FateType.reward ? -1 : 0);
    return options.reduce((a, b) => score(a) >= score(b) ? a : b);
  }

  final _force = Vector2.zero();
  final _d = Vector2.zero();

  /// 가까운 적에게서 멀어지고, 안전하면 경험치 · 장비 쪽으로 간다.
  void _steer() {
    _sinceSteer += dt;
    if (_sinceSteer < skill.react) return;
    _sinceSteer = 0;
    final w = game.world;
    final p = w.player.position;
    // 근접(기사)은 칼날이 닿도록 가까이 붙어 싸운다.
    final melee = game.character.id == CharacterId.knight;
    _force.setZero();
    for (final e in w.enemies) {
      if (e.isDead) continue;
      _d
        ..setFrom(p)
        ..sub(e.position);
      final dist = _d.length;
      final boss = e is Boss;
      final reach =
          skill.reach * (melee ? 0.45 : 1) * (boss ? (melee ? 1.2 : 1.6) : 1);
      if (dist >= reach || dist == 0) continue;
      final k = (reach - dist) / reach;
      _force.addScaled(_d, k * k * (boss ? 4 : 1) / dist);
    }
    if (_frame++ % 10 == 0 || !(_target?.isMounted ?? false)) {
      _target = null;
      var best = 450.0 * 450;
      for (final c in w.children) {
        if (c is! AshShard && c is! ItemDrop) continue;
        final pickup = c as Pickup;
        final d2 = pickup.position.distanceToSquared(p);
        if (d2 < best) {
          best = d2;
          _target = pickup;
        }
      }
    }
    if (_force.length < skill.greed && _target != null) {
      _d
        ..setFrom(_target!.position)
        ..sub(p);
      if (_d.length2 > 0) _force.addScaled(_d.normalized(), skill.greed);
    }
    final joystick = game.joystick;
    if (_force.length2 < 1e-6) {
      joystick.delta.setZero();
    } else {
      joystick.delta
        ..setFrom(_force.normalized())
        ..scale(joystick.knobRadius);
    }
  }
}

/// 장비 하나의 대략적인 힘: 옵션 수치를 노말 기준 수치로 나눠 더한다.
double itemScore(Item item) {
  var s = 0.0;
  for (final r in item.effectiveStats) {
    s += r.value / r.stat.roll;
  }
  if (item.effect != null) s += 10;
  return s + item.transcends.length * 10;
}

/// 정비: 가방 장비 교체 → 나머지 분해 → 화톳불 → 강화 → 초월.
class Meta {
  Meta(this.game, this.random);

  final AshbornGame game;
  final math.Random random;
  int enhanceTries = 0, enhanceFails = 0, transcends = 0;

  /// 칸마다 점수가 더 높은 장비로 바꾸고, 남은 가방 장비는 분해한다.
  void tidy() {
    final inv = game.inventory;
    final gear = game.gear;
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in [...inv.bag]) {
        for (final slot in Gear.slotsFor(item.type)) {
          final displaced = gear.displacedBy(item, slot);
          final now = displaced.fold(0.0, (s, i) => s + itemScore(i));
          if (itemScore(item) > now + 0.01) {
            gear.equip(item, slot);
            changed = true;
            break;
          }
        }
      }
    }
    for (final item in [...inv.bag]) {
      inv.salvage(item);
    }
  }

  /// 살 수 있는 가장 싼 화톳불 강화부터 산다.
  void hearth() {
    final ups = game.upgrades;
    final inv = game.inventory;
    while (true) {
      final can = Upgrade.values.where((u) => ups.canBuy(u, inv)).toList()
        ..sort((a, b) => ups.cost(a).compareTo(ups.cost(b)));
      if (can.isEmpty) return;
      ups.buy(can.first, inv);
    }
  }

  /// 강화 단계가 가장 낮은 장착 장비부터 재료가 떨어질 때까지 강화하고, 초월한다.
  void enhance() {
    final inv = game.inventory;
    final gear = game.gear;
    while (true) {
      final items = gear.equipped.values.where(inv.canEnhance).toList()
        ..sort((a, b) {
          final c = a.enhance.compareTo(b.enhance);
          return c != 0 ? c : a.enhanceGold.compareTo(b.enhanceGold);
        });
      if (items.isEmpty) break;
      enhanceTries++;
      if (!inv.enhance(items.first, random)) enhanceFails++;
    }
    while (true) {
      final items = gear.equipped.values.where(inv.canTranscend).toList();
      if (items.isEmpty) break;
      if (inv.transcend(items.first, random)) transcends++;
    }
  }

  String gearSummary() {
    final g = game.gear.equipped.values.toList();
    if (g.isEmpty) return '0칸';
    final rarities = <Rarity, int>{};
    for (final i in g) {
      rarities[i.rarity] = (rarities[i.rarity] ?? 0) + 1;
    }
    final enhance = g.map((i) => i.enhance).reduce((a, b) => a + b) / g.length;
    final level = g.map((i) => i.level).reduce((a, b) => a + b) / g.length;
    final r = rarities.entries.map((e) => '${e.key.label}${e.value}').join(' ');
    return '${g.length}칸 [$r] 평균강화 +${enhance.toStringAsFixed(1)} '
        '평균Lv ${level.toStringAsFixed(1)} '
        '강화시도 $enhanceTries 실패 $enhanceFails 초월 $transcends';
  }
}
