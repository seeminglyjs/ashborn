import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/sparks.dart';
import '../enemies/enemy.dart';
import 'weapon.dart';
import 'weapon_art.dart';

/// 잿불 고리 (공용): 몸 둘레를 계속 태운다. 쿨다운마다 고리 안의 적 모두에게 피해.
/// 각성(지옥불 고리)하면 넓어지고 닿은 적을 느리게 한다.
class AshAura extends PositionComponent
    with HasWorldReference<RunWorld>, LeveledWeapon {
  AshAura() : super(priority: -1);

  @override
  WeaponId get id => WeaponId.ashAura;

  double _tick = 0;
  double _t = 0;

  double get radius =>
      Balance.auraRadius *
      areaMultiplier *
      (awakened ? Balance.infernoAuraScale : 1);

  static final _fill = Paint()..color = const Color(0x22FF6B35);
  static final _edge = Paint()
    ..color = const Color(0x66FF8C42)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _infernoFill = Paint()..color = const Color(0x334FC3FF);
  static final _infernoEdge = Paint()
    ..color = const Color(0x998FE3FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  @override
  void onMount() {
    super.onMount();
    position = world.player.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _tick -= dt;
    if (_tick > 0) return;
    _tick =
        Balance.auraTick *
        cooldownMultiplier /
        world.player.attackSpeedMultiplier;
    final player = world.player;
    for (final enemy in world.enemiesNear(player.position, radius)) {
      player.strike(
        enemy,
        Balance.auraDamage * damageMultiplier,
        id.damageType,
      );
      if (awakened) {
        enemy.ailments.chill(Balance.infernoAuraSlow, Balance.auraTick * 2);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final pulse = 1 + 0.04 * math.sin(_t * 6);
    canvas
      ..drawCircle(Offset.zero, radius * pulse, awakened ? _infernoFill : _fill)
      ..drawCircle(
        Offset.zero,
        radius * pulse,
        awakened ? _infernoEdge : _edge,
      );
  }
}

/// 낙뢰 (공용): 화면 안 적 몇에게 벼락을 내리꽂는다.
/// 각성(신의 심판)하면 벼락이 가까운 적 둘에게 튄다.
class Thunder extends Weapon {
  Thunder() : super(baseCooldown: Balance.thunderCooldown);

  @override
  WeaponId get id => WeaponId.thunder;

  int get boltCount => 1 + bonusCount + world.player.extraProjectiles;

  static const _color = Color(0xFFFFF27A);

  @override
  bool fire() {
    final candidates = world
        .enemiesNear(world.player.position, Balance.thunderRange)
        .toList();
    if (candidates.isEmpty) return false;
    candidates.shuffle(world.game.random);
    final damage = Balance.thunderDamage * damageMultiplier;
    final radius = Balance.thunderRadius * areaMultiplier;
    for (final target in candidates.take(boltCount)) {
      final at = target.position.clone();
      world
        ..add(LightningBolt(position: at, color: _color))
        ..add(Burst(position: at.clone(), radius: radius, color: _color))
        ..add(Sparks(position: at.clone(), color: _color, count: 6));
      for (final enemy in world.enemiesNear(at, radius)) {
        world.player.strike(enemy, damage, id.damageType);
      }
      if (awakened) _chain(target, damage);
    }
    return true;
  }

  void _chain(Enemy from, double damage) {
    final targets = world
        .enemiesNear(from.position, Balance.chainLightningRange)
        .where((e) => e != from)
        .take(Balance.thunderChain);
    for (final target in targets) {
      world.add(LightningArc(from.position.clone(), target.position.clone()));
      world.player.strike(target, damage * 0.6, id.damageType, secondary: true);
    }
  }
}

/// 회전 차크람 (공용): 가까운 적 쪽으로 날아갔다 손으로 돌아오며 닿는 적을 모두 벤다.
/// 각성(쌍월륜)하면 하나 더 날아가고 더 크다.
class Chakram extends Weapon {
  Chakram() : super(baseCooldown: Balance.chakramCooldown);

  @override
  WeaponId get id => WeaponId.chakram;

  int get discCount =>
      1 + bonusCount + (awakened ? 1 : 0) + world.player.extraProjectiles;

  @override
  bool fire() {
    final origin = world.player.position;
    final target = world.nearestEnemy(
      origin,
      maxDistance: Balance.chakramReach * 1.5,
    );
    if (target == null) return false;
    final aim = target.position - origin;
    for (var i = 0; i < discCount; i++) {
      final offset = (i - (discCount - 1) / 2) * 0.5;
      world.add(
        _Disc(
          weapon: this,
          position: origin.clone(),
          direction: (aim.clone()..rotate(offset))..normalize(),
          radius: Balance.chakramRadius * areaMultiplier * (awakened ? 1.5 : 1),
          speed: Balance.chakramSpeed * speedMultiplier,
        ),
      );
    }
    return true;
  }
}

class _Disc extends PositionComponent with HasWorldReference<RunWorld> {
  _Disc({
    required this.weapon,
    required super.position,
    required this.direction,
    required this.radius,
    required this.speed,
  }) : super(priority: 7);

  final Chakram weapon;
  final Vector2 direction;
  final double radius;
  final double speed;
  double _travelled = 0;
  bool _returning = false;
  double _t = 0;
  final _lastHit = <Enemy, double>{};

  static final _blur = Paint()..color = const Color(0x33E8C887);
  static final _awakenBlur = Paint()..color = const Color(0x668FE3FF);

  @override
  void update(double dt) {
    _t += dt;
    if (!_returning) {
      position.addScaled(direction, speed * dt);
      _travelled += speed * dt;
      if (_travelled >= Balance.chakramReach) _returning = true;
    } else {
      final back = world.player.position - position;
      if (back.length < speed * dt + 8) {
        removeFromParent();
        return;
      }
      position.addScaled(back..normalize(), speed * 1.2 * dt);
    }
    for (final enemy in world.enemiesNear(
      position,
      radius + Balance.enemyRadius,
    )) {
      final last = _lastHit[enemy];
      if (last != null && _t - last < Balance.chakramHitInterval) continue;
      _lastHit[enemy] = _t;
      world.player.strike(
        enemy,
        Balance.chakramDamage * weapon.damageMultiplier,
        weapon.id.damageType,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final spin = _t * 30;
    canvas.drawCircle(
      Offset.zero,
      radius * 1.5,
      weapon.awakened ? _awakenBlur : _blur,
    );
    canvas
      ..save()
      ..rotate(spin);
    chakramArt.draw(
      canvas,
      pivot: Offset(chakramArt.width / 2, chakramArt.height / 2),
      scale: radius * 2.4 / chakramArt.width,
    );
    canvas.restore();
  }
}
