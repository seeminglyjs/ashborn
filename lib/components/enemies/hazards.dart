import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../game/world/run_world.dart';
import '../effects/sparks.dart';

/// 적 공격 테두리 색. 적의 탄 · 장판 · 충격파 · 예고선은 모두 이 빨간 테두리를 둘러
/// 도트로 그린 내 공격과 한눈에 갈린다.
const enemyOutline = Color(0xFFFF1F3D);

/// 적 공격 테두리 붓. [width] 굵기로 그린다.
Paint dangerStroke(double width, [double opacity = 1]) => Paint()
  ..color = enemyOutline.withValues(alpha: opacity.clamp(0, 1))
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// 두 점 사이 적 예고선 (돌진 경로): 옅게 칠한 띠에 빨간 테두리.
void drawDangerLane(
  Canvas canvas,
  Offset from,
  Offset to,
  double width,
  Color fill,
) {
  final d = to - from;
  if (d.distance < 1) return;
  final angle = math.atan2(d.dy, d.dx);
  final rect = Rect.fromLTWH(0, -width / 2, d.distance, width);
  final shape = RRect.fromRectAndRadius(rect, Radius.circular(width / 2));
  canvas
    ..save()
    ..translate(from.dx, from.dy)
    ..rotate(angle)
    ..drawRRect(shape, Paint()..color = fill)
    ..drawRRect(shape, dangerStroke(2.5))
    ..restore();
}

/// 적의 폭발 (자폭 · 장판이 터질 때). 매끈한 원에 빨간 테두리.
class HostileBurst extends PositionComponent {
  HostileBurst({
    required super.position,
    required this.radius,
    required this.color,
  }) : super(priority: 6);

  final double radius;
  final Color color;
  static const double duration = 0.32;
  double _life = 0;
  final _fill = Paint();

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    final r = radius * (0.3 + 0.7 * (1 - (1 - t) * (1 - t)));
    _fill.color = color.withValues(alpha: 0.45 * (1 - t));
    canvas
      ..drawCircle(Offset.zero, r, _fill)
      ..drawCircle(Offset.zero, r, dangerStroke(3, 1 - t));
  }
}

/// 적이 남긴 공격 (탄 · 장판 · 충격파). 플레이어에게만 피해를 준다.
/// 보스를 잡으면 졸개와 함께 모두 사라진다.
abstract class Hazard extends PositionComponent
    with HasWorldReference<RunWorld> {
  Hazard({required super.position, super.priority = 5})
    : super(anchor: Anchor.center);

  /// 플레이어 중심이 [at] 에서 [reach] 안에 있는가 (플레이어 몸 크기 포함).
  bool touchesPlayer(Vector2 at, double reach) {
    final r = reach + Balance.playerRadius;
    return world.player.position.distanceToSquared(at) <= r * r;
  }
}

/// 곧게 날아가는 적 탄. 플레이어에 닿으면 사라진다.
class EnemyBullet extends Hazard {
  EnemyBullet({
    required super.position,
    required Vector2 direction,
    required this.damage,
    required this.type,
    required this.color,
    double speed = Balance.enemyBulletSpeed,
    this.radius = Balance.enemyBulletRadius,
  }) : velocity = (direction.isZero() ? Vector2(1, 0) : direction.normalized())
         ..scale(speed),
       super(priority: 6);

  final Vector2 velocity;
  final double damage;
  final DamageType type;
  final Color color;
  final double radius;
  double _life = Balance.enemyBulletLifetime;

  late final _glow = Paint()..color = color.withValues(alpha: 0.35);
  late final _core = Paint()..color = color;
  static final _center = Paint()..color = const Color(0xFFFFFFFF);
  static final _edge = dangerStroke(2);

  @override
  void onMount() {
    super.onMount();
    world.enemyBullets++;
  }

  @override
  void onRemove() {
    world.enemyBullets--;
    super.onRemove();
  }

  @override
  void update(double dt) {
    position.addScaled(velocity, dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    if (touchesPlayer(position, radius * 0.7)) {
      world.player.takeDamage(damage, type: type);
      world.add(Sparks(position: position.clone(), color: color, count: 4));
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawCircle(Offset.zero, radius * 1.8, _glow)
      ..drawCircle(Offset.zero, radius, _core)
      ..drawCircle(Offset.zero, radius * 0.45, _center)
      ..drawCircle(Offset.zero, radius + 1.5, _edge);
  }
}

/// 바닥에 예고 원을 그린 뒤 [delay] 초 뒤 터지는 장판. [linger] 가 있으면 터진 자리가
/// 그 시간 동안 타오르며 들어온 플레이어를 계속 아프게 한다.
class GroundBlast extends Hazard {
  GroundBlast({
    required super.position,
    required this.radius,
    required this.damage,
    required this.type,
    required this.color,
    this.delay = Balance.casterBlastDelay,
    this.linger = 0,
  }) : super(priority: -50);

  final double radius;
  final double damage;
  final DamageType type;
  final Color color;
  final double delay;
  final double linger;
  double _time = 0;
  bool _exploded = false;

  static final _ring = dangerStroke(3);
  static final _burnEdge = dangerStroke(2, 0.8);
  late final _fill = Paint()..color = color.withValues(alpha: 0.28);
  late final _burn = Paint()..color = color.withValues(alpha: 0.35);

  bool get exploded => _exploded;

  @override
  void update(double dt) {
    _time += dt;
    if (!_exploded && _time >= delay) {
      _exploded = true;
      world.add(
        HostileBurst(position: position.clone(), radius: radius, color: color),
      );
      world.add(Sparks(position: position.clone(), color: color, count: 10));
      if (touchesPlayer(position, radius)) {
        world.player.takeDamage(damage, type: type);
      }
      world.shake(0.15);
    }
    if (_exploded) {
      if (_time >= delay + linger) {
        removeFromParent();
      } else if (linger > 0 && touchesPlayer(position, radius * 0.85)) {
        // 무적 시간이 있어 매 프레임 불러도 0.5초에 한 번만 아프다.
        world.player.takeDamage(damage * 0.5, type: type);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_exploded) {
      final flicker = 0.85 + 0.15 * math.sin(_time * 18);
      canvas
        ..drawCircle(Offset.zero, radius * 0.85 * flicker, _burn)
        ..drawCircle(Offset.zero, radius * 0.85, _burnEdge);
      return;
    }
    // 예고: 테두리 안에서 채움 원이 자라 테두리에 닿으면 터진다.
    canvas
      ..drawCircle(Offset.zero, radius, _ring)
      ..drawCircle(Offset.zero, radius * (_time / delay), _fill);
  }
}

/// [from] 에서 바깥으로 퍼지는 고리. 고리 앞쪽이 지나가는 순간 플레이어에게 한 번 피해.
/// 고리를 뛰어넘을 수는 없으니 멀리 떨어지거나 고리가 지나간 안쪽으로 파고들어야 한다.
class Shockwave extends Hazard {
  Shockwave({
    required super.position,
    required this.maxRadius,
    required this.damage,
    required this.type,
    required this.color,
    this.duration = 0.9,
  }) : super(priority: -40);

  final double maxRadius;
  final double damage;
  final DamageType type;
  final Color color;
  final double duration;
  static const double thickness = 16;

  double _time = 0;
  bool _hit = false;

  late final _paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = thickness;

  double get _radius => maxRadius * (_time / duration);

  @override
  void update(double dt) {
    _time += dt;
    if (_time >= duration) {
      removeFromParent();
      return;
    }
    if (_hit) return;
    final d = world.player.position.distanceTo(position);
    if ((d - _radius).abs() <= thickness / 2 + Balance.playerRadius * 0.6) {
      _hit = true;
      world.player.takeDamage(damage, type: type);
    }
  }

  @override
  void render(Canvas canvas) {
    final t = _time / duration;
    _paint.color = color.withValues(alpha: 0.6 * (1 - t));
    final edge = dangerStroke(2.5, 1 - t * 0.6);
    canvas
      ..drawCircle(Offset.zero, _radius, _paint)
      ..drawCircle(Offset.zero, _radius + thickness / 2, edge)
      ..drawCircle(Offset.zero, math.max(0, _radius - thickness / 2), edge);
  }
}
