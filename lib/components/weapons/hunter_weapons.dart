import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/sparks.dart';
import 'projectile.dart';
import 'weapon.dart';
import 'weapon_art.dart';

/// 불씨 덫 (불씨 사냥꾼): 발밑에 덫을 묻는다. 적이 밟으면 터진다.
/// 각성(연쇄 폭뢰)하면 터진 둘레에 작은 폭발이 이어진다.
class EmberMine extends Weapon {
  EmberMine() : super(baseCooldown: Balance.mineCooldown);

  @override
  WeaponId get id => WeaponId.emberMine;

  int get mineCount => 1 + bonusCount + world.player.extraProjectiles;

  @override
  bool fire() {
    final r = world.game.random;
    final at = world.player.position;
    for (var i = 0; i < mineCount; i++) {
      if (world.children.whereType<Mine>().length >= Balance.maxMines) {
        break;
      }
      final offset = i == 0
          ? Vector2.zero()
          : (Vector2(r.nextDouble() - 0.5, r.nextDouble() - 0.5)..scale(80));
      world.add(
        Mine(
          position: at + offset,
          damage: Balance.mineDamage * damageMultiplier,
          radius: Balance.mineRadius * areaMultiplier,
          chain: awakened,
        ),
      );
    }
    return true;
  }
}

class Mine extends PositionComponent with HasWorldReference<RunWorld> {
  Mine({
    required super.position,
    required this.damage,
    required this.radius,
    this.chain = false,
  }) : super(priority: -30);

  final double damage;
  final double radius;
  final bool chain;
  double _t = 0;

  static final _body = Paint()..color = const Color(0xFF5A3A22);
  static final _light = Paint()..color = const Color(0xFFFF6B35);
  static final _armed = Paint()..color = const Color(0xFFFFE08A);

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= Balance.mineLifetime) {
      removeFromParent();
      return;
    }
    if (_t < Balance.mineArmTime) return;
    if (world
        .enemiesNear(position, Balance.mineTrigger + Balance.enemyRadius)
        .isEmpty) {
      return;
    }
    _explode(position.clone(), radius, damage);
    if (chain) {
      for (var i = 0; i < 3; i++) {
        final a = math.pi * 2 * i / 3 + _t;
        _explode(
          position + Vector2(math.cos(a), math.sin(a)) * radius,
          radius * 0.6,
          damage * 0.5,
        );
      }
    }
    removeFromParent();
  }

  void _explode(Vector2 at, double r, double amount) {
    world
      ..add(Burst(position: at, radius: r, color: const Color(0xFFFF8C42)))
      ..add(
        Sparks(
          position: at.clone(),
          color: const Color(0xFFFFC56B),
          count: 8,
          speed: 200,
        ),
      )
      ..shake(0.08);
    for (final enemy in world.enemiesNear(at, r)) {
      world.player.strike(enemy, amount, DamageType.fire);
      enemy.knock(enemy.position - at, 140);
    }
  }

  @override
  void render(Canvas canvas) {
    final blink = _t >= Balance.mineArmTime && (_t * 3).floor().isEven;
    canvas
      ..drawCircle(Offset.zero, 7, _body)
      ..drawCircle(Offset.zero, 3, blink ? _armed : _light);
  }
}

/// 투척 단검 (불씨 사냥꾼): 가장 가까운 적에게 단검을 연달아 던진다.
/// 각성(칼날 폭풍)하면 앞뒤 양옆 네 방향으로 함께 던진다.
class ThrowingKnives extends Weapon {
  ThrowingKnives() : super(baseCooldown: Balance.knifeCooldown);

  @override
  WeaponId get id => WeaponId.throwingKnives;

  int get knifeCount => 1 + bonusCount + world.player.extraProjectiles;

  @override
  bool fire() {
    final player = world.player;
    final target = world.nearestEnemy(
      player.position,
      maxDistance: Balance.knifeSpeed * Balance.knifeLifetime,
    );
    if (target == null) return false;
    final aim = (target.position - player.position)..normalize();
    final directions = awakened ? 4 : 1;
    for (var d = 0; d < directions; d++) {
      for (var i = 0; i < knifeCount; i++) {
        final offset =
            math.pi / 2 * d + (i - (knifeCount - 1) / 2) * Balance.knifeSpread;
        world.add(
          Knife(
            position: player.position.clone(),
            direction: aim.clone()..rotate(offset),
            damage: Balance.knifeDamage * damageMultiplier,
            type: id.damageType,
            pierce: bonusPierce,
            speed: Balance.knifeSpeed * speedMultiplier,
            awakened: awakened,
          ),
        );
      }
    }
    return true;
  }
}

class Knife extends Projectile {
  Knife({
    required super.position,
    required super.direction,
    required super.damage,
    required super.type,
    required super.pierce,
    required super.speed,
    this.awakened = false,
  }) : super(lifetime: Balance.knifeLifetime, size: Vector2(16, 4));

  final bool awakened;

  static final _glow = Paint()..color = const Color(0x664FC3FF);

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void render(Canvas canvas) {
    if (awakened) {
      canvas.drawRect(Rect.fromLTWH(-6, -1, size.x + 6, size.y + 2), _glow);
    }
    knifeArt.draw(
      canvas..translate(0, size.y / 2),
      pivot: Offset(0, knifeArt.height / 2),
      scale: size.x / knifeArt.width,
    );
  }
}
