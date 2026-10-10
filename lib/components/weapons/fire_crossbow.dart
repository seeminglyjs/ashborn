import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import '../effects/damage_number.dart';
import '../enemies/enemy.dart';
import 'greatsword.dart';
import 'projectile.dart';
import 'weapon.dart';
import 'weapon_art.dart';

/// 사냥 석궁 (불씨 사냥꾼): 적을 여럿 꿰뚫는 강철 화살.
/// [Balance.volleyLevel] 부터 연사 확률로 한 번 더 쏘고, [Balance.headshotLevel] 부터
/// 사격마다 [Balance.headshotChance] 확률로 끝없이 꿰뚫는 헤드샷 화살이 된다.
/// [Balance.hunterOnslaughtLevel] 부터는 연사가 [Balance.onslaughtStreak] 번 연달아 나면
/// 기사의 대검처럼 맹공에 들어가 잠시 쿨다운이 짧아진다.
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

  /// 연사 확률 (레벨업과 초월 투사체 옵션).
  double get volleyChance => level >= Balance.volleyLevel
      ? stat(WeaponStat.combo) +
            world.player.extraProjectiles * Balance.comboPerProjectile
      : 0;

  bool get hasHeadshot => level >= Balance.headshotLevel;

  bool get hasOnslaught => level >= Balance.hunterOnslaughtLevel;

  /// 지금까지 쏜 수.
  int shots = 0;

  /// 끊기지 않고 연달아 난 연사 수. 맹공에 들어가면 0으로 돌아간다.
  int streak = 0;

  /// 남은 맹공 시간.
  double onslaught = 0;
  bool get inOnslaught => onslaught > 0;

  @override
  double get cooldown =>
      super.cooldown * (inOnslaught ? Balance.onslaughtCooldown : 1);

  /// 연사로 한 번 더 쏠 때까지 남은 시간. 없으면 null.
  double? _volley;

  @override
  void update(double dt) {
    if (onslaught > 0) onslaught -= dt;
    if (_volley case final t?) {
      _volley = t - dt;
      if (_volley! <= 0) {
        _volley = null;
        _shoot();
      }
    }
    super.update(dt);
  }

  @override
  bool fire() {
    if (!_shoot()) return false;
    if (world.game.random.nextDouble() < volleyChance) {
      _volley = Balance.volleyDelay;
      _onVolley();
    } else {
      streak = 0;
    }
    return true;
  }

  void _onVolley() {
    streak++;
    if (hasOnslaught && streak >= Balance.onslaughtStreak) {
      streak = 0;
      final starting = !inOnslaught;
      onslaught = Balance.onslaughtDuration + world.player.onslaughtBonus;
      if (starting) announceOnslaught(world);
    }
  }

  bool _shoot() {
    final origin = world.player.position;
    final target = world.nearestEnemy(
      origin,
      maxDistance: Balance.crossbowRange,
    );
    if (target == null) return false;
    shots++;
    final headshot =
        hasHeadshot && world.game.random.nextDouble() < Balance.headshotChance;
    final aim = target.position - origin;
    // 쏜 반동으로 몸이 밀렸다가 다시 화살을 메긴다.
    world.player.attackPose(
      strike: Balance.shotPoseTime,
      recover: Balance.reloadPoseTime,
      aimX: aim.x,
    );
    for (var i = 0; i < arrowCount; i++) {
      final offset = (i - (arrowCount - 1) / 2) * Balance.stormSpread;
      world.add(
        FireArrow(
          position: origin.clone(),
          direction: aim.clone()..rotate(offset),
          damage:
              Balance.crossbowDamage *
              damageMultiplier *
              (headshot ? Balance.headshotDamage : 1),
          type: id.damageType,
          pierce: headshot ? Balance.headshotPierce : pierce,
          speed: Balance.crossbowSpeed * speedMultiplier * (headshot ? 1.3 : 1),
          storm: awakened,
          headshot: headshot,
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
    this.headshot = false,
  }) : super(
         bleeds: headshot,
         lifetime: Balance.crossbowLifetime,
         size: headshot ? Vector2(32, 8) : Vector2(24, 6),
       );

  /// 폭풍 석궁 화살: 푸른 번개를 두른다.
  final bool storm;

  /// 헤드샷 화살: 크고 하얀 궤적을 길게 남기고, 맞힌 적마다 반드시 출혈을 걸며,
  /// 처음 맞힌 적 머리 위에 "헤드샷!" 을 띄운다.
  final bool headshot;
  bool _called = false;

  static final _trail = Paint()..color = const Color(0x44E6EEFF);
  static final _sniperTrail = Paint()..color = const Color(0x88FFFFFF);
  static final _stormTrail = Paint()..color = const Color(0x886FD6FF);

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void onHit(Enemy enemy) {
    if (!headshot || _called) return;
    _called = true;
    world.add(
      CallOut(
        position: enemy.position + Vector2(0, -enemy.radius - 18),
        text: '헤드샷!',
        color: const Color(0xFFFFE08A),
        fontSize: 15,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final trail = headshot ? 40.0 : (storm ? 18.0 : 10.0);
    canvas.drawRect(
      Rect.fromLTWH(-trail, size.y * 0.3, trail + 4, size.y * 0.4),
      storm ? _stormTrail : (headshot ? _sniperTrail : _trail),
    );
    boltArt.draw(
      canvas..translate(0, size.y / 2),
      pivot: Offset(0, boltArt.height / 2),
      scale: size.x / boltArt.width,
    );
  }
}
