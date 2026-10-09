import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../effects/burst.dart';
import '../effects/sparks.dart';
import '../enemies/enemy.dart';
import 'projectile.dart';
import 'weapon.dart';

/// 잔불 구체 (재의 마녀): 가장 가까운 적에게 불씨를 쏜다.
/// 여러 발이면 부채꼴로 퍼진다.
class EmberOrb extends Weapon {
  EmberOrb() : super(baseCooldown: Balance.emberOrbCooldown);

  @override
  WeaponId get id => WeaponId.emberOrb;

  int get boltCount => 1 + bonusCount + world.player.extraProjectiles;

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
          type: id.damageType,
          explodes: awakened,
          pierce: bonusPierce,
          speed: Balance.emberOrbSpeed * speedMultiplier,
          radius: Balance.meteorRadius * areaMultiplier,
        ),
      );
    }
    return true;
  }
}

/// 잔불 구체의 불씨. 각성하면 ([explodes]) 맞힌 자리에서 터진다.
class EmberBolt extends Projectile {
  EmberBolt({
    required super.position,
    required super.direction,
    required super.damage,
    required super.type,
    this.explodes = false,
    super.pierce,
    super.speed = Balance.emberOrbSpeed,
    this.radius = Balance.meteorRadius,
  }) : super(
         lifetime: Balance.emberOrbLifetime,
         size: Vector2.all(Balance.emberOrbRadius * 2),
       );

  static final _glow = Paint()..color = const Color(0x55FF8C42);
  static final _core = Paint()..color = const Color(0xFFFFD27A);
  static final _meteorGlow = Paint()..color = const Color(0x77FF3A1A);
  static final _meteorCore = Paint()..color = const Color(0xFFFFFFFF);

  final bool explodes;

  /// 각성 폭발 반지름.
  final double radius;

  @override
  ShapeHitbox createHitbox() => CircleHitbox();

  @override
  void onHit(Enemy enemy) {
    if (!explodes) return;
    final at = enemy.position.clone();
    world.add(
      Burst(position: at, radius: radius, color: const Color(0xFFFF8C42)),
    );
    world.add(Sparks(position: at.clone(), color: const Color(0xFFFFC56B)));
    for (final other in world.enemiesNear(at, radius)) {
      if (other == enemy) continue;
      world.player.strike(
        other,
        damage * Balance.meteorRatio,
        type,
        secondary: true,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas
      ..drawCircle(
        c,
        Balance.emberOrbRadius * (explodes ? 2.4 : 1.8),
        explodes ? _meteorGlow : _glow,
      )
      ..drawCircle(c, Balance.emberOrbRadius, explodes ? _meteorCore : _core);
  }
}
