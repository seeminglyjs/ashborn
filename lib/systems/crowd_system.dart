import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/enemies/enemy.dart';
import '../data/balance.dart';
import '../game/world/run_world.dart';

/// 적들이 한 점으로 뭉치지 않도록 서로 밀어낸다.
///
/// 충돌 시스템 대신 격자 해시로 이웃만 확인해 적 수가 많아도 가볍게 돈다.
class CrowdSystem extends Component with HasWorldReference<RunWorld> {
  static const double _cellSize = Balance.enemyRadius * 2;
  static const double _minDistance = Balance.enemyRadius * 2;

  final _grid = <int, List<Enemy>>{};
  final _offset = Vector2.zero();

  static int _key(int cx, int cy) => ((cx & 0xFFFF) << 16) | (cy & 0xFFFF);

  @override
  void update(double dt) {
    super.update(dt);
    _grid.clear();
    final enemies = world.enemies;
    for (final enemy in enemies) {
      final key = _key(
        (enemy.position.x / _cellSize).floor(),
        (enemy.position.y / _cellSize).floor(),
      );
      (_grid[key] ??= []).add(enemy);
    }

    for (final enemy in enemies) {
      enemy.separation.setZero();
      final cx = (enemy.position.x / _cellSize).floor();
      final cy = (enemy.position.y / _cellSize).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final bucket = _grid[_key(cx + dx, cy + dy)];
          if (bucket == null) continue;
          for (final other in bucket) {
            if (identical(other, enemy)) continue;
            _offset
              ..setFrom(enemy.position)
              ..sub(other.position);
            final d2 = _offset.length2;
            if (d2 >= _minDistance * _minDistance || d2 < 1e-6) continue;
            final d = math.sqrt(d2);
            final push = (_minDistance - d) / _minDistance;
            enemy.separation.addScaled(
              _offset,
              push * Balance.enemySeparationStrength / d,
            );
          }
        }
      }
    }
  }
}
