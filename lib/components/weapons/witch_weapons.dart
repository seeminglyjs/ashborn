import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/damage.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/burst.dart';
import '../effects/pixel_fx.dart';
import 'weapon_art.dart';
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

  static final _shadow = Paint()..color = const Color(0x66000000);

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

  /// 떨어지기 전: 바닥에 도트 그림자 표적이 커지고, 오른쪽 위에서 불꼬리를 끄는 운석이 내리꽂힌다.
  /// 떨어진 뒤(각성): 그 자리에 도트 불길이 일렁인다.
  @override
  void render(Canvas canvas) {
    final pc = PixelCanvas.fine;
    if (_landed) {
      _renderBurn(canvas, pc);
      return;
    }
    final t = (_t / delay).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 1.4 * t,
        height: radius * 0.6 * t,
      ),
      _shadow,
    );
    // 표적 고리: 바닥에 납작한 금빛 도트 고리.
    PixelFx.ring(pc, radius * 0.75 * t, 1, const [Pal.gold], thin: 1);
    canvas
      ..save()
      ..scale(1, 0.45);
    pc.flush(canvas);
    canvas.restore();
    // 운석: 오른쪽 위에서 비스듬히 떨어진다. 꼬리는 지나온 쪽으로.
    final fall = 1 - t;
    final at = Offset(170 * fall, -260 * fall);
    PixelFx.glow(canvas, at, 40, const Color(0xFFF77622), strength: 0.6);
    PixelFx.comet(pc, 9, 46, time: _t, salt: hashCode & 0xFFFF);
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(math.atan2(260, -170));
    pc.flush(canvas);
    canvas.restore();
  }

  /// 타오르는 땅: 납작한 원 안에서 불꽃 혀가 솟았다 잦아든다.
  void _renderBurn(Canvas canvas, PixelCanvas pc) {
    final left = delay + Balance.meteorBurnTime - _t;
    final thin = left < 0.4 ? PixelFx.fade(1 - left / 0.4, from: 0) : 0;
    PixelFx.glow(
      canvas,
      Offset.zero,
      radius * 1.3,
      const Color(0xFFF77622),
      strength: 0.45,
    );
    final px = pc.px;
    final cells = (radius * 0.8 / px).ceil();
    final beat = (_t * 10).floor();
    for (var y = -cells; y <= cells; y++) {
      for (var x = -cells; x <= cells; x++) {
        final e = (x * x + (y * y) * 4.0) / (cells * cells);
        if (e > 1 || PixelFx.thinned(x, y, thin)) continue;
        // 바닥은 검붉게 그을리고 군데군데 불씨가 빛난다.
        final h = PixelFx.hash(x, y, 9);
        pc.dot(
          x,
          y,
          h > 0.85
              ? const Color(0xFFF77622)
              : (h > 0.4 ? Pal.redDark : const Color(0xFF3E2731)),
        );
      }
    }
    for (var i = 0; i < 9; i++) {
      final fx = ((PixelFx.hash(i, 1, hashCode) - 0.5) * cells * 1.6).round();
      final fy = ((PixelFx.hash(i, 2, hashCode) - 0.5) * cells * 0.8).round();
      final h = 2 + (PixelFx.hash(i, beat, hashCode) * 5).floor();
      for (var k = 0; k < h; k++) {
        final c = k == h - 1
            ? Pal.goldLight
            : (k > h / 2 ? Pal.gold : const Color(0xFFF77622));
        pc.dot(fx, fy - k, c);
        if (k < h / 2) pc.dot(fx + 1, fy - k, Pal.red);
      }
    }
    pc.flush(canvas);
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
       _salt = math.Random().nextInt(1 << 16),
       super(priority: 7);

  final FireTornado weapon;
  final double radius;
  final double speed;
  final bool homing;
  final Vector2 _dir;
  double _life;
  final int _salt;
  double _t = 0;
  final _lastHit = <Enemy, double>{};

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

  /// 도트 화염 회오리: 아래는 좁고 위로 갈수록 넓어지는 불기둥에 비스듬한 소용돌이 줄무늬가
  /// 돌아 올라가고, 발밑에는 불꽃 고리와 바닥 섬광, 둘레로 불티가 튄다.
  /// 줄무늬가 지나가지 않는 틈은 비워 바람 가닥처럼 보이게 한다.
  @override
  void render(Canvas canvas) {
    final pc = PixelCanvas.fine;
    final px = pc.px;
    // 나타날 때 바닥에서 솟아오르고, 사라질 때 솎아 내며 흩어진다.
    final rise = math.min(1.0, _t / 0.25);
    final left = _life / 0.45;
    final thin = left >= 1 ? 0 : PixelFx.fade(1 - left, from: 0);
    final r = radius;
    final height = r * 4.2 * (0.35 + 0.65 * rise);
    PixelFx.glow(
      canvas,
      Offset(0, -height * 0.4),
      height * 0.75,
      Pal.gold,
      strength: 0.35,
    );
    PixelFx.glow(
      canvas,
      Offset.zero,
      r * 2.2,
      const Color(0xFFF77622),
      strength: 0.6,
    );

    // 바닥: 납작한 불꽃 고리와 사방으로 튀는 짧은 섬광.
    final beat = (_t * 12).floor();
    for (var k = 0; k < 10; k++) {
      final a = math.pi * 2 * (k + PixelFx.hash(k, beat, _salt) * 0.6) / 10;
      final len = r * (1.2 + 0.7 * PixelFx.hash(k, beat, _salt + 1));
      final dir = Offset(math.cos(a), math.sin(a) * 0.38);
      PixelFx.line(
        pc,
        dir * r * 0.9,
        dir * len,
        k.isEven ? Pal.gold : const Color(0xFFF77622),
      );
    }
    final ringW = (r * 1.15 / px).round();
    final ringH = math.max(2, (r * 0.4 / px).round());
    for (var y = -ringH; y <= ringH; y++) {
      for (var x = -ringW; x <= ringW; x++) {
        final e = (x * x) / (ringW * ringW) + (y * y) / (ringH * ringH);
        if (e > 1 || e < 0.45 || PixelFx.thinned(x, y, thin)) continue;
        final flicker = PixelFx.hash(x, y + beat, _salt) > 0.75;
        pc.dot(
          x,
          y,
          e > 0.8
              ? (flicker ? Pal.gold : const Color(0xFFF77622))
              : Pal.goldLight,
        );
      }
    }

    // 불기둥: 줄마다 폭과 흔들림을 정하고, 칸마다 소용돌이 줄무늬 밝기로 색을 고른다.
    // 줄무늬는 높이를 따라 여러 번 감기며 돌아 올라간다. 몸통은 채우고 가장자리만 가닥으로 흩는다.
    final rows = (height / px).ceil();
    double centerAt(double u) => math.sin(_t * 5 + u * 3.2) * r * 0.18 * u;
    double halfAt(double u) => r * (0.18 + 0.95 * math.pow(u, 0.8));
    for (var k = 0; k < rows; k++) {
      final u = k / rows;
      final half = halfAt(u);
      final center = centerAt(u);
      final x0 = ((center - half) / px).floor();
      final x1 = ((center + half) / px).ceil();
      final y = -k - 1;
      for (var x = x0; x <= x1; x++) {
        if (PixelFx.thinned(x, y, thin)) continue;
        final v = (((x + 0.5) * px - center) / half).clamp(-1.0, 1.0);
        final theta = math.asin(v);
        final stripe = math.sin(theta * 1.7 + u * 24 - _t * 18);
        final edge = v.abs();
        // 가장자리에서 줄무늬 골이 지나가면 비워 바람 가닥이 갈라져 보이게 한다.
        if (edge > 0.72 && stripe < -0.2) continue;
        final value =
            (0.5 + 0.5 * stripe) * 0.55 +
            (1 - edge) * 0.45 +
            (u < 0.12 ? 0.3 * (1 - u / 0.12) : 0);
        final Color color;
        if (value > 0.93) {
          color = Pal.white;
        } else if (value > 0.76) {
          color = Pal.goldLight;
        } else if (value > 0.58) {
          color = Pal.gold;
        } else if (value > 0.42) {
          color = const Color(0xFFF77622);
        } else if (value > 0.28) {
          color = Pal.red;
        } else {
          color = Pal.redDark;
        }
        pc.dot(x, y, color);
      }
    }
    // 위쪽 입구: 비스듬히 보이는 납작한 고리. 회오리가 위로 열려 있는 깔때기로 읽힌다.
    final lipHalf = halfAt(1) / px;
    final lipH = math.max(1.5, lipHalf * 0.28);
    final lipCenter = centerAt(1) / px;
    final lipY = -rows - 1;
    for (var y = -lipH.ceil(); y <= lipH.ceil(); y++) {
      for (var x = -lipHalf.ceil() - 1; x <= lipHalf.ceil() + 1; x++) {
        final e = (x * x) / (lipHalf * lipHalf) + (y * y) / (lipH * lipH);
        if (e > 1.05 || e < 0.55 || PixelFx.thinned(x, y, thin)) continue;
        final front = y > 0;
        pc.dot(
          x + lipCenter.round(),
          lipY + y,
          front ? Pal.goldLight : const Color(0xFFF77622),
        );
      }
    }
    // 둘레로 솟는 불티.
    for (var i = 0; i < 7; i++) {
      final seed = PixelFx.hash(i, 5, _salt);
      final climb = ((_t * (40 + seed * 50) + seed * height) % height);
      final spread = r * (0.4 + 0.9 * climb / height);
      final x = math.sin(i * 2.4 + _t * 3) * spread;
      pc.dot(
        (x / px).floor(),
        (-climb / px).floor(),
        i.isEven ? Pal.goldLight : Pal.gold,
      );
    }
    pc.flush(canvas);
  }
}
