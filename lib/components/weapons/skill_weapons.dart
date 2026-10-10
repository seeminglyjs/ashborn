import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/class_passives.dart';
import '../../data/weapons.dart';
import '../../game/world/run_world.dart';
import '../effects/damage_number.dart';
import '../effects/pixel_fx.dart';
import '../effects/sparks.dart';
import '../enemies/enemy.dart';
import 'weapon.dart';
import 'weapon_art.dart';

/// 전투 함성 (잿불 기사): 둘레 적을 다치게 하고 느리게 묶으며, 외친 뒤 잠시 받는 피해가 준다.
/// 각성(전쟁의 포효)하면 적을 밀쳐 내고 더 오래 묶는다. 특성 '불굴의 함성' 이 쿨다운과 방어를 더한다.
class WarCry extends Weapon {
  WarCry() : super(baseCooldown: Balance.warCryCooldown);

  @override
  WeaponId get id => WeaponId.warCry;

  double get radius =>
      Balance.warCryRadius * areaMultiplier * (awakened ? 1.2 : 1);

  @override
  bool fire() {
    final player = world.player;
    final at = player.position;
    final targets = world.enemiesNear(at, radius).toList();
    if (targets.isEmpty) return false;
    final hold =
        Balance.warCrySlowTime * durationMultiplier * (awakened ? 1.5 : 1);
    for (final enemy in targets) {
      player.strike(
        enemy,
        Balance.warCryDamage * damageMultiplier,
        id.damageType,
      );
      enemy.ailments.chill(Balance.warCrySlow, hold);
      if (awakened) enemy.knock(enemy.position - at, 260);
    }
    player.guard(
      Balance.warCryGuard + skillBonus(SkillBonus.guard),
      Balance.warCryGuardTime * durationMultiplier,
    );
    world
      ..add(ShoutWave(position: at.clone(), radius: radius, roar: awakened))
      ..add(
        CallOut(
          position: at + Vector2(0, -46),
          text: awakened ? '포효!' : '함성!',
          color: Pal.goldLight,
          fontSize: 16,
        ),
      )
      ..shake(0.1);
    return true;
  }
}

/// 함성 연출: 금빛 도트 고리 세 겹이 차례로 퍼지고, 사방으로 소리 줄기가 뻗는다.
class ShoutWave extends PositionComponent {
  ShoutWave({required super.position, required this.radius, this.roar = false})
    : super(priority: 6);

  final double radius;
  final bool roar;
  static const double duration = 0.5;
  double _life = 0;

  @override
  void update(double dt) {
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _life / duration;
    final pc = PixelCanvas.shared;
    final tones = roar
        ? const [Pal.white, Pal.goldLight, Color(0xFFF77622)]
        : const [Pal.white, Pal.goldLight, Pal.gold];
    PixelFx.glow(
      canvas,
      Offset.zero,
      radius * 0.6,
      Pal.gold,
      strength: 0.4 * (1 - t),
    );
    for (var k = 0; k < 3; k++) {
      final local = (t - k * 0.15) / 0.7;
      if (local <= 0 || local >= 1) continue;
      final ease = 1 - math.pow(1 - local, 2).toDouble();
      PixelFx.ring(
        pc,
        radius * (0.2 + 0.8 * ease),
        k == 0 ? 3 : 2,
        tones,
        thin: PixelFx.fade(local, from: 0.5),
      );
    }
    if (t < 0.45) {
      // 소리 줄기: 고리 바깥으로 짧게 끊어진 선들.
      final r0 = radius * (0.3 + t);
      PixelFx.rays(pc, 12, r0, r0 + radius * 0.25, Pal.white, Pal.goldLight);
    }
    pc.flush(canvas);
  }
}

/// 잔불 정령 (재의 마녀): 몸 둘레를 도는 불덩이 정령. 닿은 적을 정해진 간격마다 태운다.
/// 각성(불새 정령)하면 하나 더 늘고 더 크다. 특성 '정령 계약' 이 피해와 회전 속도를 더한다.
class EmberSpirits extends PositionComponent
    with HasWorldReference<RunWorld>, LeveledWeapon {
  EmberSpirits() : super(priority: 8);

  @override
  WeaponId get id => WeaponId.emberSpirits;

  double _turn = 0;
  double _t = 0;
  final _lastHit = <Enemy, double>{};

  int get count =>
      2 + bonusCount + (awakened ? 1 : 0) + world.player.extraProjectiles;

  double get orbit => Balance.spiritOrbit * (1 + (areaMultiplier - 1) * 0.5);

  double get spiritRadius =>
      Balance.spiritRadius * areaMultiplier * (awakened ? 1.3 : 1);

  /// 정령 [i] 의 지금 자리 (플레이어 기준).
  Vector2 offsetOf(int i) {
    final a = _turn + math.pi * 2 * i / count;
    return Vector2(math.cos(a), math.sin(a) * 0.8)..scale(orbit);
  }

  @override
  void onMount() {
    super.onMount();
    position = world.player.size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _turn +=
        Balance.spiritTurnSpeed *
        speedMultiplier *
        world.player.attackSpeedMultiplier *
        dt;
    final player = world.player;
    final reach = spiritRadius + Balance.enemyRadius;
    final interval = Balance.spiritHitInterval;
    for (var i = 0; i < count; i++) {
      final at = player.position + offsetOf(i);
      for (final enemy in world.enemiesNear(at, reach)) {
        final last = _lastHit[enemy];
        if (last != null && _t - last < interval) continue;
        _lastHit[enemy] = _t;
        player.strike(
          enemy,
          Balance.spiritDamage * damageMultiplier,
          id.damageType,
        );
      }
    }
    if (_lastHit.length > 64) _lastHit.removeWhere((e, _) => e.isDead);
  }

  /// 정령마다 도는 쪽을 향한 도트 불덩이 (꼬리는 지나온 쪽). 불새는 더 하얗게 달아오른다.
  @override
  void render(Canvas canvas) {
    final pc = PixelCanvas.fine;
    final r = spiritRadius;
    for (var i = 0; i < count; i++) {
      final o = offsetOf(i);
      final a = _turn + math.pi * 2 * i / count;
      // 원을 따라 도는 방향 (접선).
      final heading = math.atan2(math.cos(a) * 0.8, -math.sin(a));
      PixelFx.glow(
        canvas,
        Offset(o.x, o.y),
        r * 3,
        const Color(0xFFF77622),
        strength: 0.4,
      );
      PixelFx.comet(
        pc,
        r * 0.7,
        r * 2.4,
        time: _t + i,
        salt: i * 31,
        tones: awakened
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
      // 정령의 눈 두 칸.
      pc
        ..dot(0, -1, Pal.outline)
        ..dot(0, 0, Pal.outline);
      canvas
        ..save()
        ..translate(o.x, o.y)
        ..rotate(heading);
      pc.flush(canvas);
      canvas.restore();
    }
  }
}

/// 올가미 그물 (불씨 사냥꾼): 가까운 적 무리에 그물을 던진다. 그물 안의 적은 한동안 느리게 묶이고
/// 떨어질 때 다친다. 각성(가시 그물)하면 묶인 적을 계속 벤다. 특성 '사냥 그물' 이 시간과 감속을 더한다.
class SnareNet extends Weapon {
  SnareNet() : super(baseCooldown: Balance.netCooldown);

  @override
  WeaponId get id => WeaponId.snareNet;

  int get netCount => 1 + bonusCount + world.player.extraProjectiles;

  @override
  bool fire() {
    final player = world.player;
    final first = world.nearestEnemy(
      player.position,
      maxDistance: Balance.netRange,
    );
    if (first == null) return false;
    final others = world.enemiesNear(player.position, Balance.netRange).toList()
      ..shuffle(world.game.random);
    final targets = [first, ...others.where((e) => e != first)];
    final radius = Balance.netRadius * areaMultiplier;
    final slow = math.min(0.9, Balance.netSlow + skillBonus(SkillBonus.slow));
    for (var i = 0; i < netCount && i < targets.length; i++) {
      world.add(
        ThrownNet(
          from: player.position.clone(),
          to: targets[i].position.clone(),
          radius: radius,
          damage: Balance.netDamage * damageMultiplier,
          slow: slow,
          hold: Balance.netTime * durationMultiplier,
          thorns: awakened,
          weapon: this,
        ),
      );
    }
    return true;
  }
}

/// 날아가는 그물: 접힌 그물 뭉치가 돌며 포물선으로 날아가 떨어진 자리에 펼쳐진다.
class ThrownNet extends PositionComponent with HasWorldReference<RunWorld> {
  ThrownNet({
    required Vector2 from,
    required this.to,
    required this.radius,
    required this.damage,
    required this.slow,
    required this.hold,
    required this.thorns,
    required this.weapon,
  }) : _from = from,
       super(position: from.clone(), priority: 8);

  final Vector2 _from;
  final Vector2 to;
  final double radius;
  final double damage;
  final double slow;
  final double hold;
  final bool thorns;
  final SnareNet weapon;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    final k = math.min(1.0, _t / Balance.netFlightTime);
    position
      ..setFrom(_from)
      ..lerp(to, k)
      ..y -= math.sin(k * math.pi) * 40;
    if (k < 1) return;
    world.add(
      NetTrap(
        position: to.clone(),
        radius: radius,
        damage: damage,
        slow: slow,
        hold: hold,
        thorns: thorns,
        weapon: weapon,
      ),
    );
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final pc = PixelCanvas.fine;
    // 접힌 그물 뭉치: 얽힌 밧줄 칸과 무게추.
    for (var y = -2; y < 2; y++) {
      for (var x = -2; x < 2; x++) {
        pc.dot(x, y, (x + y).isEven ? Pal.leatherLight : Pal.leather);
      }
    }
    pc
      ..dot(-3, -3, Pal.steel)
      ..dot(2, -3, Pal.steel)
      ..dot(-3, 2, Pal.steel)
      ..dot(2, 2, Pal.steel);
    canvas
      ..save()
      ..rotate(_t * 14);
    pc.flush(canvas);
    canvas.restore();
  }
}

/// 땅에 펼쳐진 그물. 안의 적을 묶어 두고, 펼쳐지는 순간 다치게 한다. 가시 그물은 계속 벤다.
class NetTrap extends PositionComponent with HasWorldReference<RunWorld> {
  NetTrap({
    required super.position,
    required this.radius,
    required this.damage,
    required this.slow,
    required this.hold,
    required this.thorns,
    required this.weapon,
  }) : super(priority: -20);

  final double radius;
  final double damage;
  final double slow;
  final double hold;
  final bool thorns;
  final SnareNet weapon;
  double _t = 0;
  double _tick = 0;

  @override
  void onMount() {
    super.onMount();
    final player = world.player;
    for (final enemy in world.enemiesNear(position, radius)) {
      player.strike(enemy, damage, weapon.id.damageType);
    }
    world.add(
      Sparks(
        position: position.clone(),
        color: Pal.leatherLight,
        count: 8,
        speed: 140,
      ),
    );
  }

  @override
  void update(double dt) {
    _t += dt;
    _tick -= dt;
    if (_tick <= 0) {
      _tick = 0.3;
      for (final enemy in world.enemiesNear(position, radius)) {
        enemy.ailments.chill(slow, 0.45);
        if (thorns) {
          world.player.strike(
            enemy,
            damage * 0.3,
            weapon.id.damageType,
            secondary: true,
          );
        }
      }
    }
    if (_t >= hold) removeFromParent();
  }

  /// 도트 그물: 둥근 테두리 밧줄 안에 마름모 그물코, 매듭은 금빛(가시 그물은 붉은 가시).
  /// 펼쳐질 때 바깥으로 퍼지고, 사라질 때 솎아 낸다.
  @override
  void render(Canvas canvas) {
    final pc = PixelCanvas.fine;
    final px = pc.px;
    final open = math.min(1.0, _t / 0.15);
    final r = radius * (0.5 + 0.5 * open);
    final left = (hold - _t) / 0.4;
    final thin = left >= 1 ? 0 : PixelFx.fade(1 - left, from: 0);
    final cells = (r / px).ceil();
    const mesh = 9;
    for (var y = -cells; y <= cells; y++) {
      for (var x = -cells; x <= cells; x++) {
        // 땅에 누운 그물이라 세로를 눌러 납작하게 본다.
        final d = math.sqrt(x * x + (y * 1.6) * (y * 1.6)) * px;
        if (d > r || PixelFx.thinned(x, y, thin)) continue;
        final a = (x + y) % mesh == 0;
        final b = (x - y) % mesh == 0;
        if (d > r - px * 1.5) {
          pc.dot(x, y, Pal.leather);
        } else if (a && b) {
          pc.dot(x, y, thorns ? Pal.red : Pal.gold);
        } else if (a || b) {
          pc.dot(x, y, Pal.leatherLight);
        }
      }
    }
    pc.flush(canvas, opacity: 0.9);
  }
}
