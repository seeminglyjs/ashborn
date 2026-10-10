import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../components/enemies/boss.dart';
import '../../components/enemies/enemy.dart';
import '../../components/props/crate.dart';
import '../../data/balance.dart';
import '../../data/damage.dart';
import 'dungeon_floor.dart';
import 'region_theme.dart';
import 'run_world.dart';

/// 바닥 타일 좌표 ([gx], [gy]) 의 열쇠.
int _key(int gx, int gy) => ((gx & 0xFFFF) << 16) | (gy & 0xFFFF);

/// 맵의 구조물 밑동. 플레이어와 적이 뚫고 지나가지 못하게 밀어낸다.
///
/// 구조물은 [DungeonFloor.propAt] 이 타일 해시로 정하니, 타일마다 한 번 물어보고 기억해 둔다.
class Obstacles {
  Obstacles(this._theme);

  /// 원본 1 픽셀의 월드 크기와 타일 한 칸의 월드 크기.
  static const double _pixel = DungeonFloor.pixel;
  static const double _tile = DungeonFloor.tile * _pixel;

  /// 가장 큰 밑동 반지름 (월드). 이만큼 둘레 타일까지 살핀다.
  static final double _maxFoot =
      Structure.values.map((s) => s.foot).reduce(math.max) * _pixel;

  final RegionTheme Function() _theme;
  RegionTheme? _cachedTheme;
  final _cache = <int, Structure?>{};

  /// ([gx], [gy]) 타일에 선 부딪히는 구조물. 그려지지 않는 자리 (조각 가장자리) 는 없다.
  Structure? structureAt(int gx, int gy) {
    final theme = _theme();
    if (!identical(theme, _cachedTheme)) {
      _cache.clear();
      _cachedTheme = theme;
    }
    if (_cache.length > 50000) _cache.clear();
    return _cache.putIfAbsent(_key(gx, gy), () {
      final prop = DungeonFloor.propAt(gx, gy, theme);
      if (prop is! Structure || prop.foot <= 0) return null;
      const n = DungeonFloor.chunkTiles;
      return prop.fitsChunk(gx % n, gy % n, n) ? prop : null;
    });
  }

  /// 구조물 밑동 원의 월드 중심.
  static Vector2 footOf(int gx, int gy) => Vector2(
    (gx * DungeonFloor.tile + 8) * _pixel,
    ((gy + 1) * DungeonFloor.tile - 4) * _pixel,
  );

  /// 반지름 [radius] 인 원 [position] 이 밑동과 겹치면 바깥으로 밀어낸다 (미끄러지듯 비켜 간다).
  /// 밀어냈으면 true.
  bool pushOut(Vector2 position, double radius) {
    final reach = radius + _maxFoot;
    final x0 = ((position.x - reach) / _tile).floor();
    final x1 = ((position.x + reach) / _tile).floor();
    final y0 = ((position.y - reach) / _tile).floor() - 1;
    final y1 = ((position.y + reach) / _tile).floor();
    var moved = false;
    for (var gy = y0; gy <= y1; gy++) {
      for (var gx = x0; gx <= x1; gx++) {
        final s = structureAt(gx, gy);
        if (s == null) continue;
        final foot = footOf(gx, gy);
        final min = radius + s.foot * _pixel;
        final dx = position.x - foot.x;
        final dy = position.y - foot.y;
        final d2 = dx * dx + dy * dy;
        if (d2 >= min * min) continue;
        if (d2 < 1e-6) {
          position.y += min;
        } else {
          final d = math.sqrt(d2);
          position
            ..x = foot.x + dx / d * min
            ..y = foot.y + dy / d * min;
        }
        moved = true;
      }
    }
    return moved;
  }
}

/// 함정 상태. 가시는 들어가 있다가 예고(끝이 살짝 보임) 뒤 솟는다.
enum TrapState { down, warning, up }

/// 바닥 함정: 녹슨 요새 · 심장의 가시와 심장의 화염 분출구.
/// 솟은 가시를 밟거나 분출 중인 불기둥에 닿으면 플레이어도 적도 다친다.
///
/// 상태는 런 시간과 타일 해시만으로 정해져 바닥 그림([DungeonFloor])과 판정이 늘 맞는다.
class TrapSystem extends Component with HasWorldReference<RunWorld> {
  /// 이 적이 마지막으로 다친 함정 주기. 한 번 솟을 때 한 번만 다친다.
  final _hitCycle = <Enemy, int>{};

  static double _phase(int gx, int gy) => DungeonFloor.hash(gx, gy, 40);

  /// ([gx], [gy]) 함정의 지금 주기 번호와 그 안의 시간.
  static (int, double) _cycle(int gx, int gy, double time, double period) {
    final t = time + _phase(gx, gy) * period;
    final n = (t / period).floor();
    return (n, t - n * period);
  }

  static TrapState spikeState(int gx, int gy, double time) {
    final (_, t) = _cycle(gx, gy, time, Balance.spikePeriod);
    const up = Balance.spikePeriod - Balance.spikeUpTime;
    if (t >= up) return TrapState.up;
    if (t >= up - Balance.spikeWarning) return TrapState.warning;
    return TrapState.down;
  }

  /// 예고 동안 0 에서 1 로 차오른다 (가시가 얼마나 솟았는지).
  static double spikeRise(int gx, int gy, double time) {
    final (_, t) = _cycle(gx, gy, time, Balance.spikePeriod);
    const up = Balance.spikePeriod - Balance.spikeUpTime;
    return ((t - (up - Balance.spikeWarning)) / Balance.spikeWarning).clamp(
      0.0,
      1.0,
    );
  }

  static TrapState ventState(int gx, int gy, double time) {
    final (_, t) = _cycle(gx, gy, time, Balance.ventPeriod);
    const up = Balance.ventPeriod - Balance.ventBurstTime;
    if (t >= up) return TrapState.up;
    if (t >= up - Balance.ventWarning) return TrapState.warning;
    return TrapState.down;
  }

  static const double _tile = DungeonFloor.tile * DungeonFloor.pixel;

  /// 월드 좌표가 놓인 타일.
  static (int, int) tileOf(Vector2 p) =>
      ((p.x / _tile).floor(), (p.y / _tile).floor());

  /// ([gx], [gy]) 의 함정 종류. 없으면 null.
  static Object? trapAt(int gx, int gy, RegionTheme theme) =>
      switch (DungeonFloor.propAt(gx, gy, theme)) {
        Decor.spikes => Decor.spikes,
        Structure.fireVent => Structure.fireVent,
        _ => null,
      };

  /// [p] 에게 지금 피해를 주는 함정. 없거나 들어가 있으면 null.
  static Object? hurting(Vector2 p, RegionTheme theme, double time) {
    final (gx, gy) = tileOf(p);
    switch (trapAt(gx, gy, theme)) {
      case Decor.spikes when spikeState(gx, gy, time) == TrapState.up:
        return Decor.spikes;
      case Structure.fireVent when ventState(gx, gy, time) == TrapState.up:
        final c = Obstacles.footOf(gx, gy);
        final inside =
            p.distanceToSquared(c) <= Balance.ventRadius * Balance.ventRadius;
        return inside ? Structure.fireVent : null;
      default:
        return null;
    }
  }

  RegionTheme get _theme => RegionTheme.of(world.stage.region);

  @override
  void update(double dt) {
    super.update(dt);
    if (world.stageCleared) return;
    final theme = _theme;
    final time = world.elapsed;
    final player = world.player;
    if (hurting(player.position, theme, time) case final trap?) {
      player.takeDamage(
        Balance.trapDamage *
            Balance.enemyContactDamage *
            world.stage.enemyDamageMultiplier,
        type: typeOf(trap),
      );
    }
    for (final enemy in world.enemies) {
      if (enemy is Boss || enemy is Crate || enemy.isDead) continue;
      final trap = hurting(enemy.position, theme, time);
      if (trap == null) continue;
      final (gx, gy) = tileOf(enemy.position);
      final period = trap == Decor.spikes
          ? Balance.spikePeriod
          : Balance.ventPeriod;
      final (cycle, _) = _cycle(gx, gy, time, period);
      if (_hitCycle[enemy] == cycle) continue;
      _hitCycle[enemy] = cycle;
      enemy.takeDamage(enemy.maxHp * Balance.trapEnemyDamage);
    }
    if (_hitCycle.length > 64) _hitCycle.removeWhere((e, _) => e.isDead);
  }

  /// 함정 피해 속성: 가시는 물리, 분출구는 화염.
  static DamageType typeOf(Object trap) =>
      trap == Decor.spikes ? DamageType.physical : DamageType.fire;
}
