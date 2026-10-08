import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/enemies/enemy.dart';
import '../data/balance.dart';
import '../game/ashborn_game.dart';
import '../game/world/run_world.dart';

/// 스테이지 시간에 따라 점점 더 많고 강한 적을 화면 밖에서 스폰한다.
/// 적의 기본 강도와 성향은 스테이지(레벨, 지역, 타락 단계)가 정한다.
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
    final time = world.stageTime;
    _timer = spawnInterval(time);

    final stage = world.stage;
    final region = stage.region;
    final room = Balance.maxEnemies - world.enemies.length;
    final count = math.min(batchSize(time), room);
    final hp = enemyHp(time) * stage.enemyHpMultiplier;
    for (var i = 0; i < count; i++) {
      world.add(
        Enemy(
          position: spawnPoint(),
          maxHp: hp,
          contactDamage:
              Balance.enemyContactDamage * stage.enemyDamageMultiplier,
          damageType: region.damageType,
          speed: Balance.enemySpeed * stage.enemySpeedMultiplier,
          color: region.enemy,
        ),
      );
    }
  }

  /// 화면 대각선 바깥 원 위의 임의 지점.
  Vector2 spawnPoint() {
    final view = game.camera.visibleWorldRect;
    final radius =
        math.sqrt(view.width * view.width + view.height * view.height) / 2 +
        Balance.spawnMargin;
    final angle = _random.nextDouble() * math.pi * 2;
    return world.player.position +
        Vector2(math.cos(angle), math.sin(angle)) * radius;
  }
}
