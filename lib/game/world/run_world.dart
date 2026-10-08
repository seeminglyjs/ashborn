import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../components/effects/burst.dart';
import '../../components/enemies/boss.dart';
import '../../components/enemies/death_puff.dart';
import '../../components/enemies/enemy.dart';
import '../../components/pickups/ash_shard.dart';
import '../../components/pickups/item_drop.dart';
import '../../components/player/player.dart';
import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/damage.dart';
import '../../data/equipment.dart';
import '../../data/stages.dart';
import '../../systems/crowd_system.dart';
import '../../systems/level_system.dart';
import '../../systems/loot_system.dart';
import '../../systems/wave_system.dart';
import '../ashborn_game.dart';
import 'ground_grid.dart';

/// 런 하나의 월드. 재시작하면 통째로 새로 만든다.
///
/// 스테이지마다 [Balance.stageDuration] 동안 웨이브를 버티면 보스가 나오고,
/// 보스를 잡으면 전리품을 주울 시간을 준 뒤 다음 지역을 고르게 한다.
class RunWorld extends World
    with HasGameReference<AshbornGame>, HasCollisionDetection {
  RunWorld(this.character, {this.stage = Stage.first})
    : player = Player(character);

  final CharacterDef character;
  final Player player;

  /// 살아 있는 적 목록. [Enemy] 가 마운트/제거될 때 스스로 갱신한다.
  final enemies = <Enemy>[];

  /// 런 전체 시간.
  double elapsed = 0;

  /// 지금 스테이지. 보스를 잡으면 다음으로 넘어간다.
  Stage stage;

  /// 지금 스테이지에서 지난 시간. 웨이브 강도와 보스 등장을 정한다.
  double stageTime = 0;

  Boss? boss;
  bool _bossSpawned = false;

  /// 보스를 잡았으면 다음 지역 선택이 뜨기까지 남은 시간.
  double? _clearTimer;

  bool get stageCleared => _clearTimer != null;

  /// 처치로 모았지만 아직 인벤토리에 넣지 않은 잔불. 클리어나 사망 때 넣는다.
  double _pendingEmber = 0;

  /// 이번 런에서 얻은 잔불.
  int runEmber = 0;

  @override
  Future<void> onLoad() async {
    game.stats.reset(xpToNext: LevelSystem.xpToNext(1));
    _publishStage();
    addAll([GroundGrid(), player, WaveSystem(), CrowdSystem()]);
    game.camera.follow(player);
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsed += dt;
    final stats = game.stats;
    stats.elapsedSeconds.value = elapsed.floor();

    if (_clearTimer case final timer?) {
      _clearTimer = timer - dt;
      if (timer > 0 && timer - dt <= 0) game.onStageCleared();
      return;
    }
    stageTime += dt;
    if (!_bossSpawned && stageTime >= Balance.stageDuration) spawnBoss();
    stats.bossCountdown.value = math.max(
      0,
      (Balance.stageDuration - stageTime).ceil(),
    );
    if (boss case final b?) stats.bossHealth.value = b.hp / b.maxHp;
  }

  void _publishStage() {
    game.stats
      ..stage.value = stage
      ..stageCleared.value = false
      ..bossHealth.value = null
      ..bossCountdown.value = Balance.stageDuration.ceil();
  }

  /// 화면 대각선 바깥 원 위의 임의 지점.
  Vector2 offscreenPoint() {
    final view = game.camera.visibleWorldRect;
    final radius =
        math.sqrt(view.width * view.width + view.height * view.height) / 2 +
        Balance.spawnMargin;
    final angle = game.random.nextDouble() * math.pi * 2;
    return player.position + Vector2(math.cos(angle), math.sin(angle)) * radius;
  }

  void spawnBoss() {
    _bossSpawned = true;
    final region = stage.region;
    final b = Boss(
      position: offscreenPoint(),
      maxHp:
          WaveSystem.enemyHp(Balance.stageDuration) *
          stage.enemyHpMultiplier *
          Balance.bossHpMultiplier,
      contactDamage:
          Balance.enemyContactDamage *
          stage.enemyDamageMultiplier *
          Balance.bossDamageMultiplier,
      damageType: region.damageType,
      speed:
          Balance.enemySpeed *
          stage.enemySpeedMultiplier *
          Balance.bossSpeedMultiplier,
      color: region.enemy,
      name: region.bossName,
    );
    boss = b;
    add(b);
    game.stats.bossHealth.value = 1;
    game.notify('${region.bossName} 등장', color: const Color(0xFFE8463A));
  }

  /// 보스를 잡으면 남은 졸개는 재가 되어 흩어지고 웨이브가 멈춘다.
  void onBossDefeated(Boss defeated) {
    boss = null;
    _clearTimer = Balance.stageClearDelay;
    game.progress.recordClear(stage);
    _dropBossChest(defeated.position);
    final reward =
        (Balance.stageClearEmber * stage.level * stage.dropChanceMultiplier)
            .round();
    game.notify(
      '잔불 +${bankEmber(bonus: reward)}',
      color: const Color(0xFFFFB347),
    );
    for (final enemy in enemies.toList()) {
      if (enemy == defeated) continue;
      add(DeathPuff(position: enemy.position.clone()));
      enemy.removeFromParent();
    }
    game.stats
      ..bossHealth.value = null
      ..stageCleared.value = true;
    game.notify('${stage.name} 클리어', color: const Color(0xFFE8C887));
  }

  void _dropBossChest(Vector2 at) {
    final items = LootSystem.bossChest(game.random, stage);
    for (final (i, item) in items.indexed) {
      final angle = math.pi * 2 * i / items.length;
      add(
        ItemDrop(
          position:
              at +
              Vector2(math.cos(angle), math.sin(angle)) *
                  Balance.bossChestRadius,
          item: item,
        ),
      );
    }
  }

  /// 모아 둔 잔불과 [bonus] 를 인벤토리에 넣고 넣은 양을 돌려준다.
  int bankEmber({int bonus = 0}) {
    final whole = _pendingEmber.floor();
    _pendingEmber -= whole;
    final amount = whole + bonus;
    game.inventory.addEmber(amount);
    runEmber += amount;
    return amount;
  }

  /// 다음 스테이지로. 마지막 지역 다음이면 타락 단계가 오른다.
  void advanceStage() {
    final previous = stage;
    stage = stage.next;
    stageTime = 0;
    _bossSpawned = false;
    _clearTimer = null;
    _publishStage();
    if (stage.corruption > previous.corruption) {
      game.notify(
        '타락 ${stage.corruption}단계: 적과 보상이 강해진다',
        color: const Color(0xFFE8463A),
      );
    }
    game.notify(stage.name, color: const Color(0xFFE8C887));
  }

  void onEnemyKilled(Vector2 position) {
    game.stats.kills.value++;
    add(AshShard(position: position));
    _pendingEmber += Balance.killEmber * stage.level;
    final item = LootSystem.rollDrop(game.random, stage);
    if (item != null) add(ItemDrop(position: position.clone(), item: item));
    if (game.gear.effects.contains(UniqueEffect.emberBurst) &&
        game.random.nextDouble() < Balance.emberBurstChance) {
      emberBurst(position);
    }
  }

  /// 잿불 폭발: [at] 주변 적에게 화염 피해.
  void emberBurst(Vector2 at) {
    add(
      Burst(
        position: at.clone(),
        radius: Balance.emberBurstRadius,
        color: const Color(0xFFFF7A2E),
      ),
    );
    for (final enemy in enemiesNear(at, Balance.emberBurstRadius)) {
      player.strike(
        enemy,
        Balance.emberBurstDamage,
        DamageType.fire,
        secondary: true,
      );
    }
  }

  /// [at] 에서 [radius] 안의 살아 있는 적. 가까운 순.
  List<Enemy> enemiesNear(Vector2 at, double radius) =>
      enemies
          .where(
            (e) =>
                !e.isDead &&
                e.position.distanceToSquared(at) <= radius * radius,
          )
          .toList()
        ..sort(
          (a, b) => a.position
              .distanceToSquared(at)
              .compareTo(b.position.distanceToSquared(at)),
        );

  void gainXp(double amount) {
    final stats = game.stats;
    var xp = stats.xp.value + amount;
    var levels = 0;
    while (xp >= stats.xpToNext.value) {
      xp -= stats.xpToNext.value;
      stats.level.value++;
      stats.xpToNext.value = LevelSystem.xpToNext(stats.level.value);
      levels++;
    }
    stats.xp.value = xp;
    if (levels > 0) game.onLevelUp(levels);
  }

  /// [from] 에서 [maxDistance] 안에 있는 가장 가까운 적.
  Enemy? nearestEnemy(Vector2 from, {required double maxDistance}) {
    Enemy? nearest;
    var best = maxDistance * maxDistance;
    for (final enemy in enemies) {
      final d = enemy.position.distanceToSquared(from);
      if (d < best) {
        best = d;
        nearest = enemy;
      }
    }
    return nearest;
  }
}
