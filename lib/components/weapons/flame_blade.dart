import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../game/world/run_world.dart';
import '../enemies/enemy.dart';

/// 불꽃 대검 (잿불 기사): 플레이어 주위를 도는 칼날.
///
/// 쿨다운 무기가 아니라 상시 판정이며, 같은 적은 일정 간격으로만 벤다.
class FlameBlade extends PositionComponent with HasWorldReference<RunWorld> {
  final _lastHit = <Enemy, double>{};

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < Balance.flameBladeCount; i++) {
      final theta = math.pi * 2 * i / Balance.flameBladeCount;
      add(
        _Blade(
          position:
              Vector2(math.cos(theta), math.sin(theta)) *
              Balance.flameBladeOrbitRadius,
          angle: theta,
        ),
      );
    }
  }

  @override
  void onMount() {
    super.onMount();
    position = world.player.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += Balance.flameBladeAngularSpeed * dt;
    if (_lastHit.length > 64) _lastHit.removeWhere((e, _) => e.isDead);
  }

  void tryHit(Enemy enemy) {
    if (enemy.isDead) return;
    final now = world.elapsed;
    final last = _lastHit[enemy];
    if (last != null && now - last < Balance.flameBladeHitInterval) return;
    _lastHit[enemy] = now;
    enemy.takeDamage(Balance.flameBladeDamage);
  }
}

class _Blade extends PositionComponent
    with CollisionCallbacks, ParentIsA<FlameBlade> {
  _Blade({required super.position, required super.angle})
    : super(
        size: Vector2(Balance.flameBladeLength, Balance.flameBladeWidth),
        anchor: Anchor.center,
      );

  static final _glow = Paint()..color = const Color(0x44FF6B35);
  static final _edge = Paint()..color = const Color(0xFFFFC56B);
  static final _core = Paint()..color = const Color(0xFFFFF1C9);

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
        _glow,
      )
      ..drawPath(
        Path()
          ..moveTo(0, h * 0.2)
          ..lineTo(w * 0.8, 0)
          ..lineTo(w, h / 2)
          ..lineTo(w * 0.8, h)
          ..lineTo(0, h * 0.8)
          ..close(),
        _edge,
      )
      ..drawRect(Rect.fromLTWH(2, h * 0.4, w * 0.75, h * 0.2), _core);
  }
}
