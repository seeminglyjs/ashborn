import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../components/effects/burst.dart';
import '../../components/effects/damage_number.dart';
import '../../components/enemies/boss.dart';
import '../../components/enemies/death_puff.dart';
import '../../components/enemies/enemy.dart';
import '../../components/pickups/ash_shard.dart';
import '../../components/pickups/item_drop.dart';
import '../../components/pickups/supply_drop.dart';
import '../../components/player/player.dart';
import '../../components/props/crate.dart';
import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/damage.dart';
import '../../data/equipment.dart';
import '../../data/stages.dart';
import '../../data/supplies.dart';
import '../../data/transcend.dart';
import '../../data/upgrades.dart';
import '../../systems/crate_system.dart';
import '../../systems/crowd_system.dart';
import '../../systems/fate_system.dart';
import '../../systems/level_system.dart';
import '../../systems/loot_system.dart';
import '../../systems/wave_system.dart';
import '../ashborn_game.dart';
import 'dungeon_floor.dart';

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

  /// 처치로 모았지만 아직 인벤토리에 넣지 않은 골드와 강화석. 클리어나 사망 때 넣는다.
  double _pendingGold = 0;
  int _pendingStones = 0;

  /// 이번 런에서 얻은 골드, 강화석, 초월석.
  int runGold = 0;
  int runStones = 0;
  int runTranscendStones = 0;

  /// 초월 옵션으로 늘어난 골드 획득량.
  double get goldMultiplier => 1 + player.transcend(TranscendOption.goldFind);

  /// 이번 런에서 고른 운명.
  final fate = RunFate();

  /// 보스가 나온 뒤 지난 시간.
  double bossTime = 0;

  /// 보스를 제한 시간 안에 잡지 못해 런이 끝났다.
  bool timedOut = false;

  /// 운명 저주 · 보상 카드와 화톳불 강화로 늘어난 잔불 획득량.
  double get emberMultiplier =>
      fate.emberMultiplier * (1 + game.upgrades.value(Upgrade.emberGain));

  @override
  Future<void> onLoad() async {
    fate.rerolls += game.upgrades.value(Upgrade.fateRerolls).round();
    game.stats.reset(xpToNext: LevelSystem.xpToNext(1));
    _publishStage();
    // 스프라이트는 기다리지 않는다. 다 읽기 전에 나온 적은 원으로 그려진다.
    unawaited(game.monsterSprites.load(game.images));
    unawaited(game.props.load(game.images));
    addAll([
      DungeonFloor(),
      player,
      WaveSystem(),
      CrowdSystem(),
      CrateSystem(),
    ]);
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
    if (boss case final b?) {
      bossTime += dt;
      stats
        ..bossHealth.value = b.hp / b.maxHp
        ..bossTimeLeft.value = math.max(
          0,
          (Balance.bossTimeLimit - bossTime).ceil(),
        );
      if (bossTime >= Balance.bossTimeLimit && !timedOut) {
        timedOut = true;
        game.onBossTimeout();
      }
    }
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
          fate.enemyHpMultiplier *
          Balance.bossHpMultiplier,
      contactDamage:
          Balance.enemyContactDamage *
          stage.enemyDamageMultiplier *
          fate.enemyDamageMultiplier *
          Balance.bossDamageMultiplier,
      damageType: region.damageType,
      speed:
          Balance.enemySpeed *
          stage.enemySpeedMultiplier *
          Balance.bossSpeedMultiplier,
      color: region.enemy,
      sprite: region.bossSprite,
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
    final (:gold, :stones) = bankLoot(
      gold:
          (Balance.stageClearGold *
                  stage.level *
                  stage.dropChanceMultiplier *
                  goldMultiplier)
              .round(),
      stones: Balance.bossStones + stage.corruption,
    );
    game.notify('골드 +$gold · 강화석 +$stones', color: const Color(0xFFE8C887));
    if (game.random.nextDouble() <
        Balance.transcendStoneChance +
            Balance.transcendStoneChancePerCorruption * stage.corruption) {
      game.inventory.addLoot(transcendStones: 1);
      runTranscendStones++;
      game.notify('초월석 +1', color: TranscendOption.color);
    }
    for (final enemy in enemies.toList()) {
      // 상자는 그대로 둔다. 전리품을 주우며 부술 수 있다.
      if (enemy == defeated || enemy is Crate) continue;
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
  /// 늘어난 잔불 획득량은 처치와 [bonus] 모두에 붙는다.
  int bankEmber({int bonus = 0}) {
    final whole = _pendingEmber.floor();
    _pendingEmber -= whole;
    final amount = whole + (bonus * emberMultiplier).round();
    game.inventory.addEmber(amount);
    runEmber += amount;
    return amount;
  }

  /// 모아 둔 골드 · 강화석과 [gold] · [stones] 를 인벤토리에 넣고 넣은 양을 돌려준다.
  ({int gold, int stones}) bankLoot({int gold = 0, int stones = 0}) {
    final whole = _pendingGold.floor();
    _pendingGold -= whole;
    final loot = (gold: whole + gold, stones: _pendingStones + stones);
    _pendingStones = 0;
    game.inventory.addLoot(gold: loot.gold, stones: loot.stones);
    runGold += loot.gold;
    runStones += loot.stones;
    return loot;
  }

  /// 다음 스테이지로. 마지막 지역 다음이면 타락 단계가 오른다.
  void advanceStage() {
    final previous = stage;
    stage = stage.next;
    stageTime = 0;
    bossTime = 0;
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
    _pendingEmber += Balance.killEmber * stage.level * emberMultiplier;
    _pendingGold += Balance.killGold * stage.level * goldMultiplier;
    final heal = player.transcend(TranscendOption.healOnKill);
    if (heal > 0) player.heal(heal);
    if (game.random.nextDouble() <
        Balance.stoneDropChance * stage.dropChanceMultiplier) {
      _pendingStones++;
    }
    final item = LootSystem.rollDrop(game.random, stage, fate.dropMultiplier);
    if (item != null) add(ItemDrop(position: position.clone(), item: item));
    if (player.effects.contains(UniqueEffect.emberBurst) &&
        game.random.nextDouble() < Balance.emberBurstChance) {
      emberBurst(position);
    }
  }

  /// 상자가 부서졌을 때. 나무 상자는 보급품 하나, 보물 상자는 레어 이상 장비와 골드 주머니.
  void breakCrate(Crate crate) {
    final at = crate.position.clone();
    final gold = (Balance.crateGold * stage.level * goldMultiplier).round();
    if (crate.chest) {
      add(
        ItemDrop(
          position: at + Vector2(-14, 0),
          item: LootSystem.chestItem(game.random, stage),
        ),
      );
      add(
        SupplyDrop(
          position: at + Vector2(14, 0),
          supply: Supply.gold,
          amount: (gold * Balance.chestGoldScale).round(),
        ),
      );
      return;
    }
    final drop = LootSystem.rollCrate(game.random);
    switch (drop.supply) {
      case null:
        add(
          ItemDrop(
            position: at,
            item: LootSystem.generate(
              game.random,
              level: stage.level,
              rarity: LootSystem.rollRarity(
                game.random,
                luck: stage.rarityLuck,
              ),
            ),
          ),
        );
      case final supply:
        add(
          SupplyDrop(
            position: at,
            supply: supply,
            amount: supply == Supply.gold ? gold : 1,
          ),
        );
    }
  }

  /// 상자에서 나온 소모품을 주웠을 때. 골드 · 강화석은 처치 보상처럼 모아 뒀다가 정산한다.
  void collectSupply(Supply supply, int amount) {
    switch (supply) {
      case Supply.potion:
        final before = player.hp;
        player.heal(player.maxHp * Balance.potionHeal);
        game.notify(
          '체력 +${(player.hp - before).round()}',
          color: const Color(0xFF7BD15A),
        );
      case Supply.gold:
        _pendingGold += amount;
        game.notify('골드 +$amount', color: const Color(0xFFE8C887));
      case Supply.stone:
        _pendingStones += amount;
        game.notify('강화석 +$amount', color: const Color(0xFF6FD8F0));
      case Supply.magnet:
        for (final shard in children.whereType<AshShard>()) {
          shard.attract();
        }
        game.notify('자석: 재의 결정을 모두 끌어당긴다', color: const Color(0xFF9FD8E8));
    }
  }

  /// 떠 있는 [DamageNumber] 수.
  int damageNumbers = 0;

  /// [at] 의 적 위로 피해 숫자를 띄운다. 너무 많이 떠 있으면 건너뛴다.
  void showDamage(Vector2 at, double amount, {required bool crit}) {
    if (amount < 0.5 || damageNumbers >= DamageNumber.maxAlive) return;
    add(
      DamageNumber(
        position: Vector2(
          at.x + (game.random.nextDouble() * 2 - 1) * 8,
          at.y - Balance.enemyRadius,
        ),
        amount: amount,
        crit: crit,
      ),
    );
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
        Balance.emberBurstDamage * player.effectPower(UniqueEffect.emberBurst),
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
