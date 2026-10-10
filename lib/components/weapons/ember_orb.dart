import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../effects/burst.dart';
import '../effects/pixel_fx.dart';
import 'weapon_art.dart';
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

  bool get hasOverheat => level >= Balance.overheatLevel;

  /// 지금까지 시전한 수. 과열 차례를 센다.
  int casts = 0;

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
    casts++;
    if (hasOverheat && casts % Balance.overheatEvery == 0) {
      world.add(
        EmberBolt(
          position: origin.clone(),
          direction: aim.clone(),
          damage: damage * Balance.overheatDamage,
          type: id.damageType,
          explodes: true,
          pierce: bonusPierce,
          speed: Balance.emberOrbSpeed * speedMultiplier * 0.8,
          radius: Balance.overheatRadius * areaMultiplier,
          bulk: Balance.overheatSize,
        ),
      );
    }
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
    this.bulk = 1,
  }) : super(
         lifetime: Balance.emberOrbLifetime,
         size: Vector2.all(Balance.emberOrbRadius * 2 * bulk),
       );

  /// 크기 배율. 과열 화염구는 크다.
  final double bulk;

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

  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
  }

  /// 도트 불덩이: 하얀 속의 머리와 뒤로 끌리는 불꼬리. 과열 화염구는 크고 꼬리가 길며,
  /// 각성(유성 잔불)은 속이 더 하얗게 달아오른다.
  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final r = Balance.emberOrbRadius * bulk * (explodes ? 1.3 : 1);
    PixelFx.glow(canvas, c, r * 4, const Color(0xFFF77622), strength: 0.45);
    final pc = PixelCanvas.fine;
    PixelFx.comet(
      pc,
      r,
      r * (bulk > 1 ? 5 : 3.2),
      time: _age,
      salt: hashCode & 0xFFFF,
      tones: explodes
          ? const [
              Pal.white,
              Pal.white,
              Pal.goldLight,
              Pal.gold,
              Color(0xFFF77622),
              Pal.red,
            ]
          : FxTones.fire,
    );
    canvas
      ..save()
      ..translate(c.dx, c.dy);
    pc.flush(canvas);
    canvas.restore();
  }
}
