import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/enemies/death_puff.dart';
import '../components/props/crate.dart';
import '../data/balance.dart';
import '../game/ashborn_game.dart';
import '../game/world/run_world.dart';
import 'wave_system.dart';

/// 플레이어 둘레 화면 가장자리쯤에 부술 수 있는 상자를 가끔 놓는다.
/// 너무 멀어진 상자는 치워 새 상자가 가까이 생기게 한다.
class CrateSystem extends Component
    with HasGameReference<AshbornGame>, HasWorldReference<RunWorld> {
  double _timer = Balance.crateFirstDelay;

  @override
  void update(double dt) {
    super.update(dt);
    if (world.stageCleared) return;
    _timer -= dt;
    if (_timer > 0) return;
    _timer = Balance.crateInterval;

    final player = world.player.position;
    final crates = world.enemies.whereType<Crate>().toList()
      ..removeWhere((crate) {
        final far =
            crate.position.distanceTo(player) > Balance.crateDespawnDistance;
        if (far) crate.removeFromParent();
        return far;
      });
    if (crates.length >= Balance.maxCrates) return;
    spawn(spawnPoint());
  }

  /// 화면 짧은 변의 절반쯤부터 대각선 끝 사이, 눈에 띄지만 바로 옆은 아닌 곳.
  Vector2 spawnPoint() {
    final view = game.camera.visibleWorldRect;
    final near = math.min(view.width, view.height) * 0.35;
    final far =
        math.sqrt(view.width * view.width + view.height * view.height) /
        2 *
        0.85;
    final random = game.random;
    final angle = random.nextDouble() * math.pi * 2;
    final distance = near + random.nextDouble() * math.max(0, far - near);
    return world.player.position +
        Vector2(math.cos(angle), math.sin(angle)) * distance;
  }

  void spawn(Vector2 at) {
    final stage = world.stage;
    final chest = game.random.nextDouble() < Balance.chestChance;
    world
      ..add(DeathPuff(position: at.clone()))
      ..add(
        Crate(
          position: at,
          chest: chest,
          maxHp:
              WaveSystem.enemyHp(world.stageTime) *
              stage.enemyHpMultiplier *
              (chest ? Balance.chestHpScale : Balance.crateHpScale),
        ),
      );
  }
}
