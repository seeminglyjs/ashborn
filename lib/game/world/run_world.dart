import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../components/effects/burst.dart';
import '../../components/effects/damage_number.dart';
import '../../components/enemies/boss.dart';
import '../../components/enemies/death_puff.dart';
import '../../components/enemies/enemy.dart';
import '../../components/enemies/hazards.dart';
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
import '../../services/audio.dart';
import '../../systems/crate_system.dart';
import '../../systems/crowd_system.dart';
import '../../systems/fate_system.dart';
import '../../systems/level_system.dart';
import '../../systems/loot_system.dart';
import '../../systems/wave_system.dart';
import '../ashborn_game.dart';
import 'atmosphere.dart';
import 'dungeon_floor.dart';
import 'obstacles.dart';
import 'region_theme.dart';

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

  /// 날아다니는 적 탄 수. [EnemyBullet] 이 스스로 갱신한다.
  int enemyBullets = 0;

  bool get canAddBullet => enemyBullets < Balance.maxEnemyBullets;

  /// 구조물 밑동. 플레이어와 적이 뚫고 지나가지 못한다.
  late final obstacles = Obstacles(() => RegionTheme.of(stage.region));

  /// 카메라가 따라가는 점. 플레이어 위치에 화면 흔들림을 더한다.
  final _camera = PositionComponent();

  /// 남은 흔들림 세기 (초 단위로 줄어든다).
  double _shake = 0;

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

  /// 이 런에 붙은 신의 은총: 영구히 받아 둔 은총으로 시작한다.
  late final fate = RunFate(game.progress.graces);

  /// 보스가 나온 뒤 지난 시간.
  double bossTime = 0;

  /// 보스를 제한 시간 안에 잡지 못해 런이 끝났다.
  bool timedOut = false;

  /// 운명 저주 · 보상 카드와 화톳불 강화로 늘어난 잔불 획득량.
  double get emberMultiplier =>
      fate.emberMultiplier * (1 + game.upgrades.value(Upgrade.emberGain));

  @override
  Future<void> onLoad() async {
    game.stats.reset(xpToNext: LevelSystem.xpToNext(1));
    _publishStage();
    final rules = stage.rules;
    if (rules.isNotEmpty) {
      game.notify(
        '타락 ${stage.corruption}단계: ${rules.map((r) => r.label).join(' · ')}',
        color: const Color(0xFFE8463A),
      );
    }
    // 스프라이트는 기다리지 않는다. 다 읽기 전에 나온 적은 원으로 그려진다.
    unawaited(game.monsterSprites.load(game.images));
    unawaited(game.props.load(game.images));
    _camera.position.setFrom(player.position);
    final floor = DungeonFloor();
    addAll([
      floor,
      // 구조물 뒤로 들어간 캐릭터를 가리는 앞쪽 구조물 (캐릭터 위에 그린다).
      StructureFront(floor),
      player,
      WaveSystem(),
      CrowdSystem(),
      CrateSystem(),
      TrapSystem(),
      Atmosphere(),
      _camera,
    ]);
    game.camera.follow(_camera);
    GameAudio.music(Bgm.battle);
  }

  /// 화면을 [amount] (초) 만큼 흔든다. 더 센 흔들림이 이긴다. 설정에서 진동을 끄면 약하게.
  void shake(double amount) => _shake = math.max(_shake, amount);

  /// [at] 이 지금 화면 안에 보이는가.
  bool isOnScreen(Vector2 at) =>
      game.camera.visibleWorldRect.contains(at.toOffset());

  void _updateCamera(double dt) {
    _camera.position.setFrom(player.position);
    if (_shake <= 0) return;
    _shake = math.max(0, _shake - dt);
    final power = math.min(_shake, 0.5) * Balance.shakePower;
    final r = game.random;
    _camera.position.add(
      Vector2(
        (r.nextDouble() * 2 - 1) * power,
        (r.nextDouble() * 2 - 1) * power,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateCamera(dt);
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
      region: region,
    );
    boss = b;
    add(b);
    game.stats.bossHealth.value = 1;
    game.notify('${region.bossName} 등장', color: const Color(0xFFE8463A));
    shake(0.5);
    GameAudio.play(Sfx.bossAppear);
    GameAudio.music(Bgm.boss);
  }

  /// 보스를 잡으면 남은 졸개는 재가 되어 흩어지고 웨이브가 멈춘다.
  void onBossDefeated(Boss defeated) {
    boss = null;
    _clearTimer = Balance.stageClearDelay;
    final firstClear = (game.progress.bestCleared?.index ?? -1) < stage.index;
    game.progress.recordClear(stage);
    _dropBossChest(defeated.position);
    // 조공명의 금화 은총은 클리어 잔불을 스테이지 레벨만큼 더 준다.
    final reward =
        (Balance.stageClearEmber * stage.level * stage.dropChanceMultiplier +
                fate.clearEmber * stage.level)
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
    final mastery = bankMastery(bonus: Balance.masteryBossXp * stage.level);
    game.notify('특성 경험치 +$mastery', color: const Color(0xFFB8A6FF));
    if (game.random.nextDouble() <
        Balance.transcendStoneChance +
            Balance.transcendStoneChancePerCorruption * stage.corruption) {
      game.inventory.addLoot(transcendStones: 1);
      runTranscendStones++;
      game.notify('초월석 +1', color: TranscendOption.color);
    }
    if (stage.isFinal) _conquer(firstClear: firstClear);
    for (final enemy in enemies.toList()) {
      // 상자는 그대로 둔다. 전리품을 주우며 부술 수 있다.
      if (enemy == defeated || enemy is Crate) continue;
      add(DeathPuff(position: enemy.position.clone()));
      enemy.removeFromParent();
    }
    for (final hazard in children.whereType<Hazard>()) {
      hazard.removeFromParent();
    }
    // 신농의 약초 은총: 클리어할 때마다 체력을 채운다.
    if (fate.clearHeal > 0) player.heal(player.maxHp * fate.clearHeal);
    shake(0.6);
    // 배경음을 거두고 보스 처치음 · 클리어 팡파르가 들리게 한다. 다음 지역에서 다시 튼다.
    GameAudio.play(Sfx.bossDown);
    GameAudio.music(null);
    game.stats
      ..bossHealth.value = null
      ..stageCleared.value = true;
    game.notify('${stage.name} 클리어', color: const Color(0xFFE8C887));
  }

  /// 이번 런으로 단계를 클리어했는가 (마지막 지역 보스를 잡았다).
  bool conquered = false;

  /// 이번 클리어로 다음 타락 단계가 처음 열렸는가.
  bool unlockedCorruption = false;

  /// 그 단계의 마지막 보스를 잡으면 단계 클리어 보상을 준다. 그 단계를 처음 클리어하면
  /// 초월석을 더 주고 다음 타락 단계가 열린다.
  void _conquer({required bool firstClear}) {
    conquered = true;
    final c = stage.corruption;
    final (:gold, :stones) = bankLoot(
      gold: (Balance.conquestGold * stage.level * goldMultiplier).round(),
      stones: Balance.conquestStones * (c + 1),
    );
    game.notify(
      '${stage.corruption == 0 ? '마지막 지역' : '타락 ${stage.corruption}단계'} 클리어 보상: 골드 +$gold · 강화석 +$stones',
      color: const Color(0xFFE8C887),
    );
    if (firstClear) {
      unlockedCorruption = true;
      game.inventory.addLoot(transcendStones: Balance.firstConquestTranscend);
      runTranscendStones += Balance.firstConquestTranscend;
      game.notify(
        '첫 클리어! 초월석 +${Balance.firstConquestTranscend} · 타락 ${c + 1}단계 해금',
        color: const Color(0xFFE8463A),
      );
    }
  }

  void _dropBossChest(Vector2 at) {
    final items = LootSystem.bossChest(game.random, stage, character.id);
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

  /// 이번 런에서 쌓은, 아직 넣지 않은 숙련 경험치와 넣은 양.
  double _pendingMastery = 0;
  int runMastery = 0;

  /// 모아 둔 숙련 경험치와 [bonus] 를 이 캐릭터의 숙련에 넣고 넣은 양을 돌려준다.
  int bankMastery({double bonus = 0}) {
    final amount = (_pendingMastery + bonus).floor();
    _pendingMastery = 0;
    game.mastery.addXp(character.id, amount.toDouble());
    runMastery += amount;
    return amount;
  }

  /// 다음 지역으로. 마지막 지역(단계 클리어)에서는 런이 끝나므로 넘어가지 않는다.
  void advanceStage() {
    if (stage.isFinal) return;
    stage = stage.next;
    stageTime = 0;
    bossTime = 0;
    _bossSpawned = false;
    _clearTimer = null;
    _publishStage();
    GameAudio.music(Bgm.battle);
    game.notify(stage.name, color: const Color(0xFFE8C887));
  }

  /// 깔려 있는 잿불 유해 수 ([DeathBlast] 가 스스로 센다).
  int deathBlasts = 0;

  /// [xp] 는 떨어뜨릴 재의 결정 수 (거구는 여럿). [elite] 면 강화석을 확정으로 주고
  /// 장비 드랍 확률이 [Balance.eliteDropBonus] 배다.
  void onEnemyKilled(Vector2 position, {int xp = 1, bool elite = false}) {
    game.stats.kills.value++;
    GameAudio.play(Sfx.kill);
    for (var i = 0; i < xp; i++) {
      add(
        AshShard(
          position: i == 0
              ? position
              : position +
                    Vector2(
                      (game.random.nextDouble() - 0.5) * 24,
                      (game.random.nextDouble() - 0.5) * 24,
                    ),
        ),
      );
    }
    _pendingEmber += Balance.killEmber * stage.level * emberMultiplier;
    _pendingGold += Balance.killGold * stage.level * goldMultiplier;
    final heal = player.transcend(TranscendOption.healOnKill);
    if (heal > 0) player.heal(heal);
    if (game.random.nextDouble() <
        Balance.stoneDropChance * stage.dropChanceMultiplier) {
      _pendingStones++;
    }
    if (elite) _pendingStones += Balance.eliteStones;
    final item = LootSystem.rollDrop(
      game.random,
      stage,
      fate.dropMultiplier * (elite ? Balance.eliteDropBonus : 1),
      character.id,
    );
    if (item != null) add(ItemDrop(position: position.clone(), item: item));
    if (player.effects.contains(UniqueEffect.emberBurst) &&
        game.random.nextDouble() < Balance.emberBurstChance) {
      emberBurst(position);
    }
  }

  /// 상자가 부서졌을 때. 나무 상자는 보급품 하나, 보물 상자는 레어 이상 장비와 골드 주머니.
  void breakCrate(Crate crate) {
    final at = crate.position.clone();
    GameAudio.play(Sfx.crate);
    final gold = (Balance.crateGold * stage.level * goldMultiplier).round();
    if (crate.chest) {
      add(
        ItemDrop(
          position: at + Vector2(-14, 0),
          item: LootSystem.chestItem(game.random, stage, character.id),
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
              owner: character.id,
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
        GameAudio.play(Sfx.heal);
        game.notify(
          '체력 +${(player.hp - before).round()}',
          color: const Color(0xFF7BD15A),
        );
      case Supply.gold:
        _pendingGold += amount;
        GameAudio.play(Sfx.coin);
        game.notify('골드 +$amount', color: const Color(0xFFE8C887));
      case Supply.stone:
        _pendingStones += amount;
        GameAudio.play(Sfx.gem);
        game.notify('강화석 +$amount', color: const Color(0xFF6FD8F0));
      case Supply.magnet:
        for (final shard in children.whereType<AshShard>()) {
          shard.attract();
        }
        GameAudio.play(Sfx.magnet);
        game.notify('자석: 재의 결정을 모두 끌어당긴다', color: const Color(0xFF9FD8E8));
    }
  }

  /// 떠 있는 [DamageNumber] 수.
  int damageNumbers = 0;

  /// [at] 의 적 위로 피해 숫자를 띄운다. 너무 많이 떠 있으면 건너뛴다.
  void showDamage(
    Vector2 at,
    double amount, {
    required bool crit,
    DamageType type = DamageType.physical,
  }) {
    if (amount < 0.5 || damageNumbers >= DamageNumber.maxAlive) return;
    add(
      DamageNumber(
        position: Vector2(
          at.x + (game.random.nextDouble() * 2 - 1) * 8,
          at.y - Balance.enemyRadius,
        ),
        amount: amount,
        crit: crit,
        color: hitColor(type, crit: crit),
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
    _pendingMastery += amount;
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
