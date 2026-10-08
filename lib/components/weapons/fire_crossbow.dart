import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import 'projectile.dart';
import 'weapon.dart';

/// 화염 석궁 (불씨 사냥꾼): 적을 여럿 꿰뚫는 불화살.
class FireCrossbow extends Weapon {
  FireCrossbow() : super(baseCooldown: Balance.crossbowCooldown);

  @override
  bool fire() {
    final origin = world.player.position;
    final target = world.nearestEnemy(
      origin,
      maxDistance: Balance.crossbowRange,
    );
    if (target == null) return false;
    world.add(
      FireArrow(position: origin.clone(), direction: target.position - origin),
    );
    return true;
  }
}

class FireArrow extends Projectile {
  FireArrow({required super.position, required super.direction})
    : super(
        speed: Balance.crossbowSpeed,
        damage: Balance.crossbowDamage,
        lifetime: Balance.crossbowLifetime,
        pierce: Balance.crossbowPierce,
        size: Vector2(24, 6),
      );

  static final _trail = Paint()..color = const Color(0x66FF6B35);
  static final _shaft = Paint()..color = const Color(0xFFFFE0A3);
  static final _tip = Paint()..color = const Color(0xFFFF6B35);

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(Rect.fromLTWH(-10, 1, size.x, size.y - 2), _trail)
      ..drawRect(Rect.fromLTWH(0, 2, size.x - 6, 2), _shaft)
      ..drawPath(
        Path()
          ..moveTo(size.x - 7, 0)
          ..lineTo(size.x, size.y / 2)
          ..lineTo(size.x - 7, size.y)
          ..close(),
        _tip,
      );
  }
}
