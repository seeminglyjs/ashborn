import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/ground_fx.dart';
import '../effects/pixel_fx.dart';
import 'weapon_art.dart';
import '../effects/sparks.dart';
import 'weapon.dart';

/// 대지 강타 (잿불 기사): 둘레 땅을 내려쳐 적을 다치게 하고 멀리 밀어낸다.
/// 각성(지진)하면 한 박자 뒤 더 넓은 여진이 한 번 더 퍼진다.
class EarthSlam extends Weapon {
  EarthSlam() : super(baseCooldown: Balance.earthSlamCooldown);

  @override
  WeaponId get id => WeaponId.earthSlam;

  double get radius => Balance.earthSlamRadius * areaMultiplier;

  static const _color = Color(0xFFE0A060);
  static const _quakeColor = Color(0xFFFFE08A);

  @override
  bool fire() {
    final at = world.player.position;
    if (world.enemiesNear(at, radius).isEmpty) return false;
    slam(world, at.clone(), radius, awakened ? _quakeColor : _color);
    if (awakened) {
      world.add(
        _Aftershock(
          weapon: this,
          at: at.clone(),
          radius: radius * Balance.aftershockScale,
        ),
      );
    }
    return true;
  }

  void slam(RunWorld world, Vector2 at, double radius, Color color) {
    world
      ..add(Ring(position: at, radius: radius, color: color, strokeWidth: 10))
      ..add(
        EarthSpikes(
          position: at.clone(),
          radius: radius * 0.85,
          count: 12,
          ember: color == _quakeColor,
        ),
      )
      ..add(Sparks(position: at.clone(), color: color, count: 10, speed: 200))
      ..shake(0.12);
    for (final enemy in world.enemiesNear(at, radius)) {
      world.player.strike(
        enemy,
        Balance.earthSlamDamage * damageMultiplier,
        id.damageType,
      );
      enemy.knock(enemy.position - at, Balance.earthSlamKnockback);
    }
  }
}

class _Aftershock extends Component with HasWorldReference<RunWorld> {
  _Aftershock({required this.weapon, required this.at, required this.radius});

  final EarthSlam weapon;
  final Vector2 at;
  final double radius;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t < Balance.aftershockDelay) return;
    weapon.slam(world, at, radius, EarthSlam._quakeColor);
    removeFromParent();
  }
}

/// 심판의 일격 (잿불 기사): 가장 가까운 적 쪽을 넓은 반달로 벤다. 개수가 늘면 다른 방향도 함께.
/// 각성(심판의 검)하면 등 뒤도 함께 베고 참격이 더 커진다.
class Cleave extends Weapon {
  Cleave() : super(baseCooldown: Balance.cleaveCooldown);

  @override
  WeaponId get id => WeaponId.cleave;

  double get radius =>
      Balance.cleaveRadius * areaMultiplier * (awakened ? 1.25 : 1);

  /// 한 번에 베는 방향 수.
  int get slashes =>
      1 + bonusCount + (awakened ? 1 : 0) + world.player.extraProjectiles;

  @override
  bool fire() {
    final player = world.player;
    final at = player.position;
    if (world.enemiesNear(at, radius).isEmpty) return false;
    // 도망치며 싸워도 헛치지 않게 가장 가까운 적 쪽을 벤다.
    final target = world.nearestEnemy(at, maxDistance: radius)!;
    final aim = target.position - at;
    final base = math.atan2(aim.y, aim.x);
    final count = slashes;
    for (var i = 0; i < count; i++) {
      final angle = base + math.pi * 2 * i / count;
      world.add(
        SlashArc(
          position: at.clone(),
          angle: angle,
          radius: radius,
          awakened: awakened,
        ),
      );
      for (final enemy in world.enemiesNear(at, radius)) {
        final to = enemy.position - at;
        var diff = math.atan2(to.y, to.x) - angle;
        diff = math.atan2(math.sin(diff), math.cos(diff));
        if (diff.abs() > Balance.cleaveArc) continue;
        player.strike(
          enemy,
          Balance.cleaveDamage * damageMultiplier,
          id.damageType,
        );
      }
    }
    return true;
  }
}

/// 반달 모양 참격. 휘두르는 방향으로 쓸고 지나가며 사라진다.
class SlashArc extends PositionComponent {
  SlashArc({
    required super.position,
    required double angle,
    required this.radius,
    this.awakened = false,
  }) : super(angle: angle, priority: 7);

  final double radius;
  final bool awakened;
  static const double duration = 0.18;
  double _life = 0;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  /// 도트 반달 참격: 휘두른 만큼 초승달이 그려지고, 바깥 날은 하얗게, 안쪽은 칼자국 색.
  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    const arc = Balance.cleaveArc;
    final sweep = arc * 2 * math.min(1, t * 2.5);
    final base = awakened ? const Color(0xFF8FE3FF) : Pal.gold;
    PixelFx.glow(
      canvas,
      Offset(radius * 0.6, 0),
      radius * 0.7,
      base,
      strength: 0.35 * (1 - t),
    );
    final pc = PixelCanvas.fine;
    PixelFx.arc(pc, radius * 0.45, radius * 0.95, -arc, sweep, [
      Pal.white,
      Color.lerp(base, Pal.white, 0.45)!,
      base,
      awakened ? const Color(0xFF124E89) : const Color(0xFFF77622),
    ], thin: PixelFx.fade(t, from: 0.45));
    pc.flush(canvas);
  }
}
