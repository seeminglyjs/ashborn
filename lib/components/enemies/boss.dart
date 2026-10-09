import '../../data/balance.dart';
import 'enemy.dart';

/// 지역의 보스. 크고 단단하며, 주기적으로 플레이어에게 돌진한다.
class Boss extends Enemy {
  Boss({
    required super.position,
    required super.maxHp,
    required super.contactDamage,
    required super.damageType,
    required super.speed,
    required super.color,
    super.sprite,
    required this.name,
  }) : _walkSpeed = speed,
       super(radius: Balance.bossRadius, priority: 8);

  final String name;
  final double _walkSpeed;
  double _chargeTimer = Balance.bossChargeInterval;
  double _charging = 0;

  bool get isCharging => _charging > 0;

  @override
  void update(double dt) {
    if (_charging > 0) {
      _charging -= dt;
    } else {
      _chargeTimer -= dt;
      if (_chargeTimer <= 0) {
        _chargeTimer = Balance.bossChargeInterval;
        _charging = Balance.bossChargeDuration;
      }
    }
    speed = _walkSpeed * (isCharging ? Balance.bossChargeSpeed : 1);
    super.update(dt);
  }

  @override
  void onDeath() => world.onBossDefeated(this);
}
