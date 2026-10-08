import 'package:flame/components.dart';

import '../../components/enemies/enemy.dart';
import '../../components/pickups/ash_shard.dart';
import '../../components/player/player.dart';
import '../../data/characters.dart';
import '../../systems/crowd_system.dart';
import '../../systems/level_system.dart';
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
    game.stats.reset(maxHp: player.maxHp, xpToNext: LevelSystem.xpToNext(1));
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
  }

  void gainXp(double amount) {
    final stats = game.stats;
    var xp = stats.xp.value + amount;
    while (xp >= stats.xpToNext.value) {
      xp -= stats.xpToNext.value;
      stats.level.value++;
      stats.xpToNext.value = LevelSystem.xpToNext(stats.level.value);
    }
    stats.xp.value = xp;
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
