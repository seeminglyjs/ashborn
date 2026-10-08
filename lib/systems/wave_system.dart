import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/enemies/enemy.dart';
import '../data/balance.dart';
import '../game/ashborn_game.dart';
import '../game/world/run_world.dart';

/// 시간에 따라 점점 더 많고 강한 적을 화면 밖에서 스폰한다.
class WaveSystem extends Component
    with HasGameReference<AshbornGame>, HasWorldReference<RunWorld> {
  WaveSystem({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  double _timer = 0;

  static double spawnInterval(double elapsed) => math.max(
    Balance.minSpawnInterval,
    Balance.baseSpawnInterval *
        math.pow(0.5, elapsed / Balance.spawnIntervalHalfLife),
  );

  static int batchSize(double elapsed) =>
      1 + (elapsed / Balance.batchGrowthPeriod).floor();

  static double enemyHp(double elapsed) =>
      Balance.enemyBaseHp * (1 + elapsed / Balance.enemyHpGrowthPeriod);

  @override
  void update(double dt) {
    super.update(dt);
    _timer -= dt;
    if (_timer > 0) return;
    _timer = spawnInterval(world.elapsed);

    final room = Balance.maxEnemies - world.enemies.length;
    final count = math.min(batchSize(world.elapsed), room);
    final hp = enemyHp(world.elapsed);
    for (var i = 0; i < count; i++) {
      world.add(Enemy(position: _spawnPoint(), maxHp: hp));
    }
  }

  /// 화면 대각선 바깥 원 위의 임의 지점.
  Vector2 _spawnPoint() {
    final view = game.camera.visibleWorldRect;
    final radius =
        math.sqrt(view.width * view.width + view.height * view.height) / 2 +
        Balance.spawnMargin;
    final angle = _random.nextDouble() * math.pi * 2;
    return world.player.position +
        Vector2(math.cos(angle), math.sin(angle)) * radius;
  }
}
