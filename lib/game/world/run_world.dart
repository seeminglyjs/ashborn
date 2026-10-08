import 'dart:ui';

import 'package:flame/components.dart';

import '../../components/effects/burst.dart';
import '../../components/enemies/enemy.dart';
import '../../components/pickups/ash_shard.dart';
import '../../components/pickups/item_drop.dart';
import '../../components/player/player.dart';
import '../../data/balance.dart';
import '../../data/characters.dart';
import '../../data/damage.dart';
import '../../data/equipment.dart';
import '../../systems/crowd_system.dart';
import '../../systems/level_system.dart';
import '../../systems/loot_system.dart';
import '../../systems/wave_system.dart';
import '../ashborn_game.dart';
import 'ground_grid.dart';

/// 런 하나의 월드. 재시작하면 통째로 새로 만든다.
class RunWorld extends World
    with HasGameReference<AshbornGame>, HasCollisionDetection {
  RunWorld(this.character) : player = Player(character);

  final CharacterDef character;
  final Player player;

  /// 살아 있는 적 목록. [Enemy] 가 마운트/제거될 때 스스로 갱신한다.
  final enemies = <Enemy>[];

  double elapsed = 0;

  @override
  Future<void> onLoad() async {
    game.stats.reset(xpToNext: LevelSystem.xpToNext(1));
    addAll([GroundGrid(), player, WaveSystem(), CrowdSystem()]);
    game.camera.follow(player);
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsed += dt;
    game.stats.elapsedSeconds.value = elapsed.floor();
  }

  void onEnemyKilled(Vector2 position) {
    game.stats.kills.value++;
    add(AshShard(position: position));
    final item = LootSystem.rollDrop(game.random);
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
