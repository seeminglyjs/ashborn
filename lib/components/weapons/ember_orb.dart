import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/damage_number.dart';
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

  bool get hasSurge => level >= Balance.surgeLevel;

  /// 지금까지 시전한 수. 원소 폭주 차례를 센다.
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
    // 지팡이를 내밀어 잔불을 터뜨리고 다시 거둔다.
    world.player.attackPose(
      strike: Balance.shotPoseTime,
      recover: Balance.reloadPoseTime,
      aimX: aim.x,
    );
    final damage = Balance.emberOrbDamage * damageMultiplier;
    casts++;
    // 원소 폭주: 이번 시전은 구체 대신 4원소 레이저를 쏜다.
    if (hasSurge && casts % Balance.surgeEvery == 0) {
      world
        ..add(
          ElementalBeam(
            position: origin.clone(),
            angle: math.atan2(aim.y, aim.x),
            damage: damage * Balance.surgeDamage,
            beamWidth: Balance.surgeWidth * areaMultiplier,
          ),
        )
        ..add(
          CallOut(
            position: origin + Vector2(0, -44),
            text: '원소 폭주!',
            color: const Color(0xFFB8A6FF),
            fontSize: 16,
          ),
        );
      return true;
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

/// 원소 폭주의 4원소 레이저. 쏘는 순간 줄 위의 적을 모두 한 번씩 꿰뚫고, 화염 · 냉기 · 번개 ·
/// 바람 네 가닥이 꼬인 빛줄기로 잠시 남았다가 솎아 내며 사라진다. 피해는 네 원소로 고루 나뉘어
/// 네 가지 축적(점화 · 냉각 · 감전)을 함께 쌓는다.
class ElementalBeam extends PositionComponent with HasWorldReference<RunWorld> {
  ElementalBeam({
    required super.position,
    required this.angle,
    required this.damage,
    required this.beamWidth,
  }) : super(priority: 5);

  @override
  final double angle;
  final double damage;

  /// 레이저 굵기 (월드). 컴포넌트 크기와 상관없다.
  final double beamWidth;
  double _life = 0;

  static const double length = Balance.surgeLength;
  static const _elements = [
    DamageType.fire,
    DamageType.cold,
    DamageType.lightning,
    DamageType.wind,
  ];

  /// 네 가닥의 색 (Endesga 32): 밝은 쪽, 어두운 쪽.
  static const _strands = [
    (Color(0xFFFEAE34), Color(0xFFF77622)),
    (Color(0xFF2CE8F5), Color(0xFF0099DB)),
    (Color(0xFFFEE761), Color(0xFFFEAE34)),
    (Color(0xFF63C74D), Color(0xFF3E8948)),
  ];

  @override
  void onMount() {
    super.onMount();
    final dir = Vector2(math.cos(angle), math.sin(angle));
    for (final enemy in world.enemies.toList()) {
      final rel = enemy.position - position;
      final along = rel.dot(dir);
      if (along < -enemy.radius || along > length + enemy.radius) continue;
      final side = (rel - dir * along).length;
      if (side > beamWidth / 2 + enemy.radius) continue;
      world.player.strike(enemy, damage, DamageType.fire, split: _elements);
    }
    world.shake(0.12);
  }

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= Balance.surgeTime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / Balance.surgeTime;
    // 처음엔 굵게 터졌다가 가늘어진다.
    final half = beamWidth / 2 * (t < 0.15 ? 1.2 : 1.2 - (t - 0.15) * 0.9);
    canvas
      ..save()
      ..rotate(angle);
    PixelFx.glow(canvas, Offset.zero, beamWidth * 1.6, const Color(0xFFB8A6FF));
    final pc = PixelCanvas.fine;
    final px = pc.px;
    final cells = (length / px).floor();
    // 하얀 속.
    final core = math.max(1, (half * 0.35 / px).round());
    for (var x = 0; x < cells; x++) {
      for (var y = -core; y < core; y++) {
        pc.dot(x, y, Pal.white);
      }
    }
    // 속을 감아 도는 네 가닥: 위상을 4분의 1씩 어긋나게 해 꼬인 빛줄기로.
    for (var i = 0; i < _strands.length; i++) {
      final (light, dark) = _strands[i];
      for (var x = 0; x < cells; x++) {
        final phase = x * 0.22 - _life * 30 + i * math.pi / 2;
        final y = (math.sin(phase) * half / px).round();
        final front = math.cos(phase) > 0;
        pc
          ..dot(x, y, front ? light : dark)
          ..dot(x, y + 1, dark);
      }
    }
    pc.flush(canvas, opacity: 1 - PixelFx.fade(t, from: 0.5) / 4);
    canvas.restore();
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

  /// 도트 불덩이: 하얀 속의 머리와 뒤로 끌리는 불꼬리. 각성(유성 잔불)은 속이 더 하얗게 달아오른다.
  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final r = Balance.emberOrbRadius * (explodes ? 1.3 : 1);
    PixelFx.glow(canvas, c, r * 4, const Color(0xFFF77622), strength: 0.45);
    final pc = PixelCanvas.fine;
    PixelFx.comet(
      pc,
      r,
      r * 3.2,
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
