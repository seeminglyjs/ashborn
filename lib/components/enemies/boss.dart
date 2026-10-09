import 'dart:ui';

import '../../data/balance.dart';
import 'enemy.dart';

/// 지역의 보스. 크고 단단하며, 주기적으로 플레이어에게 돌진한다.
/// [Balance.bossEnrageTime] 안에 잡지 못하면 광폭화한다.
class Boss extends Enemy {
  Boss({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    required this.name,
  }) : _walkSpeed = speed,
       super(radius: Balance.bossRadius, priority: 8);

  static const enrageColor = Color(0xFFFF1F1F);

  final String name;
  final double _walkSpeed;
  double _chargeTimer = Balance.bossChargeInterval;
  double _charging = 0;

  /// 나온 뒤 지난 시간.
  double age = 0;

  bool get isCharging => _charging > 0;
  bool get isEnraged => age >= Balance.bossEnrageTime;

  /// 광폭화까지 남은 시간.
  double get untilEnrage => Balance.bossEnrageTime - age;

  @override
  double get damage =>
      contactDamage * (isEnraged ? Balance.bossEnrageDamage : 1);

  @override
  void update(double dt) {
    final wasEnraged = isEnraged;
    age += dt;
    if (isEnraged && !wasEnraged) world.onBossEnraged(this);
    if (_charging > 0) {
      _charging -= dt;
    } else {
      _chargeTimer -= dt;
      if (_chargeTimer <= 0) {
        _chargeTimer = Balance.bossChargeInterval;
        _charging = Balance.bossChargeDuration;
      }
    }
    speed = isEnraged
        ? world.player.speed * Balance.bossEnrageChase
        : _walkSpeed * (isCharging ? Balance.bossChargeSpeed : 1);
    super.update(dt);
    if (isEnraged) paint.color = enrageColor;
  }

  @override
  void onDeath() => world.onBossDefeated(this);
}
