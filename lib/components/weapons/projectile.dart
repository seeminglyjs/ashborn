import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/damage.dart';
import '../../game/world/run_world.dart';
import '../enemies/enemy.dart';

/// 직선으로 날아가 적을 맞히는 투사체. [pierce] 만큼 더 꿰뚫는다.
abstract class Projectile extends PositionComponent
    with CollisionCallbacks, HasWorldReference<RunWorld> {
  Projectile({
    required super.position,
    required Vector2 direction,
    required double speed,
    required this.damage,
    required this.type,
    required double lifetime,
    required super.size,
    this.pierce = 0,
    this.secondary = false,
    this.bleeds = false,
  }) : velocity = (direction.isZero() ? Vector2(1, 0) : direction.normalized())
         ..scale(speed),
       _life = lifetime,
       super(
         anchor: Anchor.center,
         angle: math.atan2(direction.y, direction.x),
       );

  final Vector2 velocity;
  final double damage;
  final DamageType type;
  int pierce;

  /// 효과로 생긴 투사체 (얼음 파편 · 바람 검기): 장비 속성 피해를 다시 더하지 않는다.
  final bool secondary;

  /// 맞힌 적마다 출혈 확률과 상관없이 출혈을 건다 (헤드샷).
  final bool bleeds;
  double _life;
  final _hit = <Enemy>{};

  ShapeHitbox createHitbox();

  @override
  Future<void> onLoad() async {
    add(createHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.addScaled(velocity, dt);
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (isRemoving || other is! Enemy || other.isDead) return;
    if (!_hit.add(other)) return;
    world.player.strike(
      other,
      damage,
      type,
      secondary: secondary,
      bleed: bleeds,
    );
    onHit(other);
    if (pierce-- <= 0) removeFromParent();
  }

  /// 적을 맞힌 뒤 추가 효과.
  void onHit(Enemy enemy) {}
}
