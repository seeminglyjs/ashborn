import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../enemies/enemy.dart';
import 'weapon.dart';

/// 불꽃 대검 (잿불 기사): 플레이어 주위를 도는 칼날.
///
/// 쿨다운 무기가 아니라 상시 판정이며, 같은 적은 일정 간격으로만 벤다.
class FlameBlade extends PositionComponent
    with HasWorldReference<RunWorld>, LeveledWeapon {
  final _lastHit = <Enemy, double>{};

  /// 아직 마운트 전인 칼날도 지울 수 있도록 직접 들고 있는다.
  final _blades = <_Blade>[];

  @override
  WeaponId get id => WeaponId.flameBlade;

  int get bladeCount =>
      Balance.flameBladeCount +
      bonusCount +
      (awakened ? Balance.infernoBladeBonus : 0) +
      world.player.extraProjectiles;

  double get orbitRadius =>
      Balance.flameBladeOrbitRadius *
      areaMultiplier *
      (awakened ? Balance.infernoOrbitScale : 1);

  /// 칼날을 만든 때의 궤도 반지름. 범위 패시브를 얻으면 다시 만든다.
  double _builtRadius = 0;

  @override
  Future<void> onLoad() async => _buildBlades();

  @override
  void onLevelChanged() => _buildBlades();

  void _buildBlades() {
    removeAll(_blades);
    _blades.clear();
    _builtRadius = orbitRadius;
    final scale = math.sqrt(areaMultiplier);
    for (var i = 0; i < bladeCount; i++) {
      final theta = math.pi * 2 * i / bladeCount;
      _blades.add(
        _Blade(
          position: Vector2(math.cos(theta), math.sin(theta)) * orbitRadius,
          angle: theta,
          scale: scale,
          awakened: awakened,
        ),
      );
    }
    addAll(_blades);
  }

  @override
  void onMount() {
    super.onMount();
    position = world.player.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // 초월 옵션이 붙은 장비를 바꿔 끼면 칼날 수가 바뀐다.
    if (_blades.length != bladeCount || _builtRadius != orbitRadius) {
      _buildBlades();
    }
    angle +=
        Balance.flameBladeAngularSpeed *
        speedMultiplier *
        world.player.attackSpeedMultiplier *
        dt;
    if (_lastHit.length > 64) _lastHit.removeWhere((e, _) => e.isDead);
  }

  void tryHit(Enemy enemy) {
    if (enemy.isDead) return;
    final now = world.elapsed;
    final last = _lastHit[enemy];
    final interval =
        Balance.flameBladeHitInterval *
        cooldownMultiplier /
        world.player.attackSpeedMultiplier;
    if (last != null && now - last < interval) return;
    _lastHit[enemy] = now;
    world.player.strike(
      enemy,
      Balance.flameBladeDamage * damageMultiplier,
      id.damageType,
    );
  }
}

class _Blade extends PositionComponent
    with CollisionCallbacks, ParentIsA<FlameBlade> {
  _Blade({
    required super.position,
    required super.angle,
    required double scale,
    required this.awakened,
  }) : super(
         size:
             Vector2(Balance.flameBladeLength, Balance.flameBladeWidth) * scale,
         anchor: Anchor.center,
       );

  /// 업화의 대검: 하얗게 달아오른 칼날에 푸른 불꽃.
  final bool awakened;

  static final _glow = Paint()..color = const Color(0x44FF6B35);
  static final _edge = Paint()..color = const Color(0xFFFFC56B);
  static final _core = Paint()..color = const Color(0xFFFFF1C9);
  static final _infernoGlow = Paint()..color = const Color(0x664FC3FF);
  static final _infernoEdge = Paint()..color = const Color(0xFFFFFFFF);
  static final _infernoCore = Paint()..color = const Color(0xFF8FE3FF);

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Enemy) parent.tryHit(other);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-4, -4, w + 8, h + 8),
          const Radius.circular(8),
        ),
        awakened ? _infernoGlow : _glow,
      )
      ..drawPath(
        Path()
          ..moveTo(0, h * 0.2)
          ..lineTo(w * 0.8, 0)
          ..lineTo(w, h / 2)
          ..lineTo(w * 0.8, h)
          ..lineTo(0, h * 0.8)
          ..close(),
        awakened ? _infernoEdge : _edge,
      )
      ..drawRect(
        Rect.fromLTWH(2, h * 0.4, w * 0.75, h * 0.2),
        awakened ? _infernoCore : _core,
      );
  }
}
