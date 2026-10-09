import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import 'projectile.dart';
import 'weapon.dart';

/// 화염 석궁 (불씨 사냥꾼): 적을 여럿 꿰뚫는 불화살.
class FireCrossbow extends Weapon {
  FireCrossbow() : super(baseCooldown: Balance.crossbowCooldown);

  @override
  WeaponId get id => WeaponId.fireCrossbow;

  int get pierce =>
      Balance.crossbowPierce +
      bonusPierce +
      (awakened ? Balance.stormPierceBonus : 0);

  int get arrowCount =>
      (awakened ? Balance.stormArrows : 1) +
      bonusCount +
      world.player.extraProjectiles;

  @override
  bool fire() {
    final origin = world.player.position;
    final target = world.nearestEnemy(
      origin,
      maxDistance: Balance.crossbowRange,
    );
    if (target == null) return false;
    final aim = target.position - origin;
    for (var i = 0; i < arrowCount; i++) {
      final offset = (i - (arrowCount - 1) / 2) * Balance.stormSpread;
      world.add(
        FireArrow(
          position: origin.clone(),
          direction: aim.clone()..rotate(offset),
          damage: Balance.crossbowDamage * damageMultiplier,
          type: id.damageType,
          pierce: pierce,
          speed: Balance.crossbowSpeed * speedMultiplier,
          storm: awakened,
        ),
      );
    }
    return true;
  }
}

class FireArrow extends Projectile {
  FireArrow({
    required super.position,
    required super.direction,
    required super.damage,
    required super.type,
    required super.pierce,
    super.speed = Balance.crossbowSpeed,
    this.storm = false,
  }) : super(lifetime: Balance.crossbowLifetime, size: Vector2(24, 6));

  /// 폭풍 석궁 화살: 푸른 번개를 두른다.
  final bool storm;

  static final _trail = Paint()..color = const Color(0x66FF6B35);
  static final _shaft = Paint()..color = const Color(0xFFFFE0A3);
  static final _tip = Paint()..color = const Color(0xFFFF6B35);
  static final _stormTrail = Paint()..color = const Color(0x886FD6FF);
  static final _stormTip = Paint()..color = const Color(0xFFFFFFFF);

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(
        Rect.fromLTWH(storm ? -18 : -10, 1, size.x, size.y - 2),
        storm ? _stormTrail : _trail,
      )
      ..drawRect(Rect.fromLTWH(0, 2, size.x - 6, 2), _shaft)
      ..drawPath(
        Path()
          ..moveTo(size.x - 7, 0)
          ..lineTo(size.x, size.y / 2)
          ..lineTo(size.x - 7, size.y)
          ..close(),
        storm ? _stormTip : _tip,
      );
  }
}
