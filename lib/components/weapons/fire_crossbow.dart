import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../data/balance.dart';
import '../../data/weapons.dart';
import 'projectile.dart';
import 'weapon.dart';
import 'weapon_art.dart';

/// 사냥 석궁 (불씨 사냥꾼): 적을 여럿 꿰뚫는 강철 화살.
/// [Balance.volleyLevel] 부터 연사 확률로 한 번 더 쏘고, [Balance.sniperLevel] 부터
/// [Balance.sniperEvery] 번째 사격은 끝없이 꿰뚫는 저격 화살이 된다.
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

  bool get hasSniper => level >= Balance.sniperLevel;

  /// 지금까지 쏜 수. 저격 차례를 센다.
  int shots = 0;

  /// 연사로 한 번 더 쏠 때까지 남은 시간. 없으면 null.
  double? _volley;

  @override
  void update(double dt) {
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
    }
    return true;
  }

  bool _shoot() {
    final origin = world.player.position;
    final target = world.nearestEnemy(
      origin,
      maxDistance: Balance.crossbowRange,
    );
    if (target == null) return false;
    shots++;
    final sniper = hasSniper && shots % Balance.sniperEvery == 0;
    final aim = target.position - origin;
    for (var i = 0; i < arrowCount; i++) {
      final offset = (i - (arrowCount - 1) / 2) * Balance.stormSpread;
      world.add(
        FireArrow(
          position: origin.clone(),
          direction: aim.clone()..rotate(offset),
          damage:
              Balance.crossbowDamage *
              damageMultiplier *
              (sniper ? Balance.sniperDamage : 1),
          type: id.damageType,
          pierce: sniper ? Balance.sniperPierce : pierce,
          speed: Balance.crossbowSpeed * speedMultiplier * (sniper ? 1.3 : 1),
          storm: awakened,
          sniper: sniper,
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
    this.sniper = false,
  }) : super(
         lifetime: Balance.crossbowLifetime,
         size: sniper ? Vector2(32, 8) : Vector2(24, 6),
       );

  /// 폭풍 석궁 화살: 푸른 번개를 두른다.
  final bool storm;

  /// 저격 화살: 크고 하얀 궤적을 길게 남긴다.
  final bool sniper;

  static final _trail = Paint()..color = const Color(0x44E6EEFF);
  static final _sniperTrail = Paint()..color = const Color(0x88FFFFFF);
  static final _stormTrail = Paint()..color = const Color(0x886FD6FF);

  @override
  ShapeHitbox createHitbox() => RectangleHitbox();

  @override
  void render(Canvas canvas) {
    final trail = sniper ? 40.0 : (storm ? 18.0 : 10.0);
    canvas.drawRect(
      Rect.fromLTWH(-trail, size.y * 0.3, trail + 4, size.y * 0.4),
      storm ? _stormTrail : (sniper ? _sniperTrail : _trail),
    );
    boltArt.draw(
      canvas..translate(0, size.y / 2),
      pivot: Offset(0, boltArt.height / 2),
      scale: size.x / boltArt.width,
    );
  }
}
