import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/sparks.dart';
import '../enemies/enemy.dart';
import 'weapon.dart';

/// 운석 낙하 (재의 마녀): 화면 안 적 머리 위로 불덩이가 떨어진다.
/// 각성(유성우)하면 떨어진 자리가 잠시 타올라 들어온 적을 계속 태운다.
class Meteor extends Weapon {
  Meteor() : super(baseCooldown: Balance.meteorCooldown);

  @override
  WeaponId get id => WeaponId.meteor;

  int get meteorCount => 1 + bonusCount + world.player.extraProjectiles;

  @override
  bool fire() {
    final targets = world
        .enemiesNear(world.player.position, Balance.meteorTargetRange)
        .take(12)
        .toList();
    if (targets.isEmpty) return false;
    final r = world.game.random;
    for (var i = 0; i < meteorCount; i++) {
      final target = targets[r.nextInt(targets.length)];
      world.add(
        FallingMeteor(
          position: target.position.clone(),
          damage: Balance.meteorDamage * damageMultiplier,
          radius: Balance.meteorBlastRadius * areaMultiplier,
          delay: Balance.meteorFallTime + i * 0.08,
          burns: awakened,
        ),
      );
    }
    return true;
  }
}

/// 땅에 그림자를 드리운 뒤 떨어져 터지는 불덩이.
class FallingMeteor extends PositionComponent with HasWorldReference<RunWorld> {
  FallingMeteor({
    required super.position,
    required this.damage,
    required this.radius,
    required this.delay,
    this.burns = false,
  }) : super(priority: 8);

  final double damage;
  final double radius;
  final double delay;
  final bool burns;
  double _t = 0;
  bool _landed = false;
  double _burnTick = 0;

  static final _shadow = Paint()..color = const Color(0x55000000);
  static final _rock = Paint()..color = const Color(0xFFFFD27A);
  static final _fire = Paint()..color = const Color(0x99FF6B35);
  static final _burn = Paint()..color = const Color(0x55FF5A1E);

  @override
  void update(double dt) {
    _t += dt;
    if (!_landed && _t >= delay) {
      _landed = true;
      world
        ..add(
          Burst(
            position: position.clone(),
            radius: radius,
            color: const Color(0xFFFF7A2E),
          ),
        )
        ..add(
          Sparks(
            position: position.clone(),
            color: const Color(0xFFFFB347),
            count: 10,
            speed: 200,
          ),
        )
        ..shake(0.1);
      for (final enemy in world.enemiesNear(position, radius)) {
        world.player.strike(enemy, damage, DamageType.fire);
      }
      if (!burns) removeFromParent();
      return;
    }
    if (_landed) {
      _burnTick -= dt;
      if (_burnTick <= 0) {
        _burnTick = 0.5;
        for (final enemy in world.enemiesNear(position, radius)) {
          world.player.strike(
            enemy,
            damage * Balance.meteorBurnRatio,
            DamageType.fire,
            secondary: true,
          );
        }
      }
      if (_t >= delay + Balance.meteorBurnTime) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_landed) {
      final flicker = 0.85 + 0.15 * math.sin(_t * 20);
      canvas.drawCircle(Offset.zero, radius * 0.8 * flicker, _burn);
      return;
    }
    final t = (_t / delay).clamp(0.0, 1.0);
    // 그림자가 커지는 동안 불덩이가 위에서 내려온다.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 1.4 * t,
        height: radius * 0.6 * t,
      ),
      _shadow,
    );
    final y = -260 * (1 - t);
    canvas
      ..drawCircle(Offset(-y * 0.3, y), 16, _fire)
      ..drawCircle(Offset(-y * 0.3, y), 9, _rock);
  }
}

/// 화염 회오리 (재의 마녀): 사방으로 떠돌며 닿는 적을 태우는 회오리를 날린다.
/// 각성(화염 폭풍)하면 더 커지고 가까운 적을 쫓아간다.
class FireTornado extends Weapon {
  FireTornado() : super(baseCooldown: Balance.tornadoCooldown);

  @override
  WeaponId get id => WeaponId.fireTornado;

  int get tornadoCount =>
      1 + bonusCount + (awakened ? 1 : 0) + world.player.extraProjectiles;

  @override
  bool fire() {
    if (world.enemies.isEmpty) return false;
    final r = world.game.random;
    final start = r.nextDouble() * math.pi * 2;
    for (var i = 0; i < tornadoCount; i++) {
      final a = start + math.pi * 2 * i / tornadoCount;
      world.add(
        Tornado(
          weapon: this,
          position: world.player.position.clone(),
          direction: Vector2(math.cos(a), math.sin(a)),
          radius: Balance.tornadoRadius * areaMultiplier * (awakened ? 1.4 : 1),
          speed: Balance.tornadoSpeed * speedMultiplier,
          lifetime: Balance.tornadoLifetime * durationMultiplier,
          homing: awakened,
        ),
      );
    }
    return true;
  }
}

class Tornado extends PositionComponent with HasWorldReference<RunWorld> {
  Tornado({
    required this.weapon,
    required super.position,
    required Vector2 direction,
    required this.radius,
    required this.speed,
    required double lifetime,
    this.homing = false,
  }) : _dir = direction,
       _life = lifetime,
       super(priority: 7);

  final FireTornado weapon;
  final double radius;
  final double speed;
  final bool homing;
  final Vector2 _dir;
  double _life;
  double _t = 0;
  final _lastHit = <Enemy, double>{};

  static final _outer = Paint()..color = const Color(0x55FF6B35);
  static final _mid = Paint()..color = const Color(0x99FF9A3D);
  static final _core = Paint()..color = const Color(0xCCFFE0A3);

  @override
  void update(double dt) {
    _t += dt;
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
      return;
    }
    if (homing) {
      final target = world.nearestEnemy(position, maxDistance: 220);
      if (target != null) {
        final to = (target.position - position)..normalize();
        _dir
          ..lerp(to, math.min(1, dt * 3))
          ..normalize();
      }
    } else {
      // 이리저리 흔들리며 떠돈다.
      _dir.rotate(math.sin(_t * 3) * dt * 1.5);
    }
    position.addScaled(_dir, speed * dt);
    final interval = Balance.tornadoHitInterval;
    for (final enemy in world.enemiesNear(
      position,
      radius + Balance.enemyRadius,
    )) {
      final last = _lastHit[enemy];
      if (last != null && _t - last < interval) continue;
      _lastHit[enemy] = _t;
      world.player.strike(
        enemy,
        Balance.tornadoDamage * weapon.damageMultiplier,
        weapon.id.damageType,
      );
    }
    if (_lastHit.length > 64) _lastHit.removeWhere((e, _) => e.isDead);
  }

  @override
  void render(Canvas canvas) {
    // 위로 갈수록 넓어지는 소용돌이 고리 세 겹.
    for (var i = 0; i < 3; i++) {
      final wobble = math.sin(_t * 14 + i * 2) * radius * 0.15;
      final w = radius * (0.7 + i * 0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(wobble, -i * radius * 0.45),
          width: w * 2,
          height: w * 0.8,
        ),
        i == 0 ? _core : (i == 1 ? _mid : _outer),
      );
    }
  }
}
