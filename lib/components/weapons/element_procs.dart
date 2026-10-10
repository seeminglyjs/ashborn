import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../game/world/run_world.dart';
import 'projectile.dart';

/// 얼어 있던 적이 쓰러지며 튀는 얼음 파편. 맞은 적에게 냉기 피해 (다시 쌓여 얼 수 있다).
class IceShard extends Projectile {
  IceShard({
    required super.position,
    required super.direction,
    required super.damage,
  }) : super(
         type: DamageType.cold,
         speed: Balance.shardSpeed,
         lifetime: Balance.shardLifetime,
         size: Vector2(14, 6),
         secondary: true,
       );

  static final _body = Paint()..color = const Color(0xFF9FE0FF);
  static final _edge = Paint()..color = const Color(0xFFFFFFFF);
  static final _trail = Paint()..color = const Color(0x5574C6F0);

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    canvas
      ..drawRect(Rect.fromLTWH(-8, h * 0.3, 10, h * 0.4), _trail)
      ..drawPath(
        Path()
          ..moveTo(0, h / 2)
          ..lineTo(w * 0.35, 0)
          ..lineTo(w, h / 2)
          ..lineTo(w * 0.35, h)
          ..close(),
        _body,
      )
      ..drawRect(Rect.fromLTWH(w * 0.35, h * 0.35, w * 0.5, 1.5), _edge);
  }
}

/// 바람 검기: 일직선으로 날아가며 닿는 적을 모두 벤다.
class WindSlash extends Projectile {
  WindSlash({
    required super.position,
    required super.direction,
    required super.damage,
  }) : super(
         type: DamageType.wind,
         speed: Balance.windSlashSpeed,
         lifetime: Balance.windSlashLifetime,
         size: Vector2(18, 34),
         pierce: 999,
         secondary: true,
       );

  double _age = 0;

  static final _outer = Paint()
    ..color = const Color(0x669CF0C0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;
  static final _inner = Paint()
    ..color = const Color(0xFFEFFFF5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
  }

  @override
  void render(Canvas canvas) {
    // 진행 방향(오른쪽)으로 볼록한 초승달.
    final fade = (1 - _age / Balance.windSlashLifetime).clamp(0.3, 1.0);
    final rect = Rect.fromLTWH(-size.x, 0, size.x * 2, size.y);
    _outer.color = const Color(0xFF9CF0C0).withValues(alpha: 0.45 * fade);
    _inner.color = const Color(0xFFEFFFF5).withValues(alpha: fade);
    canvas
      ..drawArc(rect, -math.pi / 2.4, math.pi / 1.2, false, _outer)
      ..drawArc(rect.deflate(3), -math.pi / 2.6, math.pi / 1.3, false, _inner);
  }
}

/// 소용돌이: 자리에 [Balance.vortexDuration] 초 머물며 둘레 적을 끌어당기고 계속 벤다.
class Vortex extends PositionComponent with HasWorldReference<RunWorld> {
  Vortex({required super.position, required this.damage})
    : super(priority: 6, anchor: Anchor.center);

  /// 한 번 칠 때의 바람 피해.
  final double damage;
  double _age = 0;
  double _tick = 0;

  static final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final _fill = Paint();

  @override
  void update(double dt) {
    _age += dt;
    _tick -= dt;
    const r = Balance.vortexRadius;
    for (final enemy in world.enemiesNear(position, r)) {
      final pull = position - enemy.position;
      if (pull.length2 > 16) {
        enemy.position.addScaled(pull.normalized(), Balance.vortexPull * dt);
      }
    }
    if (_tick <= 0) {
      _tick = Balance.vortexTick;
      for (final enemy in world.enemiesNear(position, r)) {
        world.player.strike(enemy, damage, DamageType.wind, secondary: true);
      }
    }
    if (_age >= Balance.vortexDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    const r = Balance.vortexRadius;
    final grow = math.min(1.0, _age / 0.2);
    final fade = math.min(1.0, (Balance.vortexDuration - _age) / 0.3);
    _fill.color = const Color(0xFF9CF0C0).withValues(alpha: 0.12 * fade);
    canvas.drawCircle(Offset.zero, r * grow, _fill);
    // 안쪽으로 감겨 드는 바람 줄기 네 가닥이 돈다.
    for (var k = 0; k < 4; k++) {
      final spin = _age * 9 + k * math.pi / 2;
      for (var ring = 0; ring < 3; ring++) {
        final radius = r * grow * (0.35 + 0.3 * ring);
        _paint
          ..strokeWidth = 3.5 - ring
          ..color =
              (ring == 0 ? const Color(0xFFEFFFF5) : const Color(0xFF9CF0C0))
                  .withValues(alpha: (0.9 - ring * 0.25) * fade);
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          spin - ring * 0.6,
          0.9,
          false,
          _paint,
        );
      }
    }
  }
}
