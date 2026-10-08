import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import 'projectile.dart';
import 'weapon.dart';

/// 잔불 구체 (재의 마녀): 가장 가까운 적에게 불씨를 쏜다.
/// 여러 발이면 부채꼴로 퍼진다.
class EmberOrb extends Weapon {
  EmberOrb() : super(baseCooldown: Balance.emberOrbCooldown);

  @override
  WeaponId get id => WeaponId.emberOrb;

  int get boltCount => 1 + bonusCount;

  @override
  bool fire() {
    final origin = world.player.position;
    final target = world.nearestEnemy(
      origin,
      maxDistance: Balance.emberOrbRange,
    );
    if (target == null) return false;
    final aim = target.position - origin;
    final damage = Balance.emberOrbDamage * damageMultiplier;
    for (var i = 0; i < boltCount; i++) {
      final offset = (i - (boltCount - 1) / 2) * Balance.emberOrbSpread;
      world.add(
        EmberBolt(
          position: origin.clone(),
          direction: aim.clone()..rotate(offset),
          damage: damage,
        ),
      );
    }
    return true;
  }
}

class EmberBolt extends Projectile {
  EmberBolt({
    required super.position,
    required super.direction,
    required super.damage,
  }) : super(
         speed: Balance.emberOrbSpeed,
         lifetime: Balance.emberOrbLifetime,
         size: Vector2.all(Balance.emberOrbRadius * 2),
       );

  static final _glow = Paint()..color = const Color(0x55FF8C42);
  static final _core = Paint()..color = const Color(0xFFFFD27A);

  @override
  ShapeHitbox createHitbox() => CircleHitbox();

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas
      ..drawCircle(c, Balance.emberOrbRadius * 1.8, _glow)
      ..drawCircle(c, Balance.emberOrbRadius, _core);
  }
}
